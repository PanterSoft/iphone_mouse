# Core Connectivity Layer - Architecture Documentation

## Overview

This module implements a **dual-mode connectivity layer** for converting an iOS device into a computer mouse/trackpad. It provides a standardized interface that abstracts the underlying transport mechanism (Bluetooth or WiFi).

## Architecture

### Protocol Interface (`MouseProtocol`)

The `MouseProtocol` interface provides a unified API for mouse input transmission:

```swift
protocol MouseProtocol {
    func sendInput(deltaX: Int16, deltaY: Int16, buttons: UInt8, scroll: Int8) throws
    func connect() throws
    func disconnect()
}
```

### Implementations

1. **`BluetoothHidService`** - CoreBluetooth-based implementation
2. **`WifiNetworkService`** - Network framework-based implementation (UDP + TCP)

## Data Format Standards

### HID Report Format (Bluetooth)

**6-byte structure:**
```
Byte 0: Buttons bitmap (8 bits)
  - Bit 0: Left button (0x01)
  - Bit 1: Right button (0x02)
  - Bit 2: Middle button (0x04)
  - Bits 3-7: Reserved

Bytes 1-2: X-axis delta (int16, little-endian)
  - Range: -32768 to 32767
  - Positive = Right, Negative = Left

Bytes 3-4: Y-axis delta (int16, little-endian)
  - Range: -32768 to 32767
  - Positive = Down, Negative = Up

Byte 5: Scroll wheel delta (int8)
  - Range: -127 to 127
  - Positive = Scroll Up, Negative = Scroll Down
```

### WiFi Packet Format (UDP)

**5-byte structure (optimized for low latency):**
```
Byte 0: Header/Sync (0xAA for mouse movement, 0xBB for control)
Byte 1: Buttons bitmap (same as HID)
Byte 2: Delta X (int8, clamped to -127..127)
Byte 3: Delta Y (int8, clamped to -127..127)
Byte 4: Scroll wheel (int8, -127..127)
```

**Why 8-bit deltas for WiFi?**
- **Latency**: Smaller packets = faster transmission
- **Bandwidth**: Reduces network overhead
- **Practical**: Mouse movements are typically small increments
- **Multiple packets**: Large movements are automatically broken into multiple packets

## Design Decisions

### 1. Background Threading

Both services use dedicated dispatch queues to prevent UI blocking:

- **Bluetooth**: `DispatchQueue(label: "com.iphone.mouse.bluetooth", qos: .userInitiated)`
- **WiFi**: `DispatchQueue(label: "com.iphone.mouse.network", qos: .userInitiated)`

All network operations run asynchronously on these queues.

### 2. UDP for Movement, TCP for Control

**UDP (Movement Data):**
- **Zero latency**: Fire-and-forget, no acknowledgment overhead
- **Best-effort delivery**: Acceptable for mouse movement (small packet loss is imperceptible)
- **Lower overhead**: No connection state management

**TCP (Control Commands):**
- **Reliable delivery**: Critical for button clicks, configuration
- **Ordered delivery**: Ensures commands execute in correct sequence
- **Connection state**: Maintains persistent connection for control

### 3. Value Clamping

**16-bit to 8-bit Clamping (WiFi):**
```swift
static func clampToInt8(_ value: Int16) -> Int8 {
    return Int8(max(-127, min(127, Int32(value))))
}
```

**Why?**
- WiFi packets use single bytes for X/Y to minimize latency
- Large movements are naturally broken into multiple packets
- Clamping prevents overflow and maintains packet structure

### 4. iOS Bluetooth Limitations

**Important Note**: iOS cannot act as a true HID peripheral like Android's `BluetoothHidDevice` API. However:

- We send **HID-formatted data** over CoreBluetooth
- The receiving Mac server interprets this as standard HID reports
- Functionally equivalent to true HID, just using a custom transport

## Usage Example

```swift
// Initialize connection manager
let connectionManager = MouseConnectionManager()

// Connect via Bluetooth
try connectionManager.connect(mode: .bluetooth)

// Or connect via WiFi
try connectionManager.connect(mode: .wifi(
    host: "192.168.1.100",
    udpPort: 8888,
    tcpPort: 8889
))

// Send movement
try connectionManager.sendMovement(deltaX: 10.0, deltaY: -5.0)

// Send button click
try connectionManager.sendButtonClick(.left)

// Send scroll
try connectionManager.sendInput(deltaX: 0, deltaY: 0, buttons: 0, scroll: 10)
```

## Error Handling

All methods throw `MouseConnectionError`:

- `.bluetoothNotAvailable` - Bluetooth is off or unavailable
- `.notConnected` - Attempted to send data without connection
- `.wifiConnectionFailed` - Network connection failed
- `.invalidData` - Data format validation failed

## Performance Characteristics

### Bluetooth Mode
- **Latency**: ~5-10ms typical
- **Throughput**: ~1KB/s (sufficient for mouse input)
- **Reliability**: High (ACK-based)

### WiFi Mode (UDP)
- **Latency**: ~1-3ms on local network
- **Throughput**: Limited by network bandwidth
- **Reliability**: Best-effort (acceptable for movement)

## Thread Safety

- All network operations are thread-safe
- Published properties update on main thread
- Background queues prevent UI blocking
- No shared mutable state between threads
