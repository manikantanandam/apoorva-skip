//
//  File.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
@testable import ApoorvaUtilities

@Suite("SortType Extension Tests")
struct SortTypeExtensionTests {

    @Test("Toggling ascending should return descending")
    func testToggleAscending() {
        let currentSort = SortType.ascending
        
        #expect(currentSort.togglevalue == .descending)
    }
    
    @Test("Toggling descending should return ascending")
    func testToggleDescending() {
        let currentSort = SortType.descending
        
        #expect(currentSort.togglevalue == .ascending)
    }
}
