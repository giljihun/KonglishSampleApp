//
//  SimplePortalTestView.swift
//  KonglishSampleApp
//
//  Created by 길지훈 on 7/27/25.
//

import SwiftUI
import RealityKit
import ARKit

struct SimplePortalTestView: View {
    var body: some View {
        ZStack {
            SimplePortalARView()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button("뒤로") {
                        // NavigationView가 자동으로 처리
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    
                    Spacer()
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("포털 테스트")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    
                    Text("수직 평면을 감지하면 포털이 생성됩니다")
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
        .navigationBarHidden(true)
    }
}

struct SimplePortalARView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // AR 세션 설정
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical]
        config.environmentTexturing = .automatic
        
        // 기기 호환성 설정
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
            config.frameSemantics = .sceneDepth
        }
        
        arView.session.run(config)
        
        // Coordinator에 ARView 전달
        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 업데이트 로직
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        private var portalWorldScene: Entity?
        var arView: ARView?
        
        override init() {
            super.init()
            loadPortalWorld()
        }
        
        private func loadPortalWorld() {
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
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                    DispatchQueue.main.async {
                        self.createPortal(for: planeAnchor)
                    }
                }
            }
        }
        
        private func createPortal(for planeAnchor: ARPlaneAnchor) {
            guard let arView = arView,
                  let portalWorld = portalWorldScene?.clone(recursive: true) else {
                print("❌ ARView 또는 PortalWorld를 찾을 수 없습니다.")
                return
            }
            
            // AnchorEntity 생성
            let anchorEntity = AnchorEntity(anchor: planeAnchor)
            
            // PortalWorld에 WorldComponent 추가
            portalWorld.components.set(WorldComponent())
            
            // 포털 메시 생성
            let portalSize: Float = 0.8
            let portalMesh = MeshResource.generatePlane(width: portalSize, height: portalSize)
            let portalMaterial = SimpleMaterial(color: .clear, isMetallic: false)
            let portalEntity = ModelEntity(mesh: portalMesh, materials: [portalMaterial])
            
            // PortalComponent 설정
            portalEntity.components.set(PortalComponent(
                target: portalWorld,
                clippingMode: .plane(.positiveZ),
                crossingMode: .plane(.positiveZ)
            ))
            
            // 포털 위치 및 회전 조정
            portalEntity.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            portalEntity.transform.translation.z = 0.01
            
            // 포털 크기 조정
            portalEntity.transform.scale = [0.5, 0.5, 0.5]
            
            // 앵커에 추가
            anchorEntity.addChild(portalEntity)
            anchorEntity.addChild(portalWorld)
            
            // 씬에 추가
            arView.scene.addAnchor(anchorEntity)
            
            print("🌀 SimplePortalTestView - 포털 생성 완료")
        }
    }
}

#Preview {
    SimplePortalTestView()
}