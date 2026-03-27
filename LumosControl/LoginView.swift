//
//  LoginView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/16/1404 AP.
//
import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationView{
            ZStack{
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Lumos Control")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    VStack(spacing: 15)
                    {
                        TextField("Email",text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        
                        SecureField("Password",text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
          
                    }
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Button(action: signIn){
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity,minHeight: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading)
                    
                    NavigationLink("Don't have an account? Sign Up",destination: SignupView())
                }
                .padding(.horizontal,30)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        Auth.auth().signIn(withEmail: email, password: password){ result, error in
            isLoading = false
            if let error = error {
                self.errorMessage = error.localizedDescription
            }
            
        }
        
    }
}
