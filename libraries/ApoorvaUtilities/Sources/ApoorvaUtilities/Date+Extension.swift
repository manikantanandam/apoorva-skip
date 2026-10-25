//
//  Date+Extension.swift
//  ApoorvaUtilities
//
//  Created by Manikanta Nandam on 11/10/26.
//

import Foundation

public extension Date {
    func toString(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    var daysOld : Int {
        let calendar = Calendar.current
        
        // Remove time components to compare full days accurately
        let startDate = calendar.startOfDay(for: self)
        let endDate = calendar.startOfDay(for: Date())
        
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        
        // Return only positive days passed (0 if today or in the future)
        return max(0, components.day ?? 0)
    }
    
    static func from(day: Int, month: Int, year: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }
}
