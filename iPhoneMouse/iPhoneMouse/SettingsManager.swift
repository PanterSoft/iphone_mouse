import Foundation
import Combine

enum SensorType: String, CaseIterable {
    case arkit = "ARKit (Camera/LiDAR)"
    case imu = "IMU (Accelerometer)"

    var description: String {
        switch self {
        case .arkit:
            return "Uses camera or LiDAR for precise surface tracking"
        case .imu:
            return "Uses accelerometer for movement detection"
        }
    }
}

enum ControlMode: String, CaseIterable {
    case motion = "Motion Control"
    case controller = "Controller (D-Pad)"

    var description: String {
        switch self {
        case .motion:
            return "Control mouse by moving your iPhone"
        case .controller:
            return "Control mouse with on-screen buttons"
        }
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var sensorType: SensorType {
        didSet {
            UserDefaults.standard.set(sensorType.rawValue, forKey: "sensorType")
        }
    }

    @Published var showARVisualization: Bool {
        didSet {
            UserDefaults.standard.set(showARVisualization, forKey: "showARVisualization")
        }
    }

    @Published var sensitivity: Double {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: "sensitivity")
        }
    }

    @Published var controlMode: ControlMode {
        didSet {
            UserDefaults.standard.set(controlMode.rawValue, forKey: "controlMode")
        }
    }

    @Published var smoothingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(smoothingEnabled, forKey: "smoothingEnabled")
        }
    }

    private init() {
        if let savedSensorType = UserDefaults.standard.string(forKey: "sensorType"),
           let type = SensorType(rawValue: savedSensorType) {
            self.sensorType = type
        } else {
            self.sensorType = .arkit
        }

        self.showARVisualization = UserDefaults.standard.bool(forKey: "showARVisualization")
        self.sensitivity = UserDefaults.standard.double(forKey: "sensitivity") != 0 ?
            UserDefaults.standard.double(forKey: "sensitivity") : 5000.0

        if let savedControlMode = UserDefaults.standard.string(forKey: "controlMode"),
           let mode = ControlMode(rawValue: savedControlMode) {
            self.controlMode = mode
        } else {
            self.controlMode = .motion
        }

        self.smoothingEnabled = UserDefaults.standard.bool(forKey: "smoothingEnabled")
        if !UserDefaults.standard.bool(forKey: "smoothingEnabledSet") {
            // Default to enabled for new users
            self.smoothingEnabled = true
            UserDefaults.standard.set(true, forKey: "smoothingEnabledSet")
        }
    }
}
