import SwiftUI
import RealityKit
import ARKit

struct CombinedTestView: View {
    var body: some View {
        ZStack {
            SimplePortalARView()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {}
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Apple Portal 테스트")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    
                    Text("벽을 터치하면 포털이 생성됩니다")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .padding(.bottom, 50)
            }
            .padding()
        }
        //.navigationBarHidden(true)
    }
}

struct SimplePortalARView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 설정
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical]
        config.environmentTexturing = .automatic
        
        // 기기 호환성을 고려한 씬 언더스탠딩 설정
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
            config.frameSemantics = .sceneDepth
            print("✅ LiDAR 기기: 완전한 가려짐 지원")
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics = .personSegmentationWithDepth
            print("⚡ 비-LiDAR 기기: 사람 가려짐만 지원")
        } else {
            print("❌ 구형 기기: 가려짐 기능 불가능")
        }
        
        arView.session.run(config)
        
        // sceneUnderstanding 옵션 활성화
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // 터치 제스처 추가
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 업데이트 로직
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var arView: ARView?
        private var portalWorldScene: Entity?
        
        override init() {
            super.init()
            loadPortalAssets()
        }
        
        private func loadPortalAssets() {
            Task {
                do {
                    // PortalWorld.usdz만 로드
                    if let portalWorldURL = Bundle.main.url(forResource: "skybox1", withExtension: "usdz") {
                        portalWorldScene = try await Entity.init(contentsOf: portalWorldURL)
                        print("✅ PortalWorld.usdz 로드 성공!")
                    } else {
                        print("❌ PortalWorld.usdz 파일을 찾을 수 없습니다.")
                    }
                } catch {
                    print("❌ PortalWorld.usdz 로드 실패: \(error)")
                }
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            
            let location = gesture.location(in: arView)
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .vertical)
            
            guard let firstResult = results.first else {
                print("❌ 수직 평면을 찾을 수 없습니다")
                return
            }
            
            print("✅ 수직 평면 발견 - 포털 생성!")
            createPortal(at: firstResult, in: arView)
        }
        
        // PortalWorld.usdz를 사용한 포털 생성
        private func createPortal(at result: ARRaycastResult, in arView: ARView) {
            // PortalWorld.usdz가 로드되지 않았으면 포털 생성 안함
            guard let portalWorldScene = portalWorldScene?.clone(recursive: true) else {
                print("❌ PortalWorld.usdz가 로드되지 않아 포털을 생성할 수 없습니다")
                return
            }
            
            // 1. World 생성
            let world = Entity()
            world.components.set(WorldComponent())
            
            // PortalWorld.usdz 콘텐츠 조정
            //portalWorldScene.transform.scale = [0.5, 0.5, 0.5]
            portalWorldScene.transform.translation.y = 0.0
            portalWorldScene.transform.translation.z = -2.0
            portalWorldScene.transform.rotation = simd_quatf(angle: .pi/2, axis: [-1, 0, 0])  // 90도 위로 - 완전히 위쪽 보기
            
            world.addChild(portalWorldScene)
            
            // 2. Portal 생성 - 원형으로
            let portalMesh = MeshResource.generatePlane(width: 0.8, depth: 0.8, cornerRadius: 0.4)  // 원형 모양
            let portal = ModelEntity(mesh: portalMesh, materials: [PortalMaterial()])
            portal.components.set(PortalComponent(target: world))
            
            
            // 3. 동화 같은 반짝이 파티클 ✨
            let sparkleEntity = Entity()
            var sparkleEmitter = ParticleEmitterComponent()
            
            // 가벼운 반짝이 파티클 설정
            sparkleEmitter.mainEmitter.birthRate = 15                  // 초당 15개 (가볍게)
            sparkleEmitter.mainEmitter.lifeSpan = 1.5                  // 1.5초 (금방 사라지게)
            sparkleEmitter.mainEmitter.size = 0.008                    // 작은 크기
            
            // 동화 같은 파스텔 색상
            sparkleEmitter.mainEmitter.color = .evolving(
                start: .single(UIColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 0.8)),  // 연한 골드
                end: .single(UIColor(red: 1.0, green: 0.7, blue: 0.9, alpha: 0.0))     // 연한 핑크로 사라짐
            )
            
            // 포털 주변에서 살짝 퍼져나가게
            sparkleEmitter.emitterShape = .sphere
            sparkleEmitter.emitterShapeSize = [0.3, 0.3, 0.1]          // 포털 중심 작은 영역
            
            // 위로 살짝 떠오르는 느낌
            sparkleEmitter.emissionDirection = [0, 0.5, 0]
            sparkleEmitter.speed = 0.1
            sparkleEmitter.speedVariation = 0.05           // 작은 속도 변화
            sparkleEmitter.mainEmitter.spreadingAngle = .pi * 0.4      // 넓게 퍼짐
            
            sparkleEntity.components.set(sparkleEmitter)
            sparkleEntity.transform.translation = [0, 0, 0.03]         // 포털 바로 앞
            
            // 4. 앵커에 추가
            let anchor = AnchorEntity(world: result.worldTransform)
            
            // portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
            portal.transform.translation.z = 0.05
            
            anchor.addChild(world)
            anchor.addChild(portal)
            anchor.addChild(sparkleEntity)   // 동화 반짝이 파티클 ✨
            arView.scene.addAnchor(anchor)
            
            print("🌀 포털 생성 완료!")
        }
    }
}

#Preview {
    CombinedTestView()
}
