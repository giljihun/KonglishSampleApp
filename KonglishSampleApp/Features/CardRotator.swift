import RealityKit
import ARKit

/// 테스트용 카드 회전 기능
class CardRotator {
    
    weak var arView: ARView?
    
    init(arView: ARView) {
        self.arView = arView
        print("CardRotator 초기화됨.")
    }
    
    /// 카드 회전 실행
    func rotateCard(_ cardEntity: CardEntity) {
        // 완료된 카드는 회전하지 않음
        guard !cardEntity.isCompleted else {
            print("이미 완료된 카드라서 회전하지 않습니다.")
            return
        }
        
        // 현재 회전에서 추가 회전 계산
        let currentRotation = cardEntity.transform.rotation
        let additionalRotation = simd_quatf(angle: .pi, axis: [1, 0, 0]) // Y축 180도
        let targetRotation = currentRotation * additionalRotation
        
        let newFlippedState = !cardEntity.isFlipped
        
        if cardEntity.isFlipped {
            print("카드를 뒷면으로 되돌립니다.")
        } else {
            print("카드를 앞면으로 뒤집습니다.")
        }
        
        // 즉시 상태 업데이트 (애니메이션 시작 전)
        cardEntity.isFlipped = newFlippedState
        cardEntity.updateMaterial()
        
        // 애니메이션으로 실제 회전 실행
        var targetTransform = cardEntity.transform
        targetTransform.rotation = targetRotation
        
        cardEntity.move(
            to: targetTransform,
            relativeTo: cardEntity.parent,
            duration: 0.5,
            timingFunction: .easeInOut
        )
        
        print("🔄 회전 애니메이션 시작: \(newFlippedState ? "앞면" : "뒷면")")
    }
}
