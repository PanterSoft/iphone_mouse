import Foundation
import AppKit
import CoreGraphics

// Ultra-simple mouse movement - just apply deltas directly
class MouseMovementSmoother {
    static let shared = MouseMovementSmoother()

    private init() {}

    // Directly move cursor with received deltas
    func moveCursor(deltaX: Double, deltaY: Double) {
        // Get current mouse location using CGEvent (same coordinate system as CGWarpMouseCursorPosition)
        guard let currentEvent = CGEvent(source: nil) else { return }
        let currentLocation = currentEvent.location

        // Get screen bounds for clamping
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Protocol says: Positive deltaX = Right, Positive deltaY = Down
        // macOS Core Graphics: Y increases UPWARD (bottom-left origin)
        // Apply deltas directly (signs already corrected on iPhone side)
        let newX = currentLocation.x + deltaX
        let newY = currentLocation.y - deltaY  // Invert Y: down = decrease Y

        // Clamp to screen bounds
        let clampedX = max(screenFrame.minX, min(screenFrame.maxX - 1, newX))
        let clampedY = max(screenFrame.minY, min(screenFrame.maxY - 1, newY))

        // Move cursor directly
        CGWarpMouseCursorPosition(CGPoint(x: clampedX, y: clampedY))
    }

    func reset() {
        // Nothing to reset
    }
}
