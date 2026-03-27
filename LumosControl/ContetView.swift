//
//  ContetView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/22/1404 AP.
//

import SwiftUI
struct ContetView: View {
    @EnvironmentObject var authService: AuthService
    var body: some View {
        ZStack{
                if let user = authService.user{
                    if let profile = authService.userProfile{
                        if profile.role == "owner" && profile.restaurantId == nil {
                            CreateRestaurantView()
                        } else if profile.restaurantId != nil {
                            LampsListView()
                        } else {
                            PendingInvitationView()
                        }
                            
                    } else {
                        ProgressView("Loading Profile...")
                    }
                } else {
                    LoginView()
                }
        }

    }
}
