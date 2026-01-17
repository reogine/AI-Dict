import Foundation
import AppKit

struct WindowPositioner {
    static func calculatePosition(for windowFrame: NSRect, nativeRect: NSRect, mouseLocation: NSPoint) -> NSPoint {
        let padding: CGFloat = 20
        var xPos: CGFloat = 0
        var yPos: CGFloat = 0
        
        // 1. FIND SCREEN
        // Try to find the screen containing the mouse OR the native window
        // Prioritize screen containing native window if valid
        var targetScreen: NSScreen?
        
        if nativeRect.width > 0 {
             // Basic check: center of native rect
             let center = NSPoint(x: nativeRect.midX, y: nativeRect.midY)
             targetScreen = NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
        }
        
        if targetScreen == nil {
             targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
        }
        
        guard let screen = targetScreen ?? NSScreen.main else {
            print("ERROR: No screens found. Defaulting to (0,0).")
            return .zero
        }
        
        let screenFrame = screen.visibleFrame
        
        // 2. CALCULATE POSITION
        if nativeRect.width > 0 && nativeRect.height > 0 {
            // NATIVE RELATIVE MODE
            
            // AppKit Y Conversion (accessibility uses Top-Left, we need Bottom-Left)
            // Note: The nativeRect passed from DictionaryWatcher should already be converted or we need to handle it.
            // DictionaryWatcher passes raw AXValue which is Top-Left.
            // Let's assume consistent conversion here:
            let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 900
            // AX Y is distance from top. AppKit Y is distance from bottom.
            // Check: if nativeRect comes from AX, y is top.
            // nativeAppKitY (Bottom of window) = ScreenHeight - (AX_Y + Height)
            // nativeAppKitTop = ScreenHeight - AX_Y
            
            // Wait, let's look at how we did it in AIDictApp.swift:
            // let nativeAppKitY = mainScreenHeight - nativeRect.origin.y - nativeRect.height
            // let nativeTop = nativeAppKitY + nativeRect.height
            // yPos = nativeTop - windowFrame.height
             
            let nativeAppKitY = mainScreenHeight - nativeRect.origin.y - nativeRect.height
            let nativeTop = nativeAppKitY + nativeRect.height
            
            yPos = nativeTop - windowFrame.height
            
            // Horizontal Logic
            let rightSideX = nativeRect.origin.x + nativeRect.width + padding
            
            // Prefer Right Side
            if rightSideX + windowFrame.width <= screenFrame.maxX {
                xPos = rightSideX
            } else {
                // Else Left Side
                xPos = nativeRect.origin.x - windowFrame.width - padding
            }
            
        } else {
            // MOUSE RELATIVE MODE (Fallback)
            let horizontalOffset: CGFloat = 405
            xPos = mouseLocation.x + horizontalOffset - (windowFrame.width / 2)
            
            // Flip to left if off-screen right
            if xPos + windowFrame.width > screenFrame.maxX {
                xPos = mouseLocation.x - horizontalOffset - (windowFrame.width / 2)
            }
            
            yPos = mouseLocation.y - windowFrame.height - 20
            
            // Flip above if off-screen bottom
            if yPos < screenFrame.minY {
                yPos = mouseLocation.y + 20
            }
        }
        
        // 3. SAFETY CLAMPING
        // Horizontal
        if xPos < screenFrame.minX { xPos = screenFrame.minX + 10 }
        if xPos + windowFrame.width > screenFrame.maxX {
            xPos = screenFrame.maxX - windowFrame.width - 10
        }
        
        // Vertical
        if yPos < screenFrame.minY { yPos = screenFrame.minY + 20 }
        if yPos + windowFrame.height > screenFrame.maxY {
            yPos = screenFrame.maxY - windowFrame.height - 10
        }
        
        return NSPoint(x: xPos, y: yPos)
    }
}
