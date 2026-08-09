import XCTest
@testable import FCPCommandConsoleCore

/// Adversarial tests for the director-control contract.
///
/// Each test here *tries* to do something FrameSmith is not allowed to do to the
/// user's edit — reorder, drop, substitute, retime, slip sync, move an edit
/// point — and asserts it is refused. The contract in
/// `docs/editorial-intelligence/DIRECTOR_CONTROL_CONTRACT.md` requires this to
/// be machine-checkable rather than prompt prose, so these are the teeth.
final class EditorialStructureLockTests: XCTestCase {
    private func identity(_ name: String, digest: Character) -> SourceIdentity {
        SourceIdentity(
            itemID: name,
            canonicalPath: "/tmp/\(name).mov",
            sha256: String(repeating: digest, count: 64)
        )
    }

    private func lock(
        deltas: [AuthorizedStructuralDelta] = [],
        regions: [ProtectedRegion] = []
    ) -> EditorialStructureLock {
        EditorialStructureLock(
            clips: [
                LockedClipPlacement(sourceIdentity: identity("a", digest: "a"), index: 0, timelineStartFrame: 0, durationFrames: 90),
                LockedClipPlacement(sourceIdentity: identity("b", digest: "b"), index: 1, timelineStartFrame: 90, durationFrames: 120),
                LockedClipPlacement(sourceIdentity: identity("c", digest: "c"), index: 2, timelineStartFrame: 210, durationFrames: 60)
            ],
            protectedRegions: regions,
            authorizedDeltas: deltas
        )
    }

    private func mutate(
        _ base: EditorialStructureLock,
        _ transform: ([LockedClipPlacement]) -> [LockedClipPlacement]
    ) -> EditorialStructureLock {
        EditorialStructureLock(
            clips: transform(base.clips),
            protectedRegions: base.protectedRegions,
            narrationDigest: base.narrationDigest,
            musicStructureDigest: base.musicStructureDigest,
            authorizedDeltas: base.authorizedDeltas
        )
    }

    // MARK: - The structure is unchanged

    func testIdenticalStructurePasses() throws {
        let locked = lock()
        XCTAssertNoThrow(try locked.validate(lock()))
        XCTAssertTrue(locked.violations(comparedTo: lock()).isEmpty)
        XCTAssertEqual(locked.fingerprint, lock().fingerprint)
    }

    func testFingerprintPreservesSuppliedEditorialOrder() {
        // Input order is a director decision. It must not be silently sorted
        // into a superficially similar but different lock.
        let forward = lock()
        let reversed = EditorialStructureLock(clips: lock().clips.reversed())
        XCTAssertNotEqual(forward.fingerprint, reversed.fingerprint)
        XCTAssertTrue(reversed.violations(comparedTo: reversed).contains(.invalidClipIndices))
    }

    // MARK: - Every unauthorized structural change is refused

