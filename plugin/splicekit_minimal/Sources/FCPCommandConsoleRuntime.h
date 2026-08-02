// Product-owned minimal runtime interface.
//
// This header deliberately exposes only typed, fail-closed stubs. It is not a
// bridge to arbitrary Final Cut internals.

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FCPCCEffectKind) {
    FCPCCEffectKindNativeTargetedRotateZoom = 0,
    FCPCCEffectKindLookOldTelevision = 1,
    FCPCCEffectKindTransitionNaturalDissolve = 2,
    FCPCCEffectKindMotionLivingStill = 3,
};

FOUNDATION_EXPORT NSString *FCPCCEffectIdentifierForKind(FCPCCEffectKind effectKind);

// Read-only Final Cut context contracts. These types never authorize a
// mutation; they are deliberately separate from the future edit API.
typedef NS_ENUM(NSInteger, FCPCCLibraryInvariantDisposition) {
    FCPCCLibraryInvariantDispositionVerified = 0,
    FCPCCLibraryInvariantDispositionManifestAbsent = 1,
    FCPCCLibraryInvariantDispositionManifestIncomplete = 2,
    FCPCCLibraryInvariantDispositionTraversalUnsupported = 3,
    FCPCCLibraryInvariantDispositionOpenLibraryCountInvalid = 4,
    FCPCCLibraryInvariantDispositionIdentityMismatch = 5,
};

@interface FCPCCLibraryIdentity : NSObject
@property (nonatomic, copy, readonly) NSString *canonicalPath;
@property (nonatomic, strong, readonly) NSNumber *device;
@property (nonatomic, strong, readonly) NSNumber *inode;
@property (nonatomic, copy, readonly) NSString *persistentUID;
- (instancetype)initWithCanonicalPath:(NSString *)canonicalPath
                               device:(NSNumber *)device
                                inode:(NSNumber *)inode
                        persistentUID:(NSString *)persistentUID NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface FCPCCLibraryManifestRecord : NSObject
@property (nonatomic, copy, readonly) NSString *canonicalPath;
@property (nonatomic, strong, readonly, nullable) NSNumber *expectedDevice;
@property (nonatomic, strong, readonly, nullable) NSNumber *expectedInode;
@property (nonatomic, copy, readonly, nullable) NSString *persistentUID;
@property (nonatomic, copy, readonly) NSString *verificationState;
- (instancetype)initWithCanonicalPath:(NSString *)canonicalPath
                        expectedDevice:(nullable NSNumber *)expectedDevice
                         expectedInode:(nullable NSNumber *)expectedInode
                         persistentUID:(nullable NSString *)persistentUID
                     verificationState:(NSString *)verificationState NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)isComplete;
@end

@interface FCPCCReadOnlyLibrarySet : NSObject
@property (nonatomic, copy, readonly) NSArray<FCPCCLibraryIdentity *> *libraries;
@property (nonatomic, readonly, getter=isCompleteTraversal) BOOL completeTraversal;
@property (nonatomic, copy, readonly) NSString *reason;
- (instancetype)initWithLibraries:(NSArray<FCPCCLibraryIdentity *> *)libraries
                completeTraversal:(BOOL)completeTraversal
                           reason:(NSString *)reason NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface FCPCCLibraryInvariantResult : NSObject
@property (nonatomic, readonly) FCPCCLibraryInvariantDisposition disposition;
@property (nonatomic, copy, readonly) NSString *reason;
@property (nonatomic, readonly, getter=isVerified) BOOL verified;
@end

FOUNDATION_EXPORT FCPCCLibraryInvariantResult *FCPCCEvaluateLibraryInvariant(FCPCCReadOnlyLibrarySet *librarySet,
                                                                               FCPCCLibraryManifestRecord * _Nullable manifest);

typedef NS_ENUM(NSInteger, FCPCCReadOnlyContextDisposition) {
    FCPCCReadOnlyContextDispositionReady = 0,
    FCPCCReadOnlyContextDispositionNoSelection = 1,
    FCPCCReadOnlyContextDispositionStaleRevision = 2,
    FCPCCReadOnlyContextDispositionPartialUnsupported = 3,
    FCPCCReadOnlyContextDispositionUnsupportedAPI = 4,
};

