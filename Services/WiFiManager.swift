//
//  WiFiManager.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/20/1404 AP.
//
import Foundation
import NetworkExtension
import CoreLocation

class WiFiManager : NSObject, CLLocationManagerDelegate, ObservableObject {
    private let locationManager: CLLocationManager = CLLocationManager()
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentSSID() async -> String? {
        guard CLLocationManager().authorizationStatus == .authorizedWhenInUse else {
            print("Location permission not granted.")
            return nil
        }
        
        if let network = await NEHotspotNetwork.fetchCurrent() {
            return network.ssid
        }
        return nil
    }
    
    func connectToLamp(ssid: String) async throws {
        let hotspotConfig = NEHotspotConfiguration(ssid: ssid)
        
        return try await withCheckedThrowingContinuation { continuation in
            NEHotspotConfigurationManager.shared.apply(hotspotConfig) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func disconnectFromLamp(ssid: String) {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
    }
}

