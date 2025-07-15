import SwiftUI
import RealityKit
import ARKit

struct StabilityARViewContainer: UIViewRepresentable {
    @Binding var detectionState: PlaneDetectionState
    @Binding var placedCards: [PlacedCard]
    
    private struct CardConstants {
        static let width: Float = 0.15
        static let height: Float = 0.002
        static let depth: Float = 0.15
        static let offsetDistance: Float = 0.01
        static let tiltCorrectionAngle: Float = -.pi / 12  // -15도
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 시작 + 평면 감지 설정
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        // 기기 호환성을 고려한 설정
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            // LiDAR 기기: 완전한 가려짐
            config.sceneReconstruction = .meshWithClassification
            config.frameSemantics = .sceneDepth
            print("LiDAR 기기: 완전한 가려짐 지원")
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            // 비-LiDAR 기기: 사람 가려짐만
            config.frameSemantics = .personSegmentationWithDepth
            print("비-LiDAR 기기: 사람 가려짐만 지원")
        } else {
            print("구형 기기: 가려짐 기능 불가능")
        }
        
        arView.session.run(config)
        
        // sceneUnderstanding 옵션 설정
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        arView.debugOptions = [
            //.showFeaturePoints,
            .showSceneUnderstanding]
        
        // Coordinator에 ARView 전달
        context.coordinator.arView = arView
        
