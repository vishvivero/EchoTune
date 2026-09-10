import Foundation
import Testing
@testable import EchoTune

/// A transcript history must survive one unreadable record: losing the whole
/// store (and then overwriting it) is exactly the data loss we can't have.
struct EchoMemoryRecoveryTests {
    private func entry(_ text: String, id: UUID = UUID()) -> EchoMemoryEntry {
        EchoMemoryEntry(
            id: id,
            date: Date(timeIntervalSince1970: 1_780_000_000),
            text: text,
            duration: 4,
            modelID: "local",
            provider: "local",
            wasEdited: false,
            wasAccepted: false,
            wasRejected: false,
            frontmostApp: nil,
            windowTitle: nil
        )
    }

    private func encodedArray(_ entries: [EchoMemoryEntry]) throws -> Data {
        try JSONEncoder().encode(entries)
    }

    @Test func healthyPayloadDecodesWithoutParkingAnything() throws {
        let data = try encodedArray([entry("Hello there"), entry("Second entry")])
        let result = EchoMemoryManager.decodeEntries(from: data)
        #expect(result.entries.count == 2)
        #expect(result.unreadablePayload == nil)
    }

    @Test func oneUnreadableRecordKeepsTheRest() throws {
        let keep = [entry("Hello there"), entry("I need to book the car in for a service")]
        var array = try JSONSerialization.jsonObject(with: encodedArray(keep)) as! [[String: Any]]
        array.insert(["id": "not-a-uuid", "text": "corrupt"], at: 1)

        let result = EchoMemoryManager.decodeEntries(from: try JSONSerialization.data(withJSONObject: array))
        #expect(result.entries.count == 2)
        #expect(result.entries.map(\.text) == keep.map(\.text))
        #expect(result.unreadablePayload != nil)
    }

    @Test func unreadablePayloadIsPreservedByteForByte() throws {
        let garbage = Data("this is not JSON at all".utf8)
        let result = EchoMemoryManager.decodeEntries(from: garbage)
        #expect(result.entries.isEmpty)
        #expect(result.unreadablePayload == garbage)
    }
}
