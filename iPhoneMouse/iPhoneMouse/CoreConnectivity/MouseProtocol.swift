import Foundation
import Combine

/// Protocol interface for mouse input transmission
/// Abstracts the underlying transport mechanism (Bluetooth or WiFi)
protocol MouseProtocol: AnyObject {
    /// Connection status publisher
    var isConnected: Published<Bool>.Publisher { get }

    /// Connection error publisher
    var connectionError: Published<String?>.Publisher { get }

    /// Send mouse input report
    /// - Parameters:
    ///   - deltaX: Horizontal movement delta (Mickeys - relative displacement)
    ///   - deltaY: Vertical movement delta (Mickeys - relative displacement)
    ///   - buttons: Button state bitmap (bit 0: left, bit 1: right, bit 2: middle)
    ///   - scroll: Scroll wheel delta (-127 to 127)
    func sendInput(deltaX: Int16, deltaY: Int16, buttons: UInt8, scroll: Int8) throws

    /// Connect to the target device
    func connect() throws

    /// Disconnect from the target device
    func disconnect()
}

/// Standard HID Mouse Report structure
/// Matches the HID Report Descriptor format
struct MouseHIDReport {
    /// Button state bitmap
    /// - Bit 0: Left button (0x01)
    /// - Bit 1: Right button (0x02)
    /// - Bit 2: Middle button (0x04)
    /// - Bits 3-7: Reserved
    var buttons: UInt8 = 0

    /// X-axis delta (relative movement, signed 16-bit)
    /// Positive = Right, Negative = Left
    var deltaX: Int16 = 0

    /// Y-axis delta (relative movement, signed 16-bit)
    /// Positive = Down, Negative = Up
    var deltaY: Int16 = 0

    /// Scroll wheel delta (signed 8-bit)
    /// Positive = Scroll Up, Negative = Scroll Down
    var scroll: Int8 = 0

    /// Convert to binary HID report format (6 bytes)
    /// Format: [Buttons(1) | X(2) | Y(2) | Scroll(1)]
    func toData() -> Data {
        var data = Data()
        data.append(buttons)

        // X-axis (int16, little-endian)
        withUnsafeBytes(of: deltaX.littleEndian) { data.append(contentsOf: $0) }

        // Y-axis (int16, little-endian)
        withUnsafeBytes(of: deltaY.littleEndian) { data.append(contentsOf: $0) }

        // Scroll (int8)
        data.append(UInt8(bitPattern: scroll))

        return data
    }

    /// Create from binary HID report format
    static func from(data: Data) -> MouseHIDReport? {
        guard data.count >= 6 else { return nil }

        return data.withUnsafeBytes { bytes in
            let buttons = bytes.load(fromByteOffset: 0, as: UInt8.self)
            let deltaX = bytes.load(fromByteOffset: 1, as: Int16.self).littleEndian
            let deltaY = bytes.load(fromByteOffset: 3, as: Int16.self).littleEndian
            let scroll = Int8(bitPattern: bytes.load(fromByteOffset: 5, as: UInt8.self))

            return MouseHIDReport(buttons: buttons, deltaX: deltaX, deltaY: deltaY, scroll: scroll)
        }
    }
}

/// WiFi packet structure (optimized for low latency)
/// Format: 5 bytes [Header | Buttons | DeltaX | DeltaY | Scroll]
struct WiFiMousePacket {
    /// Packet header/sync byte (0xAA for mouse movement)
    static let headerMouse: UInt8 = 0xAA
    static let headerControl: UInt8 = 0xBB

    var header: UInt8
    var buttons: UInt8
    var deltaX: Int8  // Clamped to -127..127 for single byte
    var deltaY: Int8  // Clamped to -127..127 for single byte
    var scroll: Int8

    /// Convert to binary packet (5 bytes)
    func toData() -> Data {
        var data = Data()
        data.append(header)
        data.append(buttons)
        data.append(UInt8(bitPattern: deltaX))
        data.append(UInt8(bitPattern: deltaY))
        data.append(UInt8(bitPattern: scroll))
        return data
    }

    /// Create from binary packet
    static func from(data: Data) -> WiFiMousePacket? {
        guard data.count >= 5 else { return nil }

        return data.withUnsafeBytes { bytes in
            let header = bytes.load(fromByteOffset: 0, as: UInt8.self)
            let buttons = bytes.load(fromByteOffset: 1, as: UInt8.self)
            let deltaX = Int8(bitPattern: bytes.load(fromByteOffset: 2, as: UInt8.self))
            let deltaY = Int8(bitPattern: bytes.load(fromByteOffset: 3, as: UInt8.self))
            let scroll = Int8(bitPattern: bytes.load(fromByteOffset: 4, as: UInt8.self))

            return WiFiMousePacket(header: header, buttons: buttons, deltaX: deltaX, deltaY: deltaY, scroll: scroll)
        }
    }

    /// Clamp 16-bit delta to 8-bit signed range (-127 to 127)
    /// This is necessary because WiFi packets use single bytes for X/Y to minimize latency
    static func clampToInt8(_ value: Int16) -> Int8 {
        return Int8(max(-127, min(127, Int32(value))))
    }
}