@interface FCPCCTimelineItemSnapshot : NSObject
@property (nonatomic, copy, readonly) NSString *stableItemIdentifier;
@property (nonatomic, copy, readonly, nullable) NSString *canonicalSourcePath;
@property (nonatomic, copy, readonly, nullable) NSString *sourceSHA256;
@property (nonatomic, copy, readonly) NSString *sourceIdentityReason;
@property (nonatomic, readonly) NSInteger primaryStorylineIndex;
@property (nonatomic, copy, readonly, nullable) NSString *previousPrimaryStorylineItemIdentifier;
@property (nonatomic, copy, readonly, nullable) NSString *nextPrimaryStorylineItemIdentifier;
@property (nonatomic, readonly) CMTimeRange timelineRange;
@property (nonatomic, readonly) BOOL hasTimelineRange;
@property (nonatomic, readonly) CMTime leadingHandle;
@property (nonatomic, readonly) BOOL hasLeadingHandle;
@property (nonatomic, readonly) CMTime trailingHandle;
@property (nonatomic, readonly) BOOL hasTrailingHandle;
- (instancetype)initWithStableItemIdentifier:(NSString *)stableItemIdentifier
                          canonicalSourcePath:(nullable NSString *)canonicalSourcePath
                                sourceSHA256:(nullable NSString *)sourceSHA256
                        sourceIdentityReason:(NSString *)sourceIdentityReason
                       primaryStorylineIndex:(NSInteger)primaryStorylineIndex
       previousPrimaryStorylineItemIdentifier:(nullable NSString *)previousPrimaryStorylineItemIdentifier
           nextPrimaryStorylineItemIdentifier:(nullable NSString *)nextPrimaryStorylineItemIdentifier
                               timelineRange:(CMTimeRange)timelineRange
                            hasTimelineRange:(BOOL)hasTimelineRange
                               leadingHandle:(CMTime)leadingHandle
                        hasLeadingHandle:(BOOL)hasLeadingHandle
                              trailingHandle:(CMTime)trailingHandle
                       hasTrailingHandle:(BOOL)hasTrailingHandle NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface FCPCCReadOnlyContextSnapshot : NSObject
@property (nonatomic, readonly) FCPCCReadOnlyContextDisposition disposition;
@property (nonatomic, copy, readonly) NSString *reason;
@property (nonatomic, copy, readonly, nullable) NSString *activeProjectName;
@property (nonatomic, readonly) CGSize frameSize;
@property (nonatomic, readonly) BOOL hasFrameSize;
@property (nonatomic, readonly) CMTime frameDuration;
@property (nonatomic, readonly) BOOL hasFrameDuration;
@property (nonatomic, copy, readonly) NSArray<FCPCCTimelineItemSnapshot *> *selectedTimelineItems;
@property (nonatomic, copy, readonly, nullable) NSString *selectionRevision;
@property (nonatomic, copy, readonly, nullable) NSString *timelineRevision;
@property (nonatomic, readonly, getter=isReadOnlyCapable) BOOL readOnlyCapable;
@property (nonatomic, readonly, getter=isMutationCapable) BOOL mutationCapable;
+ (instancetype)unsupportedWithReason:(NSString *)reason;
+ (instancetype)snapshotWithDisposition:(FCPCCReadOnlyContextDisposition)disposition
                                  reason:(NSString *)reason
                       activeProjectName:(nullable NSString *)activeProjectName
                               frameSize:(CGSize)frameSize
                           hasFrameSize:(BOOL)hasFrameSize
                           frameDuration:(CMTime)frameDuration
                       hasFrameDuration:(BOOL)hasFrameDuration
                   selectedTimelineItems:(NSArray<FCPCCTimelineItemSnapshot *> *)selectedTimelineItems
                       selectionRevision:(nullable NSString *)selectionRevision
                        timelineRevision:(nullable NSString *)timelineRevision;
