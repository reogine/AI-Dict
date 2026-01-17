import Foundation
import ApplicationServices
import AppKit

class DictionaryWatcher {
    static let shared = DictionaryWatcher()
    private var observers: [pid_t: AXObserver] = [:]
    
    // Callback now includes the frame of the native window
    var onDictionaryOpened: ((String, NSRect) -> Void)?
    
    func start() {
        print("DEBUG: Starting Dictionary Watcher (Overlay Strategy)...")
        
        // Target LookupViewService specifically
        setupLookupServiceObservation()
        
        // Watch for new apps launching to catch LookupViewService if it starts later
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appLaunched), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    }
    
    private func setupLookupServiceObservation() {
        let lookupBundleID = "com.apple.LookupViewService"
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: lookupBundleID)
        for app in apps {
            observeApp(app)
        }
    }
    
    @objc private func appLaunched(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if app.bundleIdentifier == "com.apple.LookupViewService" {
            print("DEBUG: LookupViewService launched. Attaching observer...")
            observeApp(app)
        }
    }
    
    private func observeApp(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        if observers[pid] != nil { return }
        
        var newObserver: AXObserver?
        let result = AXObserverCreate(pid, { (observer, element, notification, refcon) in
            DictionaryWatcher.shared.handleNotification(element: element, notification: notification)
        }, &newObserver)
        
        guard result == .success, let observer = newObserver else { return }
        
        let element = AXUIElementCreateApplication(pid)
        
        // Listen ONLY for window events to keep it fast
        AXObserverAddNotification(observer, element, kAXWindowCreatedNotification as CFString, UnsafeMutableRawPointer(bitPattern: 0))
        AXObserverAddNotification(observer, element, kAXFocusedWindowChangedNotification as CFString, UnsafeMutableRawPointer(bitPattern: 0))
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
        print("DEBUG: Fast Observer attached to PID: \(pid)")
    }
    
    private func handleNotification(element: AXUIElement, notification: CFString) {
        // COMPANION MODE: Get Native Window Geometry
        
        // Polling loop to wait for window to have valid size/position (it might be 0,0 at creation)
        DispatchQueue.global(qos: .userInteractive).async {
            var rect = NSRect.zero
            var attempts = 0
            
            while attempts < 10 { // Try for 500ms max (10 * 50ms)
                if let pos = self.getAXPoint(element, kAXPositionAttribute),
                   let size = self.getAXSize(element, kAXSizeAttribute),
                   size.width > 10 && size.height > 10 {
                    rect = NSRect(origin: NSPoint(x: pos.x, y: pos.y), size: size)
                    break
                }
                usleep(50000) // 50ms sleep
                attempts += 1
            }
            
            // Trigger our AI window
            if let word = AccessibilityService.shared.getWordAtCursor() {
                print("DEBUG: [COMPANION MODE] Native Rect found: \(rect)")
                DispatchQueue.main.async {
                    self.onDictionaryOpened?(word, rect)
                }
            }
        }
    }
    
    private func getAXPoint(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success {
            var point = CGPoint.zero
            if AXValueGetValue(value as! AXValue, .cgPoint, &point) {
                return point
            }
        }
        return nil
    }
    
    private func getAXSize(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success {
            var size = CGSize.zero
            if AXValueGetValue(value as! AXValue, .cgSize, &size) {
                return size
            }
        }
        return nil
    }
}
