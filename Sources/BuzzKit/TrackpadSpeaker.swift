import Foundation

/// A convenient high-level API for turning the Mac trackpad into a programmable
/// musical instrument / tone generator.
///
/// `TrackpadSpeaker` internally converts the requested waveform, frequency,
/// and duration into a `HapticPattern` and schedules playback on a shared
/// `HapticPlayer`. Because haptic motors have limited frequency response,
/// different `Waveform` values are mapped to distinct sharpness values that
/// produce audible timbre variations.
public final class TrackpadSpeaker {
    private let player = HapticPlayer()
    private var currentTask: Task<Void, Never>?

    public init() {}

    /// Plays a tone on the trackpad using the given waveform, frequency and duration.
    ///
    /// The call returns immediately; playback happens asynchronously. Successive
    /// calls will cancel any previous tone (useful for live keyboard instruments).
    ///
    /// - Parameters:
    ///   - waveform: The desired vibration shape (affects perceived timbre).
    ///   - frequency: Frequency in Hz (approximately 40–300 Hz maps best to haptics).
    ///   - duration: Length of the tone in seconds.
    public func speak(
        _ waveform: Waveform,
        frequency: Float,
        duration: TimeInterval
    ) {
        currentTask?.cancel()

        currentTask = Task {
            do {
                let pattern = Self.makePattern(
                    for: waveform,
                    frequency: frequency,
                    duration: duration
                )
                try await player.play(pattern)
            } catch {
                if !Task.isCancelled {
                    print("TrackpadSpeaker: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Cancels any currently playing tone.
    public func stop() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Pattern Generation

    private static func makePattern(
        for waveform: Waveform,
        frequency: Float,
        duration: TimeInterval
    ) -> HapticPattern {
        precondition(frequency > 0, "Frequency must be positive")
        precondition(duration > 0, "Duration must be positive")

        let intensity: Float = 0.78
        let sharpness: Float

        switch waveform {
        case .sine:
            sharpness = 0.45
        case .square:
            sharpness = 0.88   // sharper = brighter / more metallic
        case .triangle:
            sharpness = 0.62
        case .sawtooth:
            sharpness = 0.75
        }

        // Start with the library’s built-in sine factory (which already maps
        // frequency into the haptic sharpness range) then override sharpness
        // with our waveform-specific value.
        var pattern = HapticPattern.sine(
            freq: Double(frequency),
            duration: duration,
            intensity: intensity
        )

        if let first = pattern.events.first {
            let adjusted = HapticPattern.Event(
                time: first.time,
                intensity: first.intensity,
                sharpness: sharpness,
                duration: first.duration
            )
            pattern = HapticPattern(events: [adjusted])
        }

        return pattern
    }
}
