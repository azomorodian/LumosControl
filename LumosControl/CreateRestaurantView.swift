//
//  CreateRestaurantView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/22/1404 AP.
//
import SwiftUI
import FirebaseAuth

struct CreateRestaurantView: View {
    @EnvironmentObject var authService: AuthService
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var restaurantName: String = ""
    @State private var address: String = ""
    @State private var phoneNumber: String = ""
    
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    
    private let firestoreService = FirestoreServices.shared
    
    var body: some View {
        NavigationView {
            Form{
                Section(header: Text("Restaurant Details")){
                    HStack{
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.secondary)
                        TextField("Restaurant Name",text: $restaurantName)
                    }
                    HStack{
                        Image(systemName: "map.fill")
                            .foregroundColor(.secondary)
                        TextField("Address",text: $address)
                    }
                    
                    HStack{
                        Image(systemName: "phone.fill")
                            .foregroundColor(.secondary)
                        TextField("Phone Number",text: $phoneNumber)
                            .keyboardType(.phonePad)
                    }
                }
                if let errorMessage = errorMessage {
                    Section{
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Your Restaurant")
            .toolbar {
                ToolbarItem(placement: .confirmationAction){
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Save"){
                            Task {
                                await createRestaurantAndLinkToUser()
                            }
                        }
                        .disabled(restaurantName.isEmpty)
                    }
                }
            }
        }
    }
    private func createRestaurantAndLinkToUser() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Error: Could not find the current user.please sign in again."
            return
        }
        isCreating = true
        errorMessage = nil
        
        do {
            let newRestaurant = try await firestoreService.createRestaurant(
                name: restaurantName,
                address: address,
                phoneNumber: phoneNumber,
                ownerId: userId
            )
            
            guard let newRestaurantId = newRestaurant.id else {
                throw NSError(domain: "", code: -1,userInfo: [NSLocalizedDescriptionKey: "Faild to get new restaurant ID."])
            }
            
            try await authService.updateUserProfileWithRestaurant(
                userId: userId,
                restaurantId: newRestaurantId
            )
            
            print("Successfully created restaurant and linked to owner!")
            
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }
}
