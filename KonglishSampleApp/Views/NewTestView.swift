import SwiftUI
import ARKit

/// 슈팅 테스트를 위한 뷰
struct NewTestView: View {
    @State private var rightShooting = false
    @State private var shotCount = 0
    
    var body: some View {
        ZStack {
            // 슈팅 전용 AR 뷰 컨테이너
            ShootingARContainer()
                .ignoresSafeArea()
            
            // 상단 정보 표시
            VStack {
                shootingStatusView()
                
                Spacer()
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
        .navigationTitle("슈팅 테스트")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// 슈팅 상태 표시
    func shootingStatusView() -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "target")
                    .font(.title2)
                    .foregroundStyle(.red)
                
                Text("슈팅 테스트")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("발사한 구체")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(shotCount)개")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("상태")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("준비됨")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    /// 오른쪽 발사 버튼
    func rightShootingButton() -> some View {
        Button {
            shootObject()
        } label: {
            ZStack {
                Circle()
                    .fill(.purple.gradient)
                    .frame(width: 80, height: 80)
                    .scaleEffect(rightShooting ? 1.2 : 1.0)
                    .shadow(color: .purple.opacity(0.3), radius: rightShooting ? 20 : 8)
                
                Image(systemName: "paperplane.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.1), value: rightShooting)
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
        
        print("🚀 구체 발사! (총 \(shotCount)개)")
        
        // 발사 Notification 전송
        NotificationCenter.default.post(
            name: .shootObject, 
            object: nil
        )
    }
}


#Preview(traits: .landscapeLeft) {
    NavigationStack {
        NewTestView()
    }
}
