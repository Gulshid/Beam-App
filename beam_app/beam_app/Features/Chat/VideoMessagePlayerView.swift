import SwiftUI
import AVKit

/// Full-screen playback sheet for a video message, opened by tapping its bubble thumbnail.
struct VideoMessagePlayerView: View {
    let url: URL

    var body: some View {
        VideoPlayer(player: AVPlayer(url: url))
            .ignoresSafeArea()
    }
}
