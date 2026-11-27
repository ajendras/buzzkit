import ArgumentParser
import BuzzKit
import Dispatch
import Foundation

@main
struct Haptikit: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "haptikit",
        abstract: "Turn your Mac trackpad into a programmable speaker and instrument.",
        version: "1.0.0",
        subcommands: [Play.self, Convert.self, ListPresets.self, LiveRepl.self],
        defaultSubcommand: Play.self
    )
}

struct Play: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Play a preset or a saved haptic pattern file."
    )

    @Argument(help: "Preset name (heartbeat, laser, notification, bassDrum)")
    var preset: String?

    @Option(name: [.customShort("f"), .long], help: "Path to a JSON file containing a HapticPattern")
    var file: String?

    func run() throws {
        let pattern: HapticPattern

        if let filePath = file {
            let url = URL(fileURLWithPath: filePath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ValidationError("File not found: \(filePath)")
            }
            let data = try Data(contentsOf: url)
            pattern = try JSONDecoder().decode(HapticPattern.self, from: data)
            print("Loaded pattern from \(filePath) (\(pattern.events.count) events)")
        } else if let presetName = preset {
            pattern = try Self.pattern(for: presetName)
            print("Playing preset: \(presetName)")
        } else {
            throw ValidationError("Either --preset or --file must be provided. See --help.")
        }

        let player = HapticPlayer()
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            defer { semaphore.signal() }
            do {
                try await player.play(pattern)
                // Keep process alive until pattern completes
                try await Task.sleep(for: .seconds(pattern.totalDuration + 0.6))
            } catch {
                print("Playback error: \(error.localizedDescription)")
            }
        }

        semaphore.wait()
    }

    private static func pattern(for name: String) throws -> HapticPattern {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch key {
        case "heartbeat":
            return Preset.heartbeat
        case "laser":
            return Preset.laser
        case "notification":
            return Preset.notification
        case "bassdrum", "bass", "drum":
            return Preset.bassDrum
        default:
            throw ValidationError("Unknown preset '\(name)'. Run 'haptikit list-presets' to see options.")
        }
    }
}

struct Convert: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Convert a short audio file (WAV) into a haptic pattern JSON."
    )

    @Argument(help: "Input audio file path")
    var input: String

    @Option(name: [.customShort("o"), .long], help: "Output JSON path (prints to stdout if omitted)")
    var output: String?

    func run() throws {
        let inputURL = URL(fileURLWithPath: input)
        let pattern = try convertAudio(url: inputURL, maxEvents: 90)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(pattern)

        if let outputPath = output {
            let outputURL = URL(fileURLWithPath: outputPath)
            try data.write(to: outputURL)
            print("✅ Converted and saved to \(outputPath)")
            print("   Duration: \(String(format: "%.2f", pattern.totalDuration))s • \(pattern.events.count) events")
        } else {
            if let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        }
    }
}

struct ListPresets: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-presets",
        abstract: "List all built-in haptic presets."
    )

    func run() {
        print("🎨 BuzzKit Preset Library")
        print("────────────────────────")
        print("  ❤️  heartbeat     – realistic double-beat rhythm")
        print("  ⚡ laser         – rising sci-fi energy sweep")
        print("  🛎 notification  – gentle triple alert pulse")
        print("  🥁 bassDrum      – deep low-frequency thump")
        print("\nUsage example: haptikit play heartbeat")
    }
}

struct LiveRepl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "live-repl",
        abstract: "Interactive REPL for live haptic experimentation."
    )

    func run() {
        print("🎤 BuzzKit Live REPL")
        print("Type a preset name (heartbeat, laser, notification, bassDrum) or 'help' / 'exit'.")
        print("────────────────────────────────────────────────────────────")

        let player = HapticPlayer()
        let presets = ["heartbeat", "laser", "notification", "bassdrum", "bass", "drum"]

        while true {
            print("▶️ ", terminator: "")
            guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { break }
            if line.isEmpty { continue }

            if line == "exit" || line == "quit" {
                print("👋 Goodbye!")
                break
            }

            if line == "help" || line == "list" {
                ListPresets().run()
                continue
            }

            let normalized = line.lowercased()
            if presets.contains(where: { $0.hasPrefix(normalized) || normalized.hasPrefix($0) }) {
                Task {
                    do {
                        let pattern = try Play.pattern(for: line)
                        print("▶ Playing \(line)...")
                        try await player.play(pattern)
                    } catch {
                        print("⚠️  \(error.localizedDescription)")
                    }
                }
            } else {
                print("❓ Unknown command or preset. Try 'help'.")
            }
        }
    }
}
