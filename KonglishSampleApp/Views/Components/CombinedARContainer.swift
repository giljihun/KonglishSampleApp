import SwiftUI
import RealityKit
import ARKit

/*
 # CombinedARContainer - 카드 배치 + 슈팅 결합 AR 컨테이너
 
 ## 로직 플로우:
 1. **초기화**: AR 세션 설정, 모델 미리 로드, 카드 기능 설정
 2. **평면 감지**: 수직 평면 1개 감지 → 자동 중지
 3. **카드 배치**: 감지된 평면에 탭-회전 가능한 카드 배치
 4. **슈팅**: 미리 로드된 soccerball 모델을 물리 시뮬레이션으로 발사
 */

struct CombinedARContainer: UIViewRepresentable {
    @Binding var detectedPlanes: [DetectedPlane]
    @Binding var placedCards: [PlacedCard]
    @Binding var isScanning: Bool
    
    private struct CardConstants {
        static let width: Float = 0.35
        static let height: Float = 0.003
        static let depth: Float = 0.20
        static let offsetDistance: Float = 0.01
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 구성
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical, .horizontal]
        config.environmentTexturing = .automatic
        
        // 기기별 기능 설정
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
            config.frameSemantics = .sceneDepth
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics = .personSegmentationWithDepth
        }
        
        arView.session.run(config)
        arView.debugOptions = []
        
        // Coordinator 연결
        context.coordinator.arView = arView
        context.coordinator.setupCardFeatures(arView: arView)
        arView.session.delegate = context.coordinator
        
        // 탭 제스처 추가
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
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
        
        // 엔티티 추적
        private var planeEntities: [UUID: AnchorEntity] = [:]
        private var planeAnchors: [UUID: ARPlaneAnchor] = [:]
        private var cardEntities: [UUID: CardEntity] = [:]
        
        // 카드 기능
        private var cardDetector: CardDetector?
        private var cardRotator: CardRotator?
        
        // 상태 관리
        private var isDetectionActive = false
        private var preloadedModel: Entity? // 성능 최적화용 미리 로드된 모델
        
        init(detectedPlanes: Binding<[DetectedPlane]>, placedCards: Binding<[PlacedCard]>, isScanning: Binding<Bool>) {
            self._detectedPlanes = detectedPlanes
            self._placedCards = placedCards
            self._isScanning = isScanning
            super.init()
            
            setupNotifications()
            preloadModelAsync()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - 초기 설정
        
        private func setupNotifications() {
            let notifications: [(Notification.Name, Selector)] = [
                (.startPlaneDetection, #selector(handleStartPlaneDetection)),
                (.stopPlaneDetection, #selector(handleStopPlaneDetection)),
                (.scatterCards, #selector(handleScatterCards)),
                (.shootObjectAtCards, #selector(handleShootObjectAtCards))
            ]
            
            notifications.forEach { name, selector in
                NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
            }
        }
        
        func setupCardFeatures(arView: ARView) {
            cardDetector = CardDetector(arView: arView)
            cardRotator = CardRotator(arView: arView)
            
            // 충돌 이벤트 구독 (디버깅용)
            setupCollisionDetection()
        }
        
        private func setupCollisionDetection() {
            guard let arView = arView else { return }
            
            arView.scene.subscribe(to: CollisionEvents.Began.self) { event in
                print("💥 충돌 발생! \(event.entityA.name ?? "unknown") vs \(event.entityB.name ?? "unknown")")
                
                // soccerball과 card 충돌 시 회전
                if (event.entityA.name == "soccerball" && event.entityB.name == "card") ||
                   (event.entityB.name == "soccerball" && event.entityA.name == "card") {
                    print("🎯 공-카드 충돌! 카드 회전 시작")
                    
                    let cardEntity = event.entityA.name == "card" ? event.entityA as? CardEntity : event.entityB as? CardEntity
                    if let card = cardEntity {
                        self.cardRotator?.rotateCard(card)
                    }
                }
            }
        }
        
        // MARK: - 평면 감지 관리
        
        @objc func handleStartPlaneDetection() {
            isDetectionActive = true
            restartPlaneDetection()
        }
        
        @objc func handleStopPlaneDetection() {
            isDetectionActive = false
        }
        
        func updateScanningState(_ scanning: Bool) {
            isDetectionActive = scanning
        }
        
        private func stopPlaneDetectionCompletely() {
            print("🎉 5개 달성! 평면 감지 완전 중지")
            isDetectionActive = false
            isScanning = false
            
            if let arView = arView {
                let config = ARWorldTrackingConfiguration()
                config.planeDetection = []
                config.environmentTexturing = .automatic
                
                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                    config.sceneReconstruction = .meshWithClassification
                    config.frameSemantics = .sceneDepth
                }
                
                arView.session.run(config)
            }
            
            NotificationCenter.default.post(name: .targetReached, object: nil)
        }
        
        private func restartPlaneDetection() {
            if let arView = arView {
                let config = ARWorldTrackingConfiguration()
                config.planeDetection = [.vertical]
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
                if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                    DispatchQueue.main.async {
                        guard self.detectedPlanes.count < 5,
                              self.isValidPlaneSize(planeAnchor),
                              !self.isDuplicatePlane(planeAnchor) else { return }
                        
                        let detectedPlane = DetectedPlane(
                            anchor: planeAnchor,
                            position: simd_float3(planeAnchor.transform.columns.3.x, planeAnchor.transform.columns.3.y, planeAnchor.transform.columns.3.z),
                            normal: simd_float3(planeAnchor.transform.columns.1.x, planeAnchor.transform.columns.1.y, planeAnchor.transform.columns.1.z)
                        )
                        
                        self.detectedPlanes.append(detectedPlane)
                        self.addPlaneVisualization(for: planeAnchor)
                        
                        if self.detectedPlanes.count == 5 {
                            self.stopPlaneDetectionCompletely()
                        }
                    }
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
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
                    DispatchQueue.main.async {
                        self.detectedPlanes.removeAll { $0.anchor.identifier == planeAnchor.identifier }
                    }
                }
            }
        }
        
        // MARK: - 평면 필터링
        
        private func isValidPlaneSize(_ planeAnchor: ARPlaneAnchor) -> Bool {
            let width = planeAnchor.planeExtent.width
            let height = planeAnchor.planeExtent.height
            let area = width * height
            
            return area >= 0.01 && width >= 0.05 && height >= 0.05
        }
        
        private func isDuplicatePlane(_ newPlane: ARPlaneAnchor) -> Bool {
            let newPosition = simd_float3(newPlane.transform.columns.3.x, newPlane.transform.columns.3.y, newPlane.transform.columns.3.z)
            let newNormal = simd_float3(newPlane.transform.columns.1.x, newPlane.transform.columns.1.y, newPlane.transform.columns.1.z)
            
            for existingPlane in detectedPlanes {
                let distance = simd_length(newPosition - existingPlane.position)
                let dotProduct = simd_dot(newNormal, existingPlane.normal)
                
                if distance < 0.5 && abs(dotProduct) > 0.85 {
                    return true
                }
            }
            
            return false
        }
        
        // MARK: - 평면 시각화
        
        private func addPlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let arView = arView else { return }
            
            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            let width = planeAnchor.planeExtent.width * 0.95
            let height = planeAnchor.planeExtent.height * 0.95
            let planeMesh = MeshResource.generatePlane(width: width, depth: height)
            
            let material = SimpleMaterial(color: .systemBlue.withAlphaComponent(0.3), isMetallic: false)
            let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
            
            planeEntity.transform.translation.y = 0.005
            planeEntity.transform.scale = [0.2, 0.2, 0.2]
            anchorEntity.addChild(planeEntity)
            
            planeEntities[planeAnchor.identifier] = anchorEntity
            planeAnchors[planeAnchor.identifier] = planeAnchor
            arView.scene.addAnchor(anchorEntity)
            
            // 등장 애니메이션
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                var transform = planeEntity.transform
                transform.scale = [1.0, 1.0, 1.0]
                planeEntity.move(to: transform, relativeTo: anchorEntity, duration: 0.5, timingFunction: .easeOut)
            }
        }
        
        private func updatePlaneVisualization(for planeAnchor: ARPlaneAnchor, anchorEntity: AnchorEntity) {
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
            guard !detectedPlanes.isEmpty else { return }
            
            detectedPlanes.forEach { placeCardOnPlane(detectedPlane: $0) }
        }
        
        private func placeCardOnPlane(detectedPlane: DetectedPlane) {
            guard let anchorEntity = planeEntities[detectedPlane.anchor.identifier] else { return }
            
            let cardEntity = createCard()
            let offset = detectedPlane.normal * CardConstants.offsetDistance
            
            cardEntity.transform.translation = simd_float3(0, 0, 0) + offset
            cardEntity.transform.rotation = calculateCardRotation(normal: detectedPlane.normal)
            cardEntity.updateMaterial()
            
            // 회전 후 물리 설정 새로고침
            cardEntity.refreshPhysicsAfterPlacement()
            
            anchorEntity.addChild(cardEntity)
            cardEntities[UUID()] = cardEntity
            
            DispatchQueue.main.async {
                let placedCard = PlacedCard(position: detectedPlane.position, planeId: detectedPlane.id)
                self.placedCards.append(placedCard)
            }
        }
        
        private func createCard() -> CardEntity {
            let gameCard = GameCard(wordKor: "테스트", wordEng: "Test")
            return CardEntity(cardData: gameCard)
        }
        
        private func calculateCardRotation(normal: simd_float3) -> simd_quatf {
            let upVector = simd_float3(0, 1, 0)
            let rightVector = simd_normalize(simd_cross(upVector, normal))
            let correctedUp = simd_cross(normal, rightVector)
            
            return simd_quatf(simd_float3x3(rightVector, correctedUp, normal))
        }
        
        // MARK: - 탭 처리
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView,
                  let cardDetector = cardDetector,
                  let cardRotator = cardRotator else { return }
            
            let location = gesture.location(in: arView)
            
            if let cardEntity = cardDetector.findCardAtLocation(location) {
                cardRotator.rotateCard(cardEntity)
            }
        }
        
        // MARK: - 슈팅 시스템
        
        private func preloadModelAsync() {
            DispatchQueue.main.async {
                do {
                    let entity = try Entity.load(named: "soccerball")
                    entity.scale = SIMD3<Float>(1.0, 1.0, 1.0)
                    self.setupPhysicsForEntity(entity)
                    self.preloadedModel = entity
                } catch {
                    print("❌ soccerball 모델 로드 실패: \(error)")
                }
            }
        }
        
        private func setupPhysicsForEntity(_ entity: Entity) {
            print("🔧 물리 설정 시작: \(type(of: entity))")
            
            let ballRadius: Float = 0.1
            let shape = ShapeResource.generateSphere(radius: ballRadius)
            
            // Entity가 ModelEntity인지 확인하고 설정
            func setupPhysicsRecursively(for entity: Entity) {
                if let modelEntity = entity as? ModelEntity {
                    print("   ModelEntity 발견, 물리 설정 중...")
                    
                    // PhysicsBodyComponent (움직이는 공)
                    var physicsBody = PhysicsBodyComponent(
                        shapes: [shape],
                        mass: 0.5,  // 원래 질량으로 복원
                        mode: .dynamic
                    )
                    
                    // 반발력 조정 (덜 튕기게) - 다시 추가
                    physicsBody.material = PhysicsMaterialResource.generate(
                        friction: 0.5,
                        restitution: 0.3  // 반발계수 낮춤
                    )
                    
                    modelEntity.components[PhysicsBodyComponent.self] = physicsBody
                    
                    // CollisionComponent (실제 충돌)
                    modelEntity.components[CollisionComponent.self] = CollisionComponent(
                        shapes: [shape]
                    )
                    
                    print("✅ ModelEntity 물리 설정 완료")
                    return
                }
                
                // 자식 엔티티도 확인
                for child in entity.children {
                    setupPhysicsRecursively(for: child)
                }
            }
            
            setupPhysicsRecursively(for: entity)
            print("⚽ soccerball 물리 설정 완료")
        }
        
        @objc func handleShootObjectAtCards(_ notification: Notification) {
            launchPreloadedModel()
        }
        
        private func launchPreloadedModel() {
            guard let arView = arView,
                  let cameraTransform = arView.session.currentFrame?.camera.transform,
                  let preloadedModel = preloadedModel else { return }

            let cameraPosition = simd_float3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            let forwardVector = simd_float3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
            
            // 발사 위치를 아래쪽으로 조정 (손 위치처럼)
            let downwardOffset = simd_float3(0, -0.5, 0)  // 30cm 아래
            let startPosition = cameraPosition + forwardVector * 0.5 + downwardOffset

            let entity = preloadedModel.clone(recursive: true)
            entity.name = "soccerball"
            setupPhysicsForEntity(entity)
            
            let anchor = AnchorEntity(world: startPosition)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)

            applyForceToEntity(entity, forwardVector: forwardVector)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                arView.scene.removeAnchor(anchor)
            }
        }
        
        private func applyForceToEntity(_ entity: Entity, forwardVector: SIMD3<Float>) {
            print("🔍 Force 디버깅 시작")
            print("   forwardVector: \(forwardVector)")
            
            let forceStrength: Float = 600.0  // 원래 작동하던 속도로 복원
            let upwardAngle: Float = 0.2  // 원래 작동하던 각도로 복원
            let upVector = SIMD3<Float>(0, 1, 0)
            let launchDirection = simd_normalize(forwardVector + upVector * upwardAngle)
            let impulse = launchDirection * forceStrength
            
            print("   launchDirection: \(launchDirection)")
            print("   impulse: \(impulse)")
            
            // ModelEntity 찾아서 힘 적용
            func applyForceRecursively(to entity: Entity) {
                print("   Entity 체크: \(type(of: entity)) - \(entity.name)")
                
                if let modelEntity = entity as? ModelEntity {
                    let hasPhysics = modelEntity.components[PhysicsBodyComponent.self] != nil
                    print("   ModelEntity 발견! Physics: \(hasPhysics)")
                    
                    if hasPhysics {
                        modelEntity.addForce(impulse, relativeTo: nil)
                        print("🚀 ModelEntity에 힘 적용 성공!")
                        return
                    }
                }
                
                // 자식 엔티티도 확인
                for child in entity.children {
                    applyForceRecursively(to: child)
                }
            }
            
            applyForceRecursively(to: entity)
        }
    }
}
