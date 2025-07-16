import SwiftUI
import RealityKit
import ARKit

struct IntegrationARContainer: UIViewRepresentable {
    @Binding var detectedPlanes: [DetectedPlane]
    @Binding var placedCards: [PlacedCard]
    @Binding var isScanning: Bool
    
    private struct CardConstants {
        static let width: Float = 0.25      // 15cm → 25cm (더 큰 카드)
        static let height: Float = 0.003    // 2mm → 3mm (약간 두껍게)
        static let depth: Float = 0.20      // 15cm → 20cm (더 큰 카드)
        static let offsetDistance: Float = 0.01
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 설정 (수직 평면 전용)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical]
        config.environmentTexturing = .automatic
        
        // 기기 호환성을 고려한 설정
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
            config.frameSemantics = .sceneDepth
            print("🚀 LiDAR 기기: 완전한 가려짐 지원")
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics = .personSegmentationWithDepth
            print("⚡ 비-LiDAR 기기: 사람 가려짐만 지원")
        } else {
            print("❌ 구형 기기: 가려짐 기능 불가능")
        }
        
        arView.session.run(config)
        
        // sceneUnderstanding 설정
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // 디버그 옵션
        arView.debugOptions = []
        
        // Coordinator 설정
        context.coordinator.arView = arView
        
        // 평면 감지 이벤트 처리를 위한 delegate 설정
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 스캔 상태 업데이트
        context.coordinator.updateScanningState(isScanning)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(detectedPlanes: $detectedPlanes, placedCards: $placedCards, isScanning: $isScanning)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        @Binding var detectedPlanes: [DetectedPlane]
        @Binding var placedCards: [PlacedCard]
        @Binding var isScanning: Bool
        
        var arView: ARView?
        
        // 평면별 Entity 추적
        private var planeEntities: [UUID: AnchorEntity] = [:]
        private var planeAnchors: [UUID: ARPlaneAnchor] = [:]
        private var cardEntities: [UUID: ModelEntity] = [:]
        private var cardAnchors: [UUID: AnchorEntity] = [:]
        
        // 감지 상태
        private var isDetectionActive = false
        
        init(detectedPlanes: Binding<[DetectedPlane]>, placedCards: Binding<[PlacedCard]>, isScanning: Binding<Bool>) {
            self._detectedPlanes = detectedPlanes
            self._placedCards = placedCards
            self._isScanning = isScanning
            super.init()
            
            // Notification 리스너 등록
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleStartPlaneDetection),
                name: .startPlaneDetection,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleStopPlaneDetection),
                name: .stopPlaneDetection,
                object: nil
            )
            
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
        
        // MARK: - 평면 감지 관리
        
        @objc func handleStartPlaneDetection() {
            isDetectionActive = true
            restartPlaneDetection()  // ARSession 재시작
            print("🎯 평면 감지 활성화")
        }
        
        @objc func handleStopPlaneDetection() {
            isDetectionActive = false
            print("🛑 평면 감지 비활성화")
        }
        
        func updateScanningState(_ scanning: Bool) {
            isDetectionActive = scanning
        }
        
        /// 15개 달성 시 평면 감지 완전 중지
        private func stopPlaneDetectionCompletely() {
            print("🎉 15개 달성! 평면 감지 완전 중지")
            
            // 1. 감지 상태 비활성화
            isDetectionActive = false
            
            // 2. UI 스캔 상태 업데이트
            isScanning = false
            
            // 3. ARSession 평면 감지 완전 중지
            if let arView = arView {
                let config = ARWorldTrackingConfiguration()
                config.planeDetection = []  // 평면 감지 완전 중지
                config.environmentTexturing = .automatic
                
                // 기존 sceneReconstruction 설정 유지
                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                    config.sceneReconstruction = .meshWithClassification
                    config.frameSemantics = .sceneDepth
                }
                
                arView.session.run(config)
            }
            
            // 4. 목표 달성 알림
            NotificationCenter.default.post(name: .targetReached, object: nil)
        }
        
        /// 스캔 재시작 시 평면 감지 재활성화
        private func restartPlaneDetection() {
            print("🔄 평면 감지 재시작")
            
            if let arView = arView {
                let config = ARWorldTrackingConfiguration()
                config.planeDetection = [.vertical]  // 수직 평면 감지 재활성화
                config.environmentTexturing = .automatic
                
                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                    config.sceneReconstruction = .meshWithClassification
                    config.frameSemantics = .sceneDepth
                }
                
                arView.session.run(config)
            }
        }
        
        // MARK: - ARSessionDelegate
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard isDetectionActive else { return }
            
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    // 수직 평면만 처리
                    guard planeAnchor.alignment == .vertical else { continue }
                    
                    // 15개 미만일 때만 추가 (핵심 로직)
                    DispatchQueue.main.async {
                        guard self.detectedPlanes.count < 15 else { 
                            print("✋ 15개 도달 - 추가 평면 차단")
                            return 
                        }
                        
                        // 1. 평면 크기 필터링 (너무 작은 평면 제외)
                        guard self.isValidPlaneSize(planeAnchor) else {
                            print("🚫 너무 작은 평면 제외: \(planeAnchor.planeExtent.width)x\(planeAnchor.planeExtent.height)")
                            return
                        }
                        
                        // 2. 중복 평면 체크 (같은 벽의 다른 부분 제외)
                        guard !self.isDuplicatePlane(planeAnchor) else {
                            print("🚫 중복 평면 제외")
                            return
                        }
                        
                        // 3. 유효한 평면만 추가
                        let detectedPlane = DetectedPlane(
                            anchor: planeAnchor,
                            position: simd_float3(planeAnchor.transform.columns.3.x, planeAnchor.transform.columns.3.y, planeAnchor.transform.columns.3.z),
                            normal: simd_float3(planeAnchor.transform.columns.1.x, planeAnchor.transform.columns.1.y, planeAnchor.transform.columns.1.z)
                        )
                        
                        self.detectedPlanes.append(detectedPlane)
                        self.addPlaneVisualization(for: planeAnchor)
                        
                        print("✅ 유효한 평면 추가: \(self.detectedPlanes.count)/15")
                        
                        // 정확히 15개 달성 시 완전 중지
                        if self.detectedPlanes.count == 15 {
                            self.stopPlaneDetectionCompletely()
                        }
                    }
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            // 평면 업데이트 처리 (크기 변경 등)
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor,
                   let anchorEntity = planeEntities[planeAnchor.identifier] {
                    updatePlaneVisualization(for: planeAnchor, anchorEntity: anchorEntity)
                }
            }
        }
        
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    removePlaneVisualization(for: planeAnchor)
                    
                    // 감지된 평면 목록에서 제거
                    DispatchQueue.main.async {
                        self.detectedPlanes.removeAll { $0.anchor.identifier == planeAnchor.identifier }
                        print("❌ 평면 제거됨: \(self.detectedPlanes.count)/15")
                    }
                }
            }
        }
        
        // MARK: - 평면 품질 필터링
        
        /// 평면 크기가 유효한지 체크 (너무 작은 평면 제외)
        private func isValidPlaneSize(_ planeAnchor: ARPlaneAnchor) -> Bool {
            let width = planeAnchor.planeExtent.width
            let height = planeAnchor.planeExtent.height
            let area = width * height
            
            // 최소 크기 기준
            let minArea: Float = 0.05      // 최소 면적: 0.05m² (약 22cm x 22cm)
            let minWidth: Float = 0.15     // 최소 폭: 15cm
            let minHeight: Float = 0.15    // 최소 높이: 15cm
            
            let isValid = area >= minArea && width >= minWidth && height >= minHeight
            
            if !isValid {
                print("📏 평면 크기 검사: \(width)x\(height) = \(area)m² (기준: \(minArea)m²)")
            }
            
            return isValid
        }
        
        /// 중복 평면인지 체크 (같은 벽의 다른 부분 제외)
        private func isDuplicatePlane(_ newPlane: ARPlaneAnchor) -> Bool {
            let newPosition = simd_float3(newPlane.transform.columns.3.x, newPlane.transform.columns.3.y, newPlane.transform.columns.3.z)
            let newNormal = simd_float3(newPlane.transform.columns.1.x, newPlane.transform.columns.1.y, newPlane.transform.columns.1.z)
            
            for existingPlane in detectedPlanes {
                let existingPosition = existingPlane.position
                let existingNormal = existingPlane.normal
                
                // 1. 거리 체크 (50cm 이내)
                let distance = simd_length(newPosition - existingPosition)
                if distance < 0.5 {
                    
                    // 2. 법선 벡터 체크 (거의 평행한지 - 같은 벽인지)
                    let dotProduct = simd_dot(newNormal, existingNormal)
                    if abs(dotProduct) > 0.85 {  // 약 32도 이내면 같은 평면으로 판단
                        print("🔍 중복 평면 감지:")
                        print("   거리: \(distance)m")
                        print("   각도 유사도: \(abs(dotProduct))")
                        return true
                    }
                }
            }
            
            return false
        }
        
        // MARK: - 평면 시각화
        private func addPlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let arView = arView else { return }
            
            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            
            // 평면 시각화
            let width = planeAnchor.planeExtent.width * 0.95
            let height = planeAnchor.planeExtent.height * 0.95
            let planeMesh = MeshResource.generatePlane(width: width, depth: height)
            
            let material = SimpleMaterial(color: .systemBlue.withAlphaComponent(0.3), isMetallic: false)
            let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
            
            planeEntity.transform.translation.y = 0.005
            
            // 등장 애니메이션
            planeEntity.transform.scale = [0.2, 0.2, 0.2]
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
        }
        
        private func updatePlaneVisualization(for planeAnchor: ARPlaneAnchor, anchorEntity: AnchorEntity) {
            // 평면 크기 업데이트 로직
            guard let planeEntity = anchorEntity.children.first as? ModelEntity else { return }
            
            let width = planeAnchor.planeExtent.width * 0.95
            let height = planeAnchor.planeExtent.height * 0.95
            let planeMesh = MeshResource.generatePlane(width: width, depth: height)
            
            planeEntity.model?.mesh = planeMesh
        }
        
        private func removePlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let arView = arView,
                  let anchorEntity = planeEntities[planeAnchor.identifier] else { return }
            
            arView.scene.removeAnchor(anchorEntity)
            planeEntities.removeValue(forKey: planeAnchor.identifier)
            planeAnchors.removeValue(forKey: planeAnchor.identifier)
        }
        
        // MARK: - 카드 배치
        
        @objc func handleScatterCards() {
            guard !detectedPlanes.isEmpty else {
                print("❌ 배치할 평면이 없습니다")
                return
            }
            
            // 기존 카드 제거
            removeAllCards()
            
            print("🎯 \(detectedPlanes.count)개 평면에 카드 배치 시작")
            
            // 각 평면에 카드 배치
            for detectedPlane in detectedPlanes {
                placeCardOnPlane(detectedPlane: detectedPlane)
            }
        }
        
        private func placeCardOnPlane(detectedPlane: DetectedPlane) {
            guard let arView = arView,
                  let anchorEntity = planeEntities[detectedPlane.anchor.identifier] else { return }
            
            let cardEntity = createCard()
            let cardId = UUID()
            
            // 평면 중심에서 약간 앞쪽으로 오프셋
            let offset = detectedPlane.normal * CardConstants.offsetDistance
            cardEntity.transform.translation = simd_float3(0, 0, 0) + offset
            
            // 카드 회전 (평면에 맞춤)
            cardEntity.transform.rotation = calculateCardRotation(normal: detectedPlane.normal)
            
            // 카드 디자인
            addCardDesign(to: cardEntity)
            
            // 앵커에 추가
            anchorEntity.addChild(cardEntity)
            
            // 저장
            cardEntities[cardId] = cardEntity
            
            // 배치 정보 업데이트
            DispatchQueue.main.async {
                let placedCard = PlacedCard(position: detectedPlane.position, planeId: detectedPlane.id)
                self.placedCards.append(placedCard)
            }
            
            print("📌 카드 배치 완료: \(detectedPlane.position)")
        }
        
        private func createCard() -> ModelEntity {
            let cardMesh = MeshResource.generateBox(
                width: CardConstants.width,
                height: CardConstants.height,
                depth: CardConstants.depth
            )
            
            let cardEntity = ModelEntity(mesh: cardMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
            cardEntity.generateCollisionShapes(recursive: true)
            
            return cardEntity
        }
        
        private func addCardDesign(to cardEntity: ModelEntity) {
            let material = SimpleMaterial(color: .systemGreen, isMetallic: false)
            cardEntity.model?.materials = [material]
        }
        
        private func calculateCardRotation(normal: simd_float3) -> simd_quatf {
            let upVector = simd_float3(0, 1, 0)
            let rightVector = simd_normalize(simd_cross(upVector, normal))
            let correctedUp = simd_cross(normal, rightVector)
            
            return simd_quatf(simd_float3x3(rightVector, correctedUp, normal))
        }
        
        // MARK: - 카드 제거
        
        @objc func handleClearAllCards() {
            removeAllCards()
        }
        
        private func removeAllCards() {
            // 모든 카드 엔티티 제거
            for (_, cardEntity) in cardEntities {
                cardEntity.removeFromParent()
            }
            
            cardEntities.removeAll()
            
            DispatchQueue.main.async {
                self.placedCards.removeAll()
            }
            
            print("🗑️ 모든 카드 제거 완료")
        }
    }
}
