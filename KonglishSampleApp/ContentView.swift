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
                        title: "평면 스캔 정확도",
                        subtitle: "실제 오브젝트 크기와 스캔 영역이 일치하는가",
                        icon: "ruler",
                        destination: PlaneDetectionView()
                    )
                    
                    taskNavigationLink(
                        title: "배치 안정성",
                        subtitle: "카메라 이동 시 오브젝트가 원위치에 유지되고 원근감이 정확한가",
                        icon: "camera.metering.center.weighted",
                        destination: Text("ADAC4-74 구현 예정")
                    )
                    
                    taskNavigationLink(
                        title: "충돌 방지 배치",
                        subtitle: "Scatter 버튼으로 여러 카드를 겹치지 않게 무작위 배치",
                        icon: "rectangle.3.group.bubble",
                        destination: Text("ADAC4-75 구현 예정")
                    )
                    
                    taskNavigationLink(
                        title: "다층 평면 인식",
                        subtitle: "벽/의자/서랍장 등 깊이별 평면에 각각 오브젝트 배치",
                        icon: "square.stack.3d.down.forward",
                        destination: Text("ADAC4-76 구현 예정")
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
            
            Text("ARKit 샘플링 앱")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("길's 지라 태스크 개별 테스트")
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
