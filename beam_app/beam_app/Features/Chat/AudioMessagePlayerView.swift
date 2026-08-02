import SwiftUI
import AVFoundation

@MainActor
final class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0 // 0...1

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var localURL: URL?

    func toggle(remoteURL: URL) {
        if isPlaying {
            pause()
        } else {
            Task { await play(remoteURL: remoteURL) }
        }
    }

    private func play(remoteURL: URL) async {
        do {
            let fileURL = try await cachedFile(for: remoteURL)
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.delegate = self
            self.player = player

            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            startTimer()
        } catch {
            print("AudioPlayer: failed to play — \(error)")
        }
    }

    private func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            Task { @MainActor in
                self.progress = player.duration > 0 ? player.currentTime / player.duration : 0
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
            self?.progress = 0
            self?.timer?.invalidate()
        }
    }

    /// AVAudioPlayer needs a local file, so download once to a temp location and reuse it
    /// for repeat taps within this bubble's lifetime.
    private func cachedFile(for remoteURL: URL) async throws -> URL {
        if let localURL, FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }
        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try FileManager.default.moveItem(at: tempURL, to: destination)
        localURL = destination
        return destination
    }
}

/// Inline voice-message playback control shown inside a chat bubble.
struct AudioMessageView: View {
    let url: URL
    let duration: Double
    let tint: Color

    @StateObject private var viewModel = AudioPlayerViewModel()

    var body: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.toggle(remoteURL: url)
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
            }

            ProgressView(value: viewModel.progress)
                .frame(width: 100)

            Text(formatted(duration))
                .font(.caption2)
        }
        .tint(tint)
        .foregroundStyle(tint)
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
