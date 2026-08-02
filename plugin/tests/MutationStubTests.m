#import <Foundation/Foundation.h>
#import <math.h>
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

        FCPCCTimelineItemSnapshot *readyItem = [[FCPCCTimelineItemSnapshot alloc]
            initWithStableItemIdentifier:@"item-ready"
                       canonicalSourcePath:@"/private/tmp/fcpcc-native-plan-media.mov"
                             sourceSHA256:@"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                     sourceIdentityReason:@"source_identity_available"
                    primaryStorylineIndex:0
    previousPrimaryStorylineItemIdentifier:nil
        nextPrimaryStorylineItemIdentifier:nil
                            timelineRange:CMTimeRangeMake(CMTimeMake(30, 30), CMTimeMake(120, 30))
                         hasTimelineRange:YES
                            leadingHandle:kCMTimeInvalid
                     hasLeadingHandle:NO
                           trailingHandle:kCMTimeInvalid
                    hasTrailingHandle:NO];
        FCPCCReadOnlyContextSnapshot *ready = [FCPCCReadOnlyContextSnapshot
            snapshotWithDisposition:FCPCCReadOnlyContextDispositionReady
                              reason:@"read_only_context_ready"
                   activeProjectName:@"FCPCommandConsole Test"
                           frameSize:CGSizeMake(1920, 1080)
                       hasFrameSize:YES
                       frameDuration:frameDuration
                   hasFrameDuration:YES
               selectedTimelineItems:@[readyItem]
                   selectionRevision:@"selection-revision-ready"
                    timelineRevision:@"timeline-revision-ready"];
        FCPCCNativeTargetedRotateZoomRequest *request = [[FCPCCNativeTargetedRotateZoomRequest alloc]
            initWithNormalizedTargetPoint:CGPointMake(0.25, 0.75)
                               scaleStart:1.2
                                 scaleEnd:1.5
                     rotationStartDegrees:-10.0
                       rotationEndDegrees:20.0
                                 duration:CMTimeMake(60, 30)
                                   easing:FCPCCNativeKeyframeEasingNatural];
        FCPCCNativeTargetedRotateZoomTransaction *transaction = [[FCPCCNativeTargetedRotateZoomTransaction alloc]
            initWithRequest:request
             contextSnapshot:ready
            libraryInvariant:verifiedLibrary];
        FCPCCMutationController *controller = [[FCPCCMutationController alloc] init];
        FCPCCMutationResult *planResult = [controller planTransaction:transaction];
        FCPCCMutationResult *applyResult = [controller applyTransaction:transaction];
        FCPCCMutationResult *undoResult = [controller undoLastTransaction];
        if (require(planResult.disposition == FCPCCMutationDispositionPlanReady
                    && planResult.plannedAfterState != nil
                    && planResult.beforeState == nil
                    && planResult.afterState == nil
                    && !planResult.didPerformNativeMutation,
                    @"typed preview plan was not read-only")) {
            return 1;
        }
        if (require([transaction.nativeUndoActionName isEqualToString:@"FCPCommandConsole: Targeted Rotate + Zoom"], @"named native undo transaction changed")) {
            return 1;
        }
        NSArray<FCPCCNativeTransformKeyframe *> *keyframes = planResult.plannedAfterState.keyframes;
        if (require(keyframes.count == 5, @"preview plan did not contain five keyframes")) {
            return 1;
        }
        FCPCCNativeTransformKeyframe *first = keyframes.firstObject;
        FCPCCNativeTransformKeyframe *early = keyframes[1];
        FCPCCNativeTransformKeyframe *middle = keyframes[2];
        FCPCCNativeTransformKeyframe *late = keyframes[3];
        FCPCCNativeTransformKeyframe *last = keyframes.lastObject;
        if (require(CMTimeCompare(first.clipLocalTime, kCMTimeZero) == 0
                    && CMTimeCompare(last.clipLocalTime, request.duration) == 0
                    && fabs(first.uniformScale - request.scaleStart) < 0.000001
                    && fabs(first.rotationDegrees - request.rotationStartDegrees) < 0.000001
                    && fabs(last.uniformScale - request.scaleEnd) < 0.000001
                    && fabs(last.rotationDegrees - request.rotationEndDegrees) < 0.000001
                    && first.easedProgress == 0.0,
                    @"preview plan did not preserve endpoint semantics")) {
            return 1;
        }
        CGFloat sourceX = request.normalizedTargetPoint.x - 0.5;
        CGFloat sourceY = request.normalizedTargetPoint.y - 0.5;
        if (require(fabs(early.easedProgress - 0.15625) < 0.000001
                    && fabs(middle.easedProgress - 0.5) < 0.000001
                    && fabs(late.easedProgress - 0.84375) < 0.000001,
                    @"preview plan did not use deterministic smoothstep samples")) {
            return 1;
        }
        CMTime previousClipLocalTime = kCMTimeInvalid;
        for (FCPCCNativeTransformKeyframe *keyframe in keyframes) {
            CGFloat radians = keyframe.rotationDegrees * (CGFloat)(M_PI / 180.0);
            CGFloat transformedX = keyframe.uniformScale * ((sourceX * cos(radians)) - (sourceY * sin(radians)));
            CGFloat transformedY = keyframe.uniformScale * ((sourceX * sin(radians)) + (sourceY * cos(radians)));
            CGFloat outputX = transformedX + keyframe.normalizedPosition.x;
            CGFloat outputY = transformedY + keyframe.normalizedPosition.y;
            if (require(!keyframe.isNativePixelPositionConversionVerified
                        && (CMTIME_IS_VALID(previousClipLocalTime) == 0 || CMTimeCompare(keyframe.clipLocalTime, previousClipLocalTime) > 0)
                        && fabs(outputX - (sourceX * (1.0 - keyframe.easedProgress))) < 0.000001
                        && fabs(outputY - (sourceY * (1.0 - keyframe.easedProgress))) < 0.000001,
                        @"preview compensation did not keep every target sample on the centerward segment")) {
                return 1;
            }
            previousClipLocalTime = keyframe.clipLocalTime;
        }
        if (require(applyResult.disposition == FCPCCMutationDispositionRejectedHostContainment
                    && applyResult.plannedAfterState != nil
                    && applyResult.beforeState == nil
                    && applyResult.afterState == nil
                    && !applyResult.didPerformNativeMutation,
                    @"offline apply did not stop at host containment")) {
            return 1;
        }
        if (require(undoResult.disposition == FCPCCMutationDispositionUnsupportedPendingLiveContract
                    && [undoResult.reason isEqualToString:FCPCCMutationErrorUnsupportedPendingLiveContract]
                    && !undoResult.didPerformNativeMutation,
                    @"undo did not remain pending the native live contracts")) {
            return 1;
        }

        FCPCCNativeTargetedRotateZoomRequest *invalidRequest = [[FCPCCNativeTargetedRotateZoomRequest alloc]
            initWithNormalizedTargetPoint:CGPointMake(NAN, 0.5)
                               scaleStart:1.2
                                 scaleEnd:1.5
                     rotationStartDegrees:-10.0
                       rotationEndDegrees:20.0
                                 duration:CMTimeMake(60, 30)
                                   easing:FCPCCNativeKeyframeEasingNatural];
        FCPCCNativeTargetedRotateZoomTransaction *invalidTransaction = [[FCPCCNativeTargetedRotateZoomTransaction alloc]
            initWithRequest:invalidRequest
             contextSnapshot:ready
            libraryInvariant:verifiedLibrary];
        if (require([controller planTransaction:invalidTransaction].disposition == FCPCCMutationDispositionRejectedInvalidRequest, @"non-finite normalized target did not fail closed")) {
            return 1;
        }
        FCPCCNativeTargetedRotateZoomRequest *outOfBoundsRequest = [[FCPCCNativeTargetedRotateZoomRequest alloc]
            initWithNormalizedTargetPoint:CGPointMake(0.25, 0.75)
                               scaleStart:1.2
                                 scaleEnd:4.1
                     rotationStartDegrees:-10.0
                       rotationEndDegrees:20.0
                                 duration:CMTimeMake(60, 30)
                                   easing:FCPCCNativeKeyframeEasingNatural];
        FCPCCNativeTargetedRotateZoomTransaction *outOfBoundsTransaction = [[FCPCCNativeTargetedRotateZoomTransaction alloc]
            initWithRequest:outOfBoundsRequest
             contextSnapshot:ready
            libraryInvariant:verifiedLibrary];
        if (require([controller planTransaction:outOfBoundsTransaction].disposition == FCPCCMutationDispositionRejectedInvalidRequest, @"scale registry bounds did not fail closed")) {
            return 1;
        }
        FCPCCNativeTargetedRotateZoomTransaction *partialTransaction = [[FCPCCNativeTargetedRotateZoomTransaction alloc]
            initWithRequest:request
             contextSnapshot:partial
            libraryInvariant:verifiedLibrary];
        if (require([controller planTransaction:partialTransaction].disposition == FCPCCMutationDispositionRejectedContextInvariant, @"partial read-only context was treated as execution-ready")) {
            return 1;
        }
        for (FCPCCEffectKind unsupportedEffect = FCPCCEffectKindLookOldTelevision;
             unsupportedEffect <= FCPCCEffectKindMotionLivingStill;
             unsupportedEffect += 1) {
            FCPCCMutationPayload *payload = [[FCPCCMutationPayload alloc] initWithEffectKind:unsupportedEffect];
            FCPCCBeforeAfterTransaction *unsupportedTransaction = [[FCPCCBeforeAfterTransaction alloc]
                initWithPayload:payload
                 contextSnapshot:ready
                libraryInvariant:verifiedLibrary];
            if (require([controller planTransaction:unsupportedTransaction].disposition == FCPCCMutationDispositionUnsupportedEffect, @"non-native fixed effect was admitted to native mutation")) {
                return 1;
            }
        }
        FCPCCMutationPayload *genericNativePayload = [[FCPCCMutationPayload alloc] initWithEffectKind:FCPCCEffectKindNativeTargetedRotateZoom];
        FCPCCBeforeAfterTransaction *genericNativeTransaction = [[FCPCCBeforeAfterTransaction alloc]
            initWithPayload:genericNativePayload
             contextSnapshot:ready
            libraryInvariant:verifiedLibrary];
        if (require([controller planTransaction:genericNativeTransaction].disposition == FCPCCMutationDispositionRejectedInvalidRequest, @"generic payload was admitted to the dedicated native route")) {
            return 1;
        }
    }
    return 0;
}
