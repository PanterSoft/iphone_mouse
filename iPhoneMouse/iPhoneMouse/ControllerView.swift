import SwiftUI

struct ControllerView: View {
    @ObservedObject var motionController: MotionController

    var body: some View {
        VStack(spacing: 20) {
            Text("Controller Mode")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Use the D-pad to move the mouse cursor")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // D-Pad
            VStack(spacing: 0) {
                // Up button
                ControllerButton(
                    icon: "arrow.up",
                    action: { motionController.setControllerDirection(x: 0, y: 1) },
                    releaseAction: { motionController.setControllerDirection(x: 0, y: 0) }
                )

                // Middle row (Left, Center, Right)
                HStack(spacing: 0) {
                    // Left button
                    ControllerButton(
                        icon: "arrow.left",
                        action: { motionController.setControllerDirection(x: -1, y: 0) },
                        releaseAction: { motionController.setControllerDirection(x: 0, y: 0) }
                    )

                    // Center (stop)
                    Button(action: {
                        motionController.setControllerDirection(x: 0, y: 0)
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 60)
                            .background(Color.gray)
                    }
                    .buttonStyle(ControllerButtonStyle())

                    // Right button
                    ControllerButton(
                        icon: "arrow.right",
                        action: { motionController.setControllerDirection(x: 1, y: 0) },
                        releaseAction: { motionController.setControllerDirection(x: 0, y: 0) }
                    )
                }

                // Down button
                ControllerButton(
                    icon: "arrow.down",
                    action: { motionController.setControllerDirection(x: 0, y: -1) },
                    releaseAction: { motionController.setControllerDirection(x: 0, y: 0) }
                )
            }
            .cornerRadius(10)
            .shadow(radius: 5)

            // Diagonal buttons
            VStack(spacing: 10) {
                HStack(spacing: 20) {
                    // Up-Left
                    ControllerButton(
                        icon: "arrow.up.left",
                        size: 24,
                        action: { motionController.setControllerDirection(x: -1, y: 1) },
                        releaseAction: { motionController.setControllerDirection(x: 0, y: 0) },
                        isDiagonal: true
                    )

                    // Up-Right
                    ControllerButton(
                        icon: "arrow.up.right",
                        size: 24,
                        action: { motionController.setControllerDirection(x: 1, y: 1) },
                        releaseAction: { motionController.setControllerDirection(x: 0, y: 0) },
                        isDiagonal: true
                    )
                }

                HStack(spacing: 20) {
                    // Down-Left
                    ControllerButton(
                        icon: "arrow.down.left",
                        size: 24,
                        action: { motionController.setControllerDirection(x: -1, y: -1) },
                        releaseAction: { motionController.setControllerDirection(x: 0, y: 0) },
                        isDiagonal: true
                    )

                    // Down-Right
                    ControllerButton(
                        icon: "arrow.down.right",
                        size: 24,
                        action: { motionController.setControllerDirection(x: 1, y: -1) },
                        releaseAction: { motionController.setControllerDirection(x: 0, y: 0) },
                        isDiagonal: true
                    )
                }
            }
        }
        .padding()
    }
}

struct ControllerButton: View {
    let icon: String
    var size: CGFloat = 30
    let action: () -> Void
    let releaseAction: () -> Void
    var isDiagonal: Bool = false

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(.white)
                .frame(width: isDiagonal ? 60 : 80, height: isDiagonal ? 60 : 60)
                .background(isDiagonal ? Color.blue.opacity(0.8) : Color.blue)
                .cornerRadius(isDiagonal ? 8 : 0)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    action()
                }
                .onEnded { _ in
                    releaseAction()
                }
        )
    }
}

struct ControllerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
