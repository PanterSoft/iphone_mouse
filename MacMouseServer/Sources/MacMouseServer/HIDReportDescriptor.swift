import Foundation

/// Standard HID Report Descriptor for a mouse device
/// This defines the structure of HID reports sent to the operating system
struct HIDReportDescriptor {
    /// HID Report Descriptor byte array (compliant with USB HID specification)
    /// Defines:
    /// - Usage Page: Generic Desktop (0x01)
    /// - Usage: Mouse (0x02)
    /// - Collection: Application
    /// - Buttons: 3 buttons (Left, Right, Middle)
    /// - X/Y axes: Relative input (signed 16-bit)
    /// - Wheel: Vertical scroll (signed 8-bit)
    static let descriptor: [UInt8] = [
        // Usage Page (Generic Desktop)
        0x05, 0x01,                    // USAGE_PAGE (Generic Desktop)

        // Usage (Mouse)
        0x09, 0x02,                    // USAGE (Mouse)

        // Collection (Application)
        0xa1, 0x01,                    // COLLECTION (Application)

        // Buttons (3 buttons: Left, Right, Middle)
        0x09, 0x01,                    //   USAGE (Pointer)
        0xa1, 0x00,                    //   COLLECTION (Physical)

        // Button 1 (Left)
        0x05, 0x09,                    //     USAGE_PAGE (Button)
        0x19, 0x01,                    //     USAGE_MINIMUM (Button 1)
        0x29, 0x03,                    //     USAGE_MAXIMUM (Button 3)
        0x15, 0x00,                    //     LOGICAL_MINIMUM (0)
        0x25, 0x01,                    //     LOGICAL_MAXIMUM (1)
        0x95, 0x03,                    //     REPORT_COUNT (3)
        0x75, 0x01,                    //     REPORT_SIZE (1)
        0x81, 0x02,                    //     INPUT (Data,Var,Abs)

        // Padding for buttons (5 bits unused)
        0x95, 0x01,                    //     REPORT_COUNT (1)
        0x75, 0x05,                    //     REPORT_SIZE (5)
        0x81, 0x03,                    //     INPUT (Cnst,Var,Abs)

        // X Axis (Relative, 16-bit signed)
        0x05, 0x01,                    //     USAGE_PAGE (Generic Desktop)
        0x09, 0x30,                    //     USAGE (X)
        0x09, 0x31,                    //     USAGE (Y)
        0x16, 0x00, 0x80,              //     LOGICAL_MINIMUM (-32768)
        0x26, 0xFF, 0x7F,              //     LOGICAL_MAXIMUM (32767)
        0x36, 0x00, 0x80,              //     PHYSICAL_MINIMUM (-32768)
        0x46, 0xFF, 0x7F,              //     PHYSICAL_MAXIMUM (32767)
        0x75, 0x10,                    //     REPORT_SIZE (16)
        0x95, 0x02,                    //     REPORT_COUNT (2)
        0x81, 0x06,                    //     INPUT (Data,Var,Rel)

        // Wheel (Vertical scroll, 8-bit signed)
        0x09, 0x38,                    //     USAGE (Wheel)
        0x15, 0x81,                    //     LOGICAL_MINIMUM (-127)
        0x25, 0x7F,                    //     LOGICAL_MAXIMUM (127)
        0x35, 0x81,                    //     PHYSICAL_MINIMUM (-127)
        0x45, 0x7F,                    //     PHYSICAL_MAXIMUM (127)
        0x75, 0x08,                    //     REPORT_SIZE (8)
        0x95, 0x01,                    //     REPORT_COUNT (1)
        0x81, 0x06,                    //     INPUT (Data,Var,Rel)

        // End Collection (Physical)
        0xc0,                          //   END_COLLECTION

        // End Collection (Application)
        0xc0                           // END_COLLECTION
    ]

    /// Get the HID Report Descriptor as Data
    static var data: Data {
        return Data(descriptor)
    }

    /// Report size in bytes (matches our MouseMovementProtocol format)
    /// Format: 1 byte buttons + 2 bytes X + 2 bytes Y + 1 byte scroll = 6 bytes
    static let reportSize: Int = 6

    /// Validate that a report matches the descriptor format
    static func validateReport(_ data: Data) -> Bool {
        // Minimum size: 5 bytes (buttons + X + Y), optional 6th byte for scroll
        return data.count >= 5 && data.count <= 6
    }
}
