import Foundation

/// Pure generation coordinator for the app's rendered-preview and Final Cut
/// project-export tasks.
///
/// The workers themselves are deliberately not stored here. This value only
/// decides whether a completion still owns the current UI, and how a durable
/// package returned by an invalidated worker must be classified. Keeping that
/// decision deterministic makes the app's cancellation races testable without
/// launching SwiftUI or writing an export package.
public struct ProjectExportGenerationState: Sendable {
    public enum ProjectCompletionDisposition: Equatable, Sendable {
        /// The completion still owns the export slot. A current notice may be
        /// replaced only when it has not changed since the export began.
        case current(mayReplaceCurrentNotice: Bool)

        /// The completion no longer owns the export slot. A package that was
        /// already published remains a real artifact, but is retained only in
        /// the bounded stale-artifact history and must never replace current
        /// notice or readiness state.
        case stale(retainArtifact: Bool, evictOldestCount: Int)
    }

    private struct ActiveProjectExport: Sendable {
        let generation: UUID
        let noticeAtStart: String?
    }

    public let staleArtifactLimit: Int
    public private(set) var staleArtifactCount = 0
    public private(set) var activeRenderedPreviewGeneration: UUID?
    public private(set) var activeProjectExportGeneration: UUID?

    private var activeProjectExport: ActiveProjectExport? {
        didSet { activeProjectExportGeneration = activeProjectExport?.generation }
    }

    public init(staleArtifactLimit: Int = 8) {
        precondition(staleArtifactLimit >= 0, "stale artifact limit must not be negative")
        self.staleArtifactLimit = staleArtifactLimit
    }

    /// Replaces any older preview generation. A late completion from the old
    /// worker will consequently fail `completeRenderedPreview`.
    @discardableResult
    public mutating func beginRenderedPreview(generation: UUID = UUID()) -> UUID {
        activeRenderedPreviewGeneration = generation
        return generation
    }

    /// Returns `true` only for the completion that still owns the preview slot.
    /// Consuming the slot before the caller publishes prevents a duplicate or
    /// late callback from republishing the same preview.
    public mutating func completeRenderedPreview(generation: UUID) -> Bool {
        guard activeRenderedPreviewGeneration == generation else { return false }
        activeRenderedPreviewGeneration = nil
        return true
    }

    /// Begins a project export and snapshots the current notice. If another
    /// current operation publishes a newer notice while the export is running,
    /// the export may still publish its package but must preserve that notice.
    @discardableResult
    public mutating func beginProjectExport(
        generation: UUID = UUID(),
        currentNotice: String?
    ) -> UUID {
        activeProjectExport = ActiveProjectExport(
            generation: generation,
            noticeAtStart: currentNotice
        )
        return generation
    }

    /// Input/plan drift cancels ownership immediately. Synchronous workers may
    /// still return after their atomic publish point; `completeProjectExport`
    /// will classify any such package as stale.
    public mutating func cancelForInputDrift() {
        activeRenderedPreviewGeneration = nil
        activeProjectExport = nil
    }

    /// Invalidates only project-export ownership, used when the prepared
    /// rendered bytes are cleared without needing a new preview generation.
    public mutating func invalidateProjectExport() {
        activeProjectExport = nil
    }

    /// Classifies a completion without performing UI or filesystem work.
    ///
    /// - Parameters:
    ///   - currentNotice: The notice visible at completion time.
    ///   - producedArtifact: Whether the worker crossed its durable publish
    ///     point and returned a package that must be retained as stale.
    public mutating func completeProjectExport(
        generation: UUID,
        currentNotice: String?,
        producedArtifact: Bool
    ) -> ProjectCompletionDisposition {
        guard let active = activeProjectExport,
              active.generation == generation else {
            guard producedArtifact else {
                return .stale(retainArtifact: false, evictOldestCount: 0)
            }
            let uncappedCount = staleArtifactCount + 1
            let evictOldestCount = max(0, uncappedCount - staleArtifactLimit)
            staleArtifactCount = min(uncappedCount, staleArtifactLimit)
            return .stale(
                retainArtifact: true,
                evictOldestCount: evictOldestCount
            )
        }

        activeProjectExport = nil
        return .current(mayReplaceCurrentNotice: currentNotice == active.noticeAtStart)
    }
}
