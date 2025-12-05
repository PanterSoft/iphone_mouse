import Foundation

/// Standardized HID mouse report format (matches standard wireless mouse protocol)
/// Format: 5 bytes (or 6 with scroll)
/// - Byte 0: Buttons bitmap (8 bits)
///   - Bit 0: Left Click (1 = Pressed, 0 = Released)
///   - Bit 1: Right Click
///   - Bit 2: Middle Click
///   - Bits 3-7: Reserved/Side buttons
/// - Bytes 1-2: X-Axis (signed int16, little-endian)
///   - Positive = Right, Negative = Left
/// - Bytes 3-4: Y-Axis (signed int16, little-endian)
///   - Positive = Down, Negative = Up
/// - Byte 5: Scroll (signed int8, optional)
///   - Positive = Scroll Up, Negative = Scroll Down
struct MouseMovementProtocol {
    /// Button bit masks
    struct Buttons {
        static let left: UInt8 = 0x01
        static let right: UInt8 = 0x02
        static let middle: UInt8 = 0x04
    }

    /// Encode mouse movement and button state into HID report format
    /// - Parameters:
    ///   - deltaX: Horizontal movement (Mickeys - relative displacement)
    ///   - deltaY: Vertical movement (Mickeys - relative displacement)
    ///   - buttons: Button state bitmap (default: 0 = no buttons pressed)
    ///   - scroll: Scroll wheel delta (default: 0 = no scroll)
    /// - Returns: 5-byte Data packet (6 bytes if scroll is non-zero)
    static func encode(deltaX: Double, deltaY: Double, buttons: UInt8 = 0, scroll: Int8 = 0) -> Data {
        // Clamp to int16 range to prevent overflow
        let clampedX = Int16(max(-32768, min(32767, Int16(deltaX))))
        let clampedY = Int16(max(-32768, min(32767, Int16(deltaY))))

        var data = Data()

        // Byte 0: Buttons bitmap
        data.append(buttons)

        // Bytes 1-2: X-Axis (int16, little-endian)
        let xBytes = withUnsafeBytes(of: clampedX.littleEndian) { Data($0) }
        data.append(xBytes)

        // Bytes 3-4: Y-Axis (int16, little-endian)
        let yBytes = withUnsafeBytes(of: clampedY.littleEndian) { Data($0) }
        data.append(yBytes)

        // Byte 5: Scroll (optional, only include if non-zero)
        if scroll != 0 {
            data.append(UInt8(bitPattern: scroll))
        }

        return data
    }

    /// Decode HID mouse report format
    /// - Parameter data: 5-byte Data packet (minimum)
    /// - Returns: Tuple of (deltaX, deltaY, buttons, scroll) or nil if invalid
    static func decode(_ data: Data) -> (deltaX: Double, deltaY: Double, buttons: UInt8, scroll: Int8)? {
        guard data.count >= 5 else { return nil }

        return data.withUnsafeBytes { bytes in
            // Byte 0: Buttons
            let buttons = bytes.load(fromByteOffset: 0, as: UInt8.self)

            // Bytes 1-2: X-Axis (int16, little-endian)
            let deltaX = bytes.load(fromByteOffset: 1, as: Int16.self).littleEndian

            // Bytes 3-4: Y-Axis (int16, little-endian)
            let deltaY = bytes.load(fromByteOffset: 3, as: Int16.self).littleEndian

            // Byte 5: Scroll (optional, default to 0 if not present)
            let scroll: Int8 = data.count >= 6 ? Int8(bitPattern: bytes.load(fromByteOffset: 5, as: UInt8.self)) : 0

            return (Double(deltaX), Double(deltaY), buttons, scroll)
        }
    }
}
