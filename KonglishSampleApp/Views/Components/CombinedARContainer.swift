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
                print("💥 충돌 발생! \(event.entityA.name) vs \(event.entityB.name)")
                
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
            print("🎉 1개 달성! 평면 감지 완전 중지 (테스트 모드)")
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
                        // 🧪 테스트용: 1개만 감지하도록 제한
                        guard self.detectedPlanes.count < 1,
                              self.isValidPlaneSize(planeAnchor),
                              !self.isDuplicatePlane(planeAnchor) else { return }
                        
                        let detectedPlane = DetectedPlane(
                            anchor: planeAnchor,
                            position: simd_float3(planeAnchor.transform.columns.3.x, planeAnchor.transform.columns.3.y, planeAnchor.transform.columns.3.z),
                            normal: simd_float3(planeAnchor.transform.columns.1.x, planeAnchor.transform.columns.1.y, planeAnchor.transform.columns.1.z)
                        )
                        
                        self.detectedPlanes.append(detectedPlane)
                        self.addPlaneVisualization(for: planeAnchor)
                        
                        // 🧪 테스트용: 1개 달성시 즉시 중지
                        if self.detectedPlanes.count == 1 {
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
        
        // MARK: - 포털 시각화 (기존 평면 시각화 대체)
        
        private func addPlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let arView = arView else { return }
            
            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            let width = planeAnchor.planeExtent.width * 0.6
            let height = planeAnchor.planeExtent.height * 0.6
            
            // 포털 생성
            let portalEntity = createPortalEntity(width: width, height: height)
            portalEntity.transform.translation.y = 0.01
            portalEntity.name = "portal_\(planeAnchor.identifier)"
            
            anchorEntity.addChild(portalEntity)
            planeEntities[planeAnchor.identifier] = anchorEntity
            planeAnchors[planeAnchor.identifier] = planeAnchor
            arView.scene.addAnchor(anchorEntity)
            
            // 포털 열리는 애니메이션
            animatePortalOpening(portalEntity)
            
            print("🌀 포털이 열렸습니다!")
        }
        
        // 디버깅용: 기본 평면 시각화
        private func createPortalEntity(width: Float, height: Float) -> Entity {
            let container = Entity()
            
            // 일단 포털 말고 기본 평면부터 확인
            let planeMesh = MeshResource.generatePlane(width: 0.5, height: 0.5)
            let planeMaterial = SimpleMaterial(color: .blue, isMetallic: false)
            let planeEntity = ModelEntity(mesh: planeMesh, materials: [planeMaterial])
            
            // 평면을 수직으로 세우기
            planeEntity.transform.rotation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
            planeEntity.transform.translation.z = 0.05
            
            container.addChild(planeEntity)
            
            print("🔵 기본 파란 평면 생성 완료 - 포털 대신 테스트")
            return container
        }
        
        // 간단한 테스트 월드 생성
        func makeSimpleTestWorld() -> Entity {
            let world = Entity()
            world.components.set(WorldComponent())
            
            // 1. 강한 조명 추가
            let lightEntity = Entity()
            let directionalLight = DirectionalLightComponent(
                color: .white,
                intensity: 3000,
                isRealWorldProxy: false
            )
            lightEntity.components.set(directionalLight)
            lightEntity.look(at: [0, 0, -1], from: [0, 1, 0], relativeTo: nil)
            world.addChild(lightEntity)
            
            // 2. 밝은 배경
            let skyMesh = MeshResource.generateSphere(radius: 5.0)
            let skyMaterial = UnlitMaterial(color: UIColor.cyan)  // 밝은 하늘색
            let skyEntity = ModelEntity(mesh: skyMesh, materials: [skyMaterial])
            skyEntity.scale = [-1, 1, 1]  // 내부가 보이도록
            world.addChild(skyEntity)
            
            // 3. 포털 바로 앞에 작은 빨간 박스 
            let testMesh = MeshResource.generateBox(size: 0.2)  // 20cm 박스
            let testMaterial = UnlitMaterial(color: .red)  // 자체 발광
            let testEntity = ModelEntity(mesh: testMesh, materials: [testMaterial])
            
            // 포털 바로 앞에 위치
            testEntity.transform.translation = simd_float3(0, 0, -0.3)  // 30cm 앞
            
            world.addChild(testEntity)
            
            print("🟥 밝은 테스트 월드 생성 완료 - 빨간박스, 하늘색 배경, 강한 조명")
            return world
        }
        
        // WWDC23 공식: World 생성 (동화같은 세상 추가)
        func makeWorld() -> Entity {
            let world = Entity()
            world.components.set(WorldComponent())
            
            // 🌈 동화같은 배경 추가
            addFairyTaleBackground(to: world)
            
            print("🌍 동화같은 포털 월드 생성 완료")
            return world
        }
        
        /// 포털 내부에 동화같은 배경 추가 (밝은 조명 개선)
        private func addFairyTaleBackground(to world: Entity) {
            // 🔆 1. 강력한 환경 조명 추가
            let lightEntity = Entity()
            let directionalLight = DirectionalLightComponent(
                color: .white,
                intensity: 5000,  // 매우 밝게
                isRealWorldProxy: false
            )
            lightEntity.components.set(directionalLight)
            lightEntity.look(at: [0, 0, -1], from: [0, 1, 0], relativeTo: nil)
            world.addChild(lightEntity)
            
            // 🌈 2. 매우 밝은 배경 (큰 구체로 감싸기)
            let skyMesh = MeshResource.generateSphere(radius: 8.0)
            let skyMaterial = UnlitMaterial(color: UIColor(red: 1.0, green: 1.0, blue: 0.9, alpha: 1.0))  // 매우 밝은 크림색
            let skyEntity = ModelEntity(mesh: skyMesh, materials: [skyMaterial])
            skyEntity.scale = [-1, 1, 1]  // 내부가 보이도록 뒤집기
            world.addChild(skyEntity)
            
            // ✨ 3. 밝게 빛나는 별들 (자체 발광, 더 크게)
            for i in 0..<12 {
                let starMesh = MeshResource.generateSphere(radius: 0.05)
                let starColors: [UIColor] = [
                    UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0),   // 순수 노랑
                    UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0),   // 시안
                    UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0),   // 마젠타
                    UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)    // 주황
                ]
                let starMaterial = UnlitMaterial(color: starColors[i % starColors.count])
                let starEntity = ModelEntity(mesh: starMesh, materials: [starMaterial])
                
                // 별을 더 넓게 배치
                let x = Float.random(in: -2.0...2.0)
                let y = Float.random(in: -2.0...2.0)
                let z = Float.random(in: -4.0 ... -1.0)
                starEntity.transform.translation = simd_float3(x, y, z)
                
                world.addChild(starEntity)
            }
            
            // 🌸 4. 더 많은 밝은 꽃들
            for i in 0..<10 {
                let flowerMesh = MeshResource.generateSphere(radius: 0.06)
                let flowerColors: [UIColor] = [
                    UIColor(red: 1.0, green: 0.4, blue: 0.8, alpha: 1.0),   // 밝은 핑크
                    UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0),   // 밝은 보라
                    UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0),   // 밝은 하늘색
                    UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1.0)    // 밝은 노랑
                ]
                let flowerMaterial = UnlitMaterial(color: flowerColors[i % flowerColors.count])
                let flowerEntity = ModelEntity(mesh: flowerMesh, materials: [flowerMaterial])
                
                // 꽃을 원형으로 여러 층에 배치
                let angle = Float(i) * 2 * .pi / 10
                let radius: Float = 1.2 + Float(i % 3) * 0.3  // 3개 층으로
                let x = cos(angle) * radius
                let y = sin(angle) * radius
                flowerEntity.transform.translation = simd_float3(x, y, -2.0)
                
                world.addChild(flowerEntity)
            }
            
            print("🌈✨🌸 매우 밝은 동화 배경을 포털에 추가했습니다!")
        }
        
        // WWDC23 공식: Portal 생성 (방향 수정)
        func makePortal(world: Entity, size: Float) -> Entity {
            let portal = Entity()
            
            // 포털 메시 생성 (원형 포털)
            let portalMesh = MeshResource.generatePlane(width: size, height: size, cornerRadius: size/2)
            let portalMaterial = PortalMaterial()
            
            portal.components.set(
                ModelComponent(mesh: portalMesh, materials: [portalMaterial])
            )
            
            // 포털 컴포넌트 설정 - 올바른 방향으로
            portal.components.set(PortalComponent(target: world,
                                                  clippingMode: .plane(.positiveZ),
                                                  crossingMode: .plane(.positiveZ)))
            
            // 🔧 핵심 수정: 포털이 올바른 방향을 보도록 회전
            // RealityKit 포털은 기본적으로 아래를 향하므로 90도 회전 필요
            portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])  // X축 기준 90도 회전
            
            // 포털에 이름 부여 (디버깅용)
            portal.name = "portal_plane"
            
            print("🌀 포털 방향 수정 완료 - 90도 회전으로 올바른 방향 설정")
            return portal
        }
        
        // 포털에서 나오는 파티클 효과 ✨
        private func createPortalRingParticles(size: Float) -> Entity {
            let particleEntity = Entity()
            
            // RealityKit 파티클 이미터 생성
            var particleEmitter = ParticleEmitterComponent()
            
            // 파티클 기본 설정 (포털에서 밖으로 나오는 효과)
            particleEmitter.mainEmitter.birthRate = 150            // 적당한 생성률
            particleEmitter.mainEmitter.lifeSpan = 2.0            // 2초 수명
            particleEmitter.mainEmitter.size = 0.01             // 작은 파티클
            
            // 파티클 색상 (푸른빛 → 투명)
            particleEmitter.mainEmitter.color = .evolving(start: .single(.blue),
                                                          end: .single(.yellow))
            
            // 포털 중심에서 밖으로 방출
            particleEmitter.emitterShape = .torus
            particleEmitter.emitterShapeSize = [size * 0.1, size * 0.1, 0.1]  // 포털 중심 작은 영역
            
            // 파티클이 밖으로 퍼져나가는 효과
            particleEmitter.mainEmitter.spreadingAngle = .pi * 0.3  // 넓게 퍼짐
            
            particleEntity.components.set(particleEmitter)
            particleEntity.position.z = 0  // 포털 중심에
            particleEntity.name = "portal_emission_particles"
            
            print("✨ 포털 방출 파티클 생성!")
            return particleEntity
        }
        
        
        private func animatePortalOpening(_ portalEntity: Entity) {
            // 처음엔 작게 시작
            portalEntity.transform.scale = [0.1, 0.1, 0.1]
            
            // 포털이 열리는 애니메이션
            var transform = portalEntity.transform
            transform.scale = [1.0, 1.0, 1.0]
            
            portalEntity.move(
                to: transform,
                relativeTo: portalEntity.parent,
                duration: 1.5,
                timingFunction: .easeOut
            )
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
            
            // 포털에서 카드가 나오는 애니메이션 시작
            animateCardFromPortal(cardEntity, anchorEntity: anchorEntity, finalOffset: offset, normal: detectedPlane.normal)
            
            cardEntities[UUID()] = cardEntity
            
            DispatchQueue.main.async {
                let placedCard = PlacedCard(position: detectedPlane.position, planeId: detectedPlane.id)
                self.placedCards.append(placedCard)
            }
            
            // 카드 생성 완료 후 포털 천천히 닫기 (2.5초 후 시작)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.animatePortalClosing(anchorEntity)
            }
        }
        
        // 📚 간단한 포털 카드 애니메이션 (동화같은 느낌)
        private func animateCardFromPortal(_ cardEntity: CardEntity, anchorEntity: AnchorEntity, finalOffset: simd_float3, normal: simd_float3) {
            // 포털 월드에 카드 추가하여 내부에서 생성
            if let portalContainer = anchorEntity.children.first,
               let portalWorld = portalContainer.children.first(where: { $0.components[WorldComponent.self] != nil }) {
                
                let finalRotation = calculateCardRotation(normal: normal)
                
                // 1. 포털 중심에서 작게 시작
                cardEntity.transform.translation = simd_float3(0, 0, -1.0)  // 포털 중심
                cardEntity.transform.rotation = finalRotation
                cardEntity.transform.scale = [0.1, 0.1, 0.1]  // 작게 시작
                
                portalWorld.addChild(cardEntity)
                print("📚 카드가 포털 내부에서 생성됩니다!")
                
                // 2. 포털 내부에서 커지는 애니메이션 (2초)
                var growTransform = cardEntity.transform
                growTransform.scale = [1.0, 1.0, 1.0]  // 완전한 크기로
                growTransform.translation = simd_float3(0, 0, -0.1)  // 포털 면 근처
                
                cardEntity.move(to: growTransform, relativeTo: portalWorld, duration: 2.0, timingFunction: .easeOut)
                print("✨ 카드가 포털 내부에서 천천히 커집니다!")
                
                // 3. 카드 완성 후 최종 위치 설정 및 물리 활성화
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // 포털 월드에서 앵커로 이동 (부모 변경)
                    cardEntity.removeFromParent()
                    
                    // 최종 위치 설정
                    cardEntity.transform.translation = simd_float3(0, 0, 0) + finalOffset
                    cardEntity.transform.rotation = finalRotation
                    cardEntity.transform.scale = [1.0, 1.0, 1.0]
                    
                    anchorEntity.addChild(cardEntity)
                    
                    // 물리 시스템 활성화
                    cardEntity.refreshPhysicsAfterPlacement()
                    cardEntity.updateMaterial()
                    
                    print("🎉 카드가 완성되어 배치되었습니다!")
                }
            }
        }
        
        private func animatePortalClosing(_ anchorEntity: AnchorEntity) {
            guard let portalContainer = anchorEntity.children.first else { return }
            
            print("🌀 포털이 닫히기 시작...")
            
            // 포털이 줄어들면서 닫히는 애니메이션
            var closeTransform = portalContainer.transform
            closeTransform.scale = [0.01, 0.01, 0.01]
            
            portalContainer.move(
                to: closeTransform,
                relativeTo: anchorEntity,
                duration: 1.5,
                timingFunction: .easeIn
            )
            
            // 완전히 사라지는 효과
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                portalContainer.removeFromParent()
                print("💫 포털이 완전히 닫혔습니다!")
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
