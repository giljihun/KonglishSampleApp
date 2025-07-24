import SwiftUI
import RealityKit
import ARKit

/// 슈팅 테스트 전용 AR 컨테이너
struct ShootingARContainer: UIViewRepresentable {
    let enableOcclusion: Bool = false  // 슈팅 테스트용: false, 리얼한 체험용: true
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 설정
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical, .horizontal]  // 바닥도 감지!
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
        
        // sceneUnderstanding 설정 (선택적 occlusion)
        if enableOcclusion {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            print("✅ Occlusion 활성화: 리얼한 가려짐 효과")
        } else {
            print("🚫 Occlusion 비활성화: 공이 벽 뒤로 가도 사라지지 않음!")
        }
        
        // 디버그 옵션
        arView.debugOptions = []
        
        // Coordinator 설정
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 필요시 업데이트 로직
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var arView: ARView?
        
        override init() {
            super.init()
            
            // Notification 리스너 등록
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleShootObject),
                name: .shootObject,
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - 발사 처리
        @objc func handleShootObject(_ notification: Notification) {
            // 간단한 구체 생성해서 날리기
//            createAndLaunchSphere()
            createAndLaunchModel()
        }
        
        /// 간단한 구체 생성 및 발사
        private func createAndLaunchSphere() {
            guard let arView = arView else { return }
            guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
                return
            }
            
            // 카메라 위치와 방향 벡터 계산
            let cameraPosition = simd_float3(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
            
            // 카메라가 바라보는 방향 (앞 방향)
            let forwardVector = simd_float3(
                -cameraTransform.columns.2.x,
                -cameraTransform.columns.2.y,
                -cameraTransform.columns.2.z
            )
            
            // 발사 위치: 카메라 앞 50cm (패드 앞쪽에서 발사)
            let startPosition = cameraPosition + forwardVector * 0.5
            
            // 구체 생성
            let sphereEntity = ModelEntity(
                mesh: .generateSphere(radius: 0.05),
                materials: [SimpleMaterial(color: .green, isMetallic: true)]
            )
            
            // 물리 컴포넌트 추가 (튀어나올 수 있도록)
            let physicsMaterial = PhysicsMaterialResource.generate(
                staticFriction: 0.2,      // 적은 마찰력
                dynamicFriction: 0.1,     // 매우 적은 동적 마찰
                restitution: 0.8          // 높은 반발력 (잘 튀도록)
            )
            
            let physicsBody = PhysicsBodyComponent(
                massProperties: .default,
                material: physicsMaterial,
                mode: .dynamic
            )
            sphereEntity.components.set(physicsBody)
            
            // 충돌 컴포넌트 추가
            let collisionShape = ShapeResource.generateSphere(radius: 0.05)
            let collisionComponent = CollisionComponent(shapes: [collisionShape])
            sphereEntity.components.set(collisionComponent)
            
            sphereEntity.name = "test_sphere"
            
            // AnchorEntity 생성 및 위치 설정
            let anchorEntity = AnchorEntity()
            anchorEntity.transform.translation = startPosition
            anchorEntity.addChild(sphereEntity)
            arView.scene.addAnchor(anchorEntity)
            
            // 벽에 박힐 만큼 강하게 발사! 뽕!!! 
            let forceStrength: Float = 800.0  // 강하지만 적절한 힘 (너무 세면 벽 뚫음)
            let upwardAngle: Float = 0.15     // 거의 수평 발사
            
            // 위쪽 벡터 계산
            let upVector = simd_float3(0, 1, 0)
            
            // 발사 방향: 거의 수평으로, 아주 살짝만 위로
            let launchDirection = normalize(forwardVector + upVector * upwardAngle)
            let impulse = launchDirection * forceStrength

            sphereEntity.addForce(impulse, relativeTo: nil as Entity?)
            
            // 10초 후 자동 제거 (멀리 날아가는 것 확인하기 위해)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                arView.scene.removeAnchor(anchorEntity)
            }
        }
        
        /// 모델 발사!
        private func createAndLaunchModel() {
            guard let arView = arView else { return }
            guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
                return
            }

            let cameraPosition = simd_float3(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )

            let forwardVector = simd_float3(
                -cameraTransform.columns.2.x,
                -cameraTransform.columns.2.y,
                -cameraTransform.columns.2.z
            )

            let startPosition = cameraPosition + forwardVector * 0.5

            guard let entity = try? Entity.load(named: "kong") else {
                print("모델 로드 실패")
                return
            }

            // 모델 스케일 조절
            entity.scale = SIMD3<Float>(0.1, 0.1, 0.1)

            // 충돌 및 물리 컴포넌트 재귀 적용 함수
            func applyPhysicsRecursively(to entity: Entity) {
                if let modelEntity = entity as? ModelEntity {
                    modelEntity.generateCollisionShapes(recursive: true)
                    let physicsMaterial = PhysicsMaterialResource.generate(
                        staticFriction: 0.2,
                        dynamicFriction: 0.1,
                        restitution: 0.8
                    )
                    let physicsBody = PhysicsBodyComponent(
                        massProperties: .default,
                        material: physicsMaterial,
                        mode: .dynamic
                    )
                    modelEntity.components.set(physicsBody)
                }
                for child in entity.children {
                    applyPhysicsRecursively(to: child)
                }
            }

            applyPhysicsRecursively(to: entity)

            let anchor = AnchorEntity(world: startPosition)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)

            // 힘을 재귀적으로 주는 함수
            func addForceRecursively(to entity: Entity, force: SIMD3<Float>, relativeTo: Entity?) {
                if let physicsEntity = entity as? HasPhysics {
                    physicsEntity.addForce(force, relativeTo: relativeTo)
                }
                for child in entity.children {
                    addForceRecursively(to: child, force: force, relativeTo: relativeTo)
                }
            }

            let forceStrength: Float = 1000.0
            let upwardAngle: Float = 0.45
            let upVector = SIMD3<Float>(0, 1, 0)
            let launchDirection = simd_normalize(forwardVector + upVector * upwardAngle)
            let impulse = launchDirection * forceStrength

            addForceRecursively(to: entity, force: impulse, relativeTo: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                arView.scene.removeAnchor(anchor)
            }
        }


    }
}

// Notification extensions
extension Notification.Name {
    static let shootObject = Notification.Name("shootObject")
}
