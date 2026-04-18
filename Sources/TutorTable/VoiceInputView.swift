import SwiftUI

struct VoiceInputView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VoiceInputContentView(voiceCommandManager: appModel.voiceCommandManager)
            .environmentObject(appModel)
    }
}

private struct VoiceInputContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var voiceCommandManager: VoiceCommandManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Voice Input")
                    .font(.system(size: 28, weight: .semibold))

                GroupBox("Speak A Session Command") {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Press Start Listening, say what changed, then review the transcript before applying it. TutorTable can create new sessions and update payment status for existing ones.")
                            .foregroundStyle(.secondary)

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
                                        .fill(voiceCommandManager.isListening ? Color.red.opacity(0.18) : Color.accentColor.opacity(0.16))
                                        .frame(width: 78, height: 78)
                                    Image(systemName: voiceCommandManager.isListening ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(voiceCommandManager.isListening ? Color.red : Color.accentColor)
                                }
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(voiceCommandManager.isListening ? "Listening Now" : "Ready")
                                    .font(.title3.weight(.semibold))
                                Text(voiceCommandManager.statusText)
                                    .foregroundStyle(.secondary)
                                Text("Built with Apple's free speech recognition on macOS.")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transcript")
                                .font(.headline)
                            TextEditor(text: $voiceCommandManager.transcript)
                                .frame(minHeight: 180)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(nsColor: .textBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        }

                        if let errorMessage = voiceCommandManager.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }

                        HStack {
                            Button(voiceCommandManager.isListening ? "Stop Listening" : "Start Listening") {
                                if voiceCommandManager.isListening {
                                    voiceCommandManager.stopListening()
                                } else {
                                    voiceCommandManager.startListening()
                                }
                            }

                            Button("Apply Command") {
                                appModel.applyVoiceCommandTranscript()
                            }
                            .disabled(voiceCommandManager.isListening || voiceCommandManager.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Clear Transcript") {
                                voiceCommandManager.clearTranscript()
                            }
                        }
                    }
                    .padding(.top, 8)
                }

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
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 20)
        }
        .onDisappear {
            voiceCommandManager.stopListening()
        }
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
