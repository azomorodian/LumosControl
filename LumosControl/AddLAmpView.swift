//
//  AddLAmpView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/20/1404 AP.
//
import SwiftUI

struct AddLampView: View {
    @StateObject private var viewModel = AddLampViewModel()
    @State private var ssid = ""
    @State private var password = ""
    let restaurantId : String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form{
                Section(header: Text("Connect to the Lamp's WiFi")) {
                    Text("Before starting, please go to your iPhone's Settings, open WiFi, and connect to the 'Lumos-Setup-...' network.")
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Restaurant WiFi Credentials")) {
                    #if MANUAL_WIFI
                    TextField("WiFi Name (SSID)", text: $ssid)
                        .autocapitalization(.none)
                    #else
                    if let ssid = viewModel.currentSSID {
                        LabeledContent("WiFi Name", value: ssid)
                    } else {
                        Text("Detecting WiFi Name ...")
                    }
                    #endif
                    
                    SecureField("Password",text: $password)
                    
                }
                
                Section(header: Text("Setup Process")) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                    Text(viewModel.statusMessage)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section{
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
                Button(action: {
                    Task {
                        await viewModel.startProvisioning(ssid: ssid, password: password,restaurantId: self.restaurantId)
                    }
                }) {
                    Text("Start Lamp Setup")
                }
                .disabled(viewModel.isLoading || ssid.isEmpty)
            }
            .navigationTitle("Add New Lamp")
            .toolbar{
                ToolbarItem(placement: .navigationBarLeading){
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Configuration Sent",isPresented: $viewModel.setupIsComplete) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("The lamp has received the settings. It will appear in your list automatically once it connects to the internet.")
            }
        }
    }
}