        // 평면 감지 이벤트 처리를 위한 delegate 설정
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(detectionState: $detectionState, placedCards: $placedCards)
    }
    
    // ARSession 이벤트를 처리하는 Coordinator
    class Coordinator: NSObject, ARSessionDelegate {
        var arView: ARView?
        @Binding var detectionState: PlaneDetectionState
        @Binding var placedCards: [PlacedCard]
        
        // 평면별 Entity 추적
        private var planeEntities: [UUID: AnchorEntity] = [:]
        private var planeAnchors: [UUID: ARPlaneAnchor] = [:]  // 평면 앵커 직접 저장
        private var cardEntities: [UUID: ModelEntity] = [:]
        
        init(detectionState: Binding<PlaneDetectionState>, placedCards: Binding<[PlacedCard]>) {
            self._detectionState = detectionState
            self._placedCards = placedCards
            super.init()
            
            // Notification 리스너 등록
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScatterCards),
                name: .scatterCards,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleClearAllCards),
                name: .clearAllCards,
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
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
            
            // 평면 시각화 (더 연한 색상으로)
            let width = planeAnchor.planeExtent.width * 0.95
            let height = planeAnchor.planeExtent.height * 0.95
            let planeMesh = MeshResource.generatePlane(width: width, depth: height)
            
            let material = SimpleMaterial(color: .systemBlue.withAlphaComponent(0.3), isMetallic: false)
            let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
            
            // 더 높이 띄워서 겹치지 않게
            planeEntity.transform.translation.y = 0.005
            
            // 등장 애니메이션
            planeEntity.transform.scale = [0.2, 0.2, 0.2]
            
            // 앵커에 평면 추가
            anchorEntity.addChild(planeEntity)
            
            // 평면 추적을 위해 저장
            planeEntities[planeAnchor.identifier] = anchorEntity
            planeAnchors[planeAnchor.identifier] = planeAnchor
            
            // 씬에 추가
            arView.scene.addAnchor(anchorEntity)
            
            // 애니메이션
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
            
            print("평면 추가됨: \(planeAnchor.identifier)")
        }
        
        // Scatter 카드 배치 - 모든 평면 중앙에 배치
        @objc func handleScatterCards() {
            guard let arView = arView else { return }
            guard detectionState.isDetectionEnabled else { return }
            
            // 기존 카드 모두 제거
            removeAllCards(in: arView)
            
            // 각 평면의 중앙에 카드 배치
            for (planeId, _) in planeEntities {
                if let planeAnchor = planeAnchors[planeId] {
                    placeCardOnPlaneCenter(planeAnchor: planeAnchor, planeId: planeId)
                }
            }
        }
        
        // 모든 카드 제거 요청 처리
        @objc func handleClearAllCards() {
            guard arView != nil else { return }
            removeAllCards(in: arView!)
        }
        
        // 평면 중앙에 카드 배치 (포스트잇처럼)
        private func placeCardOnPlaneCenter(planeAnchor: ARPlaneAnchor, planeId: UUID) {
            // 큰 카드 생성 (포스트잇 크기)
            let cardMesh = MeshResource.generateBox(width: 0.3, height: 0.004, depth: 0.2) // 15cm x 15cm, 2mm 두께
            let cardMaterial = SimpleMaterial(color: .white, isMetallic: false)
            
            let cardEntity = ModelEntity(mesh: cardMesh, materials: [cardMaterial])
            
            // sceneUnderstanding을 위한 물리 컴포넌트 추가 (간단 버전)
            cardEntity.generateCollisionShapes(recursive: true)
            
            // 카드에 평면과 같은 회전 적용 (포스트잇처럼 평면에 맞춤)
            let planeTransform = Transform(matrix: planeAnchor.transform)
            
            if planeAnchor.alignment == .horizontal {
                cardEntity.transform.rotation = planeTransform.rotation
            } else {
                let wallRotation = simd_quatf(angle: .pi / 2, axis: simd_float3(1, 0, 0)) // X축 기준 90도 회전
                cardEntity.transform.rotation = planeTransform.rotation * wallRotation
            }
            
            // 평면 방향에 따른 오프셋 계산
            let offset: simd_float3
            if planeAnchor.alignment == .horizontal {
                offset = simd_float3(0, 0.05, 0)
            } else {
                offset = simd_float3(0, 0.05, 0)
            }
            
            // 카드 디자인 추가
            addCardDesign(to: cardEntity)
            
            // 카드 ID 생성
            let cardId = UUID()
            
            // 평면에 고정된 앵커 생성 (평면과 함께 움직임)
            if let anchorEntity = planeEntities[planeId] {
                cardEntity.transform.translation = offset // 평면 기준 상대 위치
                anchorEntity.addChild(cardEntity)
                
                // 카드 정보 저장
                cardEntities[cardId] = cardEntity
                
                // 배치된 카드 정보 업데이트
                DispatchQueue.main.async {
                    let planeCenter = planeAnchor.transform.columns.3
                    let cardPosition = simd_float3(planeCenter.x, planeCenter.y, planeCenter.z) + offset
                    let placedCard = PlacedCard(position: cardPosition, planeId: planeId)
                    self.placedCards.append(placedCard)
                }
                
                print("카드 평면 중앙에 배치됨 (\(planeAnchor.alignment == .horizontal ? "수평" : "수직"))")
            }
        }
        
        // 카드 디자인 추가
        private func addCardDesign(to cardEntity: ModelEntity) {
            // 카드 앞면에 텍스트나 이미지 추가 (간단한 색상으로 시작)
            let frontMaterial = SimpleMaterial(color: .systemOrange, isMetallic: false)
            cardEntity.model?.materials = [frontMaterial]
            
            // 나중에 실제 카드 텍스처나 텍스트 추가 가능
        }
        
        // 감지 상태 업데이트 (ON/OFF 처리)
        func updateDetectionState(_ isEnabled: Bool, in arView: ARView) {
            if !isEnabled {
                // 감지 OFF: 모든 평면과 카드 제거
                removeAllPlanes(in: arView)
                removeAllCards(in: arView)
            }
        }
        
        // 모든 평면 시각화 제거
        private func removeAllPlanes(in arView: ARView) {
            for (_, anchorEntity) in planeEntities {
                arView.scene.removeAnchor(anchorEntity)
            }
            planeEntities.removeAll()
            planeAnchors.removeAll()
        }
        
        // 모든 카드 제거
        private func removeAllCards(in arView: ARView) {
            // 카드 엔티티들을 각 평면에서 제거
            for (_, cardEntity) in cardEntities {
                cardEntity.removeFromParent()
            }
            cardEntities.removeAll()
            
            DispatchQueue.main.async {
                self.placedCards.removeAll()
            }
        }
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 감지 상태가 변경되면 처리
        context.coordinator.updateDetectionState(detectionState.isDetectionEnabled, in: uiView)
    }
}
