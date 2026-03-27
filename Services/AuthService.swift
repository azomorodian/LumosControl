//
//  Untitled.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/16/1404 AP.
//
import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

class AuthService: ObservableObject {
    @Published var user: User?
    @Published var userProfile: UserProfile?
    
    static let shared = AuthService()
   
    private var db = Firestore.firestore()
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var userProfileListener: ListenerRegistration?
    
    init() {
        authStateHandler = Auth.auth().addStateDidChangeListener {[weak self] (_,user) in
            self?.user = user
            if let user = user {
                self?.fetchUserProfileListener(userId: user.uid)
            } else {
                self?.userProfile = nil
                self?.userProfileListener?.remove()
                self?.userProfileListener = nil
            }
        }
    }
    private func fetchUserProfileListener(userId: String) {
        userProfileListener?.remove()
        
        userProfileListener = db.collection("users").document(userId).addSnapshotListener { [weak self] (document, error) in
            if let document = document, document.exists {
                self?.userProfile = try? document.data(as: UserProfile.self)
                print("User profile updated.")
            } else {
                print("Error fetching user profile: \(error?.localizedDescription ?? "Unknown error")")
                self?.userProfile = nil
            }
        }
    }
    func signIn(email: String, password: String) async->Bool {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await MainActor.run {
                self.user = result.user
            }
            print("Successfully signed in user: \(result.user.uid)")
            return true
        } catch {
            print("Failed to sign in: \(error.localizedDescription)")
            return false
        }
    }
    func signOut() {
        do {
            userProfileListener?.remove()
            userProfileListener = nil
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            print("Failed to sign out: \(error.localizedDescription)")
        }
    }
    func createNewUser(email: String, password: String, name: String, role: String) async throws->String {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        let userProfile = UserProfile(
            id: authResult.user.uid,
            email: email,
            name: name,
            restaurantId: nil,
            role: role,
            isActive: true,
            createAt: Timestamp(date: Date())
        )
        try await db.collection("users").document(authResult.user.uid).setData(from: userProfile)
        return role
    }
    func updateUserProfileWithRestaurant(userId: String,restaurantId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "restaurantId": restaurantId
        ])
    }
}
