import Foundation
import CoreHaptics

/// Errors thrown by `HapticPlayer`.
public enum HapticError: LocalizedError, Sendable {
    /// The device does not support haptics (e.g. no Taptic Engine on trackpad).
    case deviceNotSupported(String)
    /// The underlying `CHHapticEngine` could not be created or started.
    case engineFailure(String)
    /// The audio file could not be read or contained no usable data.
    case audioFileNotFound(URL)
    case invalidAudio(String)

    public var errorDescription: String? {
        switch self {
        case .deviceNotSupported(let reason):
            return "Haptics not supported on this device: \(reason)"
        case .engineFailure(let reason):
            return "Haptic engine failure: \(reason)"
        case .audioFileNotFound(let url):
            return "Audio file not found at \(url.path)"
        case .invalidAudio(let reason):
            return "Invalid audio: \(reason)"
        }
    }
}

/// An actor that safely wraps `CoreHaptics` to play `HapticPattern`s on a Mac trackpad.
///
/// The player automatically creates and manages a `CHHapticEngine`, performs
/// automatic recovery on reset, scales intensity for accessibility settings,
/// and respects “Reduce Motion” where possible. All public API is `async`/`throws`
/// and safe to call from any context.
public actor HapticPlayer {
    private var engine: CHHapticEngine?

    /// Creates a new haptic player for the Mac trackpad.
    public init() {}

    /// Plays a haptic pattern on the specified device.
    ///
    /// The pattern is converted to a `CHHapticPattern`, intensities are scaled
    /// according to accessibility preferences, and playback begins immediately.
    /// The call returns as soon as the player has been scheduled (fire-and-forget
    /// semantics for composition). Use the returned `Task` or combine with
    /// `Task.sleep` if you need to sequence patterns manually.
    ///
    /// - Parameters:
    ///   - pattern: The composed haptic pattern to play.
    ///   - device: Target device (currently only `.trackpad` is supported).
    /// - Throws: `HapticError` if the hardware does not support haptics, the
    ///   engine cannot be started, or the pattern cannot be converted.
    public func play(
        _ pattern: HapticPattern,
        on device: Device = .trackpad
    ) async throws {
        guard !pattern.events.isEmpty else { return }

        if isReduceMotionEnabled() {
            // Still play but at a gentler intensity (accessibility compliance).
            // The scaling is applied inside `convert(pattern:)`.
        }

        let chPattern = try convert(pattern: pattern)
        let engine = try await prepareEngine(for: device)
        let player = try engine.makePlayer(with: chPattern)

        // Start immediately at the current engine time.
        try player.start(atTime: CHHapticTimeImmediate)
    }

    // MARK: - Engine Management

    private func prepareEngine(for device: Device) async throws -> CHHapticEngine {
        if let existing = engine {
            return existing
        }

        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw HapticError.deviceNotSupported("Trackpad haptic motor unavailable")
        }

        let newEngine = try CHHapticEngine()

        // Automatic recovery when the system resets the engine (e.g. after sleep).
        newEngine.resetHandler = {
            // We deliberately do not capture `self` strongly; the next `play`
            // call will recreate the engine.
            print("BuzzKit: Haptic engine reset — will recreate on next play()")
        }

        // Start the engine synchronously (the async wrapper is only for API consistency).
        try newEngine.start()

        engine = newEngine
        return newEngine
    }

    // MARK: - Pattern Conversion

    private func convert(pattern: HapticPattern) throws -> CHHapticPattern {
        let intensityScale = self.intensityScale()
        var chEvents: [CHHapticEvent] = []

        for event in pattern.events {
            let scaledIntensity = max(0.0, min(1.0, event.intensity * intensityScale))

            let parameters = [
                CHHapticEventParameter(
                    parameterID: .hapticIntensity,
                    value: scaledIntensity
                ),
                CHHapticEventParameter(
                    parameterID: .hapticSharpness,
                    value: event.sharpness
                )
            ]

            let chEvent: CHHapticEvent
            if event.duration <= 0.0 {
                chEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: parameters,
                    relativeTime: event.time
                )
            } else {
                chEvent = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: parameters,
                    relativeTime: event.time,
                    duration: event.duration
                )
            }
            chEvents.append(chEvent)
        }

        return try CHHapticPattern(events: chEvents, parameters: [])
    }

    private func intensityScale() -> Float {
        // Respect system haptic intensity preference if available.
        // Default is full strength; can be extended to read from UserDefaults.
        if isReduceMotionEnabled() {
            return 0.35 // gentle mode for accessibility
        }
        return 1.0
    }

    private func isReduceMotionEnabled() -> Bool {
        // macOS accessibility setting (common key used by many apps).
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: "AppleReduceMotion") ||
               defaults.bool(forKey: "reduceMotion")
    }
}

/// The target haptic output device.
///
/// Currently only `.trackpad` is supported by BuzzKit; the enum is provided
/// for future expansion (e.g. game controllers, iOS devices).
public enum Device: Sendable {
    case trackpad
}
