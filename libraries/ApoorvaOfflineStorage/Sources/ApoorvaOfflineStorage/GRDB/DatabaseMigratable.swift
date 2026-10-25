//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation
import GRDB

public protocol DatabaseMigratable {
    static func createTable(in db: Database) throws
}
