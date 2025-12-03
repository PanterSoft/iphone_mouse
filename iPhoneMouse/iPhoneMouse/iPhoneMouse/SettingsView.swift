import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var motionController: MotionController
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sensor Type")) {
                    ForEach(SensorType.allCases, id: \.self) { sensor in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sensor.rawValue)
                                    .font(.body)
                                Text(sensor.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if settings.sensorType == sensor {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            settings.sensorType = sensor
                            motionController.updateSensorType()
                        }
                    }
                }

                if settings.sensorType == .arkit {
                    Section(header: Text("ARKit Options")) {
                        Toggle("Show Camera/LiDAR View", isOn: $settings.showARVisualization)
                            .onChange(of: settings.showARVisualization) { _ in
                                motionController.updateVisualization()
                            }
                    }
                }

                if settings.sensorType == .imu {
                    Section(header: Text("IMU Calibration")) {
                        if settings.imuCalibrated {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Calibrated")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button(action: {
                            motionController.calibrateIMU()
                            settings.imuCalibrated = true
                        }) {
                            HStack {
                                Image(systemName: "target")
                                Text("Calibrate Zero Position")
                            }
                        }

                        Text("Place your iPhone on the surface and tap to calibrate. This accounts for phone cases and uneven surfaces.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Sensitivity")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sensitivity")
                            Spacer()
                            Text("\(Int(settings.sensitivity))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.sensitivity, in: 1000...20000, step: 500)
                            .onChange(of: settings.sensitivity) { _ in
                                motionController.updateSensitivity()
                            }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
