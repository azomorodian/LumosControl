//
//  FirestoreServices.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/14/1404 AP.
//
import Foundation
import FirebaseFirestore

class FirestoreServices {
    
    static let shared = FirestoreServices()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    func fetchLamps(for restaurantId: String) async throws -> [Lamp] {
        let lampCollectionRef = db.collection("restaurants").document(restaurantId).collection("lamps")
        let snapshot = try await lampCollectionRef.getDocuments()
        print("Firestore Snapshot Count : \(snapshot.documents.count)")
        let lamps = snapshot.documents.compactMap{document-> Lamp? in
            do{
                let lamp = try document.data(as: Lamp.self)
                print("Lamp \(lamp.tableName) Convert Successfully")
                return lamp
            } catch {
                print("Document \(document.documentID) Convertion Error : \(error)")
                return nil
            }
                
        }
        return lamps
    }
    func listenForLampUpdates(for restaurantId: String, completion: @escaping ([Lamp]?, Error?) -> Void) -> ListenerRegistration{
        let lampCollectionRef = db.collection("restaurants").document(restaurantId).collection("lamps")
        let listener = lampCollectionRef.addSnapshotListener { querySnapshot, error in
            if let error = error {
                print("Error getting lamp updates: \(error)")
                completion(nil, error)
                return
            }
            guard let documents = querySnapshot?.documents else {
                print("No documents in snapshot")
                completion([], nil)
                return
            }
            let lamps = documents.compactMap { document -> Lamp? in
                do {
                    return try document.data(as: Lamp.self)
                    } catch {
                        print("Document \(document.documentID) conversion error : \(error)")
                        return nil
                    }
            }
            completion(lamps, nil)
        }
        return listener
    }
    func clearLampCall(lampId: String, restaurantId: String) async {
        let docRef = db.collection("restaurants").document(restaurantId).collection("lamps").document(lampId)
        do {
            try await docRef.updateData(["state.callStatus":"none"])
            print("Successfully update lamp \(lampId) call status")
        } catch {
            print("Error updateing lamp status: \(error.localizedDescription)")
        }
    }
    
