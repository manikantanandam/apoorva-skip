//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation

@MainActor
public class AppContainer {
    public let core = CoreContainer()
    
    // Feature containers are grouped and lazy-loaded
    public lazy var login = LoginContainer(core: core)
    public lazy var pos = POSContainer(core: core)
//    public lazy var cashflow = CashflowContainer(core: core)
//    public lazy var inventory = InventoryContainer(core: core)
//    public lazy var customer = CustomerContainer(core: core)
    
    public init() {}
}
