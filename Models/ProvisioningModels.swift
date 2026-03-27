//
//  ProvisioningModels.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/20/1404 AP.
//
import Foundation

struct DeviceIDResponse: Codable {
    let device_id: String
}

struct ConfigurePayload: Codable {
    let ssid: String
    let password: String
    let restaurant_id: String
}

struct ConfigureResponse: Codable {
    let status: String
}
