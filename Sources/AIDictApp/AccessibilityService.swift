import Foundation
import ApplicationServices
import AppKit

class AccessibilityService {
    static let shared = AccessibilityService()
    
    func getWordAtCursor() -> String? {
        // 1. Get Mouse Location using CoreGraphics (Native to Accessibility)
        guard let event = CGEvent(source: nil) else { return nil }
        let point = event.location
        
        // 2. Hit Test (System Wide)
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        var result = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)
        
        // 3. PIERCE-THROUGH LOGIC: Check if blocked by LookupViewService or Self
        if result == .success, let target = element {
            var pid: pid_t = 0
            AXUIElementGetPid(target, &pid)
            
            let app = NSRunningApplication(processIdentifier: pid)
            let bundleID = app?.bundleIdentifier ?? ""
            
            if bundleID == "com.apple.LookupViewService" || bundleID == Bundle.main.bundleIdentifier {
                // FIX #1: Use menuBarOwningApplication instead of frontmostApplication
                // In full screen mode, frontmostApplication can be the popup itself.
                // menuBarOwningApplication returns the app that owns the menu bar (the real user app).
                var targetApp: NSRunningApplication? = NSWorkspace.shared.menuBarOwningApplication
                
                // Fallback: If menuBarOwningApplication returns LookupViewService or nil, try frontmost
                if targetApp?.bundleIdentifier == "com.apple.LookupViewService" || targetApp == nil {
                    targetApp = NSWorkspace.shared.frontmostApplication
                }
                
                // Final fallback: Grab any visible app that isn't LookupViewService or us
                if targetApp?.bundleIdentifier == "com.apple.LookupViewService" || targetApp?.bundleIdentifier == Bundle.main.bundleIdentifier {
                    targetApp = NSWorkspace.shared.runningApplications.first {
                        $0.isActive && $0.bundleIdentifier != "com.apple.LookupViewService" && $0.bundleIdentifier != Bundle.main.bundleIdentifier
                    }
                }
                
                if let frontApp = targetApp,
                   frontApp.bundleIdentifier != "com.apple.LookupViewService" {
                    
                    let frontPid = frontApp.processIdentifier
                    let frontElement = AXUIElementCreateApplication(frontPid)
                    
                    // Re-try hit test specifically against the front app
                    var frontResultElement: AXUIElement?
                    let pierceResult = AXUIElementCopyElementAtPosition(frontElement, Float(point.x), Float(point.y), &frontResultElement)
                    
                    if pierceResult == .success, let piercedTarget = frontResultElement {
                        element = piercedTarget
                    }
                }
            }
        }
        
        guard let target = element else { return nil }
        
        // 4. Try Precision Extraction (AXRangeForPosition)
        var rangeValue: CFTypeRef?
        var pointValue = point
        guard let axPoint = AXValueCreate(.cgPoint, &pointValue) else { return nil }
        
        let rangeResult = AXUIElementCopyParameterizedAttributeValue(target, kAXRangeForPositionParameterizedAttribute as CFString, axPoint, &rangeValue)
        
        if rangeResult == .success, let rangeVal = rangeValue {
            var range = CFRange()
            AXValueGetValue(rangeVal as! AXValue, .cfRange, &range)
            
            // If location is 0 but we have text, it's likely a BUG in the target app (VS Code/Electron often do this).
            // We must fallback to "Brute Force Geometry" (Inverse Hit-Test).
            if range.location == 0 {
                // Get full text to check if it's actually just 1 word or a failure
                var valueRef: CFTypeRef?
                AXUIElementCopyAttributeValue(target, kAXValueAttribute as CFString, &valueRef)
                if let text = valueRef as? String, text.count > 5 { // Arbitrary threshold
                    if let scannedWord = scanForWordUnderMouse(target, point: point, text: text) {
                         return scannedWord
                    }
                }
            }
            
            // Extract word from this specific range
            return extractWordFromRange(target, range)
        }
        
        // 5. Fallback: Standard extraction
        return extractSelectedText(from: target)
    }
    
    // BRUTE FORCE: Split text into words, ask for their Rects, and see which one contains the mouse.
    private func scanForWordUnderMouse(_ element: AXUIElement, point: CGPoint, text: String) -> String? {
        let nsStr = text as NSString
        var wordRanges: [NSRange] = []
        
        // 1. Tokenize (Simple split by whitespace/newlines for speed)
        let scanner = Scanner(string: text)
        while !scanner.isAtEnd {
            let startLoc = scanner.scanLocation
            if let word = scanner.scanUpToCharacters(from: .whitespacesAndNewlines) {
                 let length = scanner.scanLocation - startLoc
                 wordRanges.append(NSRange(location: startLoc, length: length))
            }
            // Skip whitespace
            _ = scanner.scanCharacters(from: .whitespacesAndNewlines)
        }
        
        // 2. Check Geometry for each word
        for range in wordRanges {
            // Convert NSRange to CFRange
            var cfRange = CFRange(location: range.location, length: range.length)
            var rangeValue: AXValue? = AXValueCreate(.cfRange, &cfRange)
            
            var boundsValue: CFTypeRef?
            let result = AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeValue!, &boundsValue)
            
            if result == .success, let boundsVal = boundsValue {
                var rect = CGRect.zero
                AXValueGetValue(boundsVal as! AXValue, .cgRect, &rect)
                
                if rect.contains(point) {
                    let word = nsStr.substring(with: range)
                    return word
                }
            }
        }
        
        return nil
    }
    
    // Helper to get text around a specific index range
    private func extractWordFromRange(_ element: AXUIElement, _ range: CFRange) -> String? {
        var valueRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        
        guard let fullText = valueRef as? String else { return nil }
        
        let index = range.location
        if index >= 0 && index < fullText.count {
            let nsStr = fullText as NSString
            let wordRange = nsStr.rangeOfWord(at: index)
            if wordRange.location != NSNotFound {
                return nsStr.substring(with: wordRange)
            }
        }
        return nil
    }
    
    // Fallback: Only get text if it is SELECTED.
    private func extractSelectedText(from element: AXUIElement) -> String? {
        var selected: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
           let text = selected as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

// Extension to help word finding
extension NSString {
    func rangeOfWord(at index: Int) -> NSRange {
        var start = index
        while start > 0 {
            let char = self.character(at: start - 1)
            if !CharacterSet.alphanumerics.contains(UnicodeScalar(char)!) {
                break
            }
            start -= 1
        }
        
        var end = index
        while end < self.length {
            let char = self.character(at: end)
            if !CharacterSet.alphanumerics.contains(UnicodeScalar(char)!) {
                break
            }
            end += 1
        }
        
        return NSRange(location: start, length: end - start)
    }
}
