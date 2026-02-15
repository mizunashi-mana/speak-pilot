/// Inserts text into the focused application using NSPasteboard + CGEvent.
///
/// Saves the current clipboard contents, sets the text to insert,
/// simulates Cmd+V, then restores the original clipboard.
/// Requires Accessibility permission for CGEvent posting.

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os

@MainActor
@Observable
final class TextInserter {
    // MARK: - Observable properties

    /// Whether Accessibility permission has been granted.
    private(set) var isAccessibilityGranted = false

    // MARK: - Internal

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.speak-pilot",
        category: "TextInserter"
    )

    /// Delay before restoring the clipboard after simulating Cmd+V.
    private let restoreDelay: Duration = .milliseconds(100)

    // MARK: - Public API

    /// Check whether Accessibility permission is granted.
    ///
    /// - Parameter prompt: If `true`, shows the system Accessibility dialog
    ///   when permission has not been granted yet.
    /// - Returns: Whether the permission is currently granted.
    @discardableResult
    func checkAccessibility(prompt: Bool = false) -> Bool {
        // Use the string literal to avoid Swift 6 concurrency error
        // on the C global `kAXTrustedCheckOptionPrompt`.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        isAccessibilityGranted = trusted
        return trusted
    }

    /// Insert text into the focused application.
    ///
    /// Temporarily replaces the clipboard contents with the given text,
    /// simulates a Cmd+V keystroke, then restores the original clipboard.
    ///
    /// - Throws: ``TextInsertionError/accessibilityNotGranted`` if the app
    ///   does not have Accessibility permission.
    func insertText(_ text: String) async throws {
        guard isAccessibilityGranted else {
            throw TextInsertionError.accessibilityNotGranted
        }

        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard contents.
        let saved = savePasteboard(pasteboard)

        // Ensure clipboard is restored even on Task cancellation.
        defer { restorePasteboard(pasteboard, from: saved) }

        // 2. Set the text to insert.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Simulate Cmd+V.
        try simulatePaste()

        // 4. Wait for the paste to complete before restoring.
        try await Task.sleep(for: restoreDelay)

        logger.info("Inserted text (\(text.count) chars)")
    }

    // MARK: - Pasteboard save / restore

    /// Saved representation of all clipboard items.
    private struct SavedPasteboard {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private func savePasteboard(_ pasteboard: NSPasteboard) -> SavedPasteboard {
        var items: [[NSPasteboard.PasteboardType: Data]] = []
        for pasteboardItem in pasteboard.pasteboardItems ?? [] {
            var typeData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in pasteboardItem.types {
                if let data = pasteboardItem.data(forType: type) {
                    typeData[type] = data
                }
            }
            items.append(typeData)
        }
        return SavedPasteboard(items: items)
    }

    private func restorePasteboard(
        _ pasteboard: NSPasteboard,
        from saved: SavedPasteboard
    ) {
        pasteboard.clearContents()
        guard !saved.items.isEmpty else { return }

        let restoredItems = saved.items.map { itemData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }

    // MARK: - CGEvent keystroke simulation

    private func simulatePaste() throws {
        let source = CGEventSource(stateID: .hidSystemState)

        guard
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
            )
        else {
            logger.error("Failed to create CGEvent for Cmd+V")
            throw TextInsertionError.pasteSimulationFailed
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

// MARK: - Errors

enum TextInsertionError: Error, Sendable {
    /// Accessibility permission has not been granted.
    case accessibilityNotGranted
    /// CGEvent creation for Cmd+V simulation failed.
    case pasteSimulationFailed
}
