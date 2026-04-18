import SwiftUI

enum VoiceCommandPanelMode {
    case compact
    case full
}

struct VoiceInputView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VoiceCommandPanelView(
            voiceCommandManager: appModel.voiceCommandManager,
            mode: .full
        )
            .environmentObject(appModel)
    }
}

struct VoiceCommandPanelView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var voiceCommandManager: VoiceCommandManager
    let mode: VoiceCommandPanelMode

    var body: some View {
        GroupBox(mode == .compact ? "Speak To TutorTable" : "Speak A Session Command") {
            VStack(alignment: .leading, spacing: 18) {
                Text("Press Start Listening, say what changed, then review the transcript before applying it. TutorTable can create new sessions and update payment status for existing ones.")
                    .foregroundStyle(AppTheme.mutedText)

                HStack(spacing: 18) {
                    Button {
                        if voiceCommandManager.isListening {
                            voiceCommandManager.stopListening()
                        } else {
                            voiceCommandManager.startListening()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(voiceCommandManager.isListening ? Color.red.opacity(0.22) : AppTheme.accent.opacity(0.20))
                                .frame(width: mode == .compact ? 70 : 78, height: mode == .compact ? 70 : 78)
                            Image(systemName: voiceCommandManager.isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(voiceCommandManager.isListening ? Color.red : AppTheme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .appInteractiveButton(scaleAmount: 1.02)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(voiceCommandManager.isListening ? "Listening Now" : "Ready")
                            .font(.title3.weight(.semibold))
                        Text(voiceCommandManager.statusText)
                            .foregroundStyle(AppTheme.mutedText)
                        Text("Built with Apple's free speech recognition on macOS.")
                            .foregroundStyle(AppTheme.mutedText)
                            .font(.subheadline)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcript")
                        .font(.headline)
                    TextEditor(text: $voiceCommandManager.transcript)
                        .frame(minHeight: mode == .compact ? 180 : 190)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AppTheme.panelBackgroundSoft)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.panelBorder, lineWidth: 1)
                        )
                }

                if let errorMessage = voiceCommandManager.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                ViewThatFits(in: .horizontal) {
                    HStack {
                        voiceActionButtons
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        voiceActionButtons
                    }
                }

                if mode == .full {
                    GroupBox("What You Can Say") {
                        VStack(alignment: .leading, spacing: 12) {
                            VoiceExampleRow(text: "Next week Wednesday I have a session with Reef at 3pm. It will be an hour at standard rate and he hasn't paid yet.")
                            VoiceExampleRow(text: "Reef just paid for the Wednesday session that happened today.")
                            VoiceExampleRow(text: "Tomorrow at 6pm I have a session with Maya on Zoom for 90 minutes and she will pay by bank transfer.")
                        }
                        .padding(.top, 8)
                    }

                    GroupBox("How It Works") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TutorTable listens for a student name, a date and time, and payment clues like paid, unpaid, cash, or bank transfer.")
                            Text("New sessions are added straight into your normal session list and calendar. Payment updates change the existing matching session.")
                            Text("If multiple sessions could match the same spoken update, TutorTable will ask for a more specific command so it does not update the wrong lesson.")
                        }
                        .foregroundStyle(AppTheme.mutedText)
                        .padding(.top, 8)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Try saying")
                            .font(.headline)

                        VoiceExampleCapsule(text: "“Next week Wednesday I have a session with Reef at 3pm.”")
                        VoiceExampleCapsule(text: "“Reef just paid for the Wednesday session that happened today.”")
                    }
                }
            }
            .padding(.top, 8)
        }
        .onDisappear {
            voiceCommandManager.stopListening()
        }
    }
}

private extension VoiceCommandPanelView {
    @ViewBuilder
    var voiceActionButtons: some View {
        Button(voiceCommandManager.isListening ? "Stop Listening" : "Start Listening") {
            if voiceCommandManager.isListening {
                voiceCommandManager.stopListening()
            } else {
                voiceCommandManager.startListening()
            }
        }
        .appInteractiveButton()

        Button("Apply Command") {
            appModel.applyVoiceCommandTranscript()
        }
        .disabled(voiceCommandManager.isListening || voiceCommandManager.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .appInteractiveButton()

        Button("Clear Transcript") {
            voiceCommandManager.clearTranscript()
        }
        .appInteractiveButton()
    }
}

private struct VoiceExampleRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.opening")
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct VoiceExampleCapsule: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(AppTheme.mutedText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.panelBackgroundSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.panelBorder, lineWidth: 1)
            )
    }
}
