//
//  AddUserView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/22/1404 AP.
//
import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct AddUserView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var emailToInvite: String = ""
    @State private var roleToAssign = "waiter"
    
    
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let firestoreService = FirestoreServices.shared
    
    var body: some View {
        NavigationView{
            Form{
                Section(header: Text("Invite User")){
                    Text("Enter the email of the person you want to add to your restaurant. They will receive an invitation to join.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("User's Email",text: $emailToInvite)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Picker("Assign Role",selection: $roleToAssign){
                        Text("Waiter").tag("waiter")
                        Text("Admin").tag("admin")
                    }
                    .pickerStyle(.segmented)
                }
                if let errorMessage = errorMessage {
                    Section {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
                if let successMessage = successMessage {
                    Section{
                        Text(successMessage)
                            .foregroundColor(.green)
                    }
                }
                
            }
            .navigationTitle("Invite User")
            .toolbar{
                ToolbarItem(placement: .cancellationAction){
                    Button("Close"){dismiss()}
                }
                ToolbarItem(placement: .confirmationAction){
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Send Invitation"){
                            sendInvitation()
                        }
                        .disabled(emailToInvite.isEmpty)
                    }
                }
            }
        }
    }
    private func sendInvitation() {
        guard let userProfile = authService.userProfile,
              let restaurantId = userProfile.restaurantId
        else {
            self.errorMessage = "Could not load your restaurant profile. Please try again."
            return
        }
        isSending = true
        errorMessage = nil
        successMessage = nil
        
        Task{
            do{
                guard let restaurant = try await firestoreService.fetchRestaurant(withId: restaurantId) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey : "Your restaurant profile Could not be found."])
                }
                
                try await firestoreService.sendInvitation(
                    to: emailToInvite,
                    from: restaurant,
                    as: roleToAssign
                )
                self.successMessage = "Invitation successfully sent to \(emailToInvite)"
                self.emailToInvite = ""
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isSending = false
        }
    }
}
