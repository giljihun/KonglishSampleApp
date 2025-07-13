import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var detectionState: PlaneDetectionState
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 시작 + 평면 감지 설정
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        // 정확도 향상 설정
        // if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
        //     config.sceneReconstruction = .mesh  // 라이다 사용 시 메시 재구성
        // }
        
        // 깊이 정보 활용
        config.frameSemantics = .sceneDepth
        
        arView.session.run(config)
        
        arView.debugOptions = [.showFeaturePoints]
        
        // 터치 제스처 추가
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        // Coordinator에 ARView 전달
        context.coordinator.arView = arView
        
        // 평면 감지 이벤트 처리를 위한 delegate 설정
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(detectionState: $detectionState)
    }
    
    // ARSession 이벤트를 처리하는 Coordinator
    class Coordinator: NSObject, ARSessionDelegate {
        var arView: ARView?
        @Binding var detectionState: PlaneDetectionState
        
        
        init(detectionState: Binding<PlaneDetectionState>) {
            self._detectionState = detectionState
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    // 감지가 활성화된 상태에서만 평면 추가
                    guard detectionState.isDetectionEnabled else {
                        print("감지 비활성화 상태")
                        return
                    }
                    
                    addPlaneVisualization(for: planeAnchor)
                    
                    DispatchQueue.main.async {
                        let planeType = planeAnchor.alignment == .horizontal ? "수평" : "수직"
                        self.detectionState.addPlane(type: planeType)
                    }
                }
            }
        }
        
        private func addPlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let arView = arView else { return }
            
            // 평면에 고정될 AnchorEntity 생성
            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            
            // 실제 스캔 크기에 더 가까운 평면 (축소 최소화)
            let width = planeAnchor.planeExtent.width * 0.95  // 95% 크기
            let height = planeAnchor.planeExtent.height * 0.95
            let planeMesh = MeshResource.generatePlane(width: width, depth: height)
            
            print("📐 평면 크기: \(planeAnchor.planeExtent.width)x\(planeAnchor.planeExtent.height) → \(width)x\(height)")
            
            let material = SimpleMaterial(color: .systemBlue.withAlphaComponent(0.6), isMetallic: false)
            
            let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
            
            // 더 높이 띄워서 겹치지 않게
            planeEntity.transform.translation.y = 0.005
            
            // 등장 애니메이션
            planeEntity.transform.scale = [0.2, 0.2, 0.2]
            
            // 앵커에 평면 추가
            anchorEntity.addChild(planeEntity)
            
            // 씬에 추가
            arView.scene.addAnchor(anchorEntity)
            
            // 뿅! 하고 나타나는 애니메이션
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                var transform = planeEntity.transform
                transform.scale = [1.0, 1.0, 1.0]
                
                planeEntity.move(
                    to: transform,
                    relativeTo: anchorEntity,
                    duration: 0.5,
                    timingFunction: .easeOut
                )
            }
        }
        
        
        // 감지 상태 업데이트 (ON/OFF 처리)
        func updateDetectionState(_ isEnabled: Bool, in arView: ARView) {
            if !isEnabled {
                // 감지 OFF: 모든 평면 제거
                removeAllPlanes(in: arView)
            }
        }
        
        // 모든 평면 시각화 제거
        private func removeAllPlanes(in arView: ARView) {
            // 모든 AnchorEntity 제거 (더 확실한 방법)
            let allAnchors = Array(arView.scene.anchors)
            for anchor in allAnchors {
                arView.scene.removeAnchor(anchor)
            }
        }
        
        // 터치 이벤트 처리
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            guard detectionState.isDetectionEnabled else { return }
            
            let location = gesture.location(in: arView)
            
            // 평면과의 교차점 찾기
            if let query = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .any).first {
                if let planeAnchor = query.anchor as? ARPlaneAnchor {
                    // 선택된 평면 정보 업데이트
                    let selectedInfo = SelectedPlaneInfo(
                        width: planeAnchor.planeExtent.width,
                        height: planeAnchor.planeExtent.height,
                        alignment: planeAnchor.alignment == .horizontal ? "수평" : "수직"
                    )
                    
                    DispatchQueue.main.async {
                        self.detectionState.selectedPlane = selectedInfo
                        print("평면 선택됨: \(selectedInfo.width)x\(selectedInfo.height)m (\(selectedInfo.alignment))")
                    }
                }
            }
        }
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 감지 상태가 변경되면 처리
        context.coordinator.updateDetectionState(detectionState.isDetectionEnabled, in: uiView)
    }
}
