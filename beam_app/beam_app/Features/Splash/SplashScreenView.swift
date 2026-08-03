import SwiftUI

/// A polished, animated launch splash for Beam.
///
/// Purely vector/SF Symbol based (no image assets required), so it drops
/// straight into the project. Choreography:
///   1. Two soft, slowly-drifting glow orbs breathe in the background.
///   2. The logo mark scales/rotates in with a spring, while a conic
///      "beam sweep" ring rotates continuously around it.
///   3. The "Beam" wordmark reveals letter-by-letter.
///   4. The tagline fades up beneath it.
///   5. A minimal three-dot loading indicator pulses at the bottom while
///      `RootView` waits on `AppState.isLoadingSession`.
///
/// Usage: shown by `RootView` until the real session state resolves AND a
/// minimum display time has elapsed, then it crossfades away.
struct SplashScreenView: View {
    /// Set to false externally to trigger the exit transition.
    var isActive: Bool = true

    @State private var orbsAppeared = false
    @State private var logoAppeared = false
    @State private var ringRotation: Double = 0
    @State private var revealedLetters = 0
    @State private var taglineVisible = false
    @State private var dotPhase = 0

    private let wordmark = Array("beam")

    var body: some View {
        ZStack {
            background

            VStack(spacing: 28) {
                Spacer()

                logo

                VStack(spacing: 10) {
                    wordmarkView
                    taglineView
                }

                Spacer()

                loadingDots
                    .padding(.bottom, 48)
            }
        }
        .opacity(isActive ? 1 : 0)
        .scaleEffect(isActive ? 1 : 1.04)
        .animation(.easeInOut(duration: 0.45), value: isActive)
        .onAppear(perform: choreograph)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.20),
                    Color(red: 0.10, green: 0.13, blue: 0.30),
                    Color(red: 0.05, green: 0.07, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                let size = proxy.size

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.55), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width * 0.5
                        )
                    )
                    .frame(width: size.width * 0.9, height: size.width * 0.9)
                    .blur(radius: 60)
                    .offset(
                        x: orbsAppeared ? -size.width * 0.22 : -size.width * 0.32,
                        y: orbsAppeared ? -size.height * 0.28 : -size.height * 0.20
                    )
                    .opacity(orbsAppeared ? 0.9 : 0)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.5), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width * 0.45
                        )
                    )
                    .frame(width: size.width * 0.8, height: size.width * 0.8)
                    .blur(radius: 60)
                    .offset(
                        x: orbsAppeared ? size.width * 0.28 : size.width * 0.36,
                        y: orbsAppeared ? size.height * 0.30 : size.height * 0.22
                    )
                    .opacity(orbsAppeared ? 0.85 : 0)
            }
            .animation(
                .easeInOut(duration: 4.2).repeatForever(autoreverses: true),
                value: orbsAppeared
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Logo

    private var logo: some View {
        ZStack {
            // Rotating "beam sweep" ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.clear, .white.opacity(0.9), .clear],
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 128, height: 128)
                .rotationEffect(.degrees(ringRotation))
                .opacity(logoAppeared ? 1 : 0)

            // Core mark
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .shadow(color: .blue.opacity(0.55), radius: 22, y: 10)
                .overlay(
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
        .scaleEffect(logoAppeared ? 1 : 0.55)
        .rotationEffect(.degrees(logoAppeared ? 0 : -20))
        .opacity(logoAppeared ? 1 : 0)
    }

    // MARK: - Wordmark

    private var wordmarkView: some View {
        HStack(spacing: 1) {
            ForEach(Array(wordmark.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(index < revealedLetters ? 1 : 0)
                    .offset(y: index < revealedLetters ? 0 : 10)
            }
        }
        .kerning(1.5)
    }

    private var taglineView: some View {
        Text("Real conversations, right now.")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.65))
            .opacity(taglineVisible ? 1 : 0)
            .offset(y: taglineVisible ? 0 : 6)
    }

    // MARK: - Loading dots

    private var loadingDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotPhase == index ? 1.35 : 0.7)
                    .opacity(dotPhase == index ? 1 : 0.35)
            }
        }
        .opacity(logoAppeared ? 1 : 0)
    }

    // MARK: - Choreography

    private func choreograph() {
        withAnimation(.easeOut(duration: 1.6)) {
            orbsAppeared = true
        }

        withAnimation(.spring(response: 0.65, dampingFraction: 0.62).delay(0.05)) {
            logoAppeared = true
        }

        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        for index in 0...wordmark.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(index) * 0.06) {
                withAnimation(.easeOut(duration: 0.3)) {
                    revealedLetters = index
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.5)) {
                taglineVisible = true
            }
        }

        Timer.scheduledTimer(withTimeInterval: 0.42, repeats: true) { timer in
            guard logoAppeared else { return }
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.3)) {
                    dotPhase = (dotPhase + 1) % 3
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
