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
}
