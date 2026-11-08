//
//  Double+Money.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation

extension Double {
    /// Whole-rupee display, e.g. `120` rather than `120.0` — amounts in the POS/checkout/
    /// receipt flow are already rounded (`CartItem.finalPrice`), this just drops the
    /// trailing decimal for display.
    var moneyString: String {
        String(format: "%.0f", self)
    }
}