@end

// A caller that has independently sampled the current timeline revision can
// reject a previously captured snapshot without granting any edit capability.
FOUNDATION_EXPORT FCPCCReadOnlyContextSnapshot *FCPCCValidateReadOnlySnapshotAgainstTimelineRevision(
    FCPCCReadOnlyContextSnapshot *snapshot,
    NSString * _Nullable currentTimelineRevision);

typedef NS_ENUM(NSInteger, FCPCCMutationDisposition) {
    FCPCCMutationDispositionUnsupportedUnverifiedFCP123 = 0,
    // A deterministic product-owned preview plan was formed. This is not a
    // Final Cut Pro mutation result.
    FCPCCMutationDispositionPlanReady = 1,
    FCPCCMutationDispositionRejectedInvalidRequest = 2,
    FCPCCMutationDispositionRejectedContextInvariant = 3,
    FCPCCMutationDispositionRejectedLibraryInvariant = 4,
    FCPCCMutationDispositionRejectedHostContainment = 5,
    FCPCCMutationDispositionUnsupportedEffect = 6,
    FCPCCMutationDispositionUnsupportedPendingLiveContract = 7,
};

FOUNDATION_EXPORT NSString * const FCPCCMutationErrorUnsupportedUnverifiedFCP123;
FOUNDATION_EXPORT NSString * const FCPCCMutationErrorUnsupportedPendingLiveContract;

// This is a product-owned desired curve for preview/planning only. The sole
// value deliberately does not encode, infer, or select a private Final Cut
// Pro interpolation option.
typedef NS_ENUM(NSInteger, FCPCCNativeKeyframeEasing) {
    FCPCCNativeKeyframeEasingNatural = 0,
};

// The payload boundary remains typed and extensible for the four fixed effect
// kinds. A base payload can never authorize a native mutation by itself.
@interface FCPCCMutationPayload : NSObject
@property (nonatomic, readonly) FCPCCEffectKind effectKind;
- (instancetype)initWithEffectKind:(FCPCCEffectKind)effectKind NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface FCPCCNativeTargetedRotateZoomRequest : FCPCCMutationPayload
@property (nonatomic, readonly) CGPoint normalizedTargetPoint;
@property (nonatomic, readonly) CGFloat scaleStart;
@property (nonatomic, readonly) CGFloat scaleEnd;
@property (nonatomic, readonly) CGFloat rotationStartDegrees;
@property (nonatomic, readonly) CGFloat rotationEndDegrees;
@property (nonatomic, readonly) CMTime duration;
@property (nonatomic, readonly) FCPCCNativeKeyframeEasing easing;
- (instancetype)initWithNormalizedTargetPoint:(CGPoint)normalizedTargetPoint
                                   scaleStart:(CGFloat)scaleStart
                                     scaleEnd:(CGFloat)scaleEnd
                         rotationStartDegrees:(CGFloat)rotationStartDegrees
                           rotationEndDegrees:(CGFloat)rotationEndDegrees
                                     duration:(CMTime)duration
                                       easing:(FCPCCNativeKeyframeEasing)easing NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithEffectKind:(FCPCCEffectKind)effectKind NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

// A keyframe is a typed desired transform preview value. No private Final Cut
// Pro setter is called while creating one.
@interface FCPCCNativeTransformKeyframe : NSObject
@property (nonatomic, readonly) CMTime clipLocalTime;
// This product coordinate remains normalized until an exact Final Cut Pro
// pixel-position conversion and axis convention have been admitted.
@property (nonatomic, readonly) CGPoint normalizedPosition;
@property (nonatomic, readonly, getter=isNativePixelPositionConversionVerified) BOOL nativePixelPositionConversionVerified;
@property (nonatomic, readonly) CGFloat uniformScale;
@property (nonatomic, readonly) CGFloat rotationDegrees;
@property (nonatomic, readonly) CGFloat easedProgress;
- (instancetype)initWithClipLocalTime:(CMTime)clipLocalTime
                   normalizedPosition:(CGPoint)normalizedPosition
 nativePixelPositionConversionVerified:(BOOL)nativePixelPositionConversionVerified
                         uniformScale:(CGFloat)uniformScale
                      rotationDegrees:(CGFloat)rotationDegrees
                        easedProgress:(CGFloat)easedProgress NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface FCPCCNativeTransformState : NSObject
