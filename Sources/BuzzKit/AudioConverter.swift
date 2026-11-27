import Foundation
import AVFoundation

/// Waveform shapes supported when generating synthetic test audio or when
/// mapping audio characteristics to haptic sharpness.
public enum Waveform: String, CaseIterable, Codable, Sendable {
    case sine
    case square
    case triangle
    case sawtooth
}

/// Converts a short audio file (WAV recommended) into a `HapticPattern` by
/// sampling its amplitude envelope and turning each window into a short
/// continuous haptic event.
///
/// The resulting pattern respects `maxEvents` to stay within CoreHaptics
/// performance limits. Intended for tones, clicks, and simple sound effects.
public func convertAudio(url: URL, maxEvents: Int = 120) throws -> HapticPattern {
    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
        throw HapticError.audioFileNotFound(url)
    }

    let audioFile = try AVAudioFile(forReading: url)
    let format = audioFile.processingFormat
    let frameCount = AVAudioFrameCount(audioFile.length)

    guard frameCount > 0 else {
        throw HapticError.invalidAudio("Audio file contains no frames")
    }

    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    try audioFile.read(into: buffer)

    guard let channelData = buffer.floatChannelData?[0] else {
        throw HapticError.invalidAudio("No float channel data available")
    }

    let samples = UnsafeBufferPointer(start: channelData, count: Int(frameCount))
    let duration = Double(frameCount) / format.sampleRate

    // Target a haptic update rate that feels continuous but stays under the limit.
    let targetEvents = min(maxEvents, 110)
    let strideSamples = max(1, samples.count / targetEvents)
    let timeStep = duration / Double(targetEvents)

    var events: [HapticPattern.Event] = []

    for i in 0..<targetEvents {
        let start = i * strideSamples
        guard start < samples.count else { break }

        let windowSize = min(24, strideSamples)
        var sum: Float = 0.0
        for j in 0..<windowSize {
            if start + j < samples.count {
                sum += abs(samples[start + j])
            }
        }
        let rms = sum / Float(windowSize)

        // Scale RMS (audio range ≈ 0…1) into a pleasant haptic intensity.
        let intensity = max(0.05, min(1.0, rms * 2.8))

        let time = Double(i) * timeStep

        // Most tones map best to a mid-high sharpness; waveform-specific
        // adjustments are performed by TrackpadSpeaker when used directly.
        let event = HapticPattern.Event(
            time: time,
            intensity: intensity,
            sharpness: 0.65,
            duration: timeStep * 1.35 // slight overlap for smooth vibration
        )
        events.append(event)
    }

    guard !events.isEmpty else {
        throw HapticError.invalidAudio("Could not generate any haptic events from the file")
    }

    return HapticPattern(events: events)
}
