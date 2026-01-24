import Foundation
import ApplicationServices
import AppKit

class AccessibilityService {
    static let shared = AccessibilityService()
    
    func getWordAtCursor() -> String? {
        let mouseLocation = NSEvent.mouseLocation
        // Get the screen where the mouse is
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) else {
            return nil
        }
        
        // AppKit uses bottom-left origin, Accessibility uses top-left origin.
        let screenHeight = screen.frame.height
        let screenOriginY = screen.frame.origin.y
        let flippedY = screenHeight - (mouseLocation.y - screenOriginY)
        
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(flippedY), &element)
        
        guard result == .success, let element = element else {
            return nil
        }
        
        return extractText(from: element)
    }
    
    private func extractText(from element: AXUIElement, depth: Int = 0) -> String? {
        // SAFETY LIMIT: Stop recursion if too deep to prevent lag
        if depth > 2 { return nil }
        
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if let roleString = role as? String {
            // 1. FAST PATH: Check strictly text roles
            let textRoles: [String] = [
                kAXStaticTextRole as String,
                kAXTextAreaRole as String,
                kAXTextFieldRole as String
            ]
            
            if textRoles.contains(roleString) {
                return getElementValue(element)
            }
            
            // 2. CHECK VALUE FIRST: Even if it's a container, it might have a value (e.g. selected text)
            if let val = getElementValue(element) {
                return val
            }
            
            // 3. RECURSIVE CHECK: Only dig deeper if truly necessary
            let containerRoles = ["AXWebArea", "AXScrollArea", "AXGroup", "AXLink"]
            if containerRoles.contains(roleString) {
                var children: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
                
                if result == .success, let childrenArray = children as? [AXUIElement] {
                    for child in childrenArray.prefix(10) { // Safety cap: only check top 10 children
                        if let found = extractText(from: child, depth: depth + 1) {
                            return found
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func getElementValue(_ element: AXUIElement) -> String? {
        // Prioritize "Selected Text" as it's most likely what the user clicked
        var selected: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
           let text = selected as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Then check value/content
        let attributes = [kAXValueAttribute, kAXDescriptionAttribute, kAXTitleAttribute]
        for attr in attributes {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success,
               let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}
