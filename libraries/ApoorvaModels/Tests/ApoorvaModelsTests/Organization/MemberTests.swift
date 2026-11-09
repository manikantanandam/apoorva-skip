//
//  MemberTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

struct MemberTests {
    @Test func missingDefaultableFieldsFallBack() throws {
        let json = Data(#"{"id":"uid-1","role":"manager"}"#.utf8)
        let member = try JSONDecoder().decode(Member.self, from: json)
        #expect(member.role == .manager)
        #expect(member.email == "")
        #expect(member.isActive)
        #expect(member.status == "active")
        #expect(member.storeIds == [Store.defaultId])
    }

    @Test func roleStaysRequired() {
        let json = Data(#"{"id":"uid-1"}"#.utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Member.self, from: json)
        }
    }
}
