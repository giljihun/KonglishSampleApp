import SwiftUI
import RealityKit
import ARKit

struct PlaneDetectionView: View {
    @State private var detectionState = PlaneDetectionState()
    
    var body: some View {
        ZStack {
            ARViewContainer(detectionState: $detectionState)
                .cornerRadius(12)
            
            // 상단 컨트롤
            VStack {
                HStack {
                    Spacer()
                    
                    toggleButton
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                }
                
                Spacer()
                
                // 하단 UI들
                VStack(spacing: 10) {
                    // 상태창
                    statusBar
                    
                    // 측정 정보창 (평면이 선택되었을 때만 표시)
                    if detectionState.selectedPlane != nil {
                        measurementInfoPanel
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .padding()
        .navigationTitle("평면 스캔 정확도")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // 상태창 UI
    private var statusBar: some View {
        HStack {
            // 상태 아이콘
            Image(systemName: detectionState.detectedPlanes > 0 ? "checkmark.circle.fill" : "magnifyingglass")
                .foregroundStyle(detectionState.detectedPlanes > 0 ? .green : .blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(detectionState.statusMessage)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if detectionState.detectedPlanes > 0 {
                    Text("마지막 감지: \(detectionState.lastDetectedType) 평면")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 평면 개수
            Text("\(detectionState.detectedPlanes)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // 감지 토글 버튼
    private var toggleButton: some View {
        Button {
            detectionState.toggleDetection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: detectionState.isDetectionEnabled ? "stop.circle.fill" : "play.circle.fill")
                Text(detectionState.isDetectionEnabled ? "감지 중지" : "감지 시작")
                    .font(.headline)
            }
            .foregroundStyle(detectionState.isDetectionEnabled ? .red : .green)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
    
    // 측정 정보 패널
    private var measurementInfoPanel: some View {
        VStack(spacing: 15) {
            // 제목
            HStack {
                Image(systemName: "ruler.fill")
                    .foregroundStyle(.green)
                Text("선택된 평면 측정 정보")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button("닫기") {
                    detectionState.selectedPlane = nil
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            if let plane = detectionState.selectedPlane {
                VStack(spacing: 12) {
                    // 스캔된 크기 정보
                    measurementRow(
                        title: "스캔된 크기",
                        value: String(format: "%.2fm × %.2fm (%@)", plane.width, plane.height, plane.alignment),
                        color: .blue
                    )
                    
                    // 센티미터 단위로도 표시
                    measurementRow(
                        title: "센티미터",
                        value: String(format: "%.0fcm × %.0fcm", plane.width * 100, plane.height * 100),
                        color: .secondary
                    )
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // 측정 정보 행
    private func measurementRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
    
}

#Preview(traits: .landscapeLeft) {
    NavigationStack {
        PlaneDetectionView()
    }
}
