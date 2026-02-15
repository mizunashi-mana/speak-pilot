/// Manages a global hotkey (Ctrl+Option+Space) using the Carbon Event API.
///
/// Registers a system-wide hotkey that works regardless of which application
/// has focus. Does not require Accessibility permissions.

import Carbon.HIToolbox
import os

// MARK: - Constants (file-scope for C callback access)

/// Four-character signature identifying this app's hotkeys ("SPKP").
private let hotkeySignature: OSType = 0x53504B50

private let hotkeyIDValue: UInt32 = 1

@MainActor
@Observable
final class HotkeyManager {
    // MARK: - Observable properties

    /// Whether the hotkey is currently registered.
    private(set) var isRegistered = false

    // MARK: - Callback

    /// Called on the main actor when the hotkey is pressed.
    var onToggle: (@MainActor @Sendable () -> Void)?

    // MARK: - Internal

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.speak-pilot",
        category: "HotkeyManager"
    )

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// Static reference for the C callback bridge.
    ///
    /// Carbon's event handler requires a C-compatible function pointer that cannot
    /// capture Swift context. We use a static reference to route events back to
    /// the active instance. Only one `HotkeyManager` should exist per application.
    nonisolated(unsafe) private static var instance: HotkeyManager?

    // MARK: - Public API

    /// Register the global hotkey (Ctrl+Option+Space).
    func register() {
        guard !isRegistered else {
            logger.warning("register() called but hotkey is already registered")
            return
        }

        Self.instance = self

        // Install the Carbon event handler for hotkey events.
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            logger.error("InstallEventHandler failed: \(handlerStatus)")
            Self.instance = nil
            return
        }

        // Register the hotkey: Ctrl+Option+Space.
        let hotkeyID = EventHotKeyID(
            signature: hotkeySignature,
            id: hotkeyIDValue
        )

        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard registerStatus == noErr else {
            logger.error("RegisterEventHotKey failed: \(registerStatus)")
            if let handler = eventHandlerRef {
                RemoveEventHandler(handler)
                eventHandlerRef = nil
            }
            Self.instance = nil
            return
        }

        isRegistered = true
        logger.info("Hotkey registered: Ctrl+Option+Space")
    }

    /// Unregister the global hotkey.
    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }

        Self.instance = nil
        isRegistered = false
        logger.info("Hotkey unregistered")
    }

    // MARK: - Carbon callback bridge

    /// Called from the C callback on the main thread.
    fileprivate nonisolated static func dispatchHotkeyEvent() {
        Task { @MainActor in
            guard let instance else { return }
            instance.logger.debug("Hotkey pressed")
            instance.onToggle?()
        }
    }
}

// MARK: - C callback

/// Top-level C-compatible function for the Carbon event handler.
///
/// Carbon calls this on the main thread when a registered hotkey is pressed.
private func hotkeyEventHandler(
    _: EventHandlerCallRef?,
    _ event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        UInt32(kEventParamDirectObject),
        UInt32(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )

    guard status == noErr else { return status }

    // Verify this is our hotkey.
    guard hotkeyID.signature == hotkeySignature,
        hotkeyID.id == hotkeyIDValue
    else {
        return OSStatus(eventNotHandledErr)
    }

    HotkeyManager.dispatchHotkeyEvent()
    return noErr
}
