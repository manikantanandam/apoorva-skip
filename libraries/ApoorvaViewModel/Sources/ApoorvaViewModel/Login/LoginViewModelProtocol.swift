//
//  LoginViewModelProtocol.swift
//  ApoorvaViewModel
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation

public protocol LoginViewModelProtocol: ObservableObject {
    var username: String { get set }
    var password: String { get set }
    var isLoginEnabled: Bool { get }
    
    func loginPressed()
}