    func updateLampControl(lampId: String,restaurantId: String,newControl: Lamp.Control) async {
        let docRef = db.collection("restaurants").document(restaurantId).collection("lamps").document(lampId)
        do {
            let encodedControl = try Firestore.Encoder().encode(newControl)
            
            try await docRef.setData(["control":encodedControl],merge: true)
            print("Successfully updated lamp: \(lampId)")
        } catch {
            print("Error updateing lamp: \(error.localizedDescription)")
        }
        
    }
    func findLamp(byDeviceId deviceId: String,for restaurantId: String) async throws -> Lamp? {
        let snapshot = try await db.collection("restaurants").document(restaurantId).collection("lamps")
            .whereField("deviceId", isEqualTo: deviceId)
            .getDocuments()
        let lamp = try snapshot.documents.first?.data(as: Lamp.self)
        return lamp
    }
    func createNewLamp(withDeviceId deviceId: String, for restaurantId: String) async throws -> Lamp {
        let newLampData: [String: Any] = [
            "deviceId": deviceId,
            "restaurantId": restaurantId,
            "tableName" : "New Table",
            "tableNumber" : 0 ,
            "createdAt" : Timestamp(date: Date()),
            "state" : [
                "isOnline" : false,
                "batteryPercent" : 100,
                "lastSeen" : Timestamp(date: Date()),
                "status" : ""
            ],
            "control" : [
                "brightness" : 80,
                "color" : "#FFFFFF",
                "effect" : "static"
            ]
        ]
        var ref: DocumentReference? = nil
        ref = try await db.collection("restaurants").document(restaurantId).collection("lamps").addDocument(data: newLampData)
        
        let newDocument = try await ref!.getDocument()
        return try newDocument.data(as: Lamp.self)
    }
    func updateLampDetails(lampId: String , restaurantId: String,newName: String,newNumber: Int) async throws {
        let docRef = db.collection("restaurants").document(restaurantId).collection("lamps").document(lampId)
        try await docRef.updateData([
            "tableName" : newName,
            "tableNumber": newNumber
        ])
    }
    func findUserByEmail(byEmail email: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").whereField("email", isEqualTo: email).limit(to: 1).getDocuments()
        return try snapshot.documents.first?.data(as: UserProfile.self)
    }
    func assignUserToRestaurant(userId: String, restaurantId: String, role: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "restaurantId": restaurantId,
            "role": role
        ])
    }
    func updateRestaurantDetails(restaurantId: String, newName: String, newAddress: String) async throws {
        let docRef = db.collection("restaurants").document(restaurantId)
        try await docRef.updateData([
            "name" : newName,
            "address": newAddress
        ])
    }
    func createRestaurant(name: String, address: String,phoneNumber: String,ownerId: String) async throws -> Restaurant {
        let newRestaurant = Restaurant(
            name: name,
            ownerId: ownerId,
            address: address,
            phoneNumber: phoneNumber,
            isActive: true,
            SubscriptionStatus : "active",
            createdAt: Timestamp(date: Date())
        )
        
        let docRef = try db.collection("restaurants").addDocument(from: newRestaurant)
        let newDoc = try await docRef.getDocument()
        
        return try newDoc.data(as: Restaurant.self)
    }
    func sendInvitation(to email:String,from restaurant: Restaurant, as role: String) async throws {
        guard let restaurantId = restaurant.id else {
            throw NSError(domain: "AppError", code: -1,userInfo: [NSLocalizedDescriptionKey: "Restaurant data is incomplete."])
        }
        let restaurantName = restaurant.name
        let invitationData: [String: Any] = [
            "fromRestaurantId": restaurantId,
            "fromRestaurantName": restaurantName,
            "toUserEmail": email.lowercased(),
            "role":role,
            "status":"pending",
            "createdAt": Timestamp(date: Date())
        ]
        try await db.collection("invitations").addDocument(data: invitationData)
    }
    func fetchPendingInvitations(for email: String) async throws-> [Invitation] {
        let invitationsSnapshot = try await db.collection("invitations").whereField("toUserEmail", isEqualTo: email.lowercased()).whereField("status", isEqualTo: "pending").getDocuments()
        return try invitationsSnapshot.documents.compactMap{try $0.data(as: Invitation.self)}
    }
    func acceptInvitation(_ invitation: Invitation,forUser userId: String) async throws {
        guard let invitationId = invitation.id else {
            throw NSError(domain: "AppError", code: -1,userInfo: [NSLocalizedDescriptionKey: "Invitation ID is missing."])
        }
              
        let batch = db.batch()
        let userRef = db.collection("users").document(userId)
        batch.updateData(["restaurantId":invitation.fromRestaurantId,"role":invitation.role], forDocument: userRef)
        
        let invitationRef = db.collection("invitations").document(invitationId)
        batch.updateData(["status":"accepted"], forDocument: invitationRef)
        try await batch.commit()
        
    }
    func fetchRestaurant(withId restaurantId: String) async throws -> Restaurant? {
        let document = try await db.collection("restaurants").document(restaurantId).getDocument()
        return try document.data(as: Restaurant.self)
    }
    func deleteLamp(lampId:String,in restaurantId: String) async throws {
        let docRef = db.collection("restaurants").document(restaurantId).collection("lamps").document(lampId)
        print("Sending reset command to lamp \(lampId)")
        try await docRef.updateData(["control.effect":"Hard_Reset!"])
        try await Task.sleep(nanoseconds: 10_000_000_000)
        print("Deleting lamp document \(lampId) ...")
        try await docRef.delete()
    }
    func updateLampTableStatus(lampId: String , restaurantId: String,newStatus: String) async throws{
        let docRef = db.collection("restaurants").document(restaurantId).collection("lamps").document(lampId)
        try await docRef.updateData(["state.tableStatus":newStatus])
    }
}
