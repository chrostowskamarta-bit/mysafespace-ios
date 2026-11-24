import AVFoundation
import Foundation
import Observation
import Speech

/// Voice notes → text, entirely on the iPhone.
///
/// PRIVACY:
/// - `requiresOnDeviceRecognition = true`: audio is never sent to Apple or anyone else.
///   If on-device recognition isn't available for the language, dictation is unavailable
///   (we never fall back to server recognition).
/// - Audio is streamed straight into the recogniser and never written to disk.
///   Only the resulting text is kept — inside the note, private by default.
@Observable
final class OnDeviceDictation {
    enum Status: Equatable {
        case idle
        case recording
        case unavailable(String)
    }

    private(set) var status: Status = .idle
    /// Live transcript of the current recording.
    private(set) var transcript = ""

    var isRecording: Bool { status == .recording }

    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private let recognizer: SFSpeechRecognizer? =
        SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))

    func toggle() async {
        if isRecording { stop() } else { await start() }
    }

    func start() async {
        guard !isRecording else { return }
        guard await Self.requestSpeechPermission(), await AVAudioApplication.requestRecordPermission() else {
            status = .unavailable(String(localized: "Allow the microphone and speech recognition in Settings to record voice notes."))
            return
        }
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            status = .unavailable(String(localized: "Voice notes need on-device speech recognition, which isn't available for this language on this iPhone."))
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            self.request = request

            Self.installTap(on: audioEngine.inputNode, feeding: request)
            audioEngine.prepare()
            try audioEngine.start()

            transcript = ""
            status = .recording
            task = Self.recognitionTask(recognizer: recognizer, request: request) { [weak self] text, finished in
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if finished { self.stop() }
                }
            }
        } catch {
            stop()
            status = .unavailable(String(localized: "Recording couldn't start. Please try again."))
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        if status == .recording { status = .idle }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Clears the transcript once the caller has moved it into the note.
    func consumeTranscript() -> String {
        defer { transcript = "" }
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Off-main callbacks
    // DECISION: the audio tap and recognition callbacks run on background threads, so they are
    // built in nonisolated functions (the target defaults to MainActor isolation).

    nonisolated private static func installTap(on input: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        nonisolated(unsafe) let request = request
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func recognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onUpdate(result?.bestTranscription.formattedString, error != nil || (result?.isFinal ?? false))
        }
    }

    nonisolated private static func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
