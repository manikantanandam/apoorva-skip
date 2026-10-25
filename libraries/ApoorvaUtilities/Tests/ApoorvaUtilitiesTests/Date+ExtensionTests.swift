//
//  Date+ExtensionTests.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 25/10/26.
//

import Testing
import Foundation
@testable import ApoorvaUtilities

@Suite("Date Extension Tests")
struct DateExtensionTests {

    @Test("Format Date to String")
    func testToString() throws {
        // Create a fixed date using the extension's static method
        let date = try #require(Date.from(day: 25, month: 10, year: 2026))
        
        let formattedString = date.toString(format: "yyyy-MM-dd")
        
        #expect(formattedString == "2026-10-25")
        #expect(date.toString(format: "dd/MM/yyyy") == "25/10/2026")
    }
    
    @Test("Create Date from components")
    func testFromComponents() throws {
        let date = try #require(Date.from(day: 15, month: 8, year: 2023))
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        
        #expect(components.day == 15)
        #expect(components.month == 8)
        #expect(components.year == 2023)
    }
    
    @Test("Calculate days old for past dates")
    func testDaysOldPast() throws {
        let calendar = Calendar.current
        let today = Date()
        let fiveDaysAgo = try #require(calendar.date(byAdding: .day, value: -5, to: today))
        
        #expect(fiveDaysAgo.daysOld == 5)
    }
    
    @Test("Calculate days old for today and future dates (bounds check)")
    func testDaysOldTodayAndFuture() throws {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        
        // Should return 0 for today
        #expect(today.daysOld == 0)
        
        // Should return bounded 0 for future dates
        #expect(tomorrow.daysOld == 0)
    }
}
