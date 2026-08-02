// Product-owned minimal runtime interface.
//
// This header deliberately exposes only typed, fail-closed stubs. It is not a
// bridge to arbitrary Final Cut internals.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FCPCCEffectKind) {
    FCPCCEffectKindNativeTargetedRotateZoom = 0,
    FCPCCEffectKindLookOldTelevision = 1,
    FCPCCEffectKindTransitionNaturalDissolve = 2,
    FCPCCEffectKindMotionLivingStill = 3,
};

FOUNDATION_EXPORT NSString *FCPCCEffectIdentifierForKind(FCPCCEffectKind effectKind);

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
