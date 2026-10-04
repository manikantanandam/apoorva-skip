//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation

protocol Route: RawRepresentable, CaseIterable, Identifiable where RawValue == String {
    var id: String { get }
}

extension Route {
    var id: String { self.rawValue}
}
