import XCTest
@testable import BuzzKit

final class PatternCompositionTests: XCTestCase {

    func testPulseFactory() {
        let pulse = HapticPattern.pulse(intensity: 0.8, at: 0.1)
        XCTAssertEqual(pulse.events.count, 1)
        let event = pulse.events[0]
        XCTAssertEqual(event.time, 0.1, accuracy: 0.001)
        XCTAssertEqual(event.intensity, 0.8, accuracy: 0.001)
        XCTAssertEqual(event.sharpness, 0.75, accuracy: 0.001)
        XCTAssertEqual(event.duration, 0.0, accuracy: 0.001)
        XCTAssertEqual(pulse.totalDuration, 0.0, accuracy: 0.001)
    }

    func testSineFactory() {
        let sine = HapticPattern.sine(freq: 200, duration: 0.5, intensity: 0.6, at: 0.2)
        XCTAssertEqual(sine.events.count, 1)
        let event = sine.events[0]
        XCTAssertEqual(event.time, 0.2, accuracy: 0.001)
        XCTAssertEqual(event.intensity, 0.6, accuracy: 0.001)
        XCTAssertEqual(event.duration, 0.5, accuracy: 0.001)

        // Frequency-to-sharpness mapping: (200-40)/(300-40) = 0.6154 → 0.6154*0.85+0.1 ≈ 0.623
        XCTAssertEqual(event.sharpness, 0.623, accuracy: 0.01)
        XCTAssertEqual(sine.totalDuration, 0.7, accuracy: 0.001)
    }

    func testNoiseFactory() {
        let noise = HapticPattern.noise()
        XCTAssertEqual(noise.events.count, 1)
        let event = noise.events[0]
        XCTAssertEqual(event.intensity, 0.55, accuracy: 0.001)
        XCTAssertEqual(event.sharpness, 0.15, accuracy: 0.001)
        XCTAssertEqual(event.duration, 0.65, accuracy: 0.001)
        XCTAssertEqual(noise.totalDuration, 0.65, accuracy: 0.001)
    }

    func testSequenceOperator() {
        let p1 = HapticPattern.sine(freq: 100, duration: 0.3)
        let p2 = HapticPattern.pulse(intensity: 0.9, at: 0.1)
        let sequenced = p1 + p2

        XCTAssertEqual(sequenced.events.count, 2)
        XCTAssertEqual(sequenced.events[0].time, 0.0, accuracy: 0.001)
        XCTAssertEqual(sequenced.events[1].time, 0.3 + 0.1, accuracy: 0.001)
        XCTAssertEqual(sequenced.totalDuration, 0.3 + 0.1, accuracy: 0.001)
    }

    func testRepeatOperator() {
        let base = HapticPattern.sine(freq: 120, duration: 0.25, intensity: 0.7)
        let repeated3 = base * 3

        XCTAssertEqual(repeated3.events.count, 3)
        XCTAssertEqual(repeated3.events[0].time, 0.0, accuracy: 0.001)
        XCTAssertEqual(repeated3.events[1].time, 0.25, accuracy: 0.001)
        XCTAssertEqual(repeated3.events[2].time, 0.5, accuracy: 0.001)
        XCTAssertEqual(repeated3.totalDuration, 0.75, accuracy: 0.001)

        let repeated0 = base * 0
        XCTAssertTrue(repeated0.events.isEmpty)
        XCTAssertEqual(repeated0.totalDuration, 0.0, accuracy: 0.001)

        let repeated1 = base * 1
        XCTAssertEqual(repeated1, base)
    }

    func testLayerCombinesEventsWithOriginalTiming() {
        let p1 = HapticPattern.sine(freq: 80, duration: 0.6, at: 0.0)
        let p2 = HapticPattern.pulse(intensity: 1.0, at: 0.2)

        let layered = layer(p1, p2)
        XCTAssertEqual(layered.events.count, 2)
        XCTAssertEqual(layered.events[0].time, 0.0, accuracy: 0.001)
        XCTAssertEqual(layered.events[1].time, 0.2, accuracy: 0.001)
        XCTAssertEqual(layered.totalDuration, 0.6, accuracy: 0.001)
    }

    func testHapticBuilderDSL() {
        let pattern = HapticPattern {
            HapticPattern.pulse(intensity: 0.9, at: 0.0)
            loop(HapticPattern.sine(freq: 180, duration: 0.15), times: 2)
            layer(
                HapticPattern.pulse(intensity: 0.6, at: 0.6),
                HapticPattern.noise()
            )
        }

        // Builder produces a sequenced result; total events = 1 (pulse) + 2 (looped sine) + 2 (layer) = 5
        XCTAssertEqual(pattern.events.count, 5)
        XCTAssertGreaterThan(pattern.totalDuration, 0.6)
    }

    func testEventsAreAlwaysSortedByTime() {
        let unsortedEvents = [
            HapticPattern.Event(time: 0.5, intensity: 0.5),
            HapticPattern.Event(time: 0.1, intensity: 0.8),
            HapticPattern.Event(time: 0.3, intensity: 0.6)
        ]
        let pattern = HapticPattern(events: unsortedEvents)

        XCTAssertEqual(pattern.events[0].time, 0.1, accuracy: 0.001)
        XCTAssertEqual(pattern.events[1].time, 0.3, accuracy: 0.001)
        XCTAssertEqual(pattern.events[2].time, 0.5, accuracy: 0.001)
    }

    func testCodableRoundtrip() throws {
        let original = Preset.heartbeat * 2 + Preset.laser
        XCTAssertFalse(original.events.isEmpty)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HapticPattern.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.events.count, decoded.events.count)
        XCTAssertEqual(original.totalDuration, decoded.totalDuration, accuracy: 0.001)
    }

    func testEmptyPatternHandling() {
        let empty = HapticPattern(events: [])
        XCTAssertTrue(empty.events.isEmpty)
        XCTAssertEqual(empty.totalDuration, 0.0)

        let alsoEmpty = empty + empty
        XCTAssertTrue(alsoEmpty.events.isEmpty)

        let sequencedWithEmpty = sequence(HapticPattern.pulse(), empty, HapticPattern.noise())
        XCTAssertEqual(sequencedWithEmpty.events.count, 2)
    }
}
