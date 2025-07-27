//
//  ContentView.swift
//  KonglishSampleApp
//
//  Created by 길지훈 on 7/13/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                appHeaderView()
                
                VStack(spacing: 20) {
                    taskNavigationLink(
                        title: "AR 영어 학습 카드 배치 시스템",
                        subtitle: "15개 수직 평면 감지 후 자동 카드 배치 시스템",
                        icon: "square.grid.3x3.fill",
                        destination: IntegrationTestView()
                    )
                    
                    taskNavigationLink(
                        title: "포탈 테스트",
                        subtitle: "포탈",
                        icon: "sparkles",
                        destination: NewTestView()
                    )
                    
                    taskNavigationLink(
                        title: "결합 테스트",
                        subtitle: "카드 배치 + 슈팅 기능을 결합한 테스트",
                        icon: "gamecontroller.fill",
                        destination: CombinedTestView()
                    )
                    
                    taskNavigationLink(
                        title: "포털 테스트",
                        subtitle: "Reality Composer Pro 포털 + 파티클 시스템",
                        icon: "circle.hexagongrid.fill",
                        destination: PortalTestView()
                    )
                    
                }
                .frame(maxWidth: 600)
            }
            .padding()
        }
    }
    
    /// 앱 타이틀 뷰
    func appHeaderView() -> some View {
        VStack(spacing: 15) {
            Image(systemName: "arkit")
                .imageScale(.large)
                .foregroundStyle(.blue)
                .font(.system(size: 80))
            
            Text("Konglish AR 학습 앱")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("초등학생을 위한 AR 영어 발음 학습")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
    
    /// 태스크 버튼
    func taskNavigationLink<Destination: View> (
        title: String,
        subtitle: String,
        icon: String,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
}
