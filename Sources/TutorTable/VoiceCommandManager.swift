import AVFoundation
import Foundation
import Speech

@MainActor
final class VoiceCommandManager: NSObject, ObservableObject {
    @Published var transcript: String = ""
    @Published private(set) var isListening = false
    @Published private(set) var statusText = "Press Start Listening and speak a session command."
    @Published private(set) var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: .autoupdatingCurrent)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startListening() {
        guard !isListening else {
            return
        }

        transcript = ""
        errorMessage = nil
        statusText = "Requesting microphone and speech access..."

        Task { [weak self] in
            guard let self else {
                return
            }

            let speechStatus = await self.requestSpeechAuthorization()
            guard speechStatus == .authorized else {
                self.isListening = false
                self.statusText = "Speech recognition is unavailable."
                self.errorMessage = Self.speechAuthorizationMessage(for: speechStatus)
                return
            }

            let microphoneGranted = await self.requestMicrophoneAccess()
            guard microphoneGranted else {
                self.isListening = false
                self.statusText = "Microphone access is unavailable."
                self.errorMessage = "Microphone access was denied for TutorTable."
                return
            }

            self.beginListening()
        }
    }

    func stopListening() {
        guard isListening else {
            return
        }

        finishListening(statusText: transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No speech detected yet." : "Transcript ready to apply.")
    }

    func clearTranscript() {
        stopListening()
        transcript = ""
        errorMessage = nil
        statusText = "Press Start Listening and speak a session command."
    }

    private func beginListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available right now."
            statusText = "Speech recognition is unavailable."
            return
        }

        teardownRecognitionPipeline()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            statusText = "Listening..."

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else {
                    return
                }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.errorMessage = nil
                    if result.isFinal {
                        self.finishListening(statusText: "Transcript ready to apply.")
                    }
                }

                if let error {
                    self.errorMessage = "Speech recognition failed: \(error.localizedDescription)"
                    self.finishListening(statusText: "Speech recognition stopped.")
                }
            }
        } catch {
            inputNode.removeTap(onBus: 0)
            teardownRecognitionPipeline()
            errorMessage = "TutorTable could not start listening: \(error.localizedDescription)"
            statusText = "Speech recognition failed to start."
        }
    }

    private func finishListening(statusText: String) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isListening = false
        self.statusText = statusText
    }

    private func teardownRecognitionPipeline() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .authorized
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private static func speechAuthorizationMessage(for status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .denied:
            return "Speech recognition access was denied for TutorTable."
        case .restricted:
            return "Speech recognition is restricted on this Mac."
        case .notDetermined:
            return "Speech recognition permission has not been granted yet."
        case .authorized:
            return ""
        @unknown default:
            return "Speech recognition is unavailable right now."
        }
    }

    deinit {
        recognitionTask?.cancel()
    }
}
