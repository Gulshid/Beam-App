import SwiftUI
import AVFoundation

@MainActor
final class VoiceRecorderViewModel: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()

            self.recorder = recorder
            self.fileURL = url
            self.isRecording = true
            self.elapsed = 0
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsed += 0.1 }
            }
        } catch {
            print("VoiceRecorder: failed to start — \(error)")
        }
    }

    /// Stops recording and returns the captured audio + duration, or nil if nothing usable was captured.
    func stopRecording() -> (data: Data, duration: Double)? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)

        defer {
            if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
            fileURL = nil
        }
        guard let fileURL, let data = try? Data(contentsOf: fileURL), elapsed > 0.3 else { return nil }
        return (data, elapsed)
    }

    func cancelRecording() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

/// Recording bar shown in place of the text field while a voice message is being captured.
struct VoiceRecorderView: View {
    @ObservedObject var viewModel: VoiceRecorderViewModel
    let onFinish: (Data, Double) -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(viewModel.isRecording ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.isRecording)

            Text(formatted(viewModel.elapsed))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                viewModel.cancelRecording()
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }

            Button {
                if let result = viewModel.stopRecording() {
                    onFinish(result.data, result.duration)
                } else {
                    onCancel()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
