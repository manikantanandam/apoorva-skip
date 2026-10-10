//
//  File.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaServices

@MainActor
@Observable
public class POSViewModel {
    
    var customerName: String = ""
    var customerPhoneNumber: String = ""
    
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
