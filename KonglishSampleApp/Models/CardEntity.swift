import Foundation
import RealityKit
import UIKit

/// 물리 충돌이 가능한 카드 엔티티
class CardEntity: Entity, HasModel {
    static let cardWidth: Float = 0.5
    static let cardHeight: Float = 0.02  // 5cm 두께 (충돌 감지용)
    static let cardDepth: Float = 0.20
    
    let cardData: GameCard?
    var isFlipped: Bool = false
    var isCompleted: Bool = false
    
    init(cardData: GameCard?) {
        self.cardData = cardData
        super.init()
        
        // 1. 모델 생성
        self.components[ModelComponent.self] = ModelComponent(
            mesh: .generateBox(size: [Self.cardWidth, Self.cardHeight, Self.cardDepth]),
            materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)]
        )
        
        // 2. 물리 충돌 설정 (핵심!)
        setupPhysics()
        
        self.name = "card"
    }
    
    required init() {
        self.cardData = nil
        super.init()
        
        self.components[ModelComponent.self] = ModelComponent(
            mesh: .generateBox(size: [Self.cardWidth, Self.cardHeight, Self.cardDepth]),
            materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)]
        )
        
        setupPhysics()
        self.name = "card"
    }
    
    private func setupPhysics() {
        // RealityKit 최신 API - 충돌 영역을 더 크게
        let collisionWidth = Self.cardWidth * 1.2  // 20% 더 넓게
        let collisionHeight = Self.cardHeight * 0.5  // 절반으로 더 얇게  
        let collisionDepth = Self.cardDepth * 1.2   // 20% 더 길게
        
        let shape = ShapeResource.generateBox(size: [collisionWidth, collisionHeight, collisionDepth])
        
        // PhysicsBodyComponent (농구대처럼 고정)
        self.components[PhysicsBodyComponent.self] = PhysicsBodyComponent(
            shapes: [shape],
            mass: 1.0,
            mode: .static
        )
        
        // CollisionComponent (실제 충돌)
        self.components[CollisionComponent.self] = CollisionComponent(
            shapes: [shape]
        )
        
        print("🃏 카드 물리 설정 완료 - 충돌영역: \(collisionWidth)×\(collisionHeight)×\(collisionDepth)")
    }
    
    // 물리 설정을 카드가 배치된 후에 다시 업데이트하는 함수
    func refreshPhysicsAfterPlacement() {
        setupPhysics()
        addCollisionVisualization()
        print("🔄 카드 배치 후 물리 설정 새로고침")
    }
    
    // 충돌 영역 시각화 (디버깅용)
    private func addCollisionVisualization() {
        let collisionWidth = Self.cardWidth * 1.2
        let collisionHeight = Self.cardHeight * 0.5
        let collisionDepth = Self.cardDepth * 1.2
        
        // 빨간색 반투명 박스로 충돌 영역 표시
        let collisionMesh = MeshResource.generateBox(size: [collisionWidth, collisionHeight, collisionDepth])
        let collisionMaterial = SimpleMaterial(color: UIColor.red.withAlphaComponent(0.3), isMetallic: false)
        
        let collisionVisualizer = ModelEntity(mesh: collisionMesh, materials: [collisionMaterial])
        collisionVisualizer.name = "collision_visualizer"
        
        // 기존 시각화 제거 후 새로 추가
        self.children.removeAll { $0.name == "collision_visualizer" }
        self.addChild(collisionVisualizer)
        
        print("🔴 충돌 영역 시각화 추가: \(collisionWidth)×\(collisionHeight)×\(collisionDepth)")
    }
    
    func updateMaterial() {
        let material = SimpleMaterial(color: isFlipped ? .systemGreen : .systemBlue, isMetallic: false)
        self.model?.materials = [material]
    }
}
