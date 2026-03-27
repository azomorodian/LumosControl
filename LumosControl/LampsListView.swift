//
//  ContentView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/14/1404 AP.
//

import SwiftUI

struct LampsListView: View {
    @StateObject private var viewModel = LampsViewModel()
    @EnvironmentObject var authService: AuthService
    
    @State private var selectedLampForNavigation: Lamp?
    
    @State private var showAddLampSheet: Bool = false
    
    @State private var showingAddUserSheet: Bool = false
   

    
    var body: some View {
        NavigationView{
            VStack{
                if viewModel.isLoading && viewModel.lamps.isEmpty {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    Text("Error : \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .font(.headline)
                } else if viewModel.lamps.isEmpty {
                    Text("No Lamps Found")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(viewModel.lamps) { lamp in
                            ZStack {
                                NavigationLink(
                                    destination: LampDetailView(lamp:lamp),
                                    tag: lamp,
                                    selection: $selectedLampForNavigation
                                ) { EmptyView() }.opacity(0)
                                LampRow(lamp: lamp){
                                    if let restaurantId = authService.userProfile?.restaurantId{
                                        viewModel.clearCall(for: lamp,in: restaurantId)
                                    }
                                    
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    self.selectedLampForNavigation = lamp
                                }
                            }
                            .listRowInsets(EdgeInsets())
                        }
                        .onDelete(perform: deleteLamp)
                    }
                }
            }
            .navigationTitle("Lamps Control")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        authService.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing){
                    Button(action: {
                        showingAddUserSheet = true
                    }) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title3)
                    }
                    Button(action: {
                        showAddLampSheet = true
                    }){
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .onAppear{
                if let restaurantId = authService.userProfile?.restaurantId{
                    viewModel.startListening(for: restaurantId)
                } else {
                    print("Waiting for user profile to load ... ")
                }
            }
            .onDisappear(){
                viewModel.stopListening()
            }
            .sheet(isPresented: $showAddLampSheet) {
                if let restaurantId = authService.userProfile?.restaurantId{
                    AddLampView(restaurantId: restaurantId)
                        .environmentObject(authService)
                }
            }
            .sheet(isPresented: $showingAddUserSheet){
                AddUserView()
                    .environmentObject(authService)
            }
        }

    }
    private func deleteLamp(at offsets: IndexSet){
        guard let restaurantId = authService.userProfile?.restaurantId else {
            print("Error: cannot delete lamp because resaurantId is missing.")
            return
        }
        let lampsToDelete = offsets.map{viewModel.lamps[$0]}
        
        Task {
            for lamp in lampsToDelete {
                guard let lampId = lamp.id else {continue}
                do {
                    try await FirestoreServices.shared.deleteLamp(lampId: lampId, in: restaurantId)
                    print("Successfully deleted lamp: \(lampId)")
                } catch {
                    print("Error deleting lamp: \(error.localizedDescription)")
                }
            }
        }
    }
}
struct LampRow: View {
    let lamp: Lamp
    let onClearCall: () -> Void
    var body: some View {
        HStack{
            Circle()
                .fill(lamp.state.isOnline ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading){
                Text(lamp.tableName)
                    .font(.headline)
                if lamp.state.tableStatus == "reserved" {
                    Text("Reserved")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                } else {
                    Text("Սեղան No: \(lamp.tableNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if lamp.state.tableStatus == "reserved" {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.red)
                    .font(.title3)
            } else if lamp.state.callStatus == "calling"{
                Button(action: onClearCall){
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            } else if lamp.state.batteryPercent<20 {
                Image(systemName: "battery.25")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
        }
        .padding(.vertical,5)
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LampsListView()
    }
}
