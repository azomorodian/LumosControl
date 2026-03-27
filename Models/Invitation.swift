//
//  Invitation.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/23/1404 AP.
//
import Foundation
import FirebaseFirestore
struct Invitation: Identifiable, Codable {
    @DocumentID var id: String?
    let fromRestaurantId: String
    let fromRestaurantName: String
    let toUserEmail: String
    let role: String
    let status: String
    let createdAt: Timestamp
}
