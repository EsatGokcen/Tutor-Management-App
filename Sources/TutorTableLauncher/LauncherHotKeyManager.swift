import Carbon
import Foundation

struct LauncherHotKeyRegistrationResult {
    let displayName: String
    let didRegister: Bool
    let registrationErrorCode: Int32?
}

final class LauncherHotKeyManager {
    private let hotKeySignature: OSType = 0x5455544C
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?
    private var action: (() -> Void)?

    func registerPreferredShortcut(action: @escaping () -> Void) -> LauncherHotKeyRegistrationResult {
        self.action = action
        installEventHandlerIfNeeded()
        unregister()

        let candidates = [
            (UInt32(kVK_ANSI_T), UInt32(cmdKey | optionKey), "Command + Option + T"),
            (UInt32(kVK_ANSI_T), UInt32(cmdKey | controlKey), "Command + Control + T"),
            (UInt32(kVK_ANSI_T), UInt32(cmdKey | shiftKey), "Command + Shift + T")
        ]
        var lastErrorCode: Int32?

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
                return LauncherHotKeyRegistrationResult(
                    displayName: candidate.2,
                    didRegister: true,
                    registrationErrorCode: nil
                )
            }

            lastErrorCode = status
        }

        return LauncherHotKeyRegistrationResult(
            displayName: "Unavailable (use the menu bar icon to open TutorTable)",
            didRegister: false,
            registrationErrorCode: lastErrorCode
        )
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

                let manager = Unmanaged<LauncherHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
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
        GetApplicationEventTarget()
    }

    private func unregister() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
    }

    deinit {
        unregister()
    }
}
