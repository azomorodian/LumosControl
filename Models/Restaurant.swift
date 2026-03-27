//
//  Restaurant.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/14/1404 AP.
//
import Foundation
import FirebaseFirestore
struct Restaurant: Identifiable, Codable{
    @DocumentID var id: String?
    let name: String
    let ownerId: String
    let address: String
    let phoneNumber: String
    let isActive: Bool
    let SubscriptionStatus: String
    let createdAt: Timestamp
}

