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

    @Published var imuCalibrated: Bool {
        didSet {
            UserDefaults.standard.set(imuCalibrated, forKey: "imuCalibrated")
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
        self.imuCalibrated = UserDefaults.standard.bool(forKey: "imuCalibrated")
    }
}
