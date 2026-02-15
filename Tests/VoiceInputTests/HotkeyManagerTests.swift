import Foundation
import Testing

@testable import VoiceInput

@Suite("HotkeyManager")
@MainActor
struct HotkeyManagerTests {

    @Test
    func initialState() async throws {
        let manager = HotkeyManager()
        #expect(!manager.isRegistered)
        #expect(manager.onToggle == nil)
    }

    @Test
    func unregisterWithoutRegister() async throws {
        let manager = HotkeyManager()
        // Should not crash when unregistering without registering first.
        manager.unregister()
        #expect(!manager.isRegistered)
    }

    @Test
    func callbackCanBeInvoked() async throws {
        let manager = HotkeyManager()

        var callCount = 0
        manager.onToggle = { callCount += 1 }

        manager.onToggle?()
        #expect(callCount == 1)

        manager.onToggle?()
        #expect(callCount == 2)
    }

    @Test
    func callbackCanBeReplaced() async throws {
        let manager = HotkeyManager()

        var first = 0
        var second = 0

        manager.onToggle = { first += 1 }
        manager.onToggle?()
        #expect(first == 1)
        #expect(second == 0)

        manager.onToggle = { second += 1 }
        manager.onToggle?()
        #expect(first == 1)
        #expect(second == 1)
    }

    @Test
    func callbackCanBeNilled() async throws {
        let manager = HotkeyManager()
        manager.onToggle = { }
        #expect(manager.onToggle != nil)

        manager.onToggle = nil
        #expect(manager.onToggle == nil)
    }
}
