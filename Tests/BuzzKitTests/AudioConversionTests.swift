import XCTest
import AVFoundation
@testable import BuzzKit

final class AudioConversionTests: XCTestCase {

    private func createTestAudioFile(
        waveform: Waveform,
        frequency: Float,
        duration: TimeInterval,
        sampleRate: Double = 44100.0
    ) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw HapticError.invalidAudio("Failed to create PCM buffer")
        }
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        let twoPi = 2 * Float.pi

        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            let base = sin(twoPi * frequency * t)

            switch waveform {
            case .sine:
                samples[i] = base
            case .square:
                samples[i] = base >= 0 ? 1.0 : -1.0
            case .triangle:
                samples[i] = 2 * abs(2 * (t * frequency - floor(t * frequency + 0.5))) - 1
            case .sawtooth:
                samples[i] = 2 * (t * frequency - floor(t * frequency)) - 1
            }
        }

        let audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try audioFile.write(from: buffer)

        return tempURL
    }

    func testConvertSineWaveProducesValidPattern() throws {
        let audioURL = try createTestAudioFile(
            waveform: .sine,
            frequency: 220,
            duration: 0.8
        )
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let pattern = try convertAudio(url: audioURL, maxEvents: 48)

        XCTAssertEqual(pattern.events.count, 48, "Should respect maxEvents target")
        XCTAssertGreaterThan(pattern.totalDuration, 0.75)
        XCTAssertLessThan(pattern.totalDuration, 1.0)

        var totalIntensity: Float = 0
        for event in pattern.events {
            XCTAssertGreaterThanOrEqual(event.intensity, 0.05)
            XCTAssertLessThanOrEqual(event.intensity, 1.0)
            XCTAssertGreaterThanOrEqual(event.sharpness, 0.0)
            XCTAssertLessThanOrEqual(event.sharpness, 1.0)
            totalIntensity += event.intensity
        }

        let avgIntensity = totalIntensity / Float(pattern.events.count)
        XCTAssertGreaterThan(avgIntensity, 0.2, "Sine wave should produce reasonable average intensity")
    }

    func testConvertSquareWaveProducesHigherIntensityThanSine() throws {
        let sineURL = try createTestAudioFile(waveform: .sine, frequency: 180, duration: 0.6)
        let squareURL = try createTestAudioFile(waveform: .square, frequency: 180, duration: 0.6)
        defer {
            try? FileManager.default.removeItem(at: sineURL)
            try? FileManager.default.removeItem(at: squareURL)
        }

        let sinePattern = try convertAudio(url: sineURL, maxEvents: 40)
        let squarePattern = try convertAudio(url: squareURL, maxEvents: 40)

        XCTAssertEqual(sinePattern.events.count, 40)
        XCTAssertEqual(squarePattern.events.count, 40)

        let sineAvg = sinePattern.events.reduce(0.0) { $0 + Double($1.intensity) } / Double(sinePattern.events.count)
        let squareAvg = squarePattern.events.reduce(0.0) { $0 + Double($1.intensity) } / Double(squarePattern.events.count)

        XCTAssertGreaterThan(squareAvg, sineAvg, "Square wave should yield higher average intensity due to higher RMS")
    }

    func testConvertThrowsOnMissingFile() {
        let missingURL = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).wav")

        XCTAssertThrowsError(try convertAudio(url: missingURL)) { error in
            guard let hapticError = error as? HapticError else {
                XCTFail("Expected HapticError, got \(type(of: error))")
                return
            }
            if case .audioFileNotFound = hapticError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected .audioFileNotFound, got \(hapticError)")
            }
        }
    }

    func testConvertThrowsOnEmptyAudio() throws {
        let emptyURL = try createTestAudioFile(waveform: .sine, frequency: 100, duration: 0.0)
        defer { try? FileManager.default.removeItem(at: emptyURL) }

        XCTAssertThrowsError(try convertAudio(url: emptyURL)) { error in
            guard let hapticError = error as? HapticError else {
                XCTFail("Expected HapticError")
                return
            }
            if case .invalidAudio = hapticError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected .invalidAudio error")
            }
        }
    }

    func testPatternFromConvertedAudioIsPlayable() throws {
        let audioURL = try createTestAudioFile(waveform: .sine, frequency: 150, duration: 1.2)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let pattern = try convertAudio(url: audioURL, maxEvents: 70)

        let player = HapticPlayer()
        XCTAssertNoThrow(try await player.play(pattern), "Converted pattern should be playable without error")
    }
}
