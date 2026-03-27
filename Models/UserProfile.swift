//
//  UserProfile.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/14/1404 AP.
//

import Foundation
import FirebaseFirestore
struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    let email: String
    let name: String
    let restaurantId: String?
    let role: String
    let isActive: Bool
    let createAt: Timestamp
}