    func testReorderingClipsIsRefused() {
        let locked = lock()
        let reordered = mutate(locked) { clips in
            [
                LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 0, timelineStartFrame: 0, durationFrames: 120),
                LockedClipPlacement(sourceIdentity: clips[0].sourceIdentity, index: 1, timelineStartFrame: 120, durationFrames: 90),
                clips[2]
            ]
        }
        let found = locked.violations(comparedTo: reordered)
        XCTAssertTrue(found.contains { if case .clipReordered = $0 { return true }; return false })
        XCTAssertThrowsError(try locked.validate(reordered))
    }

    func testOmittingAClipIsRefused() {
        let locked = lock()
        let shortened = mutate(locked) { Array($0.prefix(2)) }
        XCTAssertEqual(locked.violations(comparedTo: shortened), [.clipCountChanged(locked: 3, candidate: 2)])
        XCTAssertThrowsError(try locked.validate(shortened))
    }

    func testDuplicatingAClipIsRefused() {
        let locked = lock()
        let padded = mutate(locked) { $0 + [$0[0]] }
        XCTAssertThrowsError(try locked.validate(padded))
    }

    /// Media the lock has never seen is a substitution, not a reorder — the
    /// distinction matters because the user gets a different sentence.
    func testSubstitutingMediaIsRefusedAsSubstitutionNotReorder() {
        let locked = lock()
        let swapped = mutate(locked) { clips in
            [
                LockedClipPlacement(sourceIdentity: self.identity("z", digest: "z"), index: 0, timelineStartFrame: 0, durationFrames: 90),
                clips[1], clips[2]
            ]
        }
        let found = locked.violations(comparedTo: swapped)
        XCTAssertTrue(found.contains { if case .mediaSubstituted = $0 { return true }; return false })
        XCTAssertFalse(found.contains { if case .clipReordered = $0 { return true }; return false })
    }

    func testChangingADurationIsRefused() {
        let locked = lock()
        let trimmed = mutate(locked) { clips in
            [clips[0], LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 1, timelineStartFrame: 90, durationFrames: 60), clips[2]]
        }
        XCTAssertTrue(locked.violations(comparedTo: trimmed).contains { if case .durationChanged = $0 { return true }; return false })
    }

    func testMovingAnEditPointIsRefused() {
        let locked = lock()
        let moved = mutate(locked) { clips in
            [clips[0], LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 1, timelineStartFrame: 100, durationFrames: 120), clips[2]]
        }
        XCTAssertTrue(locked.violations(comparedTo: moved).contains { if case .editPointMoved = $0 { return true }; return false })
    }

    /// Same timeline placement, different piece of the take. Easy to miss and
    /// exactly the kind of silent substitution the contract forbids.
    func testChangingTheSourceInPointIsRefused() {
        let locked = lock()
        let slipped = mutate(locked) { clips in
            [LockedClipPlacement(sourceIdentity: clips[0].sourceIdentity, index: 0, timelineStartFrame: 0, durationFrames: 90, sourceStartFrame: 45), clips[1], clips[2]]
        }
        XCTAssertTrue(locked.violations(comparedTo: slipped).contains { if case .sourceRangeChanged = $0 { return true }; return false })
    }

    func testRetimingIsRefused() {
        let locked = lock()
        let retimed = mutate(locked) { clips in
            [LockedClipPlacement(sourceIdentity: clips[0].sourceIdentity, index: 0, timelineStartFrame: 0, durationFrames: 90, speedMultiplier: 0.5), clips[1], clips[2]]
        }
        XCTAssertTrue(locked.violations(comparedTo: retimed).contains { if case .retimed = $0 { return true }; return false })
    }

    func testDesynchronizingAudioIsRefused() {
        let locked = lock()
        let slipped = mutate(locked) { clips in
            [clips[0], LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 1, timelineStartFrame: 90, durationFrames: 120, audioSyncOffsetFrames: 3), clips[2]]
        }
        XCTAssertTrue(locked.violations(comparedTo: slipped).contains { if case .syncChanged = $0 { return true }; return false })
    }

    func testNarrationAndMusicStructureAreProtected() {
        let withAudio = EditorialStructureLock(
            clips: lock().clips,
            narrationDigest: "narration-v1",
            musicStructureDigest: "music-v1"
        )
        let rewritten = EditorialStructureLock(
            clips: lock().clips,
            narrationDigest: "narration-v2",
            musicStructureDigest: "music-v1"
        )
        XCTAssertTrue(withAudio.violations(comparedTo: rewritten).contains(.narrationChanged))

        let restructured = EditorialStructureLock(
            clips: lock().clips,
            narrationDigest: "narration-v1",
            musicStructureDigest: "music-v2"
        )
        XCTAssertTrue(withAudio.violations(comparedTo: restructured).contains(.musicStructureChanged))
    }

    // MARK: - Reporting

    /// A user whose edit was mangled should see the whole diff at once, not
    /// rerun to discover the next problem.
    func testAllViolationsAreReportedNotJustTheFirst() {
        let locked = lock()
        let mangled = mutate(locked) { clips in
            [
                LockedClipPlacement(sourceIdentity: clips[0].sourceIdentity, index: 0, timelineStartFrame: 5, durationFrames: 45, speedMultiplier: 2),
                clips[1], clips[2]
            ]
        }
        let found = locked.violations(comparedTo: mangled)
        XCTAssertGreaterThanOrEqual(found.count, 3, "duration, edit point, and retime should all be reported")
    }

    func testDiffIsHumanReadableAndNamesTheClip() {
        let locked = lock()
        let reordered = mutate(locked) { clips in
            [
                LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 0, timelineStartFrame: 0, durationFrames: 120),
                LockedClipPlacement(sourceIdentity: clips[0].sourceIdentity, index: 1, timelineStartFrame: 120, durationFrames: 90),
                clips[2]
            ]
        }
        let diff = locked.humanReadableDiff(comparedTo: reordered)
        XCTAssertTrue(diff.contains("order"), diff)
        XCTAssertTrue(diff.contains("position 1"), diff)
        XCTAssertEqual(locked.humanReadableDiff(comparedTo: lock()), "No change to your clips, order, timing, or sync.")
    }

    // MARK: - Authorized deltas are narrow

    func testAnAuthorizedDeltaPermitsOnlyItsOwnKindAndClip() {
        let authorized = lock(deltas: [
            AuthorizedStructuralDelta(kind: .changeDuration, affectedClipIndices: [1], userRequest: "make the middle clip shorter", beforeValue: "120", afterValue: "60")
        ])
        // The authorized change on the authorized clip passes.
        let trimmed = mutate(authorized) { clips in
            [clips[0], LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 1, timelineStartFrame: 90, durationFrames: 60), clips[2]]
        }
        XCTAssertTrue(authorized.violations(comparedTo: trimmed).isEmpty)
        // And the same change without the authorization is still refused, so
        // the pass above is the delta doing work rather than a lenient compare.
        XCTAssertTrue(lock().violations(comparedTo: trimmed).contains { if case .durationChanged = $0 { return true }; return false })

        // The same change on a different clip is not covered.
        let wrongClip = mutate(authorized) { clips in
            [LockedClipPlacement(sourceIdentity: clips[0].sourceIdentity, index: 0, timelineStartFrame: 0, durationFrames: 45), clips[1], clips[2]]
        }
        XCTAssertTrue(authorized.violations(comparedTo: wrongClip).contains { if case .durationChanged = $0 { return true }; return false })

        // A different kind of change on the authorized clip is not covered.
        let wrongKind = mutate(authorized) { clips in
            [clips[0], LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 1, timelineStartFrame: 90, durationFrames: 120, speedMultiplier: 0.5), clips[2]]
        }
        XCTAssertTrue(authorized.violations(comparedTo: wrongKind).contains { if case .retimed = $0 { return true }; return false })
    }

    /// Reordering is never suppressed by a duration authorization, and media
    /// identity is checked before any delta is consulted — an authorization to
    /// trim must never become an authorization to swap footage.
    func testAuthorizationNeverExtendsToMediaIdentity() {
        let authorized = lock(deltas: [
            AuthorizedStructuralDelta(kind: .changeDuration, affectedClipIndices: [0, 1, 2], userRequest: "trim everything")
        ])
        let swapped = mutate(authorized) { clips in
            [LockedClipPlacement(sourceIdentity: self.identity("z", digest: "z"), index: 0, timelineStartFrame: 0, durationFrames: 90), clips[1], clips[2]]
        }
        XCTAssertTrue(authorized.violations(comparedTo: swapped).contains { if case .mediaSubstituted = $0 { return true }; return false })
    }

    func testExactAuthorizationRejectsAnyOtherValueAndCandidateCannotAddAuthorization() {
        let authorized = lock(deltas: [AuthorizedStructuralDelta(kind: .changeDuration, affectedClipIndices: [1], userRequest: "shorten middle", beforeValue: "120", afterValue: "60")])
        let otherDuration = mutate(authorized) { clips in [clips[0], LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 1, timelineStartFrame: 90, durationFrames: 59), clips[2]] }
        XCTAssertTrue(authorized.violations(comparedTo: otherDuration).contains { if case .durationChanged = $0 { return true }; return false })
        let candidateAuthorization = EditorialStructureLock(clips: authorized.clips, authorizedDeltas: authorized.authorizedDeltas + [AuthorizedStructuralDelta(kind: .retime, affectedClipIndices: [0], userRequest: "forged", beforeValue: "1.0", afterValue: "2.0")])
        XCTAssertTrue(authorized.violations(comparedTo: candidateAuthorization).contains(.authorizationMutated))
    }

    func testProtectedRegionRequiresComputedEvidenceAndRejectsOverTolerance() {
        let protected = EditorialStructureLock(clips: lock().clips, protectedRegions: [ProtectedRegion(identifier: "face", x: 0.2, y: 0.2, width: 0.2, height: 0.2, maximumOccludedFraction: 0.1)])
        XCTAssertTrue(protected.violations(comparedTo: protected).contains(.protectedRegionEvidenceMissing("face")))
        XCTAssertTrue(protected.violations(comparedTo: protected, impactEvidence: [.init(identifier: "face", occludedFraction: 0.2)]).contains { if case .protectedRegionLost = $0 { return true }; return false })
        XCTAssertTrue(protected.violations(comparedTo: protected, impactEvidence: [.init(identifier: "face", occludedFraction: 0.1)]).isEmpty)
    }

    func testRationalTimeOrderingIsExactAtInt64ExtremesAndNeverTrapsForUnrepresentableInputs() throws {
        XCTAssertTrue(RationalTime(Int64.max - 1, Int64.max) < RationalTime(Int64.max, Int64.max - 1))
        XCTAssertTrue(RationalTime(Int64.min + 1, Int64.max - 1) < RationalTime(-1, 1))
        XCTAssertEqual(RationalTime(2, 4), RationalTime(1, 2))
        XCTAssertEqual(RationalTime(Int64.min, -1), RationalTime(0), "a nonthrowing initializer canonicalizes an unrepresentable ratio safely")
        XCTAssertEqual(RationalTime(1, Int64.min), RationalTime(0), "a nonthrowing initializer canonicalizes an unrepresentable denominator safely")
        XCTAssertEqual(RationalTime(Int64.min, Int64.min), RationalTime(1), "the representable reduced form must survive Int64.min magnitudes")
        XCTAssertThrowsError(try JSONDecoder().decode(RationalTime.self, from: Data("{\"numerator\":1,\"denominator\":0}".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(RationalTime.self, from: Data("{\"numerator\":-9223372036854775808,\"denominator\":-1}".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(RationalTime.self, from: Data("{\"numerator\":1,\"denominator\":-9223372036854775808}".utf8)))
        XCTAssertEqual(try JSONDecoder().decode(RationalTime.self, from: Data("{\"numerator\":-9223372036854775808,\"denominator\":-9223372036854775808}".utf8)), RationalTime(1))
    }

    func testFrameCountsMustExactlyAgreeWithRationalClipTimingAndFrameDuration() {
        let base = lock()
        let badClip = LockedClipPlacement(
            sourceIdentity: base.clips[0].sourceIdentity, index: 0,
            timelineStartFrame: 0, durationFrames: 90,
            duration: RationalTime(89, 30)
        )
        let inconsistent = EditorialStructureLock(
            clips: [badClip, base.clips[1], base.clips[2]], frameRate: 30,
            frameDuration: RationalTime(1, 30)
        )
        XCTAssertTrue(inconsistent.violations(comparedTo: inconsistent).contains(.invalidTiming(index: 0)))

        let wrongFrameDuration = EditorialStructureLock(
            clips: base.clips, frameRate: 30, frameDuration: RationalTime(1, 24)
        )
        XCTAssertTrue(wrongFrameDuration.violations(comparedTo: wrongFrameDuration).contains(.invalidTiming(index: -1)))

        let ntsc = EditorialStructureLock(
            clips: [LockedClipPlacement(
                sourceIdentity: base.clips[0].sourceIdentity, index: 0,
                timelineStartFrame: 0, durationFrames: 30000
            )],
            frameRate: 30, frameDuration: RationalTime(1001, 30000)
        )
        XCTAssertFalse(ntsc.violations(comparedTo: ntsc).contains(.invalidTiming(index: -1)), "the exact 30000/1001 rate must remain representable under nominal 30 fps metadata")
    }

    func testExplicitRawFrameRationalIsNotRewrittenAsLegacyShorthand() {
        let source = identity("explicit", digest: "e")
        let explicit = LockedClipPlacement(
            sourceIdentity: source, index: 0, timelineStartFrame: 0, durationFrames: 90,
            duration: RationalTime(90, 1)
        )
        let lockWithExplicitTiming = EditorialStructureLock(
            clips: [explicit], frameRate: 30, frameDuration: RationalTime(1, 30)
        )
        XCTAssertEqual(lockWithExplicitTiming.clips[0].duration, RationalTime(90, 1))
        XCTAssertTrue(lockWithExplicitTiming.violations(comparedTo: lockWithExplicitTiming).contains(.invalidTiming(index: 0)))

        let unspecified = LockedClipPlacement(
            sourceIdentity: source, index: 0, timelineStartFrame: 0, durationFrames: 90
        )
        let lockWithLegacyFields = EditorialStructureLock(
            clips: [unspecified], frameRate: 30, frameDuration: RationalTime(1, 30)
        )
        XCTAssertEqual(lockWithLegacyFields.clips[0].duration, RationalTime(3, 1))
        XCTAssertFalse(lockWithLegacyFields.violations(comparedTo: lockWithLegacyFields).contains(.invalidTiming(index: 0)))
    }

    func testExactRationalAuthorizationAllowsOnlyTheNamedTimingValue() {
        let original = lock()
        let exact = AuthorizedStructuralDelta(kind: .changeDuration, affectedClipIndices: [1], userRequest: "exact rational trim", beforeValue: "120", afterValue: "60")
        let authorized = EditorialStructureLock(clips: original.clips, authorizedDeltas: [exact])
        let accepted = mutate(authorized) { clips in [clips[0], LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 1, timelineStartFrame: 90, durationFrames: 60), clips[2]] }
        XCTAssertTrue(authorized.violations(comparedTo: accepted).isEmpty)
        let adjacent = mutate(authorized) { clips in [clips[0], LockedClipPlacement(sourceIdentity: clips[1].sourceIdentity, index: 1, timelineStartFrame: 90, durationFrames: 61), clips[2]] }
        XCTAssertTrue(authorized.violations(comparedTo: adjacent).contains { if case .durationChanged = $0 { return true }; return false })
    }

    // MARK: - Fingerprints

    func testFingerprintChangesWithEveryProtectedField() {
        let base = lock()
        let variants: [EditorialStructureLock] = [
            mutate(base) { c in [LockedClipPlacement(sourceIdentity: c[0].sourceIdentity, index: 0, timelineStartFrame: 1, durationFrames: 90), c[1], c[2]] },
            mutate(base) { c in [LockedClipPlacement(sourceIdentity: c[0].sourceIdentity, index: 0, timelineStartFrame: 0, durationFrames: 91), c[1], c[2]] },
            mutate(base) { c in [LockedClipPlacement(sourceIdentity: c[0].sourceIdentity, index: 0, timelineStartFrame: 0, durationFrames: 90, sourceStartFrame: 1), c[1], c[2]] },
            mutate(base) { c in [LockedClipPlacement(sourceIdentity: c[0].sourceIdentity, index: 0, timelineStartFrame: 0, durationFrames: 90, speedMultiplier: 1.5), c[1], c[2]] },
            mutate(base) { c in [LockedClipPlacement(sourceIdentity: c[0].sourceIdentity, index: 0, timelineStartFrame: 0, durationFrames: 90, audioSyncOffsetFrames: 1), c[1], c[2]] },
            EditorialStructureLock(clips: base.clips, narrationDigest: "n"),
            EditorialStructureLock(clips: base.clips, musicStructureDigest: "m")
        ]
        for variant in variants {
            XCTAssertNotEqual(base.fingerprint, variant.fingerprint, "a protected field did not affect the fingerprint")
        }
    }

    func testFingerprintValidationRefusesAStaleClaim() {
        let locked = lock()
        XCTAssertNoThrow(try locked.validateFingerprint(locked.fingerprint))
        XCTAssertThrowsError(try locked.validateFingerprint("not-the-fingerprint")) { error in
            guard case EditorialStructureViolation.fingerprintMismatch = error else {
                return XCTFail("expected a fingerprint mismatch, got \(error)")
            }
        }
    }

    // MARK: - Establishing from admitted media

    func testEstablishPreservesSuppliedOrderAndButtJoinsClips() {
        let assets = ["first", "second", "third"].enumerated().map { index, name in
            LocalMediaAsset(
                itemID: name,
                url: URL(fileURLWithPath: "/tmp/\(name).png"),
                kind: .still,
                dimensions: LocalMediaDimensions(width: 1920, height: 1080),
                durationSeconds: nil, frameRate: nil, hasAudio: false,
                canonicalPath: "/tmp/\(name).png",
                sha256: String(repeating: Character(UnicodeScalar(97 + index)!), count: 64)
            )
        }
        let established = EditorialStructureLock.establish(
            orderedMedia: assets,
            clipDurationFrames: [30, 60, 90]
        )
        XCTAssertEqual(established.clips.map(\.sourceIdentity.itemID), ["first", "second", "third"])
        XCTAssertEqual(established.clips.map(\.timelineStartFrame), [0, 30, 90])
        XCTAssertEqual(established.clips.map(\.timelineEndFrame), [30, 90, 180])
        XCTAssertTrue(established.authorizedDeltas.isEmpty, "structural change must never be authorized by default")
    }
}
