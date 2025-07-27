//
//  PortalARContainer.swift
//  KonglishSampleApp
//
//  Created by 길지훈 on 7/27/25.
//

import SwiftUI
import RealityKit
import ARKit
import Foundation

struct PortalARContainer: UIViewRepresentable {
    @Binding var detectedPlanes: [DetectedPlane]
    @Binding var placedCards: [PlacedCard]
    @Binding var isScanning: Bool
    
    private struct CardConstants {
        static let width: Float = 0.35      // 15cm → 25cm (더 큰 카드)
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
        context.coordinator.setupCardFeatures(arView: arView)
        
        // 평면 감지 이벤트 처리를 위한 delegate 설정
        arView.session.delegate = context.coordinator
        
        // 탭 제스처 추가
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
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
        
        // Reality Composer Pro에서 로드할 씬들을 저장할 변수
        private var portalWorldScene: Entity?
        
        // 평면별 Entity 추적
        private var planeEntities: [UUID: AnchorEntity] = [:]
        private var planeAnchors: [UUID: ARPlaneAnchor] = [:]
        private var cardEntities: [UUID: CardEntity] = [:]
        private var cardAnchors: [UUID: AnchorEntity] = [:]
        
        // 카드 기능들
        private var cardDetector: CardDetector?
        private var cardRotator: CardRotator?
        
        // 감지 상태
        private var isDetectionActive = false
        
