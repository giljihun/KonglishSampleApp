import Foundation

// 선택된 평면 정보
struct SelectedPlaneInfo {
    let width: Float
    let height: Float
    let alignment: String
}

// 평면 감지 상태를 나타내는 모델
struct PlaneDetectionState {
    var isDetectionEnabled: Bool = false  // 초기에는 감지 비활성화
    var detectedPlanes: Int = 0
    var lastDetectedType: String = ""
    var statusMessage: String = "감지 시작 버튼을 눌러주세요"
    var selectedPlane: SelectedPlaneInfo? = nil  // 선택된 평면 정보
    
    // 상태 업데이트 메서드
    mutating func updateStatus() {
        if !isDetectionEnabled {
            statusMessage = "평면 감지가 비활성화되었습니다"
        } else if detectedPlanes == 0 {
            statusMessage = "평면을 스캔하고 있습니다..."
        } else {
            statusMessage = "\(detectedPlanes)개의 평면이 감지되었습니다!"
        }
    }
    
    mutating func addPlane(type: String) {
        guard isDetectionEnabled else { return }
        detectedPlanes += 1
        lastDetectedType = type
        updateStatus()
    }
    
    // 감지 리셋 (OFF 시 호출)
    mutating func resetDetection() {
        detectedPlanes = 0
        lastDetectedType = ""
        updateStatus()
    }
    
    // 감지 토글
    mutating func toggleDetection() {
        isDetectionEnabled.toggle()
        if !isDetectionEnabled {
            resetDetection()
        }
        updateStatus()
    }
    
}