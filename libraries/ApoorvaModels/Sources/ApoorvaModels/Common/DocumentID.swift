//
//  DocumentID.swift
//  ApoorvaModels
//

import Foundation

/// New Firestore document ids, in the same shape Firestore's own auto ids take (20 characters of
/// `A-Za-z0-9`), so docs written by this app match production. Generated locally, so it works offline.
/// Every document stores this value in its `id` field as well.
public enum DocumentID {
    static let length = 20
    static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

    public static func make() -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }
}
