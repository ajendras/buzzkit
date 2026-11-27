import Foundation
import BuzzKit
import Dispatch

print("🎵 BuzzKit - Trackpad as Sine Speaker")
print("====================================")
print("Uses TrackpadSpeaker to turn the haptic motor into a musical")
print("instrument. Different waveforms provide distinct timbres.\n")

let speaker = TrackpadSpeaker()
let semaphore = DispatchSemaphore(value: 0)

Task {
    defer { semaphore.signal() }
    
    // Simple melody - Twinkle Twinkle Little Star
    let melody: [(Waveform, Float, TimeInterval)] = [
        (.sine, 261.6, 0.4),   // C4
        (.sine, 261.6, 0.4),
        (.square, 392.0, 0.4), // G4
        (.square, 392.0, 0.4),
        (.triangle, 440.0, 0.4), // A4
        (.triangle, 440.0, 0.4),
        (.sine, 392.0, 0.8),    // G4 longer
        (.sawtooth, 349.2, 0.4), // F4
        (.sawtooth, 349.2, 0.4),
        (.sine, 329.6, 0.4),    // E4
        (.sine, 329.6, 0.4),
        (.triangle, 293.7, 0.4), // D4
        (.triangle, 293.7, 0.4),
        (.sine, 261.6, 1.2),    // C4 final
    ]
    
    print("🎶 Playing Twinkle Twinkle Little Star...")
    print("Waveforms: sine (smooth), square (bright/metallic),")
    print("           triangle (mellow), sawtooth (buzzing)\n")
    
    for (waveform, frequency, duration) in melody {
        print(String(format: "▶  %.1f Hz  %@  (%.1fs)", frequency, waveform.rawValue, duration))
        speaker.speak(waveform, frequency: frequency, duration: duration)
        // Sleep most of the note duration before next note (allows overlap for musicality)
        try await Task.sleep(for: .seconds(duration * 0.85))
    }
    
    print("\n🛑 Stopping speaker...")
    speaker.stop()
    
    // Demonstrate a sustained bass tone
    print("\n🔊 Playing a deep sustained bass tone (sine @ 65Hz)...")
    speaker.speak(.sine, frequency: 65, duration: 3.5)
    try await Task.sleep(for: .seconds(4.0))
    
    print("\n✅ TrackpadSine example complete.")
    print("The trackpad haptic motor can produce surprisingly musical tones!")
    print("\nTry editing the `melody` array with your own note sequences.")
}

semaphore.wait()
