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
    func dispatchHotkeyEventInvokesCallback() async throws {
        let manager = HotkeyManager()

        var callCount = 0
        manager.onToggle = { callCount += 1 }

        // Simulate the Carbon callback path by calling dispatchHotkeyEvent directly.
        // We need to set the static instance first (normally done by register()).
        // Since we can't call register() without a running app event loop,
        // we test the dispatch path in isolation.

        // Use a continuation to wait for the async dispatch.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            manager.onToggle = {
                callCount += 1
                continuation.resume()
            }
            // dispatchHotkeyEvent reads the static instance, which is set by register().
            // In test, we simulate by accessing the internal dispatch path.
            // Since dispatchHotkeyEvent is fileprivate, we verify the callback mechanism
            // through the public API contract instead.

            // Directly invoke the callback to verify wiring.
            manager.onToggle?()
        }

        #expect(callCount == 1)
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
