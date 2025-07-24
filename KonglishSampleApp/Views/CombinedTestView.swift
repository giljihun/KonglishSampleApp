import SwiftUI
import ARKit

/// 테스트1(탭-로테이션) + 슈팅테스트를 결합한 테스트3
struct CombinedTestView: View {
    @State private var detectedPlanes: [DetectedPlane] = []
    @State private var placedCards: [PlacedCard] = []
    @State private var isScanning = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var targetAchieved = false
    @State private var rightShooting = false
    @State private var shotCount = 0
    
    // 목표 평면 수 (테스트용)
    private let targetPlaneCount = 1
    
    var body: some View {
        ZStack {
            // 결합된 AR 뷰 컨테이너
            CombinedARContainer(
                detectedPlanes: $detectedPlanes,
                placedCards: $placedCards,
                isScanning: $isScanning
            )
            .ignoresSafeArea()
            
            // 상단 정보 표시
            VStack {
                combinedStatusView()
                
                Spacer()
                
                // 하단 컨트롤
                bottomControlsView()
                    .padding(.bottom, 30)
            }
            
            // 오른쪽 발사 버튼
            HStack {
                Spacer()
                
                VStack {
                    Spacer()
                    rightShootingButton()
                    Spacer()
                }
                .padding(.trailing, 30)
            }
        }
        .navigationTitle("결합 테스트")
        .navigationBarTitleDisplayMode(.inline)
        .alert("알림", isPresented: $showingAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .targetReached)) { _ in
            targetAchieved = true
            print("🎉 UI: 목표 달성 알림 수신")
        }
    }
    
    /// 결합된 상태 표시
    func combinedStatusView() -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("카드 배치 + 슈팅 결합 테스트")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("감지된 평면")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(detectedPlanes.count)/\(targetPlaneCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(detectedPlanes.count >= targetPlaneCount ? .green : .blue)
                }
                
                VStack(spacing: 4) {
                    Text("배치된 카드")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(placedCards.count)개")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("발사한 구체")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(shotCount)개")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    /// 하단 컨트롤
    func bottomControlsView() -> some View {
        VStack(spacing: 15) {
            // 목표 달성 시 Scatter 버튼 표시
            if targetAchieved || detectedPlanes.count >= targetPlaneCount {
                completionView()
            }
            
            // 컨트롤 버튼들
            HStack(spacing: 20) {
                Button {
                    toggleScanning()
                } label: {
                    HStack {
                        Image(systemName: isScanning ? "stop.circle.fill" : "play.circle.fill")
                        Text(isScanning ? "스캔 중지" : "스캔 시작")
                    }
                    .font(.body)
                    .foregroundStyle(isScanning ? .red : .green)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .padding(.horizontal)
    }
    
    /// 스캔 완료 뷰
    func completionView() -> some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text("평면 감지 완료! 카드 배치 후 슈팅 시작!")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            
            Button {
                scatterCards()
            } label: {
                HStack {
                    Image(systemName: "sharedwithyou")
                    Text("카드 배치!")
                }
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: 600)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    /// 오른쪽 발사 버튼
    func rightShootingButton() -> some View {
        Button {
            shootObject()
        } label: {
            ZStack {
                Circle()
                    .fill(.red.gradient)
                    .frame(width: 80, height: 80)
                    .scaleEffect(rightShooting ? 1.2 : 1.0)
                    .shadow(color: .red.opacity(0.3), radius: rightShooting ? 20 : 8)
                
                Image(systemName: "target")
                    .font(.title)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.1), value: rightShooting)
    }
    
    // MARK: - 액션 메서드들
    
    private func toggleScanning() {
        isScanning.toggle()
        
        if isScanning {
            startScanning()
        } else {
            stopScanning()
        }
    }
    
    private func startScanning() {
        NotificationCenter.default.post(name: .startPlaneDetection, object: nil)
        print("🎯 평면 감지 시작")
    }
    
    private func stopScanning() {
        NotificationCenter.default.post(name: .stopPlaneDetection, object: nil)
        detectedPlanes = []
        print("🛑 평면 감지 중지")
    }
    
    private func scatterCards() {
        guard detectedPlanes.count >= targetPlaneCount else {
            alertMessage = "아직 충분한 평면이 감지되지 않았습니다."
            showingAlert = true
            return
        }
        
        NotificationCenter.default.post(name: .scatterCards, object: nil)
        print("🎯 카드 배치 시작")
    }
    
    /// 구체 발사
    private func shootObject() {
        // 발사 애니메이션 효과
        withAnimation(.easeInOut(duration: 0.1)) {
            rightShooting = true
        }
        
        // 애니메이션 리셋
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                rightShooting = false
            }
        }
        
        // 발사 카운트 증가
        shotCount += 1
        
        print("🚀 카드를 향해 구체 발사! (총 \(shotCount)개)")
        
        // 발사 Notification 전송
        NotificationCenter.default.post(
            name: .shootObjectAtCards, 
            object: nil
        )
    }
}

// Notification extensions
extension Notification.Name {
    static let shootObjectAtCards = Notification.Name("shootObjectAtCards")
}

#Preview(traits: .landscapeLeft) {
    NavigationStack {
        CombinedTestView()
    }
}
