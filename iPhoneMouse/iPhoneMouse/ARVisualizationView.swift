import SwiftUI
import ARKit
import SceneKit

struct ARVisualizationView: UIViewRepresentable {
    @ObservedObject var motionController: MotionController

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        if let session = motionController.arSession {
            arView.session = session
        }
        arView.autoenablesDefaultLighting = true
        arView.showsStatistics = false

        let scene = SCNScene()
        arView.scene = scene

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if let session = motionController.arSession {
            uiView.session = session
        }
    }
}

struct ARVisualizationViewWrapper: View {
    @ObservedObject var motionController: MotionController

    var body: some View {
        ZStack {
            ARVisualizationView(motionController: motionController)

            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                            HStack {
                                Image(systemName: "cube.transparent")
                                Text("LiDAR")
                            }
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        } else {
                            HStack {
                                Image(systemName: "camera")
                                Text("Camera")
                            }
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
