import RealityKit
import ARKit

/// 테스트용 카드 감지 기능 (탭 기반)
class CardDetector {
    
    weak var arView: ARView?
    
    init(arView: ARView) {
        self.arView = arView
        print("CardDetector 초기화됨.")
    }
    
    /// 탭한 위치에서 카드 찾기
    func findCardAtLocation(_ location: CGPoint) -> CardEntity? {
        guard let arView = arView else { return nil }
        
        print("🔍 탭 위치: \(location)")
        
        // 1. 먼저 raycast로 평면에 ray를 쏴봄
        let raycastResults = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)
        print("🚀 raycast 결과 개수: \(raycastResults.count)")
        
        if !raycastResults.isEmpty {
            // raycast가 맞은 위치 근처의 카드 찾기
            for result in raycastResults {
                let hitPosition = result.worldTransform.columns.3
                print("🎯 raycast 맞은 위치: \(hitPosition)")
                
                if let cardEntity = findNearestCard(to: hitPosition) {
                    print("✅ 근처 CardEntity 발견!")
                    return cardEntity
                }
            }
        }
        
        // 2. raycast가 실패하면 기존 hitTest 시도
        let hitResults = arView.hitTest(location)
        print("🎯 hitTest 결과 개수: \(hitResults.count)")
        
        for (index, result) in hitResults.enumerated() {
            print("   \(index): \(type(of: result.entity)) - \(result.entity)")
            
            if let cardEntity = findCardEntity(from: result.entity) {
                print("✅ CardEntity 발견!")
                return cardEntity
            }
        }
        
        print("❌ CardEntity를 찾을 수 없음")
        return nil
    }
    
    /// 특정 위치 근처의 카드 찾기
    private func findNearestCard(to position: SIMD4<Float>) -> CardEntity? {
        guard let arView = arView else { return nil }
        
        let targetPosition = SIMD3<Float>(position.x, position.y, position.z)
        
        // 모든 앵커를 순회해서 카드 찾기
        for anchor in arView.scene.anchors {
            if let anchorEntity = anchor as? AnchorEntity {
                for child in anchorEntity.children {
                    if let cardEntity = child as? CardEntity {
                        let cardPosition = cardEntity.position(relativeTo: nil)
                        let distance = simd_distance(cardPosition, targetPosition)
                        
                        print("📏 카드 거리: \(distance)m")
                        
                        // 50cm 이내에 있는 카드 반환
                        if distance < 0.5 {
                            return cardEntity
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Entity에서 CardEntity 찾기 (재귀적으로)
    private func findCardEntity(from entity: Entity) -> CardEntity? {
        if let cardEntity = entity as? CardEntity {
            return cardEntity
        }
        
        if let parent = entity.parent {
            return findCardEntity(from: parent)
        }
        
        return nil
    }
}
