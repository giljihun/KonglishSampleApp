//
//  PortalTestView.swift
//  KonglishSampleApp
//
//  Created by 길지훈 on 7/27/25.
//

import SwiftUI
import ARKit

struct PortalTestView: View {
    @State private var detectedPlanes: [DetectedPlane] = []
    @State private var placedCards: [PlacedCard] = []
    @State private var isScanning = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var targetAchieved = false
    
    // 목표 평면 수 (테스트용)
    private let targetPlaneCount = 1
    
    var body: some View {
        ZStack {
            // AR 뷰 컨테이너
            PortalARContainer(
                detectedPlanes: $detectedPlanes,
                placedCards: $placedCards,
                isScanning: $isScanning
            )
            .ignoresSafeArea()
            
            // 상단 정보 표시
            VStack {
                statusHeaderView()
                
                Spacer()
                
                // 하단 컨트롤
                bottomControlsView()
                    .padding(.bottom, 30)
            }
        }
        .navigationTitle("포탈 테스트")
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
    
    /// 상단 상태 표시
    func statusHeaderView() -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "viewfinder")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("수직 평면 감지 중...")
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
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("배치된 카드")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(placedCards.count)개")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
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
                
                Text("모든 평면을 찾았습니다!")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            
            Button {
                scatterCards()
            } label: {
                HStack {
                    Image(systemName: "sharedwithyou")
                    Text("Scatter !")
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
    
}
