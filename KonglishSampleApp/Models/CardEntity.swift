import Foundation
import RealityKit
import UIKit

/// 물리 충돌이 가능한 카드 엔티티 (Konglish 디자인 적용)
class CardEntity: Entity, HasModel {
    // Konglish 실제 카드 크기 적용 (가로세로 비율 68:44)
    static let cardWidth: Float = 0.255   // 25.5cm
    static let cardHeight: Float = 0.01   // 1cm 두께 (얇게)
    static let cardDepth: Float = 0.165   // 16.5cm (가로세로 비율 맞춤)
    
    let cardData: GameCard?
    var isFlipped: Bool = false
    var isCompleted: Bool = false
    
    init(cardData: GameCard?) {
        self.cardData = cardData
        super.init()
        
        // 1. 모델 생성 (Konglish 스타일 카드)
        self.components[ModelComponent.self] = ModelComponent(
            mesh: .generateBox(size: [Self.cardWidth, Self.cardHeight, Self.cardDepth]),
            materials: [createCardMaterial()]
        )
        
        // 2. 물리 충돌 설정 (핵심!)
        setupPhysics()
        
        self.name = "card"
        
        // 3. 카드 디자인 업데이트
        updateCardDesign()
    }
    
    required init() {
        self.cardData = nil
        super.init()
        
        self.components[ModelComponent.self] = ModelComponent(
            mesh: .generateBox(size: [Self.cardWidth, Self.cardHeight, Self.cardDepth]),
            materials: [createCardMaterial()]
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
        // addCollisionVisualization()
        
        // 포털 크로싱 컴포넌트 추가 (WWDC23 스타일)
        self.components.set(PortalCrossingComponent())
        print("🔄 카드 배치 후 물리 설정 새로고침 + 포털 크로싱 설정")
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
    
    // MARK: - Konglish Card Design
    
    /// Konglish 스타일 카드 머티리얼 생성
    private func createCardMaterial() -> Material {
        // Konglish 카드 배경색 (연한 노란색)
        let cardBackgroundColor = UIColor(red: 0.855, green: 0.855, blue: 0.571, alpha: 1.0)
        return SimpleMaterial(color: cardBackgroundColor, isMetallic: false)
    }
    
    /// 카드 디자인 업데이트 (동적 텍스처 적용)
    private func updateCardDesign() {
        guard let cardData = cardData else { return }
        
        Task { @MainActor in
            let cardTexture = await createCardTexture(for: cardData)
            self.model?.materials = [cardTexture]
        }
    }
    
    /// Konglish 스타일 카드 텍스처 생성
    @MainActor
    private func createCardTexture(for cardData: GameCard) async -> Material {
        let cardSize = CGSize(width: 680 * 4, height: 440 * 4) // 고해상도
        
        let cardImage = createCardImage(
            engTitle: cardData.wordEng,
            korTitle: cardData.wordKor,
            size: cardSize
        )
        
        // UIImage를 RealityKit 텍스처로 변환
        do {
            guard let cgImage = cardImage.cgImage else {
                return createCardMaterial()
            }
            
            let texture = try await TextureResource.generate(
                from: cgImage,
                withName: nil,
                options: .init(semantic: .normal, compression: .default)
            )
            
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(texture: MaterialParameters.Texture(texture))
            return material
        } catch {
            print("❌ 카드 텍스처 생성 실패: \(error)")
            return createCardMaterial()
        }
    }
    
    /// Konglish 카드 이미지 생성 (실제 디자인 적용)
    private func createCardImage(engTitle: String, korTitle: String, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 1. 배경 그리기 (Konglish 카드 색상)
            let cardBackgroundColor = UIColor(red: 0.855, green: 0.855, blue: 0.571, alpha: 1.0)
            cardBackgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 2. 카드 테두리 그리기
            let borderColor = UIColor.white
            borderColor.setStroke()
            let borderRect = CGRect(origin: .zero, size: size).insetBy(dx: 20, dy: 20)
            let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: 40)
            borderPath.lineWidth = 8
            borderPath.stroke()
            
            // 3. 이미지 영역 (왼쪽)
            let imageRect = CGRect(
                x: size.width * 0.06,   // 40/680 비율
                y: size.height * 0.18,  // 80/440 비율
                width: size.width * 0.41,  // 280/680 비율
                height: size.height * 0.64 // 280/440 비율
            )
            
            // 임시 이미지 (사과 아이콘)
            let placeholderColor = UIColor.white
            placeholderColor.setFill()
            let imagePath = UIBezierPath(roundedRect: imageRect, cornerRadius: 20)
            imagePath.fill()
            
            // 사과 아이콘 그리기 (간단한 원형)
            let iconRect = imageRect.insetBy(dx: imageRect.width * 0.2, dy: imageRect.height * 0.2)
            let iconColor = UIColor.systemRed
            iconColor.setFill()
            let iconPath = UIBezierPath(ovalIn: iconRect)
            iconPath.fill()
            
            // 4. 단락 스타일 설정
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            // 5. 영문 텍스트 (오른쪽 위)
            let engTextRect = CGRect(
                x: size.width * 0.49,   // 336/680 비율
                y: size.height * 0.26,  // 116/440 비율
                width: size.width * 0.45, // 304/680 비율
                height: size.height * 0.18 // 80/440 비율
            )
            
            let engFont = UIFont.systemFont(ofSize: size.width * 0.08, weight: .black) // 크기 조정
            let engAttributedText = NSAttributedString(string: engTitle, attributes: [
                .font: engFont,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: UIColor.black,
                .strokeColor: UIColor.white,
                .strokeWidth: -10,
            ])
            engAttributedText.draw(in: engTextRect)
            
            // 6. 국문 텍스트 (오른쪽 아래)
            let korTextRect = CGRect(
                x: size.width * 0.49,   // 336/680 비율
                y: size.height * 0.64,  // 280/440 비율
                width: size.width * 0.45, // 304/680 비율
                height: size.height * 0.11 // 47/440 비율
            )
            
            let korFont = UIFont.systemFont(ofSize: size.width * 0.05, weight: .bold) // 크기 조정
            let korAttributedText = NSAttributedString(string: korTitle, attributes: [
                .font: korFont,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: UIColor.black,
                .strokeColor: UIColor.white,
                .strokeWidth: -6,
            ])
            korAttributedText.draw(in: korTextRect)
        }
    }
}
