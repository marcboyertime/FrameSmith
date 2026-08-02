#import <Foundation/Foundation.h>
#import "FCPCommandConsoleRuntime.h"

static int require(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "MutationStubTests: %s\n", message.UTF8String);
        return 1;
    }
    return 0;
}

int main(void) {
    @autoreleasepool {
        NSArray<NSString *> *expectedIdentifiers = @[
            @"native.targeted_rotate_zoom",
            @"look.old_television",
            @"transition.natural_dissolve",
            @"motion.living_still",
        ];
        for (NSUInteger index = 0; index < expectedIdentifiers.count; index += 1) {
            if (require([FCPCCEffectIdentifierForKind((FCPCCEffectKind)index) isEqualToString:expectedIdentifiers[index]], @"effect identifier mismatch")) {
                return 1;
            }
        }

        NSString *canonicalLibraryPath = @"/private/tmp/fcpcc-read-only-unit-library.fcpbundle";
        FCPCCLibraryManifestRecord *manifest = [[FCPCCLibraryManifestRecord alloc]
            initWithCanonicalPath:canonicalLibraryPath
                     expectedDevice:@123
                      expectedInode:@456
                      persistentUID:@"library-uid-verified"
                  verificationState:@"verified"];
        FCPCCLibraryIdentity *verifiedIdentity = [[FCPCCLibraryIdentity alloc]
            initWithCanonicalPath:canonicalLibraryPath
                           device:@123
                            inode:@456
                    persistentUID:@"library-uid-verified"];
        FCPCCReadOnlyLibrarySet *verifiedSet = [[FCPCCReadOnlyLibrarySet alloc]
            initWithLibraries:@[verifiedIdentity]
            completeTraversal:YES
                       reason:@"active_library_set_complete"];
        FCPCCLibraryInvariantResult *verifiedLibrary = FCPCCEvaluateLibraryInvariant(verifiedSet, manifest);
        if (require(verifiedLibrary.disposition == FCPCCLibraryInvariantDispositionVerified && verifiedLibrary.isVerified, @"verified disposable library did not pass")) {
            return 1;
        }

        NSArray<FCPCCLibraryIdentity *> *wrongIdentities = @[
            [[FCPCCLibraryIdentity alloc] initWithCanonicalPath:@"/private/tmp/wrong-library.fcpbundle" device:@123 inode:@456 persistentUID:@"library-uid-verified"],
            [[FCPCCLibraryIdentity alloc] initWithCanonicalPath:canonicalLibraryPath device:@124 inode:@456 persistentUID:@"library-uid-verified"],
            [[FCPCCLibraryIdentity alloc] initWithCanonicalPath:canonicalLibraryPath device:@123 inode:@457 persistentUID:@"library-uid-verified"],
            [[FCPCCLibraryIdentity alloc] initWithCanonicalPath:canonicalLibraryPath device:@123 inode:@456 persistentUID:@"wrong-library-uid"],
        ];
        for (FCPCCLibraryIdentity *wrongIdentity in wrongIdentities) {
            FCPCCReadOnlyLibrarySet *wrongSet = [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[wrongIdentity] completeTraversal:YES reason:@"active_library_set_complete"];
            FCPCCLibraryInvariantResult *wrongLibrary = FCPCCEvaluateLibraryInvariant(wrongSet, manifest);
            if (require(wrongLibrary.disposition == FCPCCLibraryInvariantDispositionIdentityMismatch && !wrongLibrary.isVerified, @"wrong library path, device, inode, or UID did not fail closed")) {
                return 1;
            }
        }

        FCPCCReadOnlyLibrarySet *multipleLibraries = [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[verifiedIdentity, verifiedIdentity] completeTraversal:YES reason:@"active_library_set_complete"];
        FCPCCReadOnlyLibrarySet *noLibraries = [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[] completeTraversal:YES reason:@"active_library_set_complete"];
        FCPCCReadOnlyLibrarySet *unsupportedTraversal = [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[] completeTraversal:NO reason:@"fcp_12_3_fixed_contract_unavailable"];
        if (require(FCPCCEvaluateLibraryInvariant(multipleLibraries, manifest).disposition == FCPCCLibraryInvariantDispositionOpenLibraryCountInvalid, @"multiple libraries did not fail closed")
            || require(FCPCCEvaluateLibraryInvariant(noLibraries, manifest).disposition == FCPCCLibraryInvariantDispositionOpenLibraryCountInvalid, @"no library did not fail closed")
            || require(FCPCCEvaluateLibraryInvariant(unsupportedTraversal, manifest).disposition == FCPCCLibraryInvariantDispositionTraversalUnsupported, @"unsupported library traversal did not fail closed")) {
            return 1;
        }

        CMTime frameDuration = CMTimeMake(1, 30);
        CMTimeRange timelineRange = CMTimeRangeMake(CMTimeMake(0, 30), CMTimeMake(30, 30));
        FCPCCReadOnlyContextSnapshot *noSelection = [FCPCCReadOnlyContextSnapshot
            snapshotWithDisposition:FCPCCReadOnlyContextDispositionReady
                              reason:@"read_only_context_ready"
                   activeProjectName:@"FCPCommandConsole Test"
                           frameSize:CGSizeMake(1920, 1080)
                       hasFrameSize:YES
                       frameDuration:frameDuration
                   hasFrameDuration:YES
               selectedTimelineItems:@[]
                   selectionRevision:nil
                    timelineRevision:@"timeline-revision-a"];
        if (require(noSelection.disposition == FCPCCReadOnlyContextDispositionNoSelection && !noSelection.isMutationCapable, @"no selection did not fail closed")) {
            return 1;
        }

        FCPCCTimelineItemSnapshot *invalidSourceIdentity = [[FCPCCTimelineItemSnapshot alloc]
            initWithStableItemIdentifier:@"item-1"
                       canonicalSourcePath:@"/private/tmp/../tmp/noncanonical.mov"
                             sourceSHA256:@"not-a-sha256"
                     sourceIdentityReason:@"source_identity_available"
                    primaryStorylineIndex:0
    previousPrimaryStorylineItemIdentifier:nil
        nextPrimaryStorylineItemIdentifier:nil
                            timelineRange:timelineRange
                         hasTimelineRange:YES
                            leadingHandle:kCMTimeInvalid
                     hasLeadingHandle:NO
                           trailingHandle:kCMTimeInvalid
                    hasTrailingHandle:NO];
        if (require(invalidSourceIdentity.canonicalSourcePath == nil && invalidSourceIdentity.sourceSHA256 == nil && [invalidSourceIdentity.sourceIdentityReason isEqualToString:@"source_identity_unavailable_invalid_canonical_path_or_sha256"], @"invalid source identity was not nulled")) {
            return 1;
        }

        FCPCCTimelineItemSnapshot *item = [[FCPCCTimelineItemSnapshot alloc]
            initWithStableItemIdentifier:@"item-1"
                       canonicalSourcePath:nil
                             sourceSHA256:nil
                     sourceIdentityReason:@"source_identity_unavailable_media_url_contract_not_admitted"
                    primaryStorylineIndex:0
    previousPrimaryStorylineItemIdentifier:nil
        nextPrimaryStorylineItemIdentifier:@"item-2"
                            timelineRange:timelineRange
                         hasTimelineRange:YES
                            leadingHandle:kCMTimeInvalid
                     hasLeadingHandle:NO
                           trailingHandle:kCMTimeInvalid
                    hasTrailingHandle:NO];
        FCPCCReadOnlyContextSnapshot *partial = [FCPCCReadOnlyContextSnapshot
            snapshotWithDisposition:FCPCCReadOnlyContextDispositionPartialUnsupported
                              reason:@"partial_unsupported_source_identity_unavailable_media_url_contract_not_admitted_and_handles_unavailable_no_exact_contract"
                   activeProjectName:@"FCPCommandConsole Test"
                           frameSize:CGSizeMake(1920, 1080)
                       hasFrameSize:YES
                       frameDuration:frameDuration
                   hasFrameDuration:YES
               selectedTimelineItems:@[item]
                   selectionRevision:@"selection-revision-a"
                    timelineRevision:@"timeline-revision-a"];
        if (require(partial.isReadOnlyCapable && !partial.isMutationCapable, @"partial read-only snapshot granted mutation")
            || require(item.canonicalSourcePath == nil && item.sourceSHA256 == nil && [item.sourceIdentityReason isEqualToString:@"source_identity_unavailable_media_url_contract_not_admitted"], @"partial source identity reason changed")) {
            return 1;
        }

        FCPCCReadOnlyContextSnapshot *stale = FCPCCValidateReadOnlySnapshotAgainstTimelineRevision(partial, @"timeline-revision-b");
        FCPCCReadOnlyContextSnapshot *unsupported = [FCPCCReadOnlyContextSnapshot unsupportedWithReason:@"unsupported_api_contract"];
        if (require(stale.disposition == FCPCCReadOnlyContextDispositionStaleRevision && !stale.isReadOnlyCapable && !stale.isMutationCapable, @"stale revision did not fail closed")
            || require(unsupported.disposition == FCPCCReadOnlyContextDispositionUnsupportedAPI && !unsupported.isReadOnlyCapable && !unsupported.isMutationCapable, @"unsupported API did not fail closed")) {
            return 1;
        }

        FCPCCBeforeAfterTransaction *transaction = [[FCPCCBeforeAfterTransaction alloc] initWithEffectKind:FCPCCEffectKindNativeTargetedRotateZoom beforeState:@{} afterState:@{}];
        FCPCCMutationController *controller = [[FCPCCMutationController alloc] init];
        FCPCCMutationResult *applyResult = [controller applyTransaction:transaction];
        FCPCCMutationResult *undoResult = [controller undoLastTransaction];
        if (require(applyResult.disposition == FCPCCMutationDispositionUnsupportedUnverifiedFCP123, @"apply did not fail closed")) {
            return 1;
        }
        if (require(undoResult.disposition == FCPCCMutationDispositionUnsupportedUnverifiedFCP123, @"undo did not fail closed")) {
            return 1;
        }
        if (require([applyResult.reason isEqualToString:@"unsupported_unverified_fcp_12_3"], @"apply reason changed")) {
            return 1;
        }
        if (require([undoResult.reason isEqualToString:@"unsupported_unverified_fcp_12_3"], @"undo reason changed")) {
            return 1;
        }
    }
    return 0;
}
