import Foundation
import Testing

@testable import VoiceInput

@Suite("TextInserter")
@MainActor
struct TextInserterTests {

    @Test
    func initialState() async throws {
        let inserter = TextInserter()
        #expect(!inserter.isAccessibilityGranted)
    }

    @Test
    func insertTextWithoutAccessibility() async throws {
        let inserter = TextInserter()
        await #expect(throws: TextInsertionError.self) {
            try await inserter.insertText("test")
        }
    }

    @Test
    func checkAccessibilityCanBeCalled() async throws {
        let inserter = TextInserter()
        // Result depends on the test environment; just verify it doesn't crash.
        _ = inserter.checkAccessibility(prompt: false)
    }
}