@property (nonatomic, copy, readonly) NSString *stableItemIdentifier;
@property (nonatomic, copy, readonly) NSString *selectionRevision;
@property (nonatomic, copy, readonly) NSString *timelineRevision;
@property (nonatomic, readonly) CGSize frameSize;
@property (nonatomic, copy, readonly) NSArray<FCPCCNativeTransformKeyframe *> *keyframes;
- (instancetype)initWithStableItemIdentifier:(NSString *)stableItemIdentifier
                            selectionRevision:(NSString *)selectionRevision
                             timelineRevision:(NSString *)timelineRevision
                                    frameSize:(CGSize)frameSize
                                    keyframes:(NSArray<FCPCCNativeTransformKeyframe *> *)keyframes NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface FCPCCBeforeAfterTransaction : NSObject
@property (nonatomic, copy, readonly) NSString *transactionIdentifier;
@property (nonatomic, readonly) FCPCCEffectKind effectKind;
@property (nonatomic, strong, readonly) FCPCCMutationPayload *payload;
@property (nonatomic, strong, readonly) FCPCCReadOnlyContextSnapshot *contextSnapshot;
@property (nonatomic, strong, readonly) FCPCCLibraryInvariantResult *libraryInvariant;
- (instancetype)initWithPayload:(FCPCCMutationPayload *)payload
                   contextSnapshot:(FCPCCReadOnlyContextSnapshot *)contextSnapshot
                  libraryInvariant:(FCPCCLibraryInvariantResult *)libraryInvariant NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

// This is the only transaction subtype admitted to the future native route.
// The other three fixed payload kinds retain the generic typed boundary and
// remain unsupported by FCPCCMutationController.
@interface FCPCCNativeTargetedRotateZoomTransaction : FCPCCBeforeAfterTransaction
@property (nonatomic, strong, readonly) FCPCCNativeTargetedRotateZoomRequest *request;
@property (nonatomic, copy, readonly) NSString *nativeUndoActionName;
- (instancetype)initWithRequest:(FCPCCNativeTargetedRotateZoomRequest *)request
                 contextSnapshot:(FCPCCReadOnlyContextSnapshot *)contextSnapshot
                libraryInvariant:(FCPCCLibraryInvariantResult *)libraryInvariant NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithPayload:(FCPCCMutationPayload *)payload
                 contextSnapshot:(FCPCCReadOnlyContextSnapshot *)contextSnapshot
                libraryInvariant:(FCPCCLibraryInvariantResult *)libraryInvariant NS_UNAVAILABLE;
@end

@interface FCPCCMutationResult : NSObject
@property (nonatomic, readonly) FCPCCMutationDisposition disposition;
@property (nonatomic, copy, readonly) NSString *reason;
@property (nonatomic, strong, readonly, nullable) FCPCCNativeTransformState *plannedAfterState;
@property (nonatomic, strong, readonly, nullable) FCPCCNativeTransformState *beforeState;
@property (nonatomic, strong, readonly, nullable) FCPCCNativeTransformState *afterState;
@property (nonatomic, readonly, getter=didPerformNativeMutation) BOOL nativeMutationPerformed;
+ (instancetype)unsupportedUnverified;
@end

@interface FCPCCMutationController : NSObject
// This pure planner is available for deterministic preview and test evidence.
// It cannot write a Final Cut Pro project.
- (FCPCCMutationResult *)planTransaction:(FCPCCBeforeAfterTransaction *)transaction;
- (FCPCCMutationResult *)applyTransaction:(FCPCCBeforeAfterTransaction *)transaction;
- (FCPCCMutationResult *)undoLastTransaction;
@end

NS_ASSUME_NONNULL_END
