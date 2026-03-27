//
//  DeviceProvisioningService.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/20/1404 AP.
//
import Foundation

class DeviceProvisioningService {
    private let baseURL = "http://192.168.4.1"
    
    func fetchDeviceId() async throws -> String {
        guard let url = URL(string: "\(baseURL)/device_id") else {
            throw URLError(.badURL)
        }
        let (data, _ ) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(DeviceIDResponse.self, from: data)
        return response.device_id
    }
    
    func sendConfiguration(payload: ConfigurePayload) async throws -> Bool{
        guard let url = URL(string: "\(baseURL)/configure") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        request.allowsConstrainedNetworkAccess = true
        
        let (date,response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let configureResponse = try JSONDecoder().decode(ConfigureResponse.self, from: date)
        return configureResponse.status == "success"
    }
}
