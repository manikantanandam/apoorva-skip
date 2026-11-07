//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaServices
import ApoorvaModels

@MainActor
@Observable
public class POSViewModel {
    
    var customerName: String = ""
    var customerPhoneNumber: String = ""

    /// Cart quantities keyed by item id. Drives `ManiItemTile`'s stepper;
    /// there is no real checkout/sale logic behind it yet.
    var quantities: [String: Int] = [:]

    var items: [InventoryItem] = [
        InventoryItem(name: "Bangles 12"),
        InventoryItem(name: "Black Beads"),
        InventoryItem(name: "Earrings"),
        InventoryItem(name: "Rubber Bands"),
        InventoryItem(name: "Necklace"),
        InventoryItem(name: "Thadu"),
        InventoryItem(name: "Rings"),
        InventoryItem(name: "Stickers"),
        InventoryItem(name: "Bracelets"),
        InventoryItem(name: "Anklets"),
        InventoryItem(name: "Watches"),
        InventoryItem(name: "Pins")

    ]
    
    private var authService: AuthServicing
    
    public init(authService: AuthServicing) {
        self.authService = authService
    }
    
    func logoutPressed() {
        do {
            try authService.logout()
        } catch {
            print("Error \(error)")
        }
    }

    func quantity(for item: InventoryItem) -> Int {
        quantities[item.id] ?? 0
    }

    func increment(_ item: InventoryItem) {
        quantities[item.id, default: 0] += 1
    }

    func decrement(_ item: InventoryItem) {
        guard let current = quantities[item.id], current > 0 else { return }
        quantities[item.id] = current - 1
    }

    var cartItems: [InventoryItem] {
        items.filter { quantity(for: $0) > 0 }
    }

    var cartItemCount: Int {
        quantities.values.reduce(0, +)
    }
}
