//
//  ContentView.swift
//  KonglishSampleApp
//
//  Created by 길지훈 on 7/13/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "textbook")
                .imageScale(.large)
                .foregroundStyle(.blue)
                .font(.system(size: 60))
            
            Text("AR 영어 학습 앱")
                .font(.title)
                .fontWeight(.bold)
            
            Text("초등학생을 위한 몰입형 영어 학습")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button {
                print("앱 시작!")
            } label: {
                Text("시작하기")
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
        }
        .padding()
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
}
