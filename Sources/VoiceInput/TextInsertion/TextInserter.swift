/// Inserts text into the focused application.
///
/// Primarily uses the Accessibility API (`kAXSelectedTextAttribute`) to
/// insert text directly at the cursor position without clipboard interference.
/// Falls back to NSPasteboard + CGEvent (Cmd+V simulation) when the focused
/// element does not support Accessibility text insertion.
/// Requires Accessibility permission.

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
    /// First attempts to insert via the Accessibility API
    /// (`kAXSelectedTextAttribute`), which avoids clipboard interference.
    /// Falls back to clipboard paste (NSPasteboard + Cmd+V) when the
    /// Accessibility approach is not supported by the focused element.
    ///
    /// - Throws: ``TextInsertionError/accessibilityNotGranted`` if the app
    ///   does not have Accessibility permission.
    func insertText(_ text: String) async throws {
        guard isAccessibilityGranted else {
            throw TextInsertionError.accessibilityNotGranted
        }

        // Try Accessibility API first (avoids clipboard interference).
        if insertTextViaAccessibility(text) {
            return
        }

        // Fall back to clipboard paste.
        logger.info("Falling back to clipboard paste for text insertion")
        try await insertTextViaClipboard(text)
    }

    // MARK: - Accessibility API insertion

    /// Try to insert text using the Accessibility API.
    ///
    /// Sets `kAXSelectedTextAttribute` on the focused element, which
    /// replaces the current selection (or inserts at the cursor position
    /// when nothing is selected).
    ///
    /// - Returns: `true` if the text was successfully inserted.
    private func insertTextViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedValue: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusResult == .success, let focused = focusedValue else {
            logger.debug("Accessibility: no focused element found (\(focusResult.rawValue))")
            return false
        }

        // swiftlint:disable:next force_cast — AXUIElement is a CoreFoundation type; cast always succeeds.
        let element = focused as! AXUIElement

        let setResult = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        if setResult == .success {
            logger.info("Inserted text via Accessibility API (\(text.count) chars)")
            return true
        }

        logger.debug(
            "Accessibility: failed to set selected text (\(setResult.rawValue))"
        )
        return false
    }

    // MARK: - Clipboard paste insertion

    /// Insert text by temporarily placing it on the clipboard and
    /// simulating Cmd+V.
    private func insertTextViaClipboard(_ text: String) async throws {
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

        logger.info("Inserted text via clipboard paste (\(text.count) chars)")
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
