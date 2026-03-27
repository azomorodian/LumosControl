//
//  AddLampViewModel.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/20/1404 AP.
//
import Foundation
#if !MANUAL_WIFI
import NetworkExtension
#endif

@MainActor
class AddLampViewModel: ObservableObject {
    @Published var statusMessage: String = "Enter your Wi-Fi password to begin."
    @Published var isLoading: Bool = false
    @Published var setupIsComplete: Bool = false
    @Published var errorMessage: String?
    @Published var currentSSID: String?
    
    private let provisioningService = DeviceProvisioningService()
    private let firestoreService = FirestoreServices.shared
    
    #if !MANUAL_WIFI
    private let wifiManager = WiFiManager()
    #endif
    private let lampSSIDPrefix = "Lumos-Setup"
    
    init() {
        #if !MANUAL_WIFI
        wifiManager.requestLocationPermission()
        #endif
    }
    func fetchInitialData() async {
        #if !MANUAL_WIFI
        self.currentSSID = await wifiManager.getCurrentSSID()
        #else
        self.statusMessage = "Please enter your WiFi name and password."
        #endif
    }
    func startProvisioning(ssid: String, password: String,restaurantId: String) async {
        isLoading = true
        errorMessage = nil
        setupIsComplete = false
        
        #if !MANUAL_WIFI
        let lampSSID = "Lumos-Setuo-..."
        defer {
            wifiManager.disconnectFromLamp(ssid: lampSSID)
            isLoading = false
        }
        #else
        defer{ isLoading = false}
        #endif
        
        
        do {
            #if !MANUAL_WIFI
            statusMessage = "1/3: Connecting to lamp's WiFi ..."
            try await wifiManager.connectToLamp(ssid: lampSSID)
            try await Task.sleep(nanoseconds: 3_000_000_000)
            #else
            statusMessage = "1/2: Assuming connection to the lamp's WiFi ..."
            try await Task.sleep(nanoseconds: 1_000_000_000)
            #endif
            
            statusMessage = "2/2: Sending configuration to lamp ..."
            let payload = ConfigurePayload(ssid: ssid,password: password,restaurant_id: restaurantId)
            let success = try await provisioningService.sendConfiguration(payload: payload)
            
            if success {
                statusMessage = "Configuration sent! The lamp will now try to connect and register itself. You can close the screen."
                setupIsComplete = true
            } else {
                throw NSError(domain: "AppError",code: 2,userInfo: [NSLocalizedDescriptionKey: "Lamp rejected the configuration."])
            }
        } catch {
            self.errorMessage = error.localizedDescription
            statusMessage = "Setup failed! Please try again."
        }
    }
}

