//
//  SignupView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/22/1404 AP.
//
import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var name: String = ""
    @State private var role: String = "owner"
    
    @State private var isSigningUp: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
            Form{
                Section(header: Text("Account Credentials")){
                    TextField("Email",text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password",text: $password)
                }
                Section(header: Text("Profile Information")){
                    TextField("Full Name",text: $name)
                    Picker("Your Role",selection: $role){
                        Text("Restaurant Owner").tag("owner")
                        Text("Staff / Waiter").tag("waiter")
                    }
                    .pickerStyle(.segmented)
                }
                if let errorMessage = errorMessage {
                    Section {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
                Button(action: signup){
                    if isSigningUp {
                        ProgressView()
                    } else {
                        Text("Sign Up")
                    }
                }
                .disabled(isSigningUp || email.isEmpty || name.isEmpty)
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
        }
    private func signup() {
        isSigningUp = true
        errorMessage = nil
        Task {
            do {
                _ = try await authService.createNewUser(
                    email: email,
                    password: password,
                    name: name,
                    role: role
                )
                
            } catch {
                self.errorMessage = error.localizedDescription
                isSigningUp = false
            }
            
        }
    }
}
