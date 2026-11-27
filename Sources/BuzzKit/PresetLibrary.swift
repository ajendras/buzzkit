import Foundation

/// Curated collection of ready-to-use haptic patterns.
///
/// These presets showcase the DSL, provide instant gratification for
/// musicians and tinkerers, and serve as starting points for custom compositions.
/// All patterns are fully Codable and respect accessibility intensity scaling.
public enum Preset {
    /// Realistic double-thump heartbeat (lub-dub) with natural spacing.
    public static let heartbeat: HapticPattern = HapticPattern(events: [
        HapticPattern.Event(time: 0.00, intensity: 0.95, sharpness: 0.82, duration: 0.0),
        HapticPattern.Event(time: 0.22, intensity: 0.68, sharpness: 0.48, duration: 0.0),
        HapticPattern.Event(time: 1.05, intensity: 0.92, sharpness: 0.80, duration: 0.0),
        HapticPattern.Event(time: 1.27, intensity: 0.65, sharpness: 0.45, duration: 0.0),
        HapticPattern.Event(time: 2.10, intensity: 0.88, sharpness: 0.78, duration: 0.0),
        HapticPattern.Event(time: 2.32, intensity: 0.60, sharpness: 0.42, duration: 0.0)
    ])

    /// Sci-fi laser sweep with rising intensity and sharpness.
    public static let laser: HapticPattern = {
        let events = (0...9).map { i in
            let progress = Float(i) / 9.0
            return HapticPattern.Event(
                time: Double(i) * 0.065,
                intensity: 0.25 + progress * 0.75,
                sharpness: 0.55 + progress * 0.45,
                duration: 0.09
            )
        }
        return HapticPattern(events: events)
    }()

    /// Gentle triple-pulse notification family (think macOS banner).
    public static let notification: HapticPattern = HapticPattern(events: [
        HapticPattern.Event(time: 0.00, intensity: 0.65, sharpness: 0.65, duration: 0.0),
        HapticPattern.Event(time: 0.18, intensity: 0.75, sharpness: 0.70, duration: 0.0),
        HapticPattern.Event(time: 0.55, intensity: 0.90, sharpness: 0.80, duration: 0.0)
    ])

    /// Deep bass drum hit — low-frequency, high-intensity continuous thump.
    public static let bassDrum: HapticPattern = HapticPattern.sine(
        freq: 48,
        duration: 0.42,
        intensity: 0.92,
        at: 0.0
    )
}
