//
//  LampsViewModel.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/14/1404 AP.
//

import Foundation
import FirebaseFirestore
@MainActor
class LampsViewModel: ObservableObject {
    @Published var lamps: [Lamp] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    //private let restaurantId = "HE5lEHnJyUCzqfNXmUjX"
    
    private var listener: ListenerRegistration?
    
    func startListening(for restaurantId: String) {
        guard listener == nil else {
            return
        }
        isLoading = true
        errorMessage = nil
        listener?.remove()
        
        listener = FirestoreServices.shared.listenForLampUpdates(for: restaurantId) { [weak self] (fetchLamps, error) in
            self?.isLoading = false
            if let error = error {
                self?.errorMessage = error.localizedDescription
                print("Error fetching lamps: \(error.localizedDescription)")
            } else if let fetchLamps = fetchLamps {
                self?.lamps = fetchLamps
            }
        }
    }
    func stopListening() {
        listener?.remove()
        listener = nil
        print("Stopped listening for lamp updates.")
    }
    func fetchLamps(for restaurandId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedLamps = try await FirestoreServices.shared.fetchLamps(for: restaurandId)
            self.lamps = fetchedLamps
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching lamps : \(error.localizedDescription)")
        }
        isLoading = false
    }
    func clearCall(for lamp: Lamp,in restaurantId: String) {
        guard let lampId = lamp.id else { return }
        Task{
            await FirestoreServices.shared.clearLampCall(lampId: lampId, restaurantId: restaurantId)
        }
    }
}


