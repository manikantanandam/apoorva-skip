//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaServices
import ApoorvaModels

typealias Category = ApoorvaModels.Category

@MainActor
@Observable
public class POSViewModel {
    
    var customerName: String = ""
    var customerPhoneNumber: String = ""
    
    var items: [Category] = [
        Category(name: "Bangles 12"),
        Category(name: "Black Beads"),
        Category(name: "Earrings"),
        Category(name: "Rubber Bands"),
        Category(name: "Necklace"),
        Category(name: "Thadu"),
        Category(name: "Rings"),
        Category(name: "Stickers"),
        Category(name: "Bracelets"),
        Category(name: "Anklets"),
        Category(name: "Watches"),
        Category(name: "Pins")

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
