//
//  PendingInvitationView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/23/1404 AP.
//
import SwiftUI
struct PendingInvitationView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var invitation: [Invitation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let firestoreService = FirestoreServices.shared
    
    var body: some View {
        VStack (spacing: 20){
            if isLoading {
                ProgressView("Checking for invitation ...")
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            } else if invitation.isEmpty {
                Text("Waiting for Assignment...")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Your account is active. A restaurant owner must send you an invitation to join their restaurant.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                //Display the first pending invitation.
                if let firstInvitation = invitation.first {
                    InvitationCardView(invitation: firstInvitation)
                }
            }
            Spacer()
            Button("Sign Out") {
                authService.signOut()
            }
            .padding()
        }
        .onAppear(perform: fetchInvitations)
                
    }
    private func fetchInvitations() {
        guard let userEmail = authService.user?.email else {
            return
        }
        isLoading = true
        Task{
            do {
                self.invitation = try await firestoreService.fetchPendingInvitations(for: userEmail)
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
            
        }
    }
}
struct InvitationCardView: View {
    @EnvironmentObject var authService : AuthService
    let invitation: Invitation
    @State private var isAccepting = false
    var body: some View {
        VStack(spacing: 15) {
            Text("You're Invited!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("The restaurant **\(invitation.fromRestaurantId)** has invited you to join team as a **\(invitation.role)**.")
                .multilineTextAlignment(.center)
                .padding()
            if isAccepting {
                ProgressView()
            } else {
                Button("Accept Invitation"){
                    accept()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private func accept() {
        
        let firestoreService = FirestoreServices.shared
        guard let userId = authService.user?.uid else { return }
        
        isAccepting = true
        Task {
            do {
                try await firestoreService.acceptInvitation(invitation, forUser: userId)
                
            } catch {
                print("Error accepting invitation: \(error.localizedDescription)")
                isAccepting = false
            }
        }
    }
}