        init(detectedPlanes: Binding<[DetectedPlane]>, placedCards: Binding<[PlacedCard]>, isScanning: Binding<Bool>) {
            self._detectedPlanes = detectedPlanes
            self._placedCards = placedCards
            self._isScanning = isScanning
            super.init()
            loadScenes()
            
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
        
        /// 1개 달성 시 평면 감지 완전 중지
        private func stopPlaneDetectionCompletely() {
            print("🎉 1개 달성! 평면 감지 완전 중지")
            
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
                    
                    // 1개 미만일 때만 추가 (테스트용)
                    DispatchQueue.main.async {
                        guard self.detectedPlanes.count < 1 else {
                            print("✋ 1개 도달 - 추가 평면 차단")
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
                        
                        print("✅ 유효한 평면 추가: \(self.detectedPlanes.count)/1")
                        
                        // 정확히 1개 달성 시 완전 중지
                        if self.detectedPlanes.count == 1 {
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
                        print("❌ 평면 제거됨: \(self.detectedPlanes.count)/1")
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
            
            // 최소 크기 기준 (테스트용으로 완화)
            let minArea: Float = 0.01      // 최소 면적: 0.01m² (약 10cm x 10cm)
            let minWidth: Float = 0.05     // 최소 폭: 5cm
            let minHeight: Float = 0.05    // 최소 높이: 5cm
            
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
        
        // MARK: - 포털 시각화
        private func addPlaneVisualization(for planeAnchor: ARPlaneAnchor) {
            guard let arView = arView else { return }
            
            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            
            // PortalWorld 씬 로드 확인
            guard let portalWorld = portalWorldScene?.clone(recursive: true) else {
                print("❌ PortalWorld 씬이 로드되지 않았습니다.")
                return
            }
            
            // PortalWorld에 WorldComponent 추가
            portalWorld.components.set(WorldComponent())
            print("✅ PortalWorld에 WorldComponent 설정됨")
            
            // 기본 포털 메시 생성 (사각형)
            let portalSize: Float = 0.5 // 포털 크기
            let portalMesh = MeshResource.generatePlane(width: portalSize, height: portalSize)
            let portalMaterial = SimpleMaterial(color: .clear, isMetallic: false) // 투명 재질
            
            let portalEntity = ModelEntity(mesh: portalMesh, materials: [portalMaterial])
            
            // PortalComponent를 사용하여 PortalWorld와 연결
            portalEntity.components.set(PortalComponent(
                target: portalWorld,
                clippingMode: .plane(.positiveZ),
                crossingMode: .plane(.positiveZ)
            ))
            
            // 포털 위치 및 회전 조정 (수직 평면에 맞춤)
            portalEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) // 평면을 세움
            portalEntity.transform.translation.z = 0.01 // 평면에서 약간 앞으로
            
            // PortalEntity를 앵커에 추가
            anchorEntity.addChild(portalEntity)
            
            // PortalWorld를 앵커에 추가 (PortalEntity의 자식이 아닌, 동일한 앵커에 추가)
            // 이렇게 하면 PortalWorld가 PortalEntity의 가림막을 통해 보이게 됩니다.
            anchorEntity.addChild(portalWorld)
            
            planeEntities[planeAnchor.identifier] = anchorEntity
            planeAnchors[planeAnchor.identifier] = planeAnchor
            arView.scene.addAnchor(anchorEntity)
            
            print("🌀 기본 포털 배치 완료")
        }
        
        // MARK: - 씬 로드
        private func loadScenes() {
            Task {
                do {
                    if let portalWorldURL = Bundle.main.url(forResource: "PortalWorld", withExtension: "usdz") {
                        portalWorldScene = try await Entity.init(contentsOf: portalWorldURL)
                        print("✅ PortalWorld 씬 로드 성공")
                    } else {
                        print("❌ PortalWorld.usdz 파일을 찾을 수 없습니다.")
                    }
                } catch {
                    print("❌ PortalWorld 씬 로드 실패: \(error)")
                }
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
                print("배치할 평면이 없음.")
                return
            }
            
            print("🎯 \(detectedPlanes.count)개 평면에 카드 배치 시작")
            
            // 각 평면에 카드 배치
            for detectedPlane in detectedPlanes {
                placeCardOnPlane(detectedPlane: detectedPlane)
            }
        }
        
        private func placeCardOnPlane(detectedPlane: DetectedPlane) {
            
            guard let anchorEntity = planeEntities[detectedPlane.anchor.identifier] else { return }
            
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
            print("📌 카드 저장됨: \(cardId) - 총 \(cardEntities.count)개")
            
            // 배치 정보 업데이트
            DispatchQueue.main.async {
                let placedCard = PlacedCard(position: detectedPlane.position, planeId: detectedPlane.id)
                self.placedCards.append(placedCard)
            }
            
            print("📌 카드 배치 완료: \(detectedPlane.position)")
        }
        
        private func createCard() -> CardEntity {
            let gameCard = GameCard(
                wordKor: "테스트", wordEng: "Test"
            )
            
            let cardEntity = CardEntity(cardData: gameCard)
            return cardEntity
        }
        
        private func addCardDesign(to cardEntity: CardEntity) {
            // CardEntity에서 자체적으로 머티리얼 관리
            cardEntity.updateMaterial()
        }
        
        private func calculateCardRotation(normal: simd_float3) -> simd_quatf {
            let upVector = simd_float3(0, 1, 0)
            let rightVector = simd_normalize(simd_cross(upVector, normal))
            let correctedUp = simd_cross(normal, rightVector)
            
            return simd_quatf(simd_float3x3(rightVector, correctedUp, normal))
        }
        
        // MARK: - 카드 기능 설정
        func setupCardFeatures(arView: ARView) {
            cardDetector = CardDetector(arView: arView)
            cardRotator = CardRotator(arView: arView)
        }
        
        // MARK: - 탭 처리
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView,
                  let cardDetector = cardDetector,
                  let cardRotator = cardRotator else { return }
            
            let location = gesture.location(in: arView)
            
            // 탭한 위치에서 카드 찾기
            if let cardEntity = cardDetector.findCardAtLocation(location) {
                print("🃏 카드 탭됨: \(cardEntity.cardData?.wordEng ?? "Unknown")")
                
                // 카드 회전 실행
                cardRotator.rotateCard(cardEntity)
                
                // 테스트용: 완료 상태 변경 제거 (계속 회전 가능하게)
            } else {
                print("❌ 카드를 찾을 수 없습니다.")
            }
        }
        
        private func loadPortalScene() -> Entity? {
            // 이 함수는 더 이상 사용되지 않습니다.
            return nil
        }
        
        private func loadPortalWorld() -> Entity? {
            // 이 함수는 더 이상 사용되지 않습니다.
            return nil
        }
        
    }
}
