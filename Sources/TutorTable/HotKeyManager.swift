import Carbon
import Foundation

struct HotKeyRegistrationResult {
    let displayName: String
    let usedFallback: Bool
    let didRegister: Bool
}

final class HotKeyManager {
    private let hotKeySignature: OSType = 0x54555452
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?
    private var action: (() -> Void)?

    func registerPreferredShortcut(action: @escaping () -> Void) -> HotKeyRegistrationResult {
        self.action = action
        installEventHandlerIfNeeded()
        unregister()

        let candidates = [
            (UInt32(kVK_ANSI_M), UInt32(cmdKey | optionKey), "Command + Option + M"),
            (UInt32(kVK_ANSI_M), UInt32(cmdKey | controlKey), "Command + Control + M"),
            (UInt32(kVK_ANSI_T), UInt32(cmdKey | shiftKey), "Command + Shift + T")
        ]

        for (index, candidate) in candidates.enumerated() {
            let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(
                candidate.0,
                candidate.1,
                hotKeyID,
                eventTarget,
                0,
                &hotKeyReference
            )

            if status == noErr {
                return HotKeyRegistrationResult(
                    displayName: candidate.2,
                    usedFallback: index > 0,
                    didRegister: true
                )
            }
        }

        return HotKeyRegistrationResult(
            displayName: "Unavailable (use the Dock to reopen the app)",
            usedFallback: false,
            didRegister: false
        )
    }

    func unregister() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerReference == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            eventTarget,
            { _, _, userData in
                guard let userData else {
                    return noErr
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.action?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerReference
        )
    }

    private var eventTarget: EventTargetRef {
        GetEventDispatcherTarget()
    }

    deinit {
        unregister()
    }
}
