import Foundation
import AppKit

struct WindowPositioner {
    static func calculatePosition(for windowFrame: NSRect, nativeRect: NSRect, mouseLocation: NSPoint) -> NSPoint {
        let padding: CGFloat = 20
        var xPos: CGFloat = 0
        var yPos: CGFloat = 0
        
        // 1. FIND SCREEN (FIX #2: Improved for Full Screen Spaces)
        // Priority order: Screen containing nativeRect center → Screen containing mouse → Main screen
        var targetScreen: NSScreen?
        
        if nativeRect.width > 0 && nativeRect.height > 0 {
            // FIX #2: Convert nativeRect center from AX coordinates (top-left) to AppKit (bottom-left)
            // to properly find the screen in full screen mode.
            let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 900
            let appKitCenterY = mainScreenHeight - nativeRect.midY
            let appKitCenter = NSPoint(x: nativeRect.midX, y: appKitCenterY)
            
            targetScreen = NSScreen.screens.first { screen in
                screen.frame.contains(appKitCenter)
            }
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
            
            // FIX #3: Use the ACTUAL screen's height for conversion, not just the first screen
            // This is critical for multi-monitor and full screen setups.
            let referenceHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
            
            // AX coordinates: origin is top-left of primary screen
            // AppKit coordinates: origin is bottom-left of primary screen
            // nativeRect.origin.y = distance from TOP of primary screen
            // We need: distance from BOTTOM of primary screen
            
            let nativeAppKitY = referenceHeight - nativeRect.origin.y - nativeRect.height
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
