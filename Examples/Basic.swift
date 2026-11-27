import Foundation
import BuzzKit
import Dispatch

print("🐝 BuzzKit - Basic Example")
print("=========================")
print("Demonstrates Preset usage, custom DSL patterns using @HapticBuilder,")
print("operator overloading (+ and *), and async playback.\n")

let player = HapticPlayer()
let semaphore = DispatchSemaphore(value: 0)

Task {
    defer { semaphore.signal() }
    
    do {
        // Preset usage
        print("❤️ Playing Preset.heartbeat (realistic double-thump)")
        try await player.play(Preset.heartbeat)
        try await Task.sleep(for: .seconds(Preset.heartbeat.totalDuration + 0.6))
        
        // Custom DSL with @HapticBuilder
        print("🥁 Building custom rhythm with @HapticBuilder DSL...")
        let customRhythm = HapticPattern {
            loop(Preset.bassDrum, times: 3)
            layer(
                HapticPattern.sine(freq: 85, duration: 0.9, intensity: 0.8),
                HapticPattern.noise()
            )
            Preset.notification
        }
        print("   Pattern has \(customRhythm.events.count) events")
        try await player.play(customRhythm)
        try await Task.sleep(for: .seconds(customRhythm.totalDuration + 0.6))
        
        // Operators
        print("⚡ Composing with operators: laser * 2 + notification")
        let composed = Preset.laser * 2 + Preset.notification
        try await player.play(composed)
        try await Task.sleep(for: .seconds(composed.totalDuration + 0.8))
        
        print("\n🎉 Example finished! The Mac trackpad played all patterns.")
        print("💡 Next steps:")
        print("   • Run 'swift run haptikit live-repl'")
        print("   • Open BuzzKitDemo app")
        print("   • Explore TrackpadSine.swift for musical tones")
        
    } catch {
        print("❌ Playback error: \(error.localizedDescription)")
    }
}

semaphore.wait()
