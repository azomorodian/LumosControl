//
//  Lamp.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/14/1404 AP.
//

import Foundation
import FirebaseFirestore
struct Lamp: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    
    let restaurantId: String?
    let deviceId: String
    let tableNumber: Int
    let tableName: String
    let createdAt: Timestamp
    
    var state: State
    var control: Control
    
    struct State: Codable, Hashable {
        let batteryPercent: Int
        let isOnline: Bool
        let lastSeen: Timestamp
        let tableStatus: String
        let callStatus: String
    }
    struct Control: Codable, Hashable {
        let brightness: Int
        let color: String
        let effect: String
    }
}
