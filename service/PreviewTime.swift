import Foundation

/// Keeps a preview sampling instant inside the duration of its current emitted
/// channels.  Channel replacement can shorten an effect while SwiftUI retains
/// view state, so this must be a shared pure rule rather than slider behavior.
public enum PreviewTime {
    public static func clamped(_ time: Double, duration: Double) -> Double {
        guard duration.isFinite, duration > 0, time.isFinite else { return 0 }
        return min(max(time, 0), duration)
    }
}
