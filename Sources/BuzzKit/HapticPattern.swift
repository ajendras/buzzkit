import Foundation

/// A composable, codable representation of a haptic pattern suitable for playback
/// on a Mac trackpad or other CoreHaptics-compatible device.
///
/// `HapticPattern` is the central type in BuzzKit. It can be created via static
/// factories, composed using a fluent DSL powered by `@HapticBuilder`, combined
/// with `+` (sequence) and `*` (repeat) operators, and serialized for storage
/// or transmission.
public struct HapticPattern: Codable, Equatable, Sendable {
    /// A single haptic event within a pattern.
    ///
    /// - Note: `duration == 0` denotes a transient event; positive values indicate
    ///   a continuous event.
    public struct Event: Codable, Equatable, Sendable {
        /// Relative start time in seconds.
        public let time: TimeInterval
        /// Intensity clamped to `[0.0, 1.0]`.
        public let intensity: Float
        /// Sharpness (roughly frequency feel) clamped to `[0.0, 1.0]`.
        /// Higher values feel sharper / higher-frequency.
        public let sharpness: Float
        /// Duration of the event. `0` = transient.
        public let duration: TimeInterval

        /// Creates a validated haptic event.
        /// - Parameters:
        ///   - time: Relative start time.
        ///   - intensity: Clamped to `[0, 1]`.
        ///   - sharpness: Clamped to `[0, 1]`.
        ///   - duration: `0` for transient, positive for continuous.
        public init(
            time: TimeInterval = 0,
            intensity: Float = 1.0,
            sharpness: Float = 0.5,
            duration: TimeInterval = 0
        ) {
            precondition(time >= 0, "Event time must be non-negative")
            precondition(duration >= 0, "Event duration must be non-negative")

            self.time = time
            self.intensity = max(0.0, min(1.0, intensity))
            self.sharpness = max(0.0, min(1.0, sharpness))
            self.duration = max(0.0, duration)
        }
    }

    /// The individual events that make up this pattern, sorted by start time.
    public let events: [Event]

    /// The total duration of the entire pattern (max end time of any event).
    public let totalDuration: TimeInterval

    /// Creates a pattern from a list of events.
    ///
    /// Events are automatically sorted by time and the total duration is computed.
    public init(events: [Event]) {
        let sorted = events.sorted { $0.time < $1.time }
        self.events = sorted

        if sorted.isEmpty {
            self.totalDuration = 0
        } else {
            let maxEnd = sorted.reduce(0.0) { max($0, $1.time + $1.duration) }
            self.totalDuration = maxEnd
        }
    }

    /// Creates a pattern using the `@HapticBuilder` DSL.
    ///
    /// Example:
    /// ```swift
    /// let pattern = HapticPattern {
    ///     .pulse(intensity: 0.9)
    ///     loop(.sine(freq: 180, duration: 0.12), times: 3)
    ///     layer(.pulse(), .noise())
    /// }
    /// ```
    public init(@HapticBuilder _ builder: () -> HapticPattern) {
        self = builder()
    }

    // MARK: - Factories

    /// A sharp, transient pulse. Ideal for clicks, beats, and accents.
    /// - Parameters:
    ///   - intensity: Perceived strength of the pulse (`[0, 1]`).
    ///   - time: Optional relative start time.
    /// - Returns: A single-event transient `HapticPattern`.
    public static func pulse(
        intensity: Float = 1.0,
        at time: TimeInterval = 0.0
    ) -> HapticPattern {
        HapticPattern(events: [
            Event(
                time: time,
                intensity: intensity,
                sharpness: 0.75,
                duration: 0.0
            )
        ])
    }

    /// A continuous sinusoidal vibration tuned to a specific frequency.
    ///
    /// Frequency is mapped to a CoreHaptics-compatible sharpness value.
    /// Useful for musical notes and tones.
    /// - Parameters:
    ///   - freq: Frequency in Hz (typical haptic range ~40–300 Hz).
    ///   - duration: How long the vibration should last.
    ///   - intensity: Overall strength.
    /// - Returns: A continuous `HapticPattern`.
    public static func sine(
        freq: Double,
        duration: TimeInterval,
        intensity: Float = 0.7,
        at time: TimeInterval = 0.0
    ) -> HapticPattern {
        precondition(freq > 0, "Frequency must be positive")
        precondition(duration > 0, "Duration must be positive")

        // Map frequency to sharpness in the haptic range.
        // 40 Hz → ~0.1, 300 Hz → ~0.95
        let normalized = (freq - 40.0) / (300.0 - 40.0)
        let sharpness = Float(max(0.0, min(1.0, normalized * 0.85 + 0.1)))

        return HapticPattern(events: [
            Event(
                time: time,
                intensity: intensity,
                sharpness: sharpness,
                duration: duration
            )
        ])
    }

    /// A rumbling, noisy texture. Implemented as a short continuous event with
    /// low sharpness for a "buzzing" feel.
    /// - Returns: A fixed-duration noise pattern.
    public static func noise() -> HapticPattern {
        HapticPattern(events: [
            Event(
                time: 0,
                intensity: 0.55,
                sharpness: 0.15,
                duration: 0.65
            )
        ])
    }

    // MARK: - Operators

    /// Sequences two patterns: the right-hand pattern begins after the
    /// left-hand pattern finishes.
    public static func + (lhs: HapticPattern, rhs: HapticPattern) -> HapticPattern {
        if lhs.events.isEmpty { return rhs }
        if rhs.events.isEmpty { return lhs }

        let offset = lhs.totalDuration
        let shifted = rhs.events.map { event in
            Event(
                time: event.time + offset,
                intensity: event.intensity,
                sharpness: event.sharpness,
                duration: event.duration
            )
        }

        return HapticPattern(events: lhs.events + shifted)
    }

    /// Repeats a pattern a given number of times.
    ///
    /// `pattern * 0` returns an empty pattern.
    public static func * (pattern: HapticPattern, times: Int) -> HapticPattern {
        guard times > 0 else { return HapticPattern(events: []) }
        guard times > 1 else { return pattern }

        var result = pattern
        for _ in 1..<times {
            result = result + pattern
        }
        return result
    }
}
