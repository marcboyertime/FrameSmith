# Phase 1 acceptance

Implemented and testable: schema-versioned Codable models; exactly four
registry definitions (`native.targeted_rotate_zoom`, `look.old_television`,
`transition.natural_dissolve`, `motion.living_still`); deterministic aliases and bounded parsing; fail-closed
ambiguity handling; target finite/range policy; spatial anchor compensation;
dissolve adjacency, frame, range, handle, and revision checks; canonical path
policy; SHA-256 and source preservation; monthly cost ledger; provenance and
idempotency records; closed FFmpeg overlay generation; CLI inspection; and
source audits.

Not accepted as live: Final Cut launch, copied-app patching, private bridge
connection, library creation/opening, main-thread mutation, native effect
application, FCPXML interchange, responder/dialog fallback, model downloads,
uploads, or perceptual quality claims.

Acceptance commands are `swift test`, `swift run fcpcommandconsole doctor-core`,
`make test`, and `make overlay-smoke`. A successful core check never upgrades an
unproven Final Cut runtime capability.
