import Foundation
import AppKit

class MouseMovementSmoother {
    static let shared = MouseMovementSmoother()
    private let lock = NSLock()

    // Accumulated movement vectors from iPhone (raw deltas)
    private var accumulatedDeltaX: Double = 0.0
    private var accumulatedDeltaY: Double = 0.0

    // Current smoothed velocity for interpolation
    private var currentVelocityX: Double = 0.0
    private var currentVelocityY: Double = 0.0

    // Timer for smooth interpolation updates
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 1.0 / 120.0 // 120Hz smooth updates
    private let smoothingFactor: Double = 0.2 // Interpolation speed (lower = smoother)

    private init() {
        startUpdateTimer()
    }

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.interpolateAndApply()
        }
        RunLoop.current.add(updateTimer!, forMode: .common)
    }

    // iPhone sends raw movement vectors - we just accumulate them
    func addMovement(deltaX: Double, deltaY: Double) {
        lock.lock()
        defer { lock.unlock() }

        // Accumulate raw movement vectors from iPhone
        accumulatedDeltaX += deltaX
        accumulatedDeltaY += deltaY
    }

    // Interpolate accumulated movement smoothly over time
    private func interpolateAndApply() {
        lock.lock()
        let targetX = accumulatedDeltaX
        let targetY = accumulatedDeltaY
        lock.unlock()

        // Exponential interpolation towards target (smooth acceleration/deceleration)
        currentVelocityX = currentVelocityX * (1.0 - smoothingFactor) + targetX * smoothingFactor
        currentVelocityY = currentVelocityY * (1.0 - smoothingFactor) + targetY * smoothingFactor

        // Apply interpolated movement if significant
        if abs(currentVelocityX) > 0.01 || abs(currentVelocityY) > 0.01 {
            DispatchQueue.main.async {
                self.applyMovement(deltaX: self.currentVelocityX, deltaY: self.currentVelocityY)
            }

            // Reduce accumulated by what we just applied
            lock.lock()
            accumulatedDeltaX -= currentVelocityX
            accumulatedDeltaY -= currentVelocityY
            lock.unlock()
        }
    }

    // Convert movement vector to actual mouse movement
    // Uses CGWarpMouseCursorPosition for direct cursor control (like a real mouse)
    private func applyMovement(deltaX: Double, deltaY: Double) {
        // Get current mouse position synchronously on main thread
        let currentLocation: CGPoint
        if Thread.isMainThread {
            currentLocation = NSEvent.mouseLocation
        } else {
            currentLocation = DispatchQueue.main.sync {
                NSEvent.mouseLocation
            }
        }

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        // Calculate new position from movement vector
        let newX = currentLocation.x + deltaX
        let newY = currentLocation.y - deltaY

        // Clamp to screen bounds
        let clampedX = max(screenFrame.minX, min(screenFrame.maxX, newX))
        let clampedY = max(screenFrame.minY, min(screenFrame.maxY, newY))

        // Use CGWarpMouseCursorPosition for direct cursor positioning
        // This is more reliable and works like a real mouse device
        CGWarpMouseCursorPosition(CGPoint(x: clampedX, y: clampedY))

        // Disable event suppression so hardware events aren't ignored
        // This prevents macOS from ignoring mouse events after warping
        if let eventSource = CGEventSource(stateID: .hidSystemState) {
            eventSource.localEventsSuppressionInterval = 0.0
        }

        // Also post a mouse moved event so applications receive the event
        // This ensures apps can track mouse movement properly
        if let eventSource = CGEventSource(stateID: .hidSystemState) {
            let moveEvent = CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: clampedX, y: clampedY), mouseButton: .left)
            moveEvent?.post(tap: .cghidEventTap)
        }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        accumulatedDeltaX = 0.0
        accumulatedDeltaY = 0.0
        currentVelocityX = 0.0
        currentVelocityY = 0.0
    }
}
