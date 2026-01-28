import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var word: String = ""
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
        
        // LOCAL MONITOR: (If the app itself is focused)
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
        // Allow window to appear over Full Screen apps
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // host the SwiftUI view
        let contentView = DefinitionView(word: .constant(self.word), definition: .constant(self.definition), isLoading: .constant(self.isLoading))
        window.contentView = NSHostingView(rootView: contentView)
        
        // Set up Dictionary Hijacking (Overlay Strategy)
        DictionaryWatcher.shared.onDictionaryOpened = { word, nativeRect in
            print("DEBUG: Companion Triggered for word: \(word) with rect: \(nativeRect)")
            DispatchQueue.main.async {
                self.showWindow(for: word, nativeRect: nativeRect)
            }
        }
        DictionaryWatcher.shared.start()
        
        // Hide on launch
        window.orderOut(nil)
        print("DEBUG: AI-Dict active in Companion Mode. Watching for native lookups...")
    }
    
    func showWindow(for word: String, nativeRect: NSRect) {
        print("DEBUG: Showing companion window for word: \(word)")
        self.word = word
        self.fetchDefinition(for: word)
        
        // Update the view
        let contentView = DefinitionView(word: .constant(self.word), definition: .constant(self.definition), isLoading: .constant(self.isLoading))
        window.contentView = NSHostingView(rootView: contentView)
        
        // Calculate Position using Helper
        let mouseLocation = NSEvent.mouseLocation
        let newOrigin = WindowPositioner.calculatePosition(
            for: window.frame,
            nativeRect: nativeRect,
            mouseLocation: mouseLocation
        )
        
        print("DEBUG: AI Window Origin: \(newOrigin)")
        
        window.setFrameOrigin(newOrigin)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func fetchDefinition(for word: String) {
        self.isLoading = true
        self.definition = nil
        
        Task {
            let result = await AIService.shared.getDefinition(for: word)
            await MainActor.run {
                self.definition = result
                self.isLoading = false
                // Update the view again to reflect changes
                let contentView = DefinitionView(word: .constant(self.word), definition: .constant(self.definition), isLoading: .constant(self.isLoading))
                self.window.contentView = NSHostingView(rootView: contentView)
            }
        }
    }
}

@main
struct AIDictAppMain {
    static func main() {
        // Unbuffer stdout to ensure we see logs immediately
        setbuf(__stdoutp, nil)
        
        print("DEBUG: Application Launching...")
        
        // Check Accessibility Permissions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            print("DEBUG: Accessibility Permissions GRANTED. Starting app...")
        } else {
            fputs("ERROR: Accessibility Permissions DENIED. Please grant access in System Settings.\n", stderr)
            // We continue anyway to let the prompt appear, but it won't work.
        }
        
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
