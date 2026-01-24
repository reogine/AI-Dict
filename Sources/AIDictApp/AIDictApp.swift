import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    // State
    var word: String = "Scanning..."
    var definition: String? = nil
    var isLoading: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Monitor for focus loss to hide
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            self.window.orderOut(nil)
        }
        
        // GLOBAL CLICK MONITOR: Hide window if user clicks outside
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            if self.window.isVisible {
                self.window.orderOut(nil)
            }
        }
        
        // LOCAL MONITOR:
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            if self.window.isVisible {
                let clickLocation = event.locationInWindow
                if !self.window.contentView!.frame.contains(clickLocation) {
                    self.window.orderOut(nil)
                }
            }
            return event
        }
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 350),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Initial View State
        let contentView = DefinitionView(word: .constant(self.word), definition: .constant(self.definition), isLoading: .constant(self.isLoading))
        window.contentView = NSHostingView(rootView: contentView)
        
        // NEW: ASYNC SIGNAL
        DictionaryWatcher.shared.onNativeWindowDetected = { nativeRect in
            print("DEBUG: Window Detected! Showing UI immediately...")
            DispatchQueue.main.async {
                self.showScanningWindow(nativeRect: nativeRect)
                self.startAsyncScan()
            }
        }
        DictionaryWatcher.shared.start()
        
        window.orderOut(nil)
        print("DEBUG: AI-Dict Async Companion Ready.")
    }
    
    // STEP 1: Show the window INSTANTLY (Optimistic UI)
    func showScanningWindow(nativeRect: NSRect) {
        self.word = "Scanning..."
        self.definition = nil
        self.isLoading = true
        
        // Refresh View
        let contentView = DefinitionView(word: .constant(self.word), definition: .constant(self.definition), isLoading: .constant(self.isLoading))
        window.contentView = NSHostingView(rootView: contentView)
        
        // Calculate Position
        let mouseLocation = NSEvent.mouseLocation
        let newOrigin = WindowPositioner.calculatePosition(
            for: window.frame,
            nativeRect: nativeRect,
            mouseLocation: mouseLocation
        )
        window.setFrameOrigin(newOrigin)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // STEP 2: Fetch Text in Background
    func startAsyncScan() {
        Task {
            // Artificial delay (optional debug) or just run extraction
            // We use Task.detached or just standard Task to get off main thread
            
            // Note: AccessibilityService.shared.getWordAtCursor() might block slightly, 
            // but we are already shown the window.
            let foundWord = AccessibilityService.shared.getWordAtCursor()
            
            await MainActor.run {
                if let realWord = foundWord {
                    print("DEBUG: Async Scan Found: \(realWord)")
                    self.word = realWord
                    self.fetchDefinition(for: realWord)
                } else {
                    print("DEBUG: Async Scan Failed")
                    self.word = "Text Not Found"
                    self.isLoading = false
                    self.updateView()
                }
            }
        }
    }
    
    func fetchDefinition(for word: String) {
        self.isLoading = true
        self.definition = nil
        self.updateView()
        
        Task {
            let result = await AIService.shared.getDefinition(for: word)
            await MainActor.run {
                self.definition = result
                self.isLoading = false
                self.updateView()
            }
        }
    }
    
    func updateView() {
        let contentView = DefinitionView(word: .constant(self.word), definition: .constant(self.definition), isLoading: .constant(self.isLoading))
        window.contentView = NSHostingView(rootView: contentView)
    }
}

@main
struct AIDictAppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
