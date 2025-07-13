import SwiftUI
import RealityKit
import ARKit

struct PlacementStabilityView: View {
    @State private var detectionState = PlaneDetectionState()
    @State private var placedCards: [PlacedCard] = []
    
    var body: some View {
        ZStack {
            StabilityARViewContainer(detectionState: $detectionState, placedCards: $placedCards)
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
                    
                    // 배치 컨트롤
                    if detectionState.isDetectionEnabled && detectionState.detectedPlanes > 0 {
                        scatterControls
                    }
                    
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .padding()
        .navigationTitle("배치 안정성")
        .navigationBarTitleDisplayMode(.inline)
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
    
    // 상태창 UI
    private var statusBar: some View {
        HStack {
            Image(systemName: detectionState.detectedPlanes > 0 ? "checkmark.circle.fill" : "magnifyingglass")
                .foregroundStyle(detectionState.detectedPlanes > 0 ? .green : .blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(detectionState.statusMessage)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if detectionState.detectedPlanes > 0 {
                    Text("평면 \(detectionState.detectedPlanes)개 감지됨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // Scatter 컨트롤
    private var scatterControls: some View {
        HStack(spacing: 15) {
            Button {
                scatterCards()
            } label: {
                HStack {
                    Image(systemName: "square.3.layers.3d.down.forward")
                    Text("Scatter")
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            
            if !placedCards.isEmpty {
                Button {
                    clearAllCards()
                } label: {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                        Text("모두 제거")
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            
            Spacer()
        }
    }
    
    
    // Scatter 기능 - 모든 평면 중앙에 카드 배치
    private func scatterCards() {
        // StabilityARViewContainer에 scatter 요청
        NotificationCenter.default.post(name: .scatterCards, object: nil)
        print("Scatter 카드 배치 요청")
    }
    
    // 모든 카드 제거
    private func clearAllCards() {
        NotificationCenter.default.post(name: .clearAllCards, object: nil)
        print("모든 카드 제거")
    }
}

// 배치된 카드 정보
struct PlacedCard: Identifiable {
    let id = UUID()
    let position: simd_float3
    let planeId: UUID
    var isStable: Bool = true
}

#Preview(traits: .landscapeLeft) {
    NavigationStack {
        PlacementStabilityView()
    }
}

// Notification extensions
extension Notification.Name {
    static let scatterCards = Notification.Name("scatterCards")
    static let clearAllCards = Notification.Name("clearAllCards")
}
