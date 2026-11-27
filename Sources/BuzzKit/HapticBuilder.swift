import Foundation

/// A result builder that enables a clean, declarative DSL for composing
/// `HapticPattern`s.
///
/// Use it with the `HapticPattern` initializer or with the free functions
/// `sequence`, `layer`, and `loop`.
@resultBuilder
public struct HapticBuilder {
    public static func buildBlock(_ components: HapticPattern...) -> HapticPattern {
        sequence(components)
    }

    public static func buildArray(_ components: [HapticPattern]) -> HapticPattern {
        sequence(components)
    }

    public static func buildOptional(_ component: HapticPattern?) -> HapticPattern {
        component ?? HapticPattern(events: [])
    }

    public static func buildEither(first component: HapticPattern) -> HapticPattern {
        component
    }

    public static func buildEither(second component: HapticPattern) -> HapticPattern {
        component
    }

    public static func buildLimitedAvailability(_ component: HapticPattern) -> HapticPattern {
        component
    }
}

/// Repeats a haptic pattern a given number of times.
///
/// This is the primary way to create loops inside a `@HapticBuilder` closure.
/// - Parameters:
///   - pattern: The pattern to repeat.
///   - times: Number of repetitions (must be ≥ 0).
/// - Returns: A new pattern that repeats the original.
public func loop(_ pattern: HapticPattern, times: Int) -> HapticPattern {
    pattern * times
}

/// Combines an array of patterns into one sequential pattern (one after another).
///
/// Used by the result builder's `buildBlock` and `buildArray`.
public func sequence(_ patterns: [HapticPattern]) -> HapticPattern {
    patterns.reduce(HapticPattern(events: [])) { $0 + $1 }
}

/// Combines an array of patterns into one sequential pattern (variadic overload).
public func sequence(_ patterns: HapticPattern...) -> HapticPattern {
    sequence(patterns)
}

/// Layers multiple patterns so they play simultaneously, merging all events
/// while preserving each pattern’s internal timing.
///
/// The resulting pattern’s `totalDuration` will be the longest of the inputs.
public func layer(_ patterns: HapticPattern...) -> HapticPattern {
    let mergedEvents = patterns.flatMap(\.events)
    return HapticPattern(events: mergedEvents)
}
