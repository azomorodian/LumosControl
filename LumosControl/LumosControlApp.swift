//
//  LumosControlApp.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/14/1404 AP.
//

import SwiftUI
import FirebaseCore

@main
struct LumosControlApp: App {
    @StateObject private var authService = AuthService()
    
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ContetView()
                .environmentObject(authService)
        }
    }
}

