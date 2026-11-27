import SwiftUI
import BuzzKit

// MARK: - Color Extensions

extension Color {
    static let buzzPink = Color(red: 1.0, green: 0.55, blue: 0.78) // #ff8cc6
    static let buzzMint = Color(red: 0.43, green: 0.85, blue: 0.71) // #6ed8b6

    static let pastelPeach = Color(red: 1.0, green: 0.93, blue: 0.90)
    static let pastelLavender = Color(red: 0.96, green: 0.92, blue: 1.0)
}

// MARK: - View Model

final class PatternEditorViewModel: ObservableObject {
    @Published var selectedPreset: String = "Custom"
    @Published var waveform: Waveform = .sine
    @Published var frequency: Double = 180.0
    @Published var intensity: Double = 0.75
    @Published var sharpness: Double = 0.65
    @Published var duration: Double = 0.8
    @Published var isPlaying = false
    @Published var currentPattern: HapticPattern = .pulse()

    private let player = HapticPlayer()
    private var playbackTask: Task<Void, Never>?

    let presets = ["heartbeat", "laser", "notification", "bassDrum"]

    func buildPattern() -> HapticPattern {
        switch selectedPreset {
        case "heartbeat":
            return Preset.heartbeat
        case "laser":
            return Preset.laser
        case "notification":
            return Preset.notification
        case "bassDrum":
            return Preset.bassDrum
        default:
            // Custom pattern from sliders
            switch waveform {
            case .sine:
                return HapticPattern.sine(
                    freq: frequency,
                    duration: duration,
                    intensity: Float(intensity)
                )
            case .square, .triangle, .sawtooth:
                // Use TrackpadSpeaker logic but return pattern
                var pattern = HapticPattern.sine(
                    freq: frequency,
                    duration: duration,
                    intensity: Float(intensity)
                )
                if let first = pattern.events.first {
                    let adjustedSharpness: Float = {
                        switch waveform {
                        case .square: return 0.88
                        case .triangle: return 0.62
                        case .sawtooth: return 0.78
                        default: return Float(sharpness)
                        }
                    }()
                    let adjusted = HapticPattern.Event(
                        time: first.time,
                        intensity: Float(intensity),
                        sharpness: adjustedSharpness,
                        duration: first.duration
                    )
                    pattern = HapticPattern(events: [adjusted])
                }
                return pattern
            }
        }
    }

    func play() {
        isPlaying = true
        let pattern = buildPattern()
        currentPattern = pattern

        playbackTask?.cancel()
        playbackTask = Task {
            do {
                try await player.play(pattern)
                // Visual feedback duration
                try await Task.sleep(for: .seconds(pattern.totalDuration + 0.1))
            } catch {
                print("Demo playback error: \(error.localizedDescription)")
            }
            await MainActor.run {
                self.isPlaying = false
            }
        }
    }

    func stop() {
        playbackTask?.cancel()
        isPlaying = false
    }

    func selectPreset(_ name: String) {
        selectedPreset = name
        // Update sliders to sensible defaults for the preset
        switch name {
        case "heartbeat":
            frequency = 65
            intensity = 0.9
            sharpness = 0.7
            duration = 2.8
        case "laser":
            frequency = 160
            intensity = 0.75
            sharpness = 0.85
            duration = 0.65
        case "notification":
            frequency = 220
            intensity = 0.7
            sharpness = 0.75
            duration = 0.8
        case "bassDrum":
            frequency = 48
            intensity = 0.92
            sharpness = 0.25
            duration = 0.45
        default:
            break
        }
        currentPattern = buildPattern()
    }
}

// MARK: - Main View

