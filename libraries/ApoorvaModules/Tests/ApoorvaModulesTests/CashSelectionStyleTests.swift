import Testing
import Foundation
@testable import ApoorvaModules

struct CashSelectionStyleTests {
    @Test func offersBadgesAndDropdownWithReadableTitles() {
        #expect(CashSelectionStyle.allCases == [.badges, .dropdown])
        #expect(CashSelectionStyle.badges.title == "Badges")
        #expect(CashSelectionStyle.dropdown.title == "Dropdown")
    }

    @Test func storedValueRoundTripsThroughItsRawValue() {
        for style in CashSelectionStyle.allCases {
            #expect(CashSelectionStyle(rawValue: style.rawValue) == style)
        }
        // An unknown stored value (for example from a future version) is not a style, so the default applies.
        #expect(CashSelectionStyle(rawValue: "carousel") == nil)
    }

    @Test func bothScreensShareOneStorageKey() {
        #expect(CashSelectionStyle.storageKey == "cashEntry.selectionStyle")
    }
}
