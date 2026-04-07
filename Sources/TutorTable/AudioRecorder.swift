import AppKit
import AudioToolbox
import AVFoundation
import Foundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var currentFileName: String?
    @Published private(set) var errorMessage: String?

    private let audioDirectory: URL
    private var recorder: AVAudioRecorder?

    var onRecordingFinished: ((String) -> Void)?

    init(audioDirectory: URL) {
        self.audioDirectory = audioDirectory
    }

    func startRecording(for sessionID: UUID) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginRecording(for: sessionID)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }

                    if granted {
                        self.beginRecording(for: sessionID)
                    } else {
                        self.errorMessage = "Microphone access was denied."
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Microphone access is disabled for TutorTable."
        @unknown default:
            errorMessage = "Microphone access is unavailable right now."
        }
    }

    func stopRecording() -> String? {
        guard isRecording else {
            return currentFileName
        }

        recorder?.stop()
        recorder = nil
        isRecording = false

        if let currentFileName {
            onRecordingFinished?(currentFileName)
        }

        return currentFileName
    }

    func revealAudioNote(named fileName: String) {
        NSWorkspace.shared.activateFileViewerSelecting([audioURL(for: fileName)])
    }

    func audioURL(for fileName: String) -> URL {
        audioDirectory.appendingPathComponent(fileName)
    }

    private func beginRecording(for sessionID: UUID) {
        let fileName = "session-\(sessionID.uuidString)-\(Self.timestampFormatter.string(from: Date())).m4a"
        let url = audioURL(for: fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.prepareToRecord()

            guard recorder.record() else {
                errorMessage = "TutorTable could not start recording."
                return
            }

            self.recorder = recorder
            currentFileName = fileName
            errorMessage = nil
            isRecording = true
        } catch {
            errorMessage = "Recording failed: \(error.localizedDescription)"
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            self?.errorMessage = error?.localizedDescription ?? "An audio encoding error occurred."
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