struct PatternEditorView: View {
    @StateObject private var viewModel = PatternEditorViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.pastelPeach, Color.pastelLavender],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                HStack {
                    Text("🐝 BuzzKit")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.linearGradient(
                            colors: [.buzzPink, .buzzMint],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    Spacer()
                    Text("🧪 Trackpad Instrument")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                // Preset Pills
                VStack(alignment: .leading, spacing: 12) {
                    Text("Presets 💖")
                        .font(.system(.title3, design: .rounded))
                        .foregroundColor(.buzzPink)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(viewModel.presets, id: \.self) { preset in
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                        viewModel.selectPreset(preset)
                                    }
                                } label: {
                                    HStack {
                                        emojiForPreset(preset)
                                        Text(preset.capitalized)
                                            .font(.system(.callout, design: .rounded))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(viewModel.selectedPreset == preset
                                                  ? Color.buzzMint.opacity(0.2)
                                                  : Color.white.opacity(0.7))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color.buzzMint.opacity(0.4), lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                                .scaleEffect(viewModel.selectedPreset == preset ? 1.08 : 1.0)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                }

                Divider()
                    .padding(.horizontal, 40)

                // Custom Controls
                VStack(spacing: 24) {
                    HStack {
                        Text("Custom Builder 🎛️")
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.buzzPink)
                        Spacer()
                        Picker("Wave", selection: $viewModel.waveform) {
                            ForEach(Waveform.allCases, id: \.self) { w in
                                Text(w.rawValue.capitalized).tag(w)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                    .padding(.horizontal, 40)

                    VStack(spacing: 18) {
                        parameterSlider(title: "Frequency (Hz)", value: $viewModel.frequency, range: 40...320, unit: "Hz")
                        parameterSlider(title: "Intensity", value: $viewModel.intensity, range: 0.1...1.0, unit: "")
                        parameterSlider(title: "Sharpness", value: $viewModel.sharpness, range: 0.1...1.0, unit: "")
                        parameterSlider(title: "Duration", value: $viewModel.duration, range: 0.1...3.0, unit: "s")
                    }
                    .padding(.horizontal, 40)
                }

                // Visualiser
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)

                    VStack {
                        if viewModel.currentPattern.events.isEmpty {
                            Text("👆 Select a preset or tweak sliders")
                                .font(.system(.callout, design: .rounded))
                                .foregroundColor(.secondary)
                        } else {
                            HStack(spacing: 6) {
                                ForEach(Array(viewModel.currentPattern.events.enumerated()), id: \.offset) { index, event in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.buzzPink.opacity(0.9))
                                        .frame(width: 12, height: CGFloat(event.intensity) * 68)
                                        .offset(y: viewModel.isPlaying ? CGFloat.random(in: -4...4) : 0)
                                }
                            }
                            .animation(.easeInOut(duration: 0.15).repeatCount(viewModel.isPlaying ? 12 : 0, autoreverses: true), value: viewModel.isPlaying)
                        }
                    }
                }
                .frame(height: 110)
                .padding(.horizontal, 40)

                // Play Button
                Button {
                    if viewModel.isPlaying {
                        viewModel.stop()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            viewModel.play()
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                        Text(viewModel.isPlaying ? "STOP VIBRATION" : "PLAY ON TRACKPAD")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 68)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [Color.buzzPink, Color.buzzMint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Color.buzzPink.opacity(0.35), radius: 18, y: 8)
                }
                .buttonStyle(.plain)
                .scaleEffect(viewModel.isPlaying ? 0.95 : 1.0)
                .padding(.horizontal, 40)
                .disabled(viewModel.currentPattern.events.isEmpty)

                Spacer()
            }
        }
        .onChange(of: viewModel.frequency) { _ in viewModel.currentPattern = viewModel.buildPattern() }
        .onChange(of: viewModel.intensity) { _ in viewModel.currentPattern = viewModel.buildPattern() }
        .onChange(of: viewModel.sharpness) { _ in viewModel.currentPattern = viewModel.buildPattern() }
        .onChange(of: viewModel.duration) { _ in viewModel.currentPattern = viewModel.buildPattern() }
        .onChange(of: viewModel.waveform) { _ in viewModel.currentPattern = viewModel.buildPattern() }
    }

    private func emojiForPreset(_ preset: String) -> Text {
        switch preset {
        case "heartbeat": return Text("❤️")
        case "laser": return Text("⚡")
        case "notification": return Text("🛎")
        case "bassDrum": return Text("🥁")
        default: return Text("📳")
        }
    }

    private func parameterSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f\(unit)", value.wrappedValue))
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundColor(.buzzMint)
            }
            Slider(value: value, in: range, step: 0.01)
                .tint(.buzzMint)
        }
    }
}
