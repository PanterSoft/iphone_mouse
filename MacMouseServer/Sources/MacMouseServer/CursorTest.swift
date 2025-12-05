import Foundation
import AppKit

// Simple test to move cursor in a circle
class CursorTest {
    static func runCircleTest() {
        print("Starting cursor circle test...")
        print("Cursor will move in a circle pattern")
        print("Press Ctrl+C to stop\n")

        // Get screen center
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let centerX = screenFrame.midX
        let centerY = screenFrame.midY
        let radius: Double = 200
        var angle: Double = 0.0

        print("Screen center: (\(centerX), \(centerY))")
        print("Circle radius: \(radius)\n")

        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            // Calculate position on circle
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)

            // Move cursor directly - single call, no events
            CGWarpMouseCursorPosition(CGPoint(x: x, y: y))

            // Increment angle (smaller value = slower rotation)
            angle += 0.02
            if angle >= 2 * .pi {
                angle = 0
                print("Completed one circle")
            }
        }

        RunLoop.current.add(timer, forMode: .common)
    }
}
