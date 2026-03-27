//
//  LampDetailView.swift
//  LumosControl
//
//  Created by Artin Zomorodian on 6/16/1404 AP.
//
import SwiftUI
import SwiftUI

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: Double

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

extension Color {
    func toHex() -> String? {
        // Convert Color to UIColor first
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }
        
        let ri = Int(r * 255)
        let gi = Int(g * 255)
        let bi = Int(b * 255)
        
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}

struct LampDetailView: View {
    let lamp: Lamp
    @State private var color: Color
    @State private var brightness: Double
    @State private var effect: String
    
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var showingEditSheet = false
    @State private var isReserved: Bool
    
    private let firestoreService = FirestoreServices.shared
    
    private var controlDisabled: Bool {
        return isReserved
    }
    
    
    init(lamp: Lamp){
        self.lamp = lamp
        _color = State(initialValue: Color(hex: lamp.control.color) ?? .white)
        _brightness = State(initialValue: Double(lamp.control.brightness))
        _effect = State(initialValue: lamp.control.effect)
        _isReserved = State(initialValue: lamp.state.tableStatus == "reserved")
    }
    var body: some View {
        Form{
            Section(header: Text("Table Status")){
                Toggle("Reserved",isOn: $isReserved)
                    .tint(.red)
                    .onChange(of: isReserved){ newValue in
                            updateReservationStatus()
                    }
            }
            Section(header:Text("Live Control")){
                ColorPicker("Lamp Color",selection: $color, supportsOpacity: false)
                    .onChange(of: color){_ in sendUpdateRequestWithDebounce()}
                VStack{
                    Text("Brightness:\(Int(brightness))")
                    Slider(value: $brightness,in: 0...100,step: 1)
                        .onChange(of: brightness){_ in sendUpdateRequestWithDebounce()}

                }
                Picker("Effect",selection: $effect){
                    Text("Static").tag("static")
                    Text("Pulse").tag("pulse")
                    Text("Candle").tag("candle")
                    Text("Flicker").tag("flicker")
                    Text("Rainbow").tag("rainbow")
                }
                .onChange(of: effect) { _ in sendUpdateRequestWithDebounce()}
            }
            .disabled(controlDisabled)
            .opacity(controlDisabled ? 0.5 : 1.0)

        }
        .navigationTitle(lamp.tableName)
        .toolbar{
            ToolbarItem(placement: .navigationBarTrailing){
                Button(action: {
                    showingEditSheet = true
                }){
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet){
            EditLampView(lamp: lamp)
        }
    }
    private func sendUpdateRequestWithDebounce() {
        debounceTask?.cancel()
        
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                await sendUpdateRequest()
            } catch {
                print("Update task cancelled.")
            }
        }
    }
    private func sendUpdateRequest() async {
        guard let lampId = lamp.id, let restaurantId = lamp.restaurantId else {
            return
        }
        let newControl = Lamp.Control(
                                      brightness: Int(brightness),
                                      color: color.toHex() ?? "#FFFFFF",
                                      effect: effect
                                      )
        do {
            try await firestoreService.updateLampControl(
                lampId: lampId,
                restaurantId: restaurantId,
                newControl: newControl
            )
            print("Live update sent successfully!.")
        } catch {
            print("Error sending live update: \(error.localizedDescription)")
        }
    }
    private func updateReservationStatus() {
        guard let lampId = lamp.id, let restaurantId = lamp.restaurantId else {
            return
        }
        let newStatus = isReserved ? "reserved" : "available"
        
        Task {
            do {
                try await FirestoreServices.shared.updateLampTableStatus(lampId: lampId,
                                                                    restaurantId: restaurantId,
                                                                    newStatus: newStatus
                                                                    )
            } catch {
                print("Error updateing reservation status: \(error.localizedDescription)")
                isReserved.toggle()
            }
        }
    }
}
