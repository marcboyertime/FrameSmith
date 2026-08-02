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
};

FOUNDATION_EXPORT NSString * const FCPCCMutationErrorUnsupportedUnverifiedFCP123;

@interface FCPCCBeforeAfterTransaction : NSObject
@property (nonatomic, copy, readonly) NSString *transactionIdentifier;
@property (nonatomic, readonly) FCPCCEffectKind effectKind;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *beforeState;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *afterState;
- (instancetype)initWithEffectKind:(FCPCCEffectKind)effectKind
                       beforeState:(NSDictionary<NSString *, id> *)beforeState
                        afterState:(NSDictionary<NSString *, id> *)afterState;
@end

@interface FCPCCMutationResult : NSObject
@property (nonatomic, readonly) FCPCCMutationDisposition disposition;
@property (nonatomic, copy, readonly) NSString *reason;
+ (instancetype)unsupportedUnverified;
@end

@interface FCPCCMutationController : NSObject
- (FCPCCMutationResult *)applyTransaction:(FCPCCBeforeAfterTransaction *)transaction;
- (FCPCCMutationResult *)undoLastTransaction;
@end

NS_ASSUME_NONNULL_END
