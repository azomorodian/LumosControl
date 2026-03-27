//
//  WaitingForAssigmentView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/22/1404 AP.
//

import SwiftUI
struct WaitingForAssigmentView: View {
    
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Wait for assignment...")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your account has been created successfully. A restuarant owner must now assign you to thair restaurant before you can access the main controls.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Spacer()
            Button(action: {
                authService.signOut()
            }){
                Text("Sign Out")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}
