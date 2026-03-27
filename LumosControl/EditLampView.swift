//
//  EditLampView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/21/1404 AP.
//
import SwiftUI

struct EditLampView: View {
    @Environment(\.dismiss) var dismiss
    
    let lamp: Lamp
    
    @State private var tableName: String = ""
    @State private var tableNumberString: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    private let firestoreServices = FirestoreServices.shared
  
    
    init(lamp: Lamp){
        self.lamp = lamp
        _tableName = State(initialValue: lamp.tableName)
        _tableNumberString = State(initialValue: "\(lamp.tableNumber)")
    }
    var body: some View {
        NavigationView{
            Form{
                Section(header: Text("Lamp Detaials")){
                    TextField("Table Name",text: $tableName)
                    TextField("Table Number",text: $tableNumberString)
                        .keyboardType(.numberPad)
                }
                if let errorMessage = errorMessage {
                    Section{
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Lamp")
            .toolbar {
                ToolbarItem(placement: .cancellationAction){
                    Button("Cancel"){
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction){
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(tableName.isEmpty)
                        
                    }
                }
            }
        }
    }
    private func saveChanges() {
        guard let lampId = lamp.id else {
            errorMessage = "Lamp ID is missing."
            return
        }
        guard let restaurantId = lamp.restaurantId else {
            errorMessage = "Restaurant ID is missing."
            return
        }
        guard let tableNumber = Int(tableNumberString) else {
            errorMessage = "Please enter a valid number for the table."
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                try await firestoreServices.updateLampDetails(
                    lampId: lampId,
                    restaurantId: restaurantId,
                    newName: tableName,
                    newNumber: tableNumber
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
        
    }
    
}
