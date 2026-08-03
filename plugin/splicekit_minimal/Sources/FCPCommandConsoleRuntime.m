// FCPCommandConsole minimal runtime.
//
// The candidate strings below were manually transcribed from the locked
// SpliceKit symbol snapshot at f4f6618121309a69b66272b441f34cf8ad57f306.
// Candidate strings remain constants only; the separately documented exact
// compatibility gates below use two fixed selectors after their image and ABI
// checks.

#import "FCPCommandConsoleRuntime.h"

#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>
#import <errno.h>
#import <fcntl.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <math.h>
#import <objc/runtime.h>
#import <sys/stat.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>

NSString * const FCPCCMutationErrorUnsupportedUnverifiedFCP123 = @"unsupported_unverified_fcp_12_3";
NSString * const FCPCCMutationErrorUnsupportedPendingLiveContract = @"unsupported_pending_live_contract_missing_exact_native_easing_and_native_undo_rollback_contracts";

static NSString * const FCPCCExpectedHostBundleIdentifier = @"com.apple.FinalCut";
static NSString * const FCPCCExpectedHostVersion = @"12.3";
static NSString * const FCPCCExpectedHostBuild = @"450152";
static NSString * const FCPCCExpectedCopiedHostBundlePath = @"/Users/marcboyer/Applications/SpliceKit/FCPCommandConsole/Final Cut Pro - FCPCommandConsole.app";
static NSString * const FCPCCExpectedRuntimeFrameworkName = @"FCPCommandConsoleRuntime.framework";
static NSString * const FCPCCExpectedMASReceiptRelativePath = @"Contents/_MASReceipt/receipt";
static const char * const FCPCCExpectedMASReceiptSHA256 = "2e8a161e71eb0c7dbf94aee945234fe27c43665938f64a60d6615b153b3d8d8e";
static NSString * const FCPCCExpectedOnboardingFrameworkRelativeExecutablePath = @"Contents/Frameworks/ProOnboardingFlowModelOne.framework/Versions/A/ProOnboardingFlowModelOne";
static NSString * const FCPCCExpectedOnboardingCoordinatorClassName = @"POFDesktopOnboardingCoordinator";
static NSString * const FCPCCExpectedOnboardingQuerySetterName = @"setQueryDemoProjectInfo:";
static const char * const FCPCCExpectedOnboardingQuerySetterTypeEncoding = "v24@0:8@?16";
static const char * const FCPCCExpectedOnboardingFrameworkSHA256 = "636cc140036217ab1f39d998ac53faaf2dd8682c091f3c041dbde594d1f2dfce";
static NSString * const FCPCCExpectedCloudFirstLaunchHelperClassName = @"CCFirstLaunchHelper";
static NSString * const FCPCCExpectedCloudFirstLaunchSetupSelectorName = @"setupAndPresentFirstLaunchIfNeededWithCompletionHandler:";
static const char * const FCPCCExpectedCloudFirstLaunchSetupTypeEncoding = "v24@0:8@?<v@?@\"NSError\">16";
static NSString * const FCPCCExpectedFlexoFrameworkRelativeExecutablePath = @"Contents/Frameworks/Flexo.framework/Versions/A/Flexo";
static const char * const FCPCCExpectedFlexoFrameworkSHA256 = "704557a28dcd2668f9991fa6c4b601ecfe4e926161abdf3848bf235da73cb99e";
static NSString * const FCPCCExpectedProCoreFrameworkRelativeExecutablePath = @"Contents/Frameworks/ProCore.framework/Versions/A/ProCore";
static const char * const FCPCCExpectedProCoreFrameworkSHA256 = "567ef84ab789b5bbd44f7e4b5dfbb9640d397adf62ee3c2aeeb6a14330d62d17";
static NSString * const FCPCCDisposableLibraryBootstrapEnvironmentName = @"FCPCC_BOOTSTRAP_DISPOSABLE_LIBRARY";
static NSString * const FCPCCDisposableLibraryBootstrapEnvironmentValue = @"1";
static NSString * const FCPCCDisposableLibraryBootstrapParentPath = @"/Users/marcboyer/Movies/FCPCommandConsole";
static NSString * const FCPCCDisposableLibraryBootstrapTargetPath = @"/Users/marcboyer/Movies/FCPCommandConsole/FCPCommandConsole Test.fcpbundle";
static NSString * const FCPCCDisposableLibraryBootstrapProvenanceDirectory = @"/Users/marcboyer/Movies/FCPCommandConsole/provenance";
static NSString * const FCPCCDisposableLibraryBootstrapProvenancePrefix = @"disposable-library-bootstrap-";
static NSString * const FCPCCDisposableProjectBootstrapEnvironmentName = @"FCPCC_BOOTSTRAP_DISPOSABLE_PROJECT";
static NSString * const FCPCCDisposableProjectBootstrapEnvironmentValue = @"1";
static NSString * const FCPCCDisposableProjectBootstrapFixturesRootPath = @"/Users/marcboyer/Movies/FCPCommandConsole/fixtures";
static NSString * const FCPCCDisposableProjectBootstrapClipAPath = @"/Users/marcboyer/Movies/FCPCommandConsole/fixtures/clip-a.mov";
static NSString * const FCPCCDisposableProjectBootstrapClipBPath = @"/Users/marcboyer/Movies/FCPCommandConsole/fixtures/clip-b.mov";
static NSString * const FCPCCDisposableProjectBootstrapLivingStillPath = @"/Users/marcboyer/Movies/FCPCommandConsole/fixtures/living-still.png";
static NSString * const FCPCCDisposableProjectBootstrapProjectName = @"FCPCommandConsole Test";
static NSString * const FCPCCDisposableProjectBootstrapProvenancePrefix = @"disposable-project-bootstrap-";
static const char * const FCPCCDisposableProjectBootstrapClipASHA256 = "cd44c0c9565c8231ec421541f4a4877f340eae7db5129fb46ffa14f0bf871444";
static const char * const FCPCCDisposableProjectBootstrapClipBSHA256 = "a38a03bf0ababfedc56c6086479c34649a8fea8b2435b04c4901f3987c66f67c";
static const char * const FCPCCDisposableProjectBootstrapLivingStillSHA256 = "170df5348f53221de630c7d7b385e6189f53a27baa2f2246ec7df4f379ed2567";
static NSString * const FCPCCDisposableProjectBootstrapPasteboardPrefix = @"com.fcpcommandconsole.disposable-project.";
static const NSUInteger FCPCCDisposableProjectBootstrapMaximumObservationTurns = 24;
static const NSTimeInterval FCPCCDisposableProjectBootstrapLibraryOpenCompletionTimeoutSeconds = 30.0;

static BOOL FCPCCFileSHA256MatchesExpectedHex(NSString *path, const char *expectedHex);

CGPoint FCPCCProductNormalizedPointToCandidateFCPPixels(CGPoint normalizedPoint,
                                                         CGSize frameSize) {
    // Product coordinates: [0, 1] with top-left origin, x right and y down.
    // Candidate Final Cut coordinates: centered pixels, x right and y up.
    // The caller must still reject this output until the convention is
    // demonstrated against the exact enrolled disposable library.
    return CGPointMake((normalizedPoint.x - 0.5) * frameSize.width,
                       (0.5 - normalizedPoint.y) * frameSize.height);
}

// The copied executable intentionally has one additional LC_LOAD_DYLIB and a
// new signature, so its whole-file hash cannot equal the stock pre-injection
// executable hash. The patcher binds that stock hash before each deployment;
// the runtime independently verifies the exact copied path, its preserved
// active-slice UUID, its unchanged MAS receipt, and the untouched nested
// framework's whole-file hash and UUID.
static const uint8_t FCPCCExpectedHostArm64UUID[16] __attribute__((unused)) = {
    0xAD, 0x02, 0x40, 0x67, 0xE1, 0x45, 0x39, 0x88,
    0xAF, 0xF9, 0xBD, 0x33, 0x39, 0x1C, 0x41, 0x6D,
};
static const uint8_t FCPCCExpectedHostX86_64UUID[16] __attribute__((unused)) = {
    0x2A, 0xCC, 0xBD, 0x11, 0x69, 0x65, 0x3D, 0x09,
    0xBD, 0x87, 0x9A, 0x90, 0x0F, 0xDC, 0x74, 0x0E,
};
static const uint8_t FCPCCExpectedOnboardingFrameworkArm64UUID[16] __attribute__((unused)) = {
    0x45, 0xD8, 0xAC, 0x9D, 0xD5, 0x44, 0x3C, 0xD1,
    0x90, 0xDB, 0x53, 0x2D, 0xFA, 0xAA, 0x0E, 0x0D,
};
static const uint8_t FCPCCExpectedOnboardingFrameworkX86_64UUID[16] __attribute__((unused)) = {
    0xFC, 0xAA, 0x9A, 0x11, 0xC6, 0xA5, 0x3E, 0xC9,
    0x9E, 0x65, 0xAD, 0xCA, 0x14, 0xF0, 0x86, 0xF7,
};
static const uint8_t FCPCCExpectedFlexoFrameworkArm64UUID[16] __attribute__((unused)) = {
    0xAE, 0xAE, 0x4C, 0x0B, 0x76, 0x95, 0x37, 0x84,
    0xA7, 0x94, 0xAF, 0xB4, 0x98, 0x55, 0x25, 0xA8,
};
static const uint8_t FCPCCExpectedFlexoFrameworkX86_64UUID[16] __attribute__((unused)) = {
    0x52, 0x51, 0x66, 0xA8, 0xE6, 0xF4, 0x3D, 0xCA,
    0xB4, 0xF9, 0xBD, 0x98, 0xF1, 0x6B, 0x65, 0x52,
};
static const uint8_t FCPCCExpectedProCoreFrameworkArm64UUID[16] __attribute__((unused)) = {
    0xD5, 0x5A, 0xA4, 0x7E, 0xF2, 0xE7, 0x33, 0xA7,
    0xAF, 0xB5, 0xC3, 0xF1, 0x47, 0x5D, 0x15, 0x15,
};
static const uint8_t FCPCCExpectedProCoreFrameworkX86_64UUID[16] __attribute__((unused)) = {
    0xD1, 0x89, 0x28, 0x0F, 0xE7, 0x7A, 0x31, 0xDF,
    0x9B, 0xDF, 0x14, 0x79, 0xB7, 0xEE, 0x47, 0x66,
};

// Offline-inspected candidates. These values are intentionally fixed and have
// no execution path in this build.
NSString *FCPCCEffectIdentifierForKind(FCPCCEffectKind effectKind) {
    switch (effectKind) {
        case FCPCCEffectKindNativeTargetedRotateZoom:
            return @"native.targeted_rotate_zoom";
        case FCPCCEffectKindLookOldTelevision:
            return @"look.old_television";
        case FCPCCEffectKindTransitionNaturalDissolve:
            return @"transition.natural_dissolve";
        case FCPCCEffectKindMotionLivingStill:
            return @"motion.living_still";
    }
    return @"";
}

typedef NS_ENUM(NSInteger, FCPCCGateDisposition) {
    FCPCCGateDispositionVerified = 0,
    FCPCCGateDispositionHostUnverified = 1,
    FCPCCGateDispositionManifestAbsent = 2,
    FCPCCGateDispositionManifestUnverifiable = 3,
    FCPCCGateDispositionTraversalUnverified = 4,
    FCPCCGateDispositionOpenLibraryCountInvalid = 5,
    FCPCCGateDispositionLibraryIdentityMismatch = 6,
};

@interface FCPCCGateStatus : NSObject
@property (nonatomic, readonly) FCPCCGateDisposition disposition;
@property (nonatomic, copy, readonly) NSString *summary;
@property (nonatomic, readonly, getter=isVerified) BOOL verified;
- (instancetype)initWithDisposition:(FCPCCGateDisposition)disposition summary:(NSString *)summary;
@end

@implementation FCPCCGateStatus

- (instancetype)initWithDisposition:(FCPCCGateDisposition)disposition summary:(NSString *)summary {
    self = [super init];
    if (self != nil) {
        _disposition = disposition;
        _summary = [summary copy];
        _verified = disposition == FCPCCGateDispositionVerified;
    }
    return self;
}

@end

static NSString *FCPCCCanonicalFilePath(NSString *path) {
    if (path.length == 0 || !path.isAbsolutePath) {
        return nil;
    }
    NSString *standardized = [path stringByStandardizingPath];
    NSString *resolved = [standardized stringByResolvingSymlinksInPath];
    return resolved.length == 0 ? nil : [resolved stringByStandardizingPath];
}

static BOOL FCPCCIsExactCanonicalFilePath(NSString *path) {
    NSString *canonical = FCPCCCanonicalFilePath(path);
    return canonical != nil && [path isEqualToString:canonical];
}

static BOOL FCPCCUnsignedIdentityNumberIsValid(NSNumber *number) {
    if (number == nil || number.objCType == NULL) {
        return NO;
    }
    switch (number.objCType[0]) {
        case 's':
        case 'i':
        case 'l':
        case 'q':
            return number.longLongValue > 0;
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            return number.unsignedLongLongValue > 0;
        default:
            return NO;
    }
}

@interface FCPCCLibraryManifestRecord ()
+ (nullable instancetype)bundledManifest;
@end

@implementation FCPCCLibraryIdentity

- (instancetype)initWithCanonicalPath:(NSString *)canonicalPath
                               device:(NSNumber *)device
                                inode:(NSNumber *)inode
                        persistentUID:(NSString *)persistentUID {
    self = [super init];
    if (self != nil) {
        _canonicalPath = [canonicalPath copy];
        _device = [device copy];
        _inode = [inode copy];
        _persistentUID = [persistentUID copy];
    }
    return self;
}

@end

@implementation FCPCCLibraryManifestRecord

- (instancetype)initWithCanonicalPath:(NSString *)canonicalPath
                        expectedDevice:(NSNumber *)expectedDevice
                         expectedInode:(NSNumber *)expectedInode
                         persistentUID:(NSString *)persistentUID
                     verificationState:(NSString *)verificationState {
    self = [super init];
    if (self != nil) {
        _canonicalPath = [canonicalPath copy];
        _expectedDevice = [expectedDevice copy];
        _expectedInode = [expectedInode copy];
        _persistentUID = [persistentUID copy];
        _verificationState = [verificationState copy];
    }
    return self;
}

+ (instancetype)bundledManifest {
    NSBundle *runtimeBundle = [NSBundle bundleForClass:self];
    NSURL *manifestURL = [runtimeBundle URLForResource:@"FCPCommandConsoleLibraryManifest" withExtension:@"json"];
    if (manifestURL == nil) {
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfURL:manifestURL options:0 error:nil];
    if (data == nil) {
        return nil;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary<NSString *, id> *dictionary = object;
    id path = dictionary[@"canonical_path"];
    id device = dictionary[@"expected_device"];
    id inode = dictionary[@"expected_inode"];
    id uid = dictionary[@"persistent_uid"];
    id state = dictionary[@"verification_state"];
    if (![path isKindOfClass:[NSString class]] || ![state isKindOfClass:[NSString class]]) {
        return nil;
    }

    return [[self alloc] initWithCanonicalPath:path
                                expectedDevice:[device isKindOfClass:[NSNumber class]] ? device : nil
                                 expectedInode:[inode isKindOfClass:[NSNumber class]] ? inode : nil
                                 persistentUID:[uid isKindOfClass:[NSString class]] ? uid : nil
                             verificationState:state];
}

- (BOOL)isComplete {
    return FCPCCIsExactCanonicalFilePath(self.canonicalPath)
        && FCPCCUnsignedIdentityNumberIsValid(self.expectedDevice)
        && FCPCCUnsignedIdentityNumberIsValid(self.expectedInode)
        && self.persistentUID.length > 0;
}

@end

@implementation FCPCCReadOnlyLibrarySet

- (instancetype)initWithLibraries:(NSArray<FCPCCLibraryIdentity *> *)libraries
                completeTraversal:(BOOL)completeTraversal
                           reason:(NSString *)reason {
    self = [super init];
    if (self != nil) {
        _libraries = [libraries copy];
        _completeTraversal = completeTraversal;
        _reason = [reason copy];
    }
    return self;
}

@end

@interface FCPCCLibraryInvariantResult ()
- (instancetype)initWithDisposition:(FCPCCLibraryInvariantDisposition)disposition
                              reason:(NSString *)reason;
@end

@implementation FCPCCLibraryInvariantResult

- (instancetype)initWithDisposition:(FCPCCLibraryInvariantDisposition)disposition
                              reason:(NSString *)reason {
    self = [super init];
    if (self != nil) {
        _disposition = disposition;
        _reason = [reason copy];
        _verified = disposition == FCPCCLibraryInvariantDispositionVerified;
    }
    return self;
}

@end

FCPCCLibraryInvariantResult *FCPCCEvaluateLibraryInvariant(FCPCCReadOnlyLibrarySet *librarySet,
                                                             FCPCCLibraryManifestRecord *manifest) {
    if (librarySet == nil || !librarySet.isCompleteTraversal) {
        NSString *reason = librarySet.reason.length > 0 ? librarySet.reason : @"library_traversal_incomplete";
        return [[FCPCCLibraryInvariantResult alloc] initWithDisposition:FCPCCLibraryInvariantDispositionTraversalUnsupported
                                                                   reason:reason];
    }
    if (librarySet.libraries.count != 1) {
        return [[FCPCCLibraryInvariantResult alloc] initWithDisposition:FCPCCLibraryInvariantDispositionOpenLibraryCountInvalid
                                                                   reason:@"exactly_one_open_library_required"];
    }
    if (manifest == nil) {
        return [[FCPCCLibraryInvariantResult alloc] initWithDisposition:FCPCCLibraryInvariantDispositionManifestAbsent
                                                                   reason:@"library_manifest_absent"];
    }
    if (!manifest.isComplete) {
        NSString *reason = manifest.verificationState.length > 0 ? manifest.verificationState : @"library_manifest_incomplete";
        return [[FCPCCLibraryInvariantResult alloc] initWithDisposition:FCPCCLibraryInvariantDispositionManifestIncomplete
                                                                   reason:reason];
    }

    id candidate = librarySet.libraries.firstObject;
    if (![candidate isKindOfClass:[FCPCCLibraryIdentity class]]) {
        return [[FCPCCLibraryInvariantResult alloc] initWithDisposition:FCPCCLibraryInvariantDispositionTraversalUnsupported
                                                                   reason:@"library_traversal_identity_type_unsupported"];
    }
    FCPCCLibraryIdentity *observed = candidate;
    BOOL observedIdentityIsWellFormed = FCPCCIsExactCanonicalFilePath(observed.canonicalPath)
        && FCPCCUnsignedIdentityNumberIsValid(observed.device)
        && FCPCCUnsignedIdentityNumberIsValid(observed.inode)
        && observed.persistentUID.length > 0;
    BOOL matches = observedIdentityIsWellFormed
        && [observed.canonicalPath isEqualToString:manifest.canonicalPath]
        && [observed.device isEqualToNumber:manifest.expectedDevice]
        && [observed.inode isEqualToNumber:manifest.expectedInode]
        && [observed.persistentUID isEqualToString:manifest.persistentUID];
    if (!matches) {
        return [[FCPCCLibraryInvariantResult alloc] initWithDisposition:FCPCCLibraryInvariantDispositionIdentityMismatch
                                                                   reason:@"library_path_device_inode_or_persistent_uid_mismatch"];
    }

    return [[FCPCCLibraryInvariantResult alloc] initWithDisposition:FCPCCLibraryInvariantDispositionVerified
                                                               reason:@"exactly_one_library_verified"];
}

static FCPCCGateStatus *FCPCCGateStatusFromLibraryInvariantResult(FCPCCLibraryInvariantResult *result) {
    FCPCCGateDisposition disposition = FCPCCGateDispositionTraversalUnverified;
    switch (result.disposition) {
        case FCPCCLibraryInvariantDispositionVerified:
            disposition = FCPCCGateDispositionVerified;
            break;
        case FCPCCLibraryInvariantDispositionManifestAbsent:
            disposition = FCPCCGateDispositionManifestAbsent;
            break;
        case FCPCCLibraryInvariantDispositionManifestIncomplete:
            disposition = FCPCCGateDispositionManifestUnverifiable;
            break;
        case FCPCCLibraryInvariantDispositionTraversalUnsupported:
            disposition = FCPCCGateDispositionTraversalUnverified;
            break;
        case FCPCCLibraryInvariantDispositionOpenLibraryCountInvalid:
            disposition = FCPCCGateDispositionOpenLibraryCountInvalid;
            break;
        case FCPCCLibraryInvariantDispositionIdentityMismatch:
            disposition = FCPCCGateDispositionLibraryIdentityMismatch;
            break;
    }
    return [[FCPCCGateStatus alloc] initWithDisposition:disposition summary:result.reason];
}

static BOOL FCPCCValidTimelineRange(CMTimeRange range) {
    return CMTIMERANGE_IS_VALID(range)
        && CMTIME_IS_VALID(range.start)
        && CMTIME_IS_VALID(range.duration)
        && range.duration.value >= 0;
}

static BOOL FCPCCValidHandleTime(CMTime time) {
    return CMTIME_IS_VALID(time) && time.value >= 0;
}

static BOOL FCPCCBoundedNonemptyString(NSString *value) {
    return value.length > 0 && value.length <= 1024;
}

static BOOL FCPCCLowercaseSHA256HexStringIsValid(NSString *value) {
    if (value.length != CC_SHA256_DIGEST_LENGTH * 2) {
        return NO;
    }
    for (NSUInteger index = 0; index < value.length; index += 1) {
        unichar character = [value characterAtIndex:index];
        if (!((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f'))) {
            return NO;
        }
    }
    return YES;
}

@implementation FCPCCTimelineItemSnapshot

- (instancetype)initWithStableItemIdentifier:(NSString *)stableItemIdentifier
                          canonicalSourcePath:(NSString *)canonicalSourcePath
                                sourceSHA256:(NSString *)sourceSHA256
                        sourceIdentityReason:(NSString *)sourceIdentityReason
                       primaryStorylineIndex:(NSInteger)primaryStorylineIndex
       previousPrimaryStorylineItemIdentifier:(NSString *)previousPrimaryStorylineItemIdentifier
           nextPrimaryStorylineItemIdentifier:(NSString *)nextPrimaryStorylineItemIdentifier
                               timelineRange:(CMTimeRange)timelineRange
                            hasTimelineRange:(BOOL)hasTimelineRange
                               leadingHandle:(CMTime)leadingHandle
                        hasLeadingHandle:(BOOL)hasLeadingHandle
                              trailingHandle:(CMTime)trailingHandle
                       hasTrailingHandle:(BOOL)hasTrailingHandle {
    self = [super init];
    if (self != nil) {
        BOOL sourceIdentityIsValid = canonicalSourcePath.length > 0
            && FCPCCIsExactCanonicalFilePath(canonicalSourcePath)
            && FCPCCLowercaseSHA256HexStringIsValid(sourceSHA256);
        NSString *normalizedSourceIdentityReason = sourceIdentityIsValid
            ? @"source_identity_available"
            : (sourceIdentityReason.length > 0
            ? sourceIdentityReason
            : @"source_identity_unavailable");
        if (!sourceIdentityIsValid && (canonicalSourcePath.length > 0 || sourceSHA256.length > 0)) {
            normalizedSourceIdentityReason = @"source_identity_unavailable_invalid_canonical_path_or_sha256";
        }
        _stableItemIdentifier = [stableItemIdentifier copy];
        _canonicalSourcePath = sourceIdentityIsValid ? [canonicalSourcePath copy] : nil;
        _sourceSHA256 = sourceIdentityIsValid ? [sourceSHA256 copy] : nil;
        _sourceIdentityReason = [normalizedSourceIdentityReason copy];
        _primaryStorylineIndex = primaryStorylineIndex;
        _previousPrimaryStorylineItemIdentifier = [previousPrimaryStorylineItemIdentifier copy];
        _nextPrimaryStorylineItemIdentifier = [nextPrimaryStorylineItemIdentifier copy];
        _hasTimelineRange = hasTimelineRange && FCPCCValidTimelineRange(timelineRange);
        _timelineRange = _hasTimelineRange ? timelineRange : kCMTimeRangeInvalid;
        _hasLeadingHandle = hasLeadingHandle && FCPCCValidHandleTime(leadingHandle);
        _leadingHandle = _hasLeadingHandle ? leadingHandle : kCMTimeInvalid;
        _hasTrailingHandle = hasTrailingHandle && FCPCCValidHandleTime(trailingHandle);
        _trailingHandle = _hasTrailingHandle ? trailingHandle : kCMTimeInvalid;
    }
    return self;
}

@end

@interface FCPCCReadOnlyContextSnapshot ()
- (instancetype)initWithDisposition:(FCPCCReadOnlyContextDisposition)disposition
                              reason:(NSString *)reason
                   activeProjectName:(NSString *)activeProjectName
                           frameSize:(CGSize)frameSize
                       hasFrameSize:(BOOL)hasFrameSize
                       frameDuration:(CMTime)frameDuration
                   hasFrameDuration:(BOOL)hasFrameDuration
               selectedTimelineItems:(NSArray<FCPCCTimelineItemSnapshot *> *)selectedTimelineItems
                   selectionRevision:(NSString *)selectionRevision
                    timelineRevision:(NSString *)timelineRevision;
@end

@implementation FCPCCReadOnlyContextSnapshot

- (instancetype)initWithDisposition:(FCPCCReadOnlyContextDisposition)disposition
                              reason:(NSString *)reason
                   activeProjectName:(NSString *)activeProjectName
                           frameSize:(CGSize)frameSize
                       hasFrameSize:(BOOL)hasFrameSize
                       frameDuration:(CMTime)frameDuration
                   hasFrameDuration:(BOOL)hasFrameDuration
               selectedTimelineItems:(NSArray<FCPCCTimelineItemSnapshot *> *)selectedTimelineItems
                   selectionRevision:(NSString *)selectionRevision
                    timelineRevision:(NSString *)timelineRevision {
    self = [super init];
    if (self != nil) {
        NSString *normalizedReason = reason.length > 0 ? reason : @"read_only_context_unavailable";
        _disposition = disposition;
        _reason = [normalizedReason copy];
        _activeProjectName = [activeProjectName copy];
        _hasFrameSize = hasFrameSize && isfinite(frameSize.width) && isfinite(frameSize.height)
            && frameSize.width > 0.0 && frameSize.height > 0.0;
        _frameSize = _hasFrameSize ? frameSize : CGSizeZero;
        _hasFrameDuration = hasFrameDuration && CMTIME_IS_VALID(frameDuration) && frameDuration.value > 0 && frameDuration.timescale > 0;
        _frameDuration = _hasFrameDuration ? frameDuration : kCMTimeInvalid;
        _selectedTimelineItems = [selectedTimelineItems copy];
        _selectionRevision = [selectionRevision copy];
        _timelineRevision = [timelineRevision copy];
        _readOnlyCapable = disposition == FCPCCReadOnlyContextDispositionReady
            || disposition == FCPCCReadOnlyContextDispositionPartialUnsupported;
        _mutationCapable = NO;
    }
    return self;
}

+ (instancetype)unsupportedWithReason:(NSString *)reason {
    return [[self alloc] initWithDisposition:FCPCCReadOnlyContextDispositionUnsupportedAPI
                                      reason:reason
                           activeProjectName:nil
                                   frameSize:CGSizeZero
                               hasFrameSize:NO
                               frameDuration:kCMTimeInvalid
                           hasFrameDuration:NO
                       selectedTimelineItems:@[]
                           selectionRevision:nil
                            timelineRevision:nil];
}

+ (instancetype)snapshotWithDisposition:(FCPCCReadOnlyContextDisposition)disposition
                                  reason:(NSString *)reason
                       activeProjectName:(NSString *)activeProjectName
                               frameSize:(CGSize)frameSize
                           hasFrameSize:(BOOL)hasFrameSize
                           frameDuration:(CMTime)frameDuration
                       hasFrameDuration:(BOOL)hasFrameDuration
                   selectedTimelineItems:(NSArray<FCPCCTimelineItemSnapshot *> *)selectedTimelineItems
                       selectionRevision:(NSString *)selectionRevision
                        timelineRevision:(NSString *)timelineRevision {
    NSArray<FCPCCTimelineItemSnapshot *> *items = [selectedTimelineItems copy] ?: @[];
    for (id item in items) {
        if (![item isKindOfClass:[FCPCCTimelineItemSnapshot class]] || !FCPCCBoundedNonemptyString(((FCPCCTimelineItemSnapshot *)item).stableItemIdentifier)) {
            return [self unsupportedWithReason:@"selected_timeline_item_snapshot_invalid"];
        }
    }
    if ((selectionRevision != nil && !FCPCCBoundedNonemptyString(selectionRevision))
        || (timelineRevision != nil && !FCPCCBoundedNonemptyString(timelineRevision))) {
        return [self unsupportedWithReason:@"read_only_revision_invalid"];
    }
    if (items.count == 0 && disposition != FCPCCReadOnlyContextDispositionUnsupportedAPI) {
        return [[self alloc] initWithDisposition:FCPCCReadOnlyContextDispositionNoSelection
                                          reason:@"no_timeline_selection"
                               activeProjectName:activeProjectName
                                       frameSize:frameSize
                                   hasFrameSize:hasFrameSize
                                   frameDuration:frameDuration
                               hasFrameDuration:hasFrameDuration
                           selectedTimelineItems:@[]
                               selectionRevision:nil
                                timelineRevision:timelineRevision];
    }
    return [[self alloc] initWithDisposition:disposition
                                      reason:reason
                           activeProjectName:activeProjectName
                                   frameSize:frameSize
                               hasFrameSize:hasFrameSize
                               frameDuration:frameDuration
                           hasFrameDuration:hasFrameDuration
                       selectedTimelineItems:items
                           selectionRevision:selectionRevision
                            timelineRevision:timelineRevision];
}

@end

FCPCCReadOnlyContextSnapshot *FCPCCValidateReadOnlySnapshotAgainstTimelineRevision(
    FCPCCReadOnlyContextSnapshot *snapshot,
    NSString *currentTimelineRevision) {
    if (snapshot == nil) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:@"read_only_snapshot_absent"];
    }
    if (!snapshot.isReadOnlyCapable) {
        return snapshot;
    }
    if (snapshot.timelineRevision.length == 0 || currentTimelineRevision.length == 0
        || ![snapshot.timelineRevision isEqualToString:currentTimelineRevision]) {
        return [FCPCCReadOnlyContextSnapshot snapshotWithDisposition:FCPCCReadOnlyContextDispositionStaleRevision
                                                               reason:@"timeline_revision_stale_or_unavailable"
                                                    activeProjectName:snapshot.activeProjectName
                                                            frameSize:snapshot.frameSize
                                                        hasFrameSize:snapshot.hasFrameSize
                                                        frameDuration:snapshot.frameDuration
                                                    hasFrameDuration:snapshot.hasFrameDuration
                                                selectedTimelineItems:snapshot.selectedTimelineItems
                                                    selectionRevision:snapshot.selectionRevision
                                                     timelineRevision:snapshot.timelineRevision];
    }
    return snapshot;
}

@interface FCPCCRuntimeContainmentGate : NSObject
- (FCPCCGateStatus *)evaluate;
@end

static BOOL FCPCCCopiedHostMASReceiptMatches(void) {
    NSString *hostBundlePath = [NSBundle.mainBundle.bundlePath stringByStandardizingPath];
    NSString *expectedHostBundlePath = [FCPCCExpectedCopiedHostBundlePath stringByStandardizingPath];
    if (hostBundlePath.length == 0 || ![hostBundlePath isEqualToString:expectedHostBundlePath]) {
        return NO;
    }
    NSString *receiptPath = [[expectedHostBundlePath stringByAppendingPathComponent:FCPCCExpectedMASReceiptRelativePath] stringByStandardizingPath];
    return FCPCCFileSHA256MatchesExpectedHex(receiptPath, FCPCCExpectedMASReceiptSHA256);
}

@implementation FCPCCRuntimeContainmentGate

- (FCPCCGateStatus *)evaluate {
    NSBundle *hostBundle = NSBundle.mainBundle;
    NSString *hostIdentifier = hostBundle.bundleIdentifier ?: @"";
    NSString *hostVersion = [hostBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    NSString *hostBuild = [hostBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
    NSString *hostBundlePath = [hostBundle.bundlePath stringByStandardizingPath];
    NSString *runtimePath = [[NSBundle bundleForClass:[self class]].bundlePath stringByStandardizingPath];
    NSString *expectedHostBundlePath = [FCPCCExpectedCopiedHostBundlePath stringByStandardizingPath];
    NSString *expectedRuntimePath = [[expectedHostBundlePath stringByAppendingPathComponent:@"Contents/Frameworks"] stringByAppendingPathComponent:FCPCCExpectedRuntimeFrameworkName];
    BOOL exactCopiedHostPath = hostBundlePath.length > 0 && [hostBundlePath isEqualToString:expectedHostBundlePath];
    BOOL exactRuntimePath = runtimePath.length > 0 && [[runtimePath stringByStandardizingPath] isEqualToString:[expectedRuntimePath stringByStandardizingPath]];
    BOOL valid = [hostIdentifier isEqualToString:FCPCCExpectedHostBundleIdentifier]
        && [hostVersion isEqualToString:FCPCCExpectedHostVersion]
        && [hostBuild isEqualToString:FCPCCExpectedHostBuild]
        && exactCopiedHostPath
        && exactRuntimePath
        && FCPCCCopiedHostMASReceiptMatches();
    if (!valid) {
        return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionHostUnverified
                                                    summary:@"copied_app_or_runtime_containment_unverified"];
    }
    return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionVerified
                                                summary:@"copied_app_runtime_containment_verified"];
}

@end

// This is one fixed ObjC caller compatibility bridge. The runtime never
// derives a selector or class name from
// input or a bundled resource. After every image, ABI, and implementation
// check below has passed, it retains the reviewed setter implementation and
// substitutes only its outer query provider with a provider that asynchronously
// completes with nil demo metadata. That preserves the coordinator's setter
// and completion progression without invoking the copied app's network-backed
// demo metadata query path.
typedef NS_ENUM(NSUInteger, FCPCCOnboardingFrameworkIdentityDisposition) {
    FCPCCOnboardingFrameworkIdentityDispositionMatches = 0,
    FCPCCOnboardingFrameworkIdentityDispositionImageUnavailable = 1,
    FCPCCOnboardingFrameworkIdentityDispositionPathMismatch = 2,
    FCPCCOnboardingFrameworkIdentityDispositionHashMismatch = 3,
    FCPCCOnboardingFrameworkIdentityDispositionUUIDMismatch = 4,
    FCPCCOnboardingFrameworkIdentityDispositionImplementationMismatch = 5,
};

typedef NS_ENUM(NSUInteger, FCPCCCopiedHostIdentityDisposition) {
    FCPCCCopiedHostIdentityDispositionMatches = 0,
    FCPCCCopiedHostIdentityDispositionImageUnavailable = 1,
    FCPCCCopiedHostIdentityDispositionPathMismatch = 2,
    FCPCCCopiedHostIdentityDispositionUUIDMismatch = 3,
    FCPCCCopiedHostIdentityDispositionImplementationMismatch = 4,
};

static const uint8_t *FCPCCExpectedCurrentArchitectureHostUUID(void) {
#if defined(__arm64__)
    return FCPCCExpectedHostArm64UUID;
#elif defined(__x86_64__)
    return FCPCCExpectedHostX86_64UUID;
#else
    return NULL;
#endif
}

static const uint8_t *FCPCCExpectedCurrentArchitectureOnboardingFrameworkUUID(void) {
#if defined(__arm64__)
    return FCPCCExpectedOnboardingFrameworkArm64UUID;
#elif defined(__x86_64__)
    return FCPCCExpectedOnboardingFrameworkX86_64UUID;
#else
    return NULL;
#endif
}

static uintptr_t FCPCCExpectedCurrentArchitectureOnboardingQuerySetterOffset(void) {
#if defined(__arm64__)
    return 0x1313c;
#elif defined(__x86_64__)
    return 0x13cc0;
#else
    return 0;
#endif
}

static uintptr_t FCPCCExpectedCurrentArchitectureCloudFirstLaunchSetupOffset(void) {
#if defined(__arm64__)
    return 0x924e8;
#elif defined(__x86_64__)
    return 0xc74c0;
#else
    return 0;
#endif
}

static BOOL FCPCCLoadedMachOImageHasExpectedUUID(const struct mach_header *header,
                                                  const uint8_t expectedUUID[16]) {
    if (header == NULL || expectedUUID == NULL || header->magic != MH_MAGIC_64) {
        return NO;
    }

    const struct mach_header_64 *header64 = (const struct mach_header_64 *)header;
    const uint8_t *cursor = (const uint8_t *)(header64 + 1);
    uint32_t remainingBytes = header64->sizeofcmds;
    for (uint32_t index = 0; index < header64->ncmds; index += 1) {
        if (remainingBytes < sizeof(struct load_command)) {
            return NO;
        }
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(struct load_command) || command->cmdsize > remainingBytes) {
            return NO;
        }
        if (command->cmd == LC_UUID) {
            if (command->cmdsize != sizeof(struct uuid_command)) {
                return NO;
            }
            const struct uuid_command *uuidCommand = (const struct uuid_command *)command;
            return memcmp(uuidCommand->uuid, expectedUUID, sizeof(uuidCommand->uuid)) == 0;
        }
        cursor += command->cmdsize;
        remainingBytes -= command->cmdsize;
    }
    return NO;
}

static BOOL FCPCCSHA256DigestMatchesExpectedHex(const uint8_t digest[CC_SHA256_DIGEST_LENGTH],
                                                 const char *expectedHex) {
    static const char hexadecimal[] = "0123456789abcdef";
    if (digest == NULL || expectedHex == NULL || strlen(expectedHex) != CC_SHA256_DIGEST_LENGTH * 2) {
        return NO;
    }

    char actualHex[CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index += 1) {
        actualHex[index * 2] = hexadecimal[(digest[index] >> 4) & 0x0F];
        actualHex[index * 2 + 1] = hexadecimal[digest[index] & 0x0F];
    }
    return memcmp(actualHex, expectedHex, sizeof(actualHex)) == 0;
}

static BOOL FCPCCFileSHA256MatchesExpectedHex(NSString *path, const char *expectedHex) {
    const char *fileSystemPath = path.fileSystemRepresentation;
    if (path.length == 0 || fileSystemPath == NULL) {
        return NO;
    }

    int descriptor = open(fileSystemPath, O_RDONLY | O_CLOEXEC);
    if (descriptor < 0) {
        return NO;
    }

    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    BOOL readSucceeded = YES;
    uint8_t buffer[32768];
    for (;;) {
        ssize_t bytesRead = read(descriptor, buffer, sizeof(buffer));
        if (bytesRead < 0) {
            readSucceeded = NO;
            break;
        }
        if (bytesRead == 0) {
            break;
        }
        CC_SHA256_Update(&context, buffer, (CC_LONG)bytesRead);
    }
    if (close(descriptor) != 0 || !readSucceeded) {
        return NO;
    }

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    return FCPCCSHA256DigestMatchesExpectedHex(digest, expectedHex);
}

static NSString *FCPCCExpectedOnboardingFrameworkExecutablePath(void) {
    NSString *hostBundlePath = [NSBundle.mainBundle.bundlePath stringByStandardizingPath];
    if (hostBundlePath.length == 0) {
        return nil;
    }
    return [[hostBundlePath stringByAppendingPathComponent:FCPCCExpectedOnboardingFrameworkRelativeExecutablePath] stringByStandardizingPath];
}

static BOOL FCPCCCopiedHostImageUUIDMatches(void) {
    const char *mainImageName = _dyld_get_image_name(0);
    const struct mach_header *mainImageHeader = _dyld_get_image_header(0);
    const uint8_t *expectedUUID = FCPCCExpectedCurrentArchitectureHostUUID();
    NSString *expectedPath = [[FCPCCExpectedCopiedHostBundlePath stringByAppendingPathComponent:@"Contents/MacOS/Final Cut Pro"] stringByStandardizingPath];
    NSString *loadedPath = mainImageName == NULL ? nil : [[NSString alloc] initWithUTF8String:mainImageName];
    if (expectedUUID == NULL || expectedPath.length == 0 || loadedPath == nil
        || ![[loadedPath stringByStandardizingPath] isEqualToString:expectedPath]) {
        return NO;
    }
    return FCPCCLoadedMachOImageHasExpectedUUID(mainImageHeader, expectedUUID);
}

static FCPCCCopiedHostIdentityDisposition FCPCCCopiedHostIdentityForImplementation(IMP implementation,
                                                                                      uintptr_t expectedOffset) {
    Dl_info image = {0};
    if (implementation == NULL
        || expectedOffset == 0
        || dladdr((const void *)implementation, &image) == 0
        || image.dli_fbase == NULL
        || image.dli_fname == NULL) {
        return FCPCCCopiedHostIdentityDispositionImageUnavailable;
    }

    NSString *expectedPath = [[FCPCCExpectedCopiedHostBundlePath stringByAppendingPathComponent:@"Contents/MacOS/Final Cut Pro"] stringByStandardizingPath];
    NSString *loadedPath = [[NSString alloc] initWithUTF8String:image.dli_fname];
    if (expectedPath.length == 0 || loadedPath == nil
        || ![[loadedPath stringByStandardizingPath] isEqualToString:expectedPath]) {
        return FCPCCCopiedHostIdentityDispositionPathMismatch;
    }

    const uint8_t *expectedUUID = FCPCCExpectedCurrentArchitectureHostUUID();
    if (expectedUUID == NULL
        || !FCPCCLoadedMachOImageHasExpectedUUID((const struct mach_header *)image.dli_fbase, expectedUUID)) {
        return FCPCCCopiedHostIdentityDispositionUUIDMismatch;
    }

    uintptr_t actualOffset = (uintptr_t)implementation - (uintptr_t)image.dli_fbase;
    if (actualOffset != expectedOffset) {
        return FCPCCCopiedHostIdentityDispositionImplementationMismatch;
    }
    return FCPCCCopiedHostIdentityDispositionMatches;
}

static FCPCCOnboardingFrameworkIdentityDisposition FCPCCOnboardingFrameworkIdentityForImplementation(IMP implementation) {
    Dl_info image = {0};
    if (implementation == NULL
        || dladdr((const void *)implementation, &image) == 0
        || image.dli_fbase == NULL
        || image.dli_fname == NULL) {
        return FCPCCOnboardingFrameworkIdentityDispositionImageUnavailable;
    }

    NSString *expectedPath = FCPCCExpectedOnboardingFrameworkExecutablePath();
    NSString *loadedPath = [[NSString alloc] initWithUTF8String:image.dli_fname];
    if (expectedPath == nil || loadedPath == nil
        || ![[loadedPath stringByStandardizingPath] isEqualToString:expectedPath]) {
        return FCPCCOnboardingFrameworkIdentityDispositionPathMismatch;
    }
    if (!FCPCCFileSHA256MatchesExpectedHex(loadedPath, FCPCCExpectedOnboardingFrameworkSHA256)) {
        return FCPCCOnboardingFrameworkIdentityDispositionHashMismatch;
    }
    const uint8_t *expectedUUID = FCPCCExpectedCurrentArchitectureOnboardingFrameworkUUID();
    if (expectedUUID == NULL
        || !FCPCCLoadedMachOImageHasExpectedUUID((const struct mach_header *)image.dli_fbase, expectedUUID)) {
        return FCPCCOnboardingFrameworkIdentityDispositionUUIDMismatch;
    }
    uintptr_t expectedOffset = FCPCCExpectedCurrentArchitectureOnboardingQuerySetterOffset();
    uintptr_t actualOffset = (uintptr_t)implementation - (uintptr_t)image.dli_fbase;
    if (expectedOffset == 0 || actualOffset != expectedOffset) {
        return FCPCCOnboardingFrameworkIdentityDispositionImplementationMismatch;
    }
    return FCPCCOnboardingFrameworkIdentityDispositionMatches;
}

typedef void (^FCPCCOnboardingDemoProjectInfoCompletion)(NSDictionary<NSString *, id> * _Nullable demoProjectInfo);
typedef void (^FCPCCOnboardingQueryDemoProjectInfoProvider)(FCPCCOnboardingDemoProjectInfoCompletion _Nullable completion);
typedef void (*FCPCCOnboardingQueryDemoProjectInfoSetter)(id, SEL, FCPCCOnboardingQueryDemoProjectInfoProvider);

static FCPCCOnboardingQueryDemoProjectInfoSetter FCPCCVerifiedOnboardingQueryDemoProjectInfoSetter = NULL;

// The reviewed property has Swift shape
// ((([String: Any]?) -> ()) -> ())?. Keep the completion asynchronous on the
// main queue so the replacement preserves the original provider's async
// contract. A nil payload denotes no demo metadata; it is not a fabricated
// project or error.
static void FCPCCCompleteOnboardingDemoProjectInfoAsyncWithNil(FCPCCOnboardingDemoProjectInfoCompletion completion) {
    if (completion == nil) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil);
    });
}

static void FCPCCForwardOnboardingQueryDemoProjectInfoSetterWithAsyncNilMetadata(id self,
                                                                                   SEL command,
                                                                                   id queryDemoProjectInfo) {
    (void)queryDemoProjectInfo;
    FCPCCOnboardingQueryDemoProjectInfoSetter originalSetter = FCPCCVerifiedOnboardingQueryDemoProjectInfoSetter;
    if (originalSetter == NULL) {
        return;
    }
    FCPCCOnboardingQueryDemoProjectInfoProvider nilMetadataProvider = ^(FCPCCOnboardingDemoProjectInfoCompletion completion) {
        FCPCCCompleteOnboardingDemoProjectInfoAsyncWithNil(completion);
    };
    originalSetter(self, command, nilMetadataProvider);
}

static NSString *FCPCCInstallOnboardingQueryCompatibility(void) {
    static NSString *summary;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
        if (!containment.isVerified) {
            summary = @"onboarding_query_compatibility=host_containment_unverified";
            return;
        }
        if (!FCPCCCopiedHostImageUUIDMatches()) {
            summary = @"onboarding_query_compatibility=host_uuid_unverified";
            return;
        }

        Class targetClass = objc_getClass(FCPCCExpectedOnboardingCoordinatorClassName.UTF8String);
        if (targetClass == Nil) {
            summary = @"onboarding_query_compatibility=class_unavailable";
            return;
        }
        SEL selector = sel_registerName(FCPCCExpectedOnboardingQuerySetterName.UTF8String);
        if (selector == NULL) {
            summary = @"onboarding_query_compatibility=selector_unavailable";
            return;
        }

        Method method = class_getInstanceMethod(targetClass, selector);
        if (method == NULL) {
            summary = class_getClassMethod(targetClass, selector) == NULL
                ? @"onboarding_query_compatibility=method_unavailable"
                : @"onboarding_query_compatibility=method_placement_mismatch";
            return;
        }
        if (method_getNumberOfArguments(method) != 3) {
            summary = @"onboarding_query_compatibility=argument_count_mismatch";
            return;
        }
        char *returnType = method_copyReturnType(method);
        BOOL returnTypeMatches = returnType != NULL && strcmp(returnType, "v") == 0;
        if (returnType != NULL) {
            free(returnType);
        }
        if (!returnTypeMatches) {
            summary = @"onboarding_query_compatibility=return_type_mismatch";
            return;
        }
        const char *typeEncoding = method_getTypeEncoding(method);
        if (typeEncoding == NULL || strcmp(typeEncoding, FCPCCExpectedOnboardingQuerySetterTypeEncoding) != 0) {
            summary = @"onboarding_query_compatibility=type_encoding_mismatch";
            return;
        }

        IMP originalImplementation = method_getImplementation(method);
        switch (FCPCCOnboardingFrameworkIdentityForImplementation(originalImplementation)) {
            case FCPCCOnboardingFrameworkIdentityDispositionMatches:
                break;
            case FCPCCOnboardingFrameworkIdentityDispositionImageUnavailable:
                summary = @"onboarding_query_compatibility=framework_image_unavailable";
                return;
            case FCPCCOnboardingFrameworkIdentityDispositionPathMismatch:
                summary = @"onboarding_query_compatibility=framework_path_mismatch";
                return;
            case FCPCCOnboardingFrameworkIdentityDispositionHashMismatch:
                summary = @"onboarding_query_compatibility=framework_hash_mismatch";
                return;
            case FCPCCOnboardingFrameworkIdentityDispositionUUIDMismatch:
                summary = @"onboarding_query_compatibility=framework_uuid_mismatch";
                return;
            case FCPCCOnboardingFrameworkIdentityDispositionImplementationMismatch:
                summary = @"onboarding_query_compatibility=original_imp_mismatch";
                return;
        }

        FCPCCVerifiedOnboardingQueryDemoProjectInfoSetter = (FCPCCOnboardingQueryDemoProjectInfoSetter)originalImplementation;
        class_replaceMethod(targetClass,
                            selector,
                            (IMP)FCPCCForwardOnboardingQueryDemoProjectInfoSetterWithAsyncNilMetadata,
                            FCPCCExpectedOnboardingQuerySetterTypeEncoding);
        Method installedMethod = class_getInstanceMethod(targetClass, selector);
        const char *installedTypeEncoding = installedMethod == NULL ? NULL : method_getTypeEncoding(installedMethod);
        if (installedMethod == NULL
            || method_getImplementation(installedMethod) != (IMP)FCPCCForwardOnboardingQueryDemoProjectInfoSetterWithAsyncNilMetadata
            || method_getNumberOfArguments(installedMethod) != 3
            || installedTypeEncoding == NULL
            || strcmp(installedTypeEncoding, FCPCCExpectedOnboardingQuerySetterTypeEncoding) != 0) {
            summary = @"onboarding_query_compatibility=post_replacement_verification_failed";
            return;
        }
        summary = @"onboarding_query_compatibility=installed";
    });
    return summary ?: @"onboarding_query_compatibility=unavailable";
}

// This replacement intentionally has no completion parameter name and no
// body. It returns immediately without invoking, copying, retaining,
// inspecting, or otherwise accessing the caller's completion block.
static void FCPCCSuppressCloudFirstLaunchRegistration(id self __attribute__((unused)),
                                                       SEL command __attribute__((unused)),
                                                       id ignoredCompletion __attribute__((unused))) {
}

// The Cloud helper is known to appear while the copied host is finishing its
// AppKit setup.  This is a deliberately bounded availability state machine:
// registration before attempt one, then at most one synchronous WillFinish
// retry only when the class or its instance method was not available yet.
typedef NS_ENUM(NSUInteger, FCPCCCloudFirstLaunchInstallStatus) {
    FCPCCCloudFirstLaunchInstallStatusInstalled = 0,
    FCPCCCloudFirstLaunchInstallStatusClassUnavailable,
    FCPCCCloudFirstLaunchInstallStatusMethodUnavailable,
    FCPCCCloudFirstLaunchInstallStatusMainThreadRequired,
    FCPCCCloudFirstLaunchInstallStatusHostContainmentUnverified,
    FCPCCCloudFirstLaunchInstallStatusHostUUIDUnverified,
    FCPCCCloudFirstLaunchInstallStatusSelectorUnavailable,
    FCPCCCloudFirstLaunchInstallStatusMethodPlacementMismatch,
    FCPCCCloudFirstLaunchInstallStatusReturnTypeMismatch,
    FCPCCCloudFirstLaunchInstallStatusTypeEncodingMismatch,
    FCPCCCloudFirstLaunchInstallStatusHostImageUnavailable,
    FCPCCCloudFirstLaunchInstallStatusHostPathMismatch,
    FCPCCCloudFirstLaunchInstallStatusHostImageUUIDMismatch,
    FCPCCCloudFirstLaunchInstallStatusOriginalImplementationMismatch,
    FCPCCCloudFirstLaunchInstallStatusPostReplacementVerificationFailed,
};

typedef NS_ENUM(NSUInteger, FCPCCCloudFirstLaunchInstallState) {
    FCPCCCloudFirstLaunchInstallStateNew = 0,
    FCPCCCloudFirstLaunchInstallStatePendingWillFinish,
    FCPCCCloudFirstLaunchInstallStateFinished,
};

static const char * const FCPCCCloudFirstLaunchConstructorPhase = "constructor_main_thread_immediate_attempt";
static const char * const FCPCCCloudFirstLaunchWillFinishPhase = "application_will_finish_launching_availability_retry";
static const NSUInteger FCPCCCloudFirstLaunchMaximumAttempts = 2;
static id FCPCCCloudFirstLaunchWillFinishObserver;
static NSUInteger FCPCCCloudFirstLaunchAttemptCount;
static FCPCCCloudFirstLaunchInstallState FCPCCCloudFirstLaunchState = FCPCCCloudFirstLaunchInstallStateNew;

static const char *FCPCCCloudFirstLaunchInstallStatusName(FCPCCCloudFirstLaunchInstallStatus status) {
    switch (status) {
        case FCPCCCloudFirstLaunchInstallStatusInstalled:
            return "installed";
        case FCPCCCloudFirstLaunchInstallStatusClassUnavailable:
            return "class_unavailable";
        case FCPCCCloudFirstLaunchInstallStatusMethodUnavailable:
            return "method_unavailable";
        case FCPCCCloudFirstLaunchInstallStatusMainThreadRequired:
            return "main_thread_required";
        case FCPCCCloudFirstLaunchInstallStatusHostContainmentUnverified:
            return "host_containment_unverified";
        case FCPCCCloudFirstLaunchInstallStatusHostUUIDUnverified:
            return "host_uuid_unverified";
        case FCPCCCloudFirstLaunchInstallStatusSelectorUnavailable:
            return "selector_unavailable";
        case FCPCCCloudFirstLaunchInstallStatusMethodPlacementMismatch:
            return "method_placement_mismatch";
        case FCPCCCloudFirstLaunchInstallStatusReturnTypeMismatch:
            return "return_type_mismatch";
        case FCPCCCloudFirstLaunchInstallStatusTypeEncodingMismatch:
            return "type_encoding_mismatch";
        case FCPCCCloudFirstLaunchInstallStatusHostImageUnavailable:
            return "host_image_unavailable";
        case FCPCCCloudFirstLaunchInstallStatusHostPathMismatch:
            return "host_path_mismatch";
        case FCPCCCloudFirstLaunchInstallStatusHostImageUUIDMismatch:
            return "host_image_uuid_mismatch";
        case FCPCCCloudFirstLaunchInstallStatusOriginalImplementationMismatch:
            return "original_imp_mismatch";
        case FCPCCCloudFirstLaunchInstallStatusPostReplacementVerificationFailed:
            return "post_replacement_verification_failed";
    }
    return "unavailable";
}

static BOOL FCPCCCloudFirstLaunchInstallStatusAllowsAvailabilityRetry(FCPCCCloudFirstLaunchInstallStatus status) {
    return status == FCPCCCloudFirstLaunchInstallStatusClassUnavailable
        || status == FCPCCCloudFirstLaunchInstallStatusMethodUnavailable;
}

static void FCPCCWriteCloudFirstLaunchAttemptDiagnostic(const char *phase,
                                                        NSUInteger attempt,
                                                        FCPCCCloudFirstLaunchInstallStatus status) {
    // This is intentionally one bounded line per actual installation attempt.
    // Its values are fixed phase/status labels and contain no paths or payloads.
    fprintf(stderr,
            "fcpcc_cloud_first_launch phase=%s attempt=%lu status=%s\n",
            phase,
            (unsigned long)attempt,
            FCPCCCloudFirstLaunchInstallStatusName(status));
    fflush(stderr);
}

static FCPCCCloudFirstLaunchInstallStatus FCPCCAttemptCloudFirstLaunchRegistrationSuppression(void) {
    if (![NSThread isMainThread]) {
        return FCPCCCloudFirstLaunchInstallStatusMainThreadRequired;
    }

    FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
    if (!containment.isVerified) {
        return FCPCCCloudFirstLaunchInstallStatusHostContainmentUnverified;
    }
    if (!FCPCCCopiedHostImageUUIDMatches()) {
        return FCPCCCloudFirstLaunchInstallStatusHostUUIDUnverified;
    }

    Class targetClass = objc_getClass(FCPCCExpectedCloudFirstLaunchHelperClassName.UTF8String);
    if (targetClass == Nil) {
        return FCPCCCloudFirstLaunchInstallStatusClassUnavailable;
    }
    SEL selector = sel_registerName(FCPCCExpectedCloudFirstLaunchSetupSelectorName.UTF8String);
    if (selector == NULL) {
        return FCPCCCloudFirstLaunchInstallStatusSelectorUnavailable;
    }

    Method method = class_getInstanceMethod(targetClass, selector);
    if (method == NULL) {
        return class_getClassMethod(targetClass, selector) == NULL
            ? FCPCCCloudFirstLaunchInstallStatusMethodUnavailable
            : FCPCCCloudFirstLaunchInstallStatusMethodPlacementMismatch;
    }
    // This exact ABI contains a nested block signature. On the supported
    // Objective-C runtime, method_getNumberOfArguments parses that encoding as
    // twelve arguments rather than the receiver, selector, and block slots.
    // The full fixed encoding and void return below remain the authoritative
    // ABI checks; a parsed argument-count gate would reject the reviewed IMP.
    char *returnType = method_copyReturnType(method);
    BOOL returnTypeMatches = returnType != NULL && strcmp(returnType, "v") == 0;
    if (returnType != NULL) {
        free(returnType);
    }
    if (!returnTypeMatches) {
        return FCPCCCloudFirstLaunchInstallStatusReturnTypeMismatch;
    }
    const char *typeEncoding = method_getTypeEncoding(method);
    if (typeEncoding == NULL || strcmp(typeEncoding, FCPCCExpectedCloudFirstLaunchSetupTypeEncoding) != 0) {
        return FCPCCCloudFirstLaunchInstallStatusTypeEncodingMismatch;
    }

    IMP originalImplementation = method_getImplementation(method);
    switch (FCPCCCopiedHostIdentityForImplementation(originalImplementation,
                                                      FCPCCExpectedCurrentArchitectureCloudFirstLaunchSetupOffset())) {
        case FCPCCCopiedHostIdentityDispositionMatches:
            break;
        case FCPCCCopiedHostIdentityDispositionImageUnavailable:
            return FCPCCCloudFirstLaunchInstallStatusHostImageUnavailable;
        case FCPCCCopiedHostIdentityDispositionPathMismatch:
            return FCPCCCloudFirstLaunchInstallStatusHostPathMismatch;
        case FCPCCCopiedHostIdentityDispositionUUIDMismatch:
            return FCPCCCloudFirstLaunchInstallStatusHostImageUUIDMismatch;
        case FCPCCCopiedHostIdentityDispositionImplementationMismatch:
            return FCPCCCloudFirstLaunchInstallStatusOriginalImplementationMismatch;
    }

    class_replaceMethod(targetClass,
                        selector,
                        (IMP)FCPCCSuppressCloudFirstLaunchRegistration,
                        FCPCCExpectedCloudFirstLaunchSetupTypeEncoding);
    Method installedMethod = class_getInstanceMethod(targetClass, selector);
    const char *installedTypeEncoding = installedMethod == NULL ? NULL : method_getTypeEncoding(installedMethod);
    char *installedReturnType = installedMethod == NULL ? NULL : method_copyReturnType(installedMethod);
    BOOL installedReturnTypeMatches = installedReturnType != NULL && strcmp(installedReturnType, "v") == 0;
    if (installedReturnType != NULL) {
        free(installedReturnType);
    }
    if (installedMethod == NULL
        || method_getImplementation(installedMethod) != (IMP)FCPCCSuppressCloudFirstLaunchRegistration
        || !installedReturnTypeMatches
        || installedTypeEncoding == NULL
        || strcmp(installedTypeEncoding, FCPCCExpectedCloudFirstLaunchSetupTypeEncoding) != 0) {
        return FCPCCCloudFirstLaunchInstallStatusPostReplacementVerificationFailed;
    }
    return FCPCCCloudFirstLaunchInstallStatusInstalled;
}

static void FCPCCFinishCloudFirstLaunchRegistrationSuppression(void) {
    if (FCPCCCloudFirstLaunchWillFinishObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:FCPCCCloudFirstLaunchWillFinishObserver];
        FCPCCCloudFirstLaunchWillFinishObserver = nil;
    }
    FCPCCCloudFirstLaunchState = FCPCCCloudFirstLaunchInstallStateFinished;
}

static void FCPCCPerformCloudFirstLaunchRegistrationAttempt(const char *phase) {
    if (![NSThread isMainThread]
        || FCPCCCloudFirstLaunchState == FCPCCCloudFirstLaunchInstallStateFinished
        || FCPCCCloudFirstLaunchAttemptCount >= FCPCCCloudFirstLaunchMaximumAttempts) {
        return;
    }

    FCPCCCloudFirstLaunchAttemptCount += 1;
    FCPCCCloudFirstLaunchInstallStatus status = FCPCCAttemptCloudFirstLaunchRegistrationSuppression();
    FCPCCWriteCloudFirstLaunchAttemptDiagnostic(phase, FCPCCCloudFirstLaunchAttemptCount, status);

    if (status == FCPCCCloudFirstLaunchInstallStatusInstalled) {
        FCPCCFinishCloudFirstLaunchRegistrationSuppression();
        return;
    }
    if (FCPCCCloudFirstLaunchAttemptCount == 1
        && FCPCCCloudFirstLaunchInstallStatusAllowsAvailabilityRetry(status)) {
        FCPCCCloudFirstLaunchState = FCPCCCloudFirstLaunchInstallStatePendingWillFinish;
        return;
    }
    FCPCCFinishCloudFirstLaunchRegistrationSuppression();
}

static void FCPCCHandleCloudFirstLaunchWillFinishLaunching(void) {
    // The observer uses a nil queue, so the application notification is handled
    // synchronously on its posting thread. AppKit posts this lifecycle event on
    // the main thread; reject any unexpected delivery rather than patching off-main.
    if (![NSThread isMainThread]) {
        return;
    }
    if (FCPCCCloudFirstLaunchState != FCPCCCloudFirstLaunchInstallStatePendingWillFinish) {
        FCPCCFinishCloudFirstLaunchRegistrationSuppression();
        return;
    }
    FCPCCPerformCloudFirstLaunchRegistrationAttempt(FCPCCCloudFirstLaunchWillFinishPhase);
}

static void FCPCCBeginCloudFirstLaunchRegistrationSuppression(void) {
    // The constructor is expected to run on AppKit's main thread. Do not queue
    // work from a loader initializer: that could move a method mutation past
    // PEAppController dispatch or create a loader/main-queue dependency.
    if (![NSThread isMainThread]
        || FCPCCCloudFirstLaunchState != FCPCCCloudFirstLaunchInstallStateNew) {
        return;
    }

    FCPCCCloudFirstLaunchWillFinishObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:NSApplicationWillFinishLaunchingNotification
                    object:nil
                     queue:nil
                usingBlock:^(__unused NSNotification *note) {
                    FCPCCHandleCloudFirstLaunchWillFinishLaunching();
                }];
    if (FCPCCCloudFirstLaunchWillFinishObserver == nil) {
        FCPCCCloudFirstLaunchState = FCPCCCloudFirstLaunchInstallStateFinished;
        return;
    }
    FCPCCPerformCloudFirstLaunchRegistrationAttempt(FCPCCCloudFirstLaunchConstructorPhase);
}

// Read-only model access is deliberately a closed list of contracts captured
// from the locked SpliceKit reference and the local Final Cut Pro 12.3
// binaries. This resolver performs direct lookups of those literal contracts;
// it never enumerates classes, methods, or caller-provided selector names.
typedef NS_ENUM(NSUInteger, FCPCCFixedMethodImage) {
    FCPCCFixedMethodImageCopiedHost = 0,
    FCPCCFixedMethodImageFlexo = 1,
    FCPCCFixedMethodImageProCore = 2,
};

typedef struct {
    const char *className;
    const char *selectorName;
    const char *typeEncoding;
    const char *returnType;
    NSUInteger argumentCount;
    BOOL classMethod;
    FCPCCFixedMethodImage image;
    uintptr_t arm64ImplementationOffset;
    uintptr_t x86_64ImplementationOffset;
} FCPCCFixedObjCMethodContract;

typedef struct {
    Class targetClass;
    SEL selector;
    IMP implementation;
} FCPCCValidatedFixedMethod;

typedef id (*FCPCCObjectGetter)(id, SEL);
typedef CFTypeRef (*FCPCCCopiedObjectGetter)(id, SEL);
typedef id (*FCPCCSelectedItemsGetter)(id, SEL, BOOL, BOOL);
typedef CGSize (*FCPCCCGSizeGetter)(id, SEL);
typedef CMTime (*FCPCCCMTimeGetter)(id, SEL);
typedef CMTimeRange (*FCPCCCMTimeRangeGetter)(id, SEL);
typedef id (*FCPCCLibraryDocumentInitializer)(id, SEL, NSURL *, BOOL, NSError **);
typedef id (*FCPCCProjectDocumentActionNewProject)(id, SEL, id, NSString *, id, NSString *, NSError **);
typedef id (*FCPCCMediaEventProjectNewClip)(id, SEL, NSURL *, int);
typedef void (*FCPCCVoidObjectMethod)(id, SEL, id);
typedef id (*FCPCCEditActionFactory)(id, SEL, int, BOOL, NSString *);
typedef id (*FCPCCPasteboardInitializer)(id, SEL, NSString *);
typedef BOOL (*FCPCCPasteboardWriteRanges)(id, SEL, NSArray *, NSDictionary *);
typedef id (*FCPCCFigTimeRangeAndObjectFactory)(id, SEL, CMTimeRange, id);
typedef void (*FCPCCTimelinePerformEdit)(id, SEL, id, NSString *, BOOL);

static const char * const FCPCCExpectedObjectGetterTypeEncoding = "@16@0:8";
#if defined(__arm64__)
static const char * const FCPCCExpectedSelectedItemsGetterTypeEncoding = "@24@0:8B16B20";
static const char * const FCPCCExpectedLibraryDocumentCreateTypeEncoding = "@36@0:8@16B24^@28";
static const char * const FCPCCExpectedEditActionCreateTypeEncoding = "@32@0:8i16B20@24";
static const char * const FCPCCExpectedTimelinePerformEditTypeEncoding = "v36@0:8@16@24B32";
static const char * const FCPCCExpectedPasteboardWriteRangesTypeEncoding = "B32@0:8@16@24";
static const char * const FCPCCExpectedNativeBooleanReturnType = "B";
#elif defined(__x86_64__)
static const char * const FCPCCExpectedSelectedItemsGetterTypeEncoding = "@24@0:8c16c20";
static const char * const FCPCCExpectedLibraryDocumentCreateTypeEncoding = "@36@0:8@16c24^@28";
static const char * const FCPCCExpectedEditActionCreateTypeEncoding = "@32@0:8i16c20@24";
static const char * const FCPCCExpectedTimelinePerformEditTypeEncoding = "v36@0:8@16@24c32";
static const char * const FCPCCExpectedPasteboardWriteRangesTypeEncoding = "c32@0:8@16@24";
static const char * const FCPCCExpectedNativeBooleanReturnType = "c";
#else
static const char * const FCPCCExpectedSelectedItemsGetterTypeEncoding = "";
static const char * const FCPCCExpectedLibraryDocumentCreateTypeEncoding = "";
static const char * const FCPCCExpectedEditActionCreateTypeEncoding = "";
static const char * const FCPCCExpectedTimelinePerformEditTypeEncoding = "";
static const char * const FCPCCExpectedPasteboardWriteRangesTypeEncoding = "";
static const char * const FCPCCExpectedNativeBooleanReturnType = "";
#endif

static const FCPCCFixedObjCMethodContract FCPCCCopyActiveLibrariesContract = {
    "FFLibraryDocument", "copyActiveLibraries", "@16@0:8", "@", 2, YES, FCPCCFixedMethodImageFlexo, 0x1d776c, 0x2a9b80,
};
static const FCPCCFixedObjCMethodContract FCPCCLibraryDocumentContract = {
    "FFLibrary", "libraryDocument", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x1bfe88, 0x288910,
};
static const FCPCCFixedObjCMethodContract FCPCCPersistentFileIDContract = {
    "FFLibraryDocument", "persistentFileID", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x1e3b08, 0x2b9af0,
};
static const FCPCCFixedObjCMethodContract FCPCCDisposableLibraryDocumentCreateContract = {
    "FFLibraryDocument", "initWithURL:createDefaultEvent:error:", FCPCCExpectedLibraryDocumentCreateTypeEncoding, "@", 5, NO, FCPCCFixedMethodImageFlexo, 0x1d9278, 0x2abf80,
};
static const FCPCCFixedObjCMethodContract FCPCCLibraryEventsContract = {
    "FFLibrary", "events", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x1cb538, 0x2995a0,
};
static const FCPCCFixedObjCMethodContract FCPCCEventRecordProjectContract = {
    "FFEventRecord", "project", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x1b9cc4, 0x2807e0,
};
static const FCPCCFixedObjCMethodContract FCPCCMediaEventProjectNewClipFromURLContract = {
    "FFMediaEventProject", "newClipFromURL:manageFileType:", "@28@0:8@16i24", "@", 4, NO, FCPCCFixedMethodImageFlexo, 0x235260, 0x32b660,
};
static const FCPCCFixedObjCMethodContract FCPCCMediaEventProjectAddOwnedClipsObjectContract = {
    "FFMediaEventProject", "addOwnedClipsObject:", "v24@0:8@16", "v", 3, NO, FCPCCFixedMethodImageFlexo, 0x231028, 0x326080,
};
static const FCPCCFixedObjCMethodContract FCPCCProjectDocumentActionNewProjectContract = {
    "FFProjectDocument", "actionNewProject:name:sequence:actionName:error:", "@56@0:8@16@24@32@40^@48", "@", 7, YES, FCPCCFixedMethodImageFlexo, 0x2e9b90, 0x425d40,
};
static const FCPCCFixedObjCMethodContract FCPCCEditActionCreateContract = {
    "FFEditAction", "editActionOfKind:backTimed:trackType:", FCPCCExpectedEditActionCreateTypeEncoding, "@", 5, YES, FCPCCFixedMethodImageFlexo, 0xe60a6c, 0x13b8ad0,
};
static const FCPCCFixedObjCMethodContract FCPCCEditorLoadSequenceContract = {
    "PEEditorContainerModule", "loadEditorForSequence:", "v24@0:8@16", "v", 3, NO, FCPCCFixedMethodImageCopiedHost, 0x97f8, 0xb520,
};
static const FCPCCFixedObjCMethodContract FCPCCLibraryDeepLoadedSequencesContract = {
    "FFLibrary", "_deepLoadedSequences", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x1c92b4, 0x2965e0,
};
static const FCPCCFixedObjCMethodContract FCPCCEventRecordDefaultLibraryItemContract = {
    "FFEventRecord", "defaultLibraryItem", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x1ba1e4, 0x280e50,
};
static const FCPCCFixedObjCMethodContract FCPCCMediaEventProjectOwnedClipsContract = {
    "FFMediaEventProject", "ownedClips", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x230ed4, 0x325eb0,
};
static const FCPCCFixedObjCMethodContract FCPCCMediaEventProjectProjectSetContract = {
    "FFMediaEventProject", "projectSet", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x230ee8, 0x325ee0,
};
static const FCPCCFixedObjCMethodContract FCPCCMediaClippedRangeContract = {
    "FFMedia", "clippedRange", "{?={?=qiIq}{?=qiIq}}16@0:8", "{?={?=qiIq}{?=qiIq}}", 2, NO, FCPCCFixedMethodImageFlexo, 0x2915e4, 0x3a8c00,
};
static const FCPCCFixedObjCMethodContract FCPCCMediaIdentifierContract = {
    "FFMedia", "mediaIdentifier", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x291f6c, 0x3aa350,
};
static const FCPCCFixedObjCMethodContract FCPCCMediaOriginalMediaURLContract = {
    "FFMedia", "originalMediaURL", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x292054, 0x3aa450,
};
static const FCPCCFixedObjCMethodContract FCPCCPasteboardInitWithNameContract = {
    "FFPasteboard", "initWithName:", "@24@0:8@16", "@", 3, NO, FCPCCFixedMethodImageFlexo, 0xd6e2cc, 0x12795e0,
};
static const FCPCCFixedObjCMethodContract FCPCCPasteboardWriteRangesContract = {
    "FFPasteboard", "writeRangesOfMedia:options:", FCPCCExpectedPasteboardWriteRangesTypeEncoding, FCPCCExpectedNativeBooleanReturnType, 4, NO, FCPCCFixedMethodImageFlexo, 0xd6f178, 0x127a9c0,
};
static const FCPCCFixedObjCMethodContract FCPCCFigTimeRangeAndObjectFactoryContract = {
    "FigTimeRangeAndObject", "rangeAndObjectWithRange:andObject:", "@72@0:8{?={?=qiIq}{?=qiIq}}16@64", "@", 4, YES, FCPCCFixedMethodImageProCore, 0x89728, 0x92ba9,
};
static const FCPCCFixedObjCMethodContract FCPCCAnchoredTimelinePerformEditContract = {
    "FFAnchoredTimelineModule", "performEditAction:fromPasteboardWithName:fromAnimation:", FCPCCExpectedTimelinePerformEditTypeEncoding, "v", 5, NO, FCPCCFixedMethodImageFlexo, 0xafb634, 0xf052a0,
};
static const FCPCCFixedObjCMethodContract FCPCCActiveEditorContainerContract = {
    "PEAppController", "activeEditorContainer", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageCopiedHost, 0x3e3b0, 0x53210,
};
static const FCPCCFixedObjCMethodContract FCPCCEditorTimelineModuleContract = {
    "PEEditorContainerModule", "timelineModule", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageCopiedHost, 0xc278, 0xea90,
};
static const FCPCCFixedObjCMethodContract FCPCCTimelineSequenceContract = {
    "FFAnchoredTimelineModule", "sequence", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0xaaef98, 0xe93780,
};
static const FCPCCFixedObjCMethodContract FCPCCSelectedItemsContract = {
    "FFAnchoredTimelineModule", "selectedItems:includeItemBeforePlayheadIfLast:", FCPCCExpectedSelectedItemsGetterTypeEncoding, "@", 4, NO, FCPCCFixedMethodImageFlexo, 0xace8ec, 0xec25b0,
};
static const FCPCCFixedObjCMethodContract FCPCCPrimaryObjectContract = {
    "FFAnchoredSequence", "primaryObject", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0xe422c, 0x13f470,
};
static const FCPCCFixedObjCMethodContract FCPCCContainedItemsContract = {
    "FFAnchoredCollection", "containedItems", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x9194c, 0xc7e30,
};
static const FCPCCFixedObjCMethodContract FCPCCDisplayNameContract = {
    "FFAnchoredObject", "displayName", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0xa77f8, 0xe7260,
};
static const FCPCCFixedObjCMethodContract FCPCCIdentifierContract = {
    "FFAnchoredObject", "identifier", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0xa7a50, 0xe75d0,
};
static const FCPCCFixedObjCMethodContract FCPCCRepresentedToolObjectContract = {
    "FFAnchoredObject", "representedToolObject", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x61265c, 0x859350,
};
static const FCPCCFixedObjCMethodContract FCPCCFrameSizeContract = {
    "FFAnchoredObject", "frameSize", "{CGSize=dd}16@0:8", "{CGSize=dd}", 2, NO, FCPCCFixedMethodImageFlexo, 0xb95d8, 0x101140,
};
static const FCPCCFixedObjCMethodContract FCPCCFrameDurationContract = {
    "FFAnchoredObject", "frameDuration", "{?=qiIq}16@0:8", "{?=qiIq}", 2, NO, FCPCCFixedMethodImageFlexo, 0xb95f8, 0x101190,
};
static const FCPCCFixedObjCMethodContract FCPCCRangeContract = {
    "FFAnchoredObject", "timelineRange", "{?={?=qiIq}{?=qiIq}}16@0:8", "{?={?=qiIq}{?=qiIq}}", 2, NO, FCPCCFixedMethodImageFlexo, 0xaed00, 0xf1740,
};

static const uint8_t *FCPCCExpectedCurrentArchitectureFlexoFrameworkUUID(void) {
#if defined(__arm64__)
    return FCPCCExpectedFlexoFrameworkArm64UUID;
#elif defined(__x86_64__)
    return FCPCCExpectedFlexoFrameworkX86_64UUID;
#else
    return NULL;
#endif
}

static const uint8_t *FCPCCExpectedCurrentArchitectureProCoreFrameworkUUID(void) {
#if defined(__arm64__)
    return FCPCCExpectedProCoreFrameworkArm64UUID;
#elif defined(__x86_64__)
    return FCPCCExpectedProCoreFrameworkX86_64UUID;
#else
    return NULL;
#endif
}

static uintptr_t FCPCCExpectedCurrentArchitectureMethodOffset(const FCPCCFixedObjCMethodContract *contract) {
#if defined(__arm64__)
    return contract->arm64ImplementationOffset;
#elif defined(__x86_64__)
    return contract->x86_64ImplementationOffset;
#else
    return 0;
#endif
}

static NSString *FCPCCExpectedFlexoFrameworkExecutablePath(void) {
    NSString *hostBundlePath = [NSBundle.mainBundle.bundlePath stringByStandardizingPath];
    if (hostBundlePath.length == 0) {
        return nil;
    }
    return [[hostBundlePath stringByAppendingPathComponent:FCPCCExpectedFlexoFrameworkRelativeExecutablePath] stringByStandardizingPath];
}

static NSString *FCPCCExpectedProCoreFrameworkExecutablePath(void) {
    NSString *hostBundlePath = [NSBundle.mainBundle.bundlePath stringByStandardizingPath];
    if (hostBundlePath.length == 0) {
        return nil;
    }
    return [[hostBundlePath stringByAppendingPathComponent:FCPCCExpectedProCoreFrameworkRelativeExecutablePath] stringByStandardizingPath];
}

static BOOL FCPCCFlexoFrameworkImageIdentityMatches(const Dl_info *image) {
    if (image == NULL || image->dli_fbase == NULL || image->dli_fname == NULL) {
        return NO;
    }
    NSString *expectedPath = FCPCCExpectedFlexoFrameworkExecutablePath();
    NSString *loadedPath = [[NSString alloc] initWithUTF8String:image->dli_fname];
    if (expectedPath == nil || loadedPath == nil
        || ![[loadedPath stringByStandardizingPath] isEqualToString:expectedPath]) {
        return NO;
    }

    static dispatch_once_t onceToken;
    static BOOL verifiedImageIdentity;
    dispatch_once(&onceToken, ^{
        const uint8_t *expectedUUID = FCPCCExpectedCurrentArchitectureFlexoFrameworkUUID();
        verifiedImageIdentity = expectedUUID != NULL
            && FCPCCFileSHA256MatchesExpectedHex(loadedPath, FCPCCExpectedFlexoFrameworkSHA256)
            && FCPCCLoadedMachOImageHasExpectedUUID((const struct mach_header *)image->dli_fbase, expectedUUID);
    });
    return verifiedImageIdentity;
}

static BOOL FCPCCProCoreFrameworkImageIdentityMatches(const Dl_info *image) {
    if (image == NULL || image->dli_fbase == NULL || image->dli_fname == NULL) {
        return NO;
    }
    NSString *expectedPath = FCPCCExpectedProCoreFrameworkExecutablePath();
    NSString *loadedPath = [[NSString alloc] initWithUTF8String:image->dli_fname];
    if (expectedPath == nil || loadedPath == nil
        || ![[loadedPath stringByStandardizingPath] isEqualToString:expectedPath]) {
        return NO;
    }

    static dispatch_once_t onceToken;
    static BOOL verifiedImageIdentity;
    dispatch_once(&onceToken, ^{
        const uint8_t *expectedUUID = FCPCCExpectedCurrentArchitectureProCoreFrameworkUUID();
        verifiedImageIdentity = expectedUUID != NULL
            && FCPCCFileSHA256MatchesExpectedHex(loadedPath, FCPCCExpectedProCoreFrameworkSHA256)
            && FCPCCLoadedMachOImageHasExpectedUUID((const struct mach_header *)image->dli_fbase, expectedUUID);
    });
    return verifiedImageIdentity;
}

static BOOL FCPCCFlexoImplementationMatchesContract(IMP implementation, uintptr_t expectedOffset) {
    Dl_info image = {0};
    if (implementation == NULL
        || expectedOffset == 0
        || dladdr((const void *)implementation, &image) == 0
        || !FCPCCFlexoFrameworkImageIdentityMatches(&image)) {
        return NO;
    }
    return (uintptr_t)implementation - (uintptr_t)image.dli_fbase == expectedOffset;
}

static BOOL FCPCCProCoreImplementationMatchesContract(IMP implementation, uintptr_t expectedOffset) {
    Dl_info image = {0};
    if (implementation == NULL
        || expectedOffset == 0
        || dladdr((const void *)implementation, &image) == 0
        || !FCPCCProCoreFrameworkImageIdentityMatches(&image)) {
        return NO;
    }
    return (uintptr_t)implementation - (uintptr_t)image.dli_fbase == expectedOffset;
}

static BOOL FCPCCCopiedHostImplementationMatchesContract(IMP implementation, uintptr_t expectedOffset) {
    Dl_info image = {0};
    if (implementation == NULL
        || expectedOffset == 0
        || !FCPCCCopiedHostImageUUIDMatches()
        || dladdr((const void *)implementation, &image) == 0
        || image.dli_fbase == NULL
        || image.dli_fname == NULL) {
        return NO;
    }
    NSString *expectedPath = [NSBundle.mainBundle.executablePath stringByStandardizingPath];
    NSString *loadedPath = [[NSString alloc] initWithUTF8String:image.dli_fname];
    if (expectedPath.length == 0 || loadedPath == nil
        || ![[loadedPath stringByStandardizingPath] isEqualToString:expectedPath]
        || image.dli_fbase != _dyld_get_image_header(0)) {
        return NO;
    }
    return (uintptr_t)implementation - (uintptr_t)image.dli_fbase == expectedOffset;
}

static NSString *FCPCCFixedContractFailureReason(const FCPCCFixedObjCMethodContract *contract, const char *failure) {
    return [NSString stringWithFormat:@"fcp_12_3_fixed_contract_%s_%s_%s", contract->className, contract->selectorName, failure];
}

static BOOL FCPCCResolveFixedMethod(const FCPCCFixedObjCMethodContract *contract,
                                    FCPCCValidatedFixedMethod *resolved,
                                    NSString **reason) {
    Class targetClass = objc_getClass(contract->className);
    if (targetClass == Nil) {
        *reason = FCPCCFixedContractFailureReason(contract, "class_unavailable");
        return NO;
    }
    SEL selector = sel_registerName(contract->selectorName);
    if (selector == NULL) {
        *reason = FCPCCFixedContractFailureReason(contract, "selector_unavailable");
        return NO;
    }
    Method method = contract->classMethod
        ? class_getClassMethod(targetClass, selector)
        : class_getInstanceMethod(targetClass, selector);
    if (method == NULL) {
        *reason = FCPCCFixedContractFailureReason(contract, "method_placement_mismatch");
        return NO;
    }
    if (method_getNumberOfArguments(method) != contract->argumentCount) {
        *reason = FCPCCFixedContractFailureReason(contract, "argument_count_mismatch");
        return NO;
    }
    char *returnType = method_copyReturnType(method);
    BOOL returnTypeMatches = returnType != NULL && strcmp(returnType, contract->returnType) == 0;
    if (returnType != NULL) {
        free(returnType);
    }
    if (!returnTypeMatches) {
        *reason = FCPCCFixedContractFailureReason(contract, "return_type_mismatch");
        return NO;
    }
    const char *typeEncoding = method_getTypeEncoding(method);
    if (typeEncoding == NULL || strcmp(typeEncoding, contract->typeEncoding) != 0) {
        *reason = FCPCCFixedContractFailureReason(contract, "type_encoding_mismatch");
        return NO;
    }
    IMP implementation = method_getImplementation(method);
    uintptr_t expectedOffset = FCPCCExpectedCurrentArchitectureMethodOffset(contract);
    BOOL imageMatches = NO;
    switch (contract->image) {
        case FCPCCFixedMethodImageFlexo:
            imageMatches = FCPCCFlexoImplementationMatchesContract(implementation, expectedOffset);
            break;
        case FCPCCFixedMethodImageProCore:
            imageMatches = FCPCCProCoreImplementationMatchesContract(implementation, expectedOffset);
            break;
        case FCPCCFixedMethodImageCopiedHost:
            imageMatches = FCPCCCopiedHostImplementationMatchesContract(implementation, expectedOffset);
            break;
    }
    if (!imageMatches) {
        *reason = FCPCCFixedContractFailureReason(contract, "image_uuid_hash_or_implementation_mismatch");
        return NO;
    }
    resolved->targetClass = targetClass;
    resolved->selector = selector;
    resolved->implementation = implementation;
    return YES;
}

static BOOL FCPCCReceiverUsesValidatedMethod(id receiver,
                                             const FCPCCValidatedFixedMethod *method,
                                             NSString **reason) {
    if (receiver == nil || ![receiver isKindOfClass:method->targetClass]) {
        *reason = @"fcp_12_3_fixed_contract_receiver_class_mismatch";
        return NO;
    }
    Class dynamicClass = object_getClass(receiver);
    Method resolvedMethod = dynamicClass == Nil ? NULL : class_getInstanceMethod(dynamicClass, method->selector);
    if (resolvedMethod == NULL || method_getImplementation(resolvedMethod) != method->implementation) {
        *reason = @"fcp_12_3_fixed_contract_receiver_implementation_mismatch";
        return NO;
    }
    return YES;
}

static BOOL FCPCCResolvePublicLibraryDocumentFileURLGetter(Class libraryDocumentClass,
                                                           FCPCCValidatedFixedMethod *resolved,
                                                           NSString **reason) {
    SEL selector = sel_registerName("fileURL");
    Method documentMethod = selector == NULL ? NULL : class_getInstanceMethod(libraryDocumentClass, selector);
    Method publicMethod = selector == NULL ? NULL : class_getInstanceMethod([NSDocument class], selector);
    if (documentMethod == NULL || publicMethod == NULL) {
        *reason = @"library_file_url_public_contract_unavailable";
        return NO;
    }
    const char *typeEncoding = method_getTypeEncoding(documentMethod);
    if (method_getNumberOfArguments(documentMethod) != 2
        || typeEncoding == NULL
        || strcmp(typeEncoding, FCPCCExpectedObjectGetterTypeEncoding) != 0
        || method_getImplementation(documentMethod) != method_getImplementation(publicMethod)) {
        *reason = @"library_file_url_public_contract_changed";
        return NO;
    }
    resolved->targetClass = libraryDocumentClass;
    resolved->selector = selector;
    resolved->implementation = method_getImplementation(documentMethod);
    return YES;
}

static NSString *FCPCCNormalizedTypedIdentifier(id value) {
    NSString *identifier = nil;
    if ([value isKindOfClass:[NSString class]]) {
        identifier = value;
    } else if ([value isKindOfClass:[NSUUID class]]) {
        identifier = [value UUIDString];
    }
    return FCPCCBoundedNonemptyString(identifier) ? [identifier copy] : nil;
}

static BOOL FCPCCReadOnlyHostGatePasses(NSString **reason) {
    FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
    if (!containment.isVerified) {
        *reason = containment.summary;
        return NO;
    }
    if (!FCPCCCopiedHostImageUUIDMatches()) {
        *reason = @"copied_host_uuid_unverified";
        return NO;
    }
    return YES;
}

@interface FCPCCFixedModelTraversalAdapter : NSObject
- (FCPCCReadOnlyLibrarySet *)enumerateCompleteOpenLibrarySet;
@end

@implementation FCPCCFixedModelTraversalAdapter

- (FCPCCReadOnlyLibrarySet *)enumerateCompleteOpenLibrarySet {
    NSString *reason = nil;
    if (!FCPCCReadOnlyHostGatePasses(&reason)) {
        return [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[] completeTraversal:NO reason:reason];
    }

    FCPCCValidatedFixedMethod copyActiveLibraries = {0};
    FCPCCValidatedFixedMethod libraryDocument = {0};
    FCPCCValidatedFixedMethod persistentFileID = {0};
    FCPCCValidatedFixedMethod fileURL = {0};
    if (!FCPCCResolveFixedMethod(&FCPCCCopyActiveLibrariesContract, &copyActiveLibraries, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCLibraryDocumentContract, &libraryDocument, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCPersistentFileIDContract, &persistentFileID, &reason)
        || !FCPCCResolvePublicLibraryDocumentFileURLGetter(copyActiveLibraries.targetClass, &fileURL, &reason)) {
        return [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[] completeTraversal:NO reason:reason];
    }

    CFTypeRef copiedLibraries = ((FCPCCCopiedObjectGetter)copyActiveLibraries.implementation)((id)copyActiveLibraries.targetClass,
                                                                                                  copyActiveLibraries.selector);
    id activeLibraries = copiedLibraries == NULL ? nil : CFBridgingRelease(copiedLibraries);
    if (![activeLibraries isKindOfClass:[NSArray class]]) {
        return [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[] completeTraversal:NO reason:@"active_library_set_type_unsupported"];
    }

    NSMutableArray<FCPCCLibraryIdentity *> *observedLibraries = [[NSMutableArray alloc] initWithCapacity:[activeLibraries count]];
    for (id library in activeLibraries) {
        if (!FCPCCReceiverUsesValidatedMethod(library, &libraryDocument, &reason)) {
            return [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[] completeTraversal:NO reason:reason];
        }
        id document = ((FCPCCObjectGetter)libraryDocument.implementation)(library, libraryDocument.selector);
        if (!FCPCCReceiverUsesValidatedMethod(document, &persistentFileID, &reason)
            || !FCPCCReceiverUsesValidatedMethod(document, &fileURL, &reason)) {
            return [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[] completeTraversal:NO reason:reason];
        }
        NSString *persistentUID = FCPCCNormalizedTypedIdentifier(((FCPCCObjectGetter)persistentFileID.implementation)(document,
                                                                                                                           persistentFileID.selector));
        id fileURLValue = ((FCPCCObjectGetter)fileURL.implementation)(document, fileURL.selector);
        if (persistentUID == nil || ![fileURLValue isKindOfClass:[NSURL class]] || ![fileURLValue isFileURL]) {
            return [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[] completeTraversal:NO reason:@"library_persistent_identity_or_file_url_unsupported"];
        }
        NSString *canonicalPath = FCPCCCanonicalFilePath([fileURLValue path]);
        struct stat metadata = {0};
        if (canonicalPath == nil || stat(canonicalPath.fileSystemRepresentation, &metadata) != 0
            || metadata.st_dev == 0 || metadata.st_ino == 0) {
            return [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:@[] completeTraversal:NO reason:@"library_canonical_path_device_or_inode_unavailable"];
        }
        FCPCCLibraryIdentity *identity = [[FCPCCLibraryIdentity alloc] initWithCanonicalPath:canonicalPath
                                                                                        device:@((unsigned long long)metadata.st_dev)
                                                                                         inode:@((unsigned long long)metadata.st_ino)
                                                                                 persistentUID:persistentUID];
        [observedLibraries addObject:identity];
    }
    return [[FCPCCReadOnlyLibrarySet alloc] initWithLibraries:observedLibraries
                                            completeTraversal:YES
                                                       reason:@"active_library_set_complete"];
}

@end

// Disposable-library bootstrap is intentionally a separate, one-shot path.
// It accepts no caller path, model class, or selector.  The direct model call
// below is admitted only after the fixed Flexo ABI/image contract resolves.
static BOOL FCPCCDisposableLibraryBootstrapEnvironmentIsExact(void) {
    const char *value = getenv(FCPCCDisposableLibraryBootstrapEnvironmentName.UTF8String);
    const char *projectValue = getenv(FCPCCDisposableProjectBootstrapEnvironmentName.UTF8String);
    return value != NULL
        && strcmp(value, FCPCCDisposableLibraryBootstrapEnvironmentValue.UTF8String) == 0
        && projectValue == NULL;
}

static BOOL FCPCCDisposableLibraryBootstrapPathHasNoSymlinkComponents(NSString *path,
                                                                       BOOL requireDirectory,
                                                                       NSString **reason) {
    if (!FCPCCIsExactCanonicalFilePath(path)) {
        *reason = @"bootstrap_path_not_exact_canonical";
        return NO;
    }
    NSArray<NSString *> *components = path.pathComponents;
    if (components.count == 0 || ![components.firstObject isEqualToString:@"/"]) {
        *reason = @"bootstrap_path_components_unavailable";
        return NO;
    }

    NSString *currentPath = @"/";
    for (NSUInteger index = 1; index < components.count; index += 1) {
        currentPath = [currentPath stringByAppendingPathComponent:components[index]];
        struct stat metadata = {0};
        if (lstat(currentPath.fileSystemRepresentation, &metadata) != 0) {
            *reason = @"bootstrap_path_component_unavailable";
            return NO;
        }
        if (S_ISLNK(metadata.st_mode)) {
            *reason = @"bootstrap_path_component_is_symlink";
            return NO;
        }
        if (index + 1 < components.count && !S_ISDIR(metadata.st_mode)) {
            *reason = @"bootstrap_path_component_is_not_directory";
            return NO;
        }
        if (index + 1 == components.count && requireDirectory && !S_ISDIR(metadata.st_mode)) {
            *reason = @"bootstrap_path_is_not_directory";
            return NO;
        }
    }
    return YES;
}

static BOOL FCPCCDisposableLibraryBootstrapValidateAbsentCanonicalTarget(NSString *parentPath,
                                                                           NSString *targetPath,
                                                                           NSString **reason) {
    if (!FCPCCDisposableLibraryBootstrapPathHasNoSymlinkComponents(parentPath, YES, reason)) {
        return NO;
    }
    if (!FCPCCIsExactCanonicalFilePath(targetPath)
        || ![[targetPath stringByDeletingLastPathComponent] isEqualToString:parentPath]
        || targetPath.lastPathComponent.length == 0) {
        *reason = @"bootstrap_target_not_exact_canonical_child";
        return NO;
    }
    struct stat targetMetadata = {0};
    if (lstat(targetPath.fileSystemRepresentation, &targetMetadata) == 0) {
        *reason = @"bootstrap_target_already_exists";
        return NO;
    }
    if (errno != ENOENT) {
        *reason = @"bootstrap_target_absence_unverifiable";
        return NO;
    }
    return YES;
}

static BOOL FCPCCDisposableLibraryBootstrapExactTargetIsAbsent(NSString **reason) {
    if (![FCPCCDisposableLibraryBootstrapParentPath isEqualToString:[FCPCCDisposableLibraryBootstrapTargetPath stringByDeletingLastPathComponent]]) {
        *reason = @"bootstrap_compile_time_parent_target_mismatch";
        return NO;
    }
    return FCPCCDisposableLibraryBootstrapValidateAbsentCanonicalTarget(FCPCCDisposableLibraryBootstrapParentPath,
                                                                         FCPCCDisposableLibraryBootstrapTargetPath,
                                                                         reason);
}

static BOOL FCPCCDisposableLibraryBootstrapActiveLibrarySetIsEmpty(NSString **reason) {
    FCPCCValidatedFixedMethod copyActiveLibraries = {0};
    if (!FCPCCResolveFixedMethod(&FCPCCCopyActiveLibrariesContract, &copyActiveLibraries, reason)) {
        return NO;
    }
    CFTypeRef copiedLibraries = ((FCPCCCopiedObjectGetter)copyActiveLibraries.implementation)((id)copyActiveLibraries.targetClass,
                                                                                                  copyActiveLibraries.selector);
    id activeLibraries = copiedLibraries == NULL ? nil : CFBridgingRelease(copiedLibraries);
    if (![activeLibraries isKindOfClass:[NSArray class]]) {
        *reason = @"bootstrap_active_library_set_type_unsupported";
        return NO;
    }
    if ([activeLibraries count] != 0) {
        *reason = @"bootstrap_active_library_count_not_zero";
        return NO;
    }
    return YES;
}

@interface FCPCCDisposableLibraryBootstrapResult : NSObject
@property (nonatomic, copy, readonly) NSString *status;
@property (nonatomic, copy, readonly) NSString *reason;
@property (nonatomic, strong, readonly, nullable) NSNumber *device;
@property (nonatomic, strong, readonly, nullable) NSNumber *inode;
@property (nonatomic, copy, readonly, nullable) NSString *persistentUID;
- (instancetype)initWithStatus:(NSString *)status
                         reason:(NSString *)reason
                         device:(nullable NSNumber *)device
                          inode:(nullable NSNumber *)inode
                  persistentUID:(nullable NSString *)persistentUID NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation FCPCCDisposableLibraryBootstrapResult

- (instancetype)initWithStatus:(NSString *)status
                         reason:(NSString *)reason
                         device:(NSNumber *)device
                          inode:(NSNumber *)inode
                  persistentUID:(NSString *)persistentUID {
    self = [super init];
    if (self != nil) {
        _status = [status copy];
        _reason = [reason copy];
        _device = [device copy];
        _inode = [inode copy];
        _persistentUID = [persistentUID copy];
    }
    return self;
}

@end

static FCPCCDisposableLibraryBootstrapResult *FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(NSString *status,
                                                                                                                NSString *reason) {
    struct stat metadata = {0};
    NSNumber *device = nil;
    NSNumber *inode = nil;
    if (lstat(FCPCCDisposableLibraryBootstrapTargetPath.fileSystemRepresentation, &metadata) == 0
        && !S_ISLNK(metadata.st_mode)
        && metadata.st_dev != 0
        && metadata.st_ino != 0) {
        device = @((unsigned long long)metadata.st_dev);
        inode = @((unsigned long long)metadata.st_ino);
    }
    return [[FCPCCDisposableLibraryBootstrapResult alloc] initWithStatus:status
                                                                    reason:reason
                                                                    device:device
                                                                     inode:inode
                                                             persistentUID:nil];
}

static FCPCCDisposableLibraryBootstrapResult *FCPCCDisposableLibraryBootstrapVerifiedResult(NSString **reason) {
    FCPCCFixedModelTraversalAdapter *modelAdapter = [[FCPCCFixedModelTraversalAdapter alloc] init];
    FCPCCReadOnlyLibrarySet *activeSet = [modelAdapter enumerateCompleteOpenLibrarySet];
    if (!activeSet.isCompleteTraversal) {
        *reason = activeSet.reason.length > 0 ? activeSet.reason : @"bootstrap_postcreate_library_traversal_incomplete";
        return nil;
    }
    if (activeSet.libraries.count != 1) {
        *reason = @"bootstrap_postcreate_active_library_count_not_one";
        return nil;
    }
    id candidate = activeSet.libraries.firstObject;
    if (![candidate isKindOfClass:[FCPCCLibraryIdentity class]]) {
        *reason = @"bootstrap_postcreate_library_identity_type_unsupported";
        return nil;
    }
    FCPCCLibraryIdentity *identity = candidate;
    FCPCCLibraryManifestRecord *manifest = [[FCPCCLibraryManifestRecord alloc]
        initWithCanonicalPath:FCPCCDisposableLibraryBootstrapTargetPath
                expectedDevice:identity.device
                 expectedInode:identity.inode
                 persistentUID:identity.persistentUID
             verificationState:@"bootstrap_postcreate_identity"];
    FCPCCLibraryInvariantResult *invariant = FCPCCEvaluateLibraryInvariant(activeSet, manifest);
    if (!invariant.isVerified) {
        *reason = invariant.reason.length > 0 ? invariant.reason : @"bootstrap_postcreate_identity_mismatch";
        return nil;
    }
    return [[FCPCCDisposableLibraryBootstrapResult alloc] initWithStatus:@"created_verified"
                                                                    reason:@"bootstrap_exact_one_active_library_verified"
                                                                    device:identity.device
                                                                     inode:identity.inode
                                                             persistentUID:identity.persistentUID];
}

static NSString *FCPCCDisposableLibraryBootstrapBoundedProvenanceString(NSString *value,
                                                                          NSString *fallback) {
    if (!FCPCCBoundedNonemptyString(value) || value.length > 256) {
        return fallback;
    }
    return value;
}

static BOOL FCPCCWriteDisposableLibraryBootstrapProvenance(FCPCCDisposableLibraryBootstrapResult *result) {
    NSString *pathReason = nil;
    if (!FCPCCDisposableLibraryBootstrapPathHasNoSymlinkComponents(FCPCCDisposableLibraryBootstrapParentPath,
                                                                     YES,
                                                                     &pathReason)) {
        return NO;
    }

    struct stat provenanceMetadata = {0};
    if (lstat(FCPCCDisposableLibraryBootstrapProvenanceDirectory.fileSystemRepresentation, &provenanceMetadata) != 0) {
        if (errno != ENOENT || mkdir(FCPCCDisposableLibraryBootstrapProvenanceDirectory.fileSystemRepresentation, 0700) != 0) {
            return NO;
        }
        if (lstat(FCPCCDisposableLibraryBootstrapProvenanceDirectory.fileSystemRepresentation, &provenanceMetadata) != 0) {
            return NO;
        }
    }
    if (S_ISLNK(provenanceMetadata.st_mode) || !S_ISDIR(provenanceMetadata.st_mode)) {
        return NO;
    }

    NSMutableDictionary<NSString *, id> *payload = [[NSMutableDictionary alloc] initWithDictionary:@{
        @"schema_version": @1,
        @"operation": @"disposable_library_bootstrap",
        @"status": FCPCCDisposableLibraryBootstrapBoundedProvenanceString(result.status, @"bootstrap_status_unavailable"),
        @"reason": FCPCCDisposableLibraryBootstrapBoundedProvenanceString(result.reason, @"bootstrap_reason_unavailable"),
        @"canonical_path": FCPCCDisposableLibraryBootstrapTargetPath,
    }];
    if (FCPCCUnsignedIdentityNumberIsValid(result.device) && FCPCCUnsignedIdentityNumberIsValid(result.inode)) {
        payload[@"device"] = result.device;
        payload[@"inode"] = result.inode;
    }
    if (FCPCCBoundedNonemptyString(result.persistentUID) && result.persistentUID.length <= 256) {
        payload[@"persistent_uid"] = result.persistentUID;
    }

    NSError *serializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&serializationError];
    if (data == nil || serializationError != nil || data.length == 0 || data.length > 4096) {
        return NO;
    }
    NSString *fileName = [FCPCCDisposableLibraryBootstrapProvenancePrefix stringByAppendingFormat:@"%@.json", NSUUID.UUID.UUIDString];
    NSString *filePath = [FCPCCDisposableLibraryBootstrapProvenanceDirectory stringByAppendingPathComponent:fileName];
    int descriptor = open(filePath.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (descriptor < 0) {
        return NO;
    }
    ssize_t written = write(descriptor, data.bytes, data.length);
    int closeResult = close(descriptor);
    return written == (ssize_t)data.length && closeResult == 0;
}

static FCPCCDisposableLibraryBootstrapResult *FCPCCRunDisposableLibraryBootstrap(void) {
    NSString *reason = nil;
    if (![NSThread isMainThread]) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"rejected", @"bootstrap_requires_main_thread");
    }
    if (!FCPCCDisposableLibraryBootstrapEnvironmentIsExact()) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"rejected", @"bootstrap_environment_flag_not_exact");
    }
    if (!FCPCCReadOnlyHostGatePasses(&reason)) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"rejected", reason ?: @"bootstrap_host_containment_unverified");
    }
    if (!FCPCCDisposableLibraryBootstrapExactTargetIsAbsent(&reason)) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"rejected", reason);
    }
    if (!FCPCCDisposableLibraryBootstrapActiveLibrarySetIsEmpty(&reason)) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"rejected", reason);
    }

    FCPCCValidatedFixedMethod createLibraryDocument = {0};
    if (!FCPCCResolveFixedMethod(&FCPCCDisposableLibraryDocumentCreateContract, &createLibraryDocument, &reason)) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"rejected", reason);
    }
    // Recheck immediately before invoking the model initializer.  The path is
    // never opened for truncation, removed, or reused after any failure.
    if (!FCPCCDisposableLibraryBootstrapExactTargetIsAbsent(&reason)) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"rejected", reason);
    }

    NSURL *targetURL = [NSURL fileURLWithPath:FCPCCDisposableLibraryBootstrapTargetPath isDirectory:YES];
    NSError *creationError = nil;
    id allocatedDocument = [createLibraryDocument.targetClass alloc];
    id document = allocatedDocument == nil ? nil
        : ((FCPCCLibraryDocumentInitializer)createLibraryDocument.implementation)(allocatedDocument,
                                                                                     createLibraryDocument.selector,
                                                                                     targetURL,
                                                                                     YES,
                                                                                     &creationError);
    if (document == nil || creationError != nil) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"creation_failed", @"bootstrap_model_creation_failed_target_retained");
    }

    NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
    if (documentController == nil) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"partial_creation_unverified", @"bootstrap_public_document_controller_unavailable_target_retained");
    }
    // These are the public NSDocument registration and presentation APIs. No
    // responder action, dialog, or UI simulation is involved.
    [documentController addDocument:document];
    [document makeWindowControllers];
    [document showWindows];

    FCPCCDisposableLibraryBootstrapResult *verified = FCPCCDisposableLibraryBootstrapVerifiedResult(&reason);
    if (verified == nil) {
        return FCPCCDisposableLibraryBootstrapResultWithCurrentTargetMetadata(@"partial_creation_unverified", reason ?: @"bootstrap_postcreate_verification_failed_target_retained");
    }
    return verified;
}

// The project bootstrap is a distinct, explicitly armed one-shot. It never
// synthesizes a selector, touches browser selection, invokes responder-chain
// actions, or retries a model mutation after a partial result.
typedef NS_ENUM(NSUInteger, FCPCCDisposableProjectBootstrapState) {
    FCPCCDisposableProjectBootstrapStatePreflight = 0,
    FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenInvocation,
    FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenCompletion,
    FCPCCDisposableProjectBootstrapStateWaitingForOpenedLibrary,
    FCPCCDisposableProjectBootstrapStateWaitingForSequence,
    FCPCCDisposableProjectBootstrapStateWaitingForEditor,
    FCPCCDisposableProjectBootstrapStateWaitingForImports,
    FCPCCDisposableProjectBootstrapStateAppending,
    FCPCCDisposableProjectBootstrapStateWaitingForAppendVerification,
    FCPCCDisposableProjectBootstrapStateFinished,
};

typedef NS_ENUM(NSUInteger, FCPCCDisposableProjectBootstrapLibraryOpenDecision) {
    FCPCCDisposableProjectBootstrapLibraryOpenDecisionReject = 0,
    FCPCCDisposableProjectBootstrapLibraryOpenDecisionContinueWithoutOpening,
    FCPCCDisposableProjectBootstrapLibraryOpenDecisionOpenEnrolledLibrary,
};

typedef NS_ENUM(NSUInteger, FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecision) {
    FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionReject = 0,
    FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionPending,
    FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionVerified,
};

typedef struct {
    FCPCCValidatedFixedMethod copyActiveLibraries;
    FCPCCValidatedFixedMethod libraryEvents;
    FCPCCValidatedFixedMethod eventProject;
    FCPCCValidatedFixedMethod eventDefaultLibraryItem;
    FCPCCValidatedFixedMethod mediaEventOwnedClips;
    FCPCCValidatedFixedMethod mediaEventProjectSet;
    FCPCCValidatedFixedMethod createProject;
    FCPCCValidatedFixedMethod deepLoadedSequences;
    FCPCCValidatedFixedMethod activeEditorContainer;
    FCPCCValidatedFixedMethod loadEditorForSequence;
    FCPCCValidatedFixedMethod editorTimelineModule;
    FCPCCValidatedFixedMethod timelineSequence;
    FCPCCValidatedFixedMethod primaryObject;
    FCPCCValidatedFixedMethod containedItems;
    FCPCCValidatedFixedMethod displayName;
    FCPCCValidatedFixedMethod identifier;
    FCPCCValidatedFixedMethod frameSize;
    FCPCCValidatedFixedMethod frameDuration;
    FCPCCValidatedFixedMethod timelineRange;
    FCPCCValidatedFixedMethod representedToolObject;
    FCPCCValidatedFixedMethod newClipFromURL;
    FCPCCValidatedFixedMethod addOwnedClip;
    FCPCCValidatedFixedMethod mediaClippedRange;
    FCPCCValidatedFixedMethod mediaIdentifier;
    FCPCCValidatedFixedMethod mediaOriginalMediaURL;
    FCPCCValidatedFixedMethod pasteboardInitWithName;
    FCPCCValidatedFixedMethod pasteboardWriteRanges;
    FCPCCValidatedFixedMethod figTimeRangeAndObjectFactory;
    FCPCCValidatedFixedMethod editActionFactory;
    FCPCCValidatedFixedMethod timelinePerformEdit;
} FCPCCDisposableProjectBootstrapContracts;

@interface FCPCCDisposableProjectClipEvidence : NSObject
@property (nonatomic, strong, readonly) id media;
@property (nonatomic, copy, readonly) NSString *mediaIdentifier;
@property (nonatomic, copy, readonly) NSString *canonicalSourcePath;
@property (nonatomic) CMTimeRange clippedRange;
@property (nonatomic, copy, nullable) NSString *timelineItemIdentifier;
@property (nonatomic) CMTimeRange timelineRange;
@property (nonatomic) BOOL hasTimelineRange;
- (instancetype)initWithMedia:(id)media
               mediaIdentifier:(NSString *)mediaIdentifier
           canonicalSourcePath:(NSString *)canonicalSourcePath
                  clippedRange:(CMTimeRange)clippedRange NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation FCPCCDisposableProjectClipEvidence

- (instancetype)initWithMedia:(id)media
               mediaIdentifier:(NSString *)mediaIdentifier
           canonicalSourcePath:(NSString *)canonicalSourcePath
                  clippedRange:(CMTimeRange)clippedRange {
    self = [super init];
    if (self != nil) {
        _media = media;
        _mediaIdentifier = [mediaIdentifier copy];
        _canonicalSourcePath = [canonicalSourcePath copy];
        _clippedRange = clippedRange;
        _timelineRange = kCMTimeRangeInvalid;
        _hasTimelineRange = NO;
    }
    return self;
}

@end

@interface FCPCCDisposableProjectBootstrapSession : NSObject {
@public
    FCPCCDisposableProjectBootstrapContracts _contracts;
}
@property (nonatomic) FCPCCDisposableProjectBootstrapState state;
@property (nonatomic) FCPCCDisposableProjectBootstrapContracts contracts;
@property (nonatomic, strong, nullable) id library;
@property (nonatomic, strong, nullable) id eventRecord;
@property (nonatomic, strong, nullable) id mediaEventProject;
@property (nonatomic, strong, nullable) id sequence;
@property (nonatomic, strong, nullable) id timeline;
@property (nonatomic, strong, nullable) id currentPasteboard;
@property (nonatomic, copy, nullable) NSString *currentPasteboardName;
@property (nonatomic, copy, nullable) NSString *sequenceIdentifier;
@property (nonatomic, strong, readonly) NSMutableArray<FCPCCDisposableProjectClipEvidence *> *clipEvidence;
@property (nonatomic) NSUInteger observationTurns;
@property (nonatomic) NSUInteger appendIndex;
@property (nonatomic) NSUInteger projectCreationInvocationCount;
@property (nonatomic) NSUInteger importInvocationCount;
@property (nonatomic) NSUInteger appendInvocationCount;
@property (nonatomic) NSUInteger libraryOpenInvocationCount;
@property (nonatomic) BOOL libraryOpenCompletionDelivered;
@property (nonatomic) BOOL libraryOpenCompletionSucceeded;
@property (nonatomic, strong, nullable) dispatch_source_t libraryOpenCompletionTimeoutSource;
@property (nonatomic, copy) NSString *libraryOpenStatus;
@property (nonatomic, copy) NSString *libraryOpenReason;
@property (nonatomic) BOOL fixtureHashesVerifiedBeforeMutation;
@property (nonatomic) BOOL hasObservedProjectFormat;
@property (nonatomic) CGSize observedFrameSize;
@property (nonatomic) CMTime observedFrameDuration;
@property (nonatomic, copy, nullable) NSString *status;
@property (nonatomic, copy, nullable) NSString *reason;
- (instancetype)init;
@end

@implementation FCPCCDisposableProjectBootstrapSession

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _state = FCPCCDisposableProjectBootstrapStatePreflight;
        _contracts = (FCPCCDisposableProjectBootstrapContracts){0};
        _clipEvidence = [[NSMutableArray alloc] initWithCapacity:3];
        _observedFrameSize = CGSizeZero;
        _observedFrameDuration = kCMTimeInvalid;
        _libraryOpenStatus = @"not_evaluated";
        _libraryOpenReason = @"project_bootstrap_library_open_not_evaluated";
    }
    return self;
}

@end

// The lifecycle permits exactly one explicitly armed project-bootstrap
// session. Async blocks intentionally retain it weakly; this root holds the
// sole strong ownership until FCPCCFinishDisposableProjectBootstrap finalizes
// provenance and releases the identity-matching session.
static __strong FCPCCDisposableProjectBootstrapSession *FCPCCDisposableProjectBootstrapActiveSession;

static BOOL FCPCCDisposableProjectBootstrapRetainActiveSessionIfAbsent(FCPCCDisposableProjectBootstrapSession *session) {
    if (session == nil || FCPCCDisposableProjectBootstrapActiveSession != nil) {
        return NO;
    }
    FCPCCDisposableProjectBootstrapActiveSession = session;
    return YES;
}

static BOOL FCPCCDisposableProjectBootstrapReleaseActiveSessionIfMatching(FCPCCDisposableProjectBootstrapSession *session) {
    if (session == nil || FCPCCDisposableProjectBootstrapActiveSession != session) {
        return NO;
    }
    FCPCCDisposableProjectBootstrapActiveSession = nil;
    return YES;
}

static void FCPCCFinishDisposableProjectBootstrapScheduling(void);
static void FCPCCAdvanceDisposableProjectBootstrap(FCPCCDisposableProjectBootstrapSession *session);

static BOOL FCPCCDisposableProjectBootstrapEnvironmentIsExact(void) {
    const char *projectValue = getenv(FCPCCDisposableProjectBootstrapEnvironmentName.UTF8String);
    const char *libraryValue = getenv(FCPCCDisposableLibraryBootstrapEnvironmentName.UTF8String);
    return projectValue != NULL
        && strcmp(projectValue, FCPCCDisposableProjectBootstrapEnvironmentValue.UTF8String) == 0
        && libraryValue == NULL;
}

static NSString *FCPCCDisposableProjectBootstrapFixturePathAtIndex(NSUInteger index) {
    switch (index) {
        case 0:
            return FCPCCDisposableProjectBootstrapClipAPath;
        case 1:
            return FCPCCDisposableProjectBootstrapClipBPath;
        case 2:
            return FCPCCDisposableProjectBootstrapLivingStillPath;
        default:
            return nil;
    }
}

static const char *FCPCCDisposableProjectBootstrapFixtureSHA256AtIndex(NSUInteger index) {
    switch (index) {
        case 0:
            return FCPCCDisposableProjectBootstrapClipASHA256;
        case 1:
            return FCPCCDisposableProjectBootstrapClipBSHA256;
        case 2:
            return FCPCCDisposableProjectBootstrapLivingStillSHA256;
        default:
            return NULL;
    }
}

static BOOL FCPCCDisposableProjectBootstrapValidRange(CMTimeRange range) {
    return CMTIME_IS_VALID(range.start)
        && CMTIME_IS_VALID(range.duration)
        && CMTIME_IS_NUMERIC(range.start)
        && CMTIME_IS_NUMERIC(range.duration)
        && range.start.timescale > 0
        && range.duration.timescale > 0
        && range.duration.value > 0;
}

static BOOL FCPCCDisposableProjectBootstrapHasExactExpectedPrimaryStorylineCount(NSUInteger observedCount,
                                                                                  NSUInteger expectedCount,
                                                                                  NSUInteger importedCount) {
    return expectedCount > 0
        && expectedCount <= importedCount
        && observedCount == expectedCount;
}

static BOOL FCPCCDisposableProjectBootstrapValidateFixtureAtIndex(NSUInteger index, NSString **reason) {
    NSString *path = FCPCCDisposableProjectBootstrapFixturePathAtIndex(index);
    const char *expectedSHA256 = FCPCCDisposableProjectBootstrapFixtureSHA256AtIndex(index);
    if (path == nil || expectedSHA256 == NULL
        || ![[path stringByDeletingLastPathComponent] isEqualToString:FCPCCDisposableProjectBootstrapFixturesRootPath]) {
        *reason = @"project_bootstrap_fixture_compile_time_path_or_hash_mismatch";
        return NO;
    }
    NSString *pathReason = nil;
    if (!FCPCCDisposableLibraryBootstrapPathHasNoSymlinkComponents(path, NO, &pathReason)) {
        *reason = @"project_bootstrap_fixture_path_unverified";
        return NO;
    }
    struct stat metadata = {0};
    if (stat(path.fileSystemRepresentation, &metadata) != 0 || !S_ISREG(metadata.st_mode) || metadata.st_size <= 0) {
        *reason = @"project_bootstrap_fixture_not_regular_nonempty_file";
        return NO;
    }
    if (!FCPCCFileSHA256MatchesExpectedHex(path, expectedSHA256)) {
        *reason = @"project_bootstrap_fixture_sha256_mismatch";
        return NO;
    }
    return YES;
}

static BOOL FCPCCDisposableProjectBootstrapValidateAllFixtures(NSString **reason) {
    NSString *fixturesRootReason = nil;
    if (!FCPCCDisposableLibraryBootstrapPathHasNoSymlinkComponents(FCPCCDisposableProjectBootstrapFixturesRootPath,
                                                                     YES,
                                                                     &fixturesRootReason)) {
        *reason = @"project_bootstrap_fixtures_root_unverified";
        return NO;
    }
    for (NSUInteger index = 0; index < 3; index += 1) {
        if (!FCPCCDisposableProjectBootstrapValidateFixtureAtIndex(index, reason)) {
            return NO;
        }
    }
    return YES;
}

static BOOL FCPCCResolveDisposableProjectBootstrapContracts(FCPCCDisposableProjectBootstrapContracts *contracts,
                                                             NSString **reason) {
    if (contracts == NULL) {
        *reason = @"project_bootstrap_contract_storage_unavailable";
        return NO;
    }
    *contracts = (FCPCCDisposableProjectBootstrapContracts){0};
    return FCPCCResolveFixedMethod(&FCPCCCopyActiveLibrariesContract, &contracts->copyActiveLibraries, reason)
        && FCPCCResolveFixedMethod(&FCPCCLibraryEventsContract, &contracts->libraryEvents, reason)
        && FCPCCResolveFixedMethod(&FCPCCEventRecordProjectContract, &contracts->eventProject, reason)
        && FCPCCResolveFixedMethod(&FCPCCEventRecordDefaultLibraryItemContract, &contracts->eventDefaultLibraryItem, reason)
        && FCPCCResolveFixedMethod(&FCPCCMediaEventProjectOwnedClipsContract, &contracts->mediaEventOwnedClips, reason)
        && FCPCCResolveFixedMethod(&FCPCCMediaEventProjectProjectSetContract, &contracts->mediaEventProjectSet, reason)
        && FCPCCResolveFixedMethod(&FCPCCProjectDocumentActionNewProjectContract, &contracts->createProject, reason)
        && FCPCCResolveFixedMethod(&FCPCCLibraryDeepLoadedSequencesContract, &contracts->deepLoadedSequences, reason)
        && FCPCCResolveFixedMethod(&FCPCCActiveEditorContainerContract, &contracts->activeEditorContainer, reason)
        && FCPCCResolveFixedMethod(&FCPCCEditorLoadSequenceContract, &contracts->loadEditorForSequence, reason)
        && FCPCCResolveFixedMethod(&FCPCCEditorTimelineModuleContract, &contracts->editorTimelineModule, reason)
        && FCPCCResolveFixedMethod(&FCPCCTimelineSequenceContract, &contracts->timelineSequence, reason)
        && FCPCCResolveFixedMethod(&FCPCCPrimaryObjectContract, &contracts->primaryObject, reason)
        && FCPCCResolveFixedMethod(&FCPCCContainedItemsContract, &contracts->containedItems, reason)
        && FCPCCResolveFixedMethod(&FCPCCDisplayNameContract, &contracts->displayName, reason)
        && FCPCCResolveFixedMethod(&FCPCCIdentifierContract, &contracts->identifier, reason)
        && FCPCCResolveFixedMethod(&FCPCCFrameSizeContract, &contracts->frameSize, reason)
        && FCPCCResolveFixedMethod(&FCPCCFrameDurationContract, &contracts->frameDuration, reason)
        && FCPCCResolveFixedMethod(&FCPCCRangeContract, &contracts->timelineRange, reason)
        && FCPCCResolveFixedMethod(&FCPCCRepresentedToolObjectContract, &contracts->representedToolObject, reason)
        && FCPCCResolveFixedMethod(&FCPCCMediaEventProjectNewClipFromURLContract, &contracts->newClipFromURL, reason)
        && FCPCCResolveFixedMethod(&FCPCCMediaEventProjectAddOwnedClipsObjectContract, &contracts->addOwnedClip, reason)
        && FCPCCResolveFixedMethod(&FCPCCMediaClippedRangeContract, &contracts->mediaClippedRange, reason)
        && FCPCCResolveFixedMethod(&FCPCCMediaIdentifierContract, &contracts->mediaIdentifier, reason)
        && FCPCCResolveFixedMethod(&FCPCCMediaOriginalMediaURLContract, &contracts->mediaOriginalMediaURL, reason)
        && FCPCCResolveFixedMethod(&FCPCCPasteboardInitWithNameContract, &contracts->pasteboardInitWithName, reason)
        && FCPCCResolveFixedMethod(&FCPCCPasteboardWriteRangesContract, &contracts->pasteboardWriteRanges, reason)
        && FCPCCResolveFixedMethod(&FCPCCFigTimeRangeAndObjectFactoryContract, &contracts->figTimeRangeAndObjectFactory, reason)
        && FCPCCResolveFixedMethod(&FCPCCEditActionCreateContract, &contracts->editActionFactory, reason)
        && FCPCCResolveFixedMethod(&FCPCCAnchoredTimelinePerformEditContract, &contracts->timelinePerformEdit, reason);
}

static NSArray *FCPCCDisposableProjectBootstrapArrayFromSetOrArray(id value) {
    if ([value isKindOfClass:[NSArray class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSSet class]]) {
        return [(NSSet *)value allObjects];
    }
    return nil;
}

static BOOL FCPCCDisposableProjectBootstrapCollectionIsEmpty(id value) {
    if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSSet class]]) {
        return [value count] == 0;
    }
    return NO;
}

static NSString *FCPCCDisposableProjectBootstrapValidatedIdentifier(id receiver,
                                                                     const FCPCCValidatedFixedMethod *identifierMethod,
                                                                     NSString **reason) {
    if (!FCPCCReceiverUsesValidatedMethod(receiver, identifierMethod, reason)) {
        return nil;
    }
    NSString *identifier = FCPCCNormalizedTypedIdentifier(((FCPCCObjectGetter)identifierMethod->implementation)(receiver,
                                                                                                                    identifierMethod->selector));
    if (identifier == nil) {
        *reason = @"project_bootstrap_stable_identifier_unavailable";
    }
    return identifier;
}

static NSDictionary<NSString *, NSNumber *> *FCPCCDisposableProjectBootstrapCMTimePayload(CMTime time) {
    return @{
        @"value": @((long long)time.value),
        @"timescale": @((int)time.timescale),
        @"flags": @((unsigned int)time.flags),
        @"epoch": @((long long)time.epoch),
    };
}

static NSDictionary<NSString *, id> *FCPCCDisposableProjectBootstrapRangePayload(CMTimeRange range) {
    return @{
        @"start": FCPCCDisposableProjectBootstrapCMTimePayload(range.start),
        @"duration": FCPCCDisposableProjectBootstrapCMTimePayload(range.duration),
    };
}

static NSString *FCPCCDisposableProjectBootstrapBoundedProvenanceString(NSString *value,
                                                                          NSString *fallback) {
    return FCPCCDisposableLibraryBootstrapBoundedProvenanceString(value, fallback);
}

static NSArray<NSDictionary<NSString *, id> *> *FCPCCDisposableProjectBootstrapFixturePayloads(FCPCCDisposableProjectBootstrapSession *session) {
    NSMutableArray<NSDictionary<NSString *, id> *> *payloads = [[NSMutableArray alloc] initWithCapacity:3];
    for (NSUInteger index = 0; index < 3; index += 1) {
        NSString *sourcePath = FCPCCDisposableProjectBootstrapFixturePathAtIndex(index);
        const char *expectedSHA256 = FCPCCDisposableProjectBootstrapFixtureSHA256AtIndex(index);
        FCPCCDisposableProjectClipEvidence *evidence = index < session.clipEvidence.count ? session.clipEvidence[index] : nil;
        NSMutableDictionary<NSString *, id> *payload = [[NSMutableDictionary alloc] initWithDictionary:@{
            @"canonical_source_path": sourcePath ?: @"",
            @"expected_sha256": expectedSHA256 == NULL ? @"" : [NSString stringWithUTF8String:expectedSHA256],
            @"source_hash_verified_before_mutation": @(session.fixtureHashesVerifiedBeforeMutation),
            @"source_hash_matches_after": @(sourcePath != nil && expectedSHA256 != NULL && FCPCCFileSHA256MatchesExpectedHex(sourcePath, expectedSHA256)),
        }];
        if (evidence != nil) {
            payload[@"media_identifier"] = FCPCCDisposableProjectBootstrapBoundedProvenanceString(evidence.mediaIdentifier, @"media_identifier_unavailable");
            payload[@"clipped_range"] = FCPCCDisposableProjectBootstrapRangePayload(evidence.clippedRange);
            if (FCPCCBoundedNonemptyString(evidence.timelineItemIdentifier) && evidence.timelineItemIdentifier.length <= 256) {
                payload[@"timeline_item_identifier"] = evidence.timelineItemIdentifier;
            }
            if (evidence.hasTimelineRange && FCPCCDisposableProjectBootstrapValidRange(evidence.timelineRange)) {
                payload[@"timeline_range"] = FCPCCDisposableProjectBootstrapRangePayload(evidence.timelineRange);
            }
        }
        [payloads addObject:payload];
    }
    return payloads;
}

static BOOL FCPCCWriteDisposableProjectBootstrapProvenance(FCPCCDisposableProjectBootstrapSession *session) {
    NSString *pathReason = nil;
    if (session == nil
        || !FCPCCDisposableLibraryBootstrapPathHasNoSymlinkComponents(FCPCCDisposableLibraryBootstrapParentPath,
                                                                        YES,
                                                                        &pathReason)) {
        return NO;
    }
    struct stat provenanceMetadata = {0};
    if (lstat(FCPCCDisposableLibraryBootstrapProvenanceDirectory.fileSystemRepresentation, &provenanceMetadata) != 0) {
        if (errno != ENOENT || mkdir(FCPCCDisposableLibraryBootstrapProvenanceDirectory.fileSystemRepresentation, 0700) != 0) {
            return NO;
        }
        if (lstat(FCPCCDisposableLibraryBootstrapProvenanceDirectory.fileSystemRepresentation, &provenanceMetadata) != 0) {
            return NO;
        }
    }
    if (S_ISLNK(provenanceMetadata.st_mode) || !S_ISDIR(provenanceMetadata.st_mode)) {
        return NO;
    }

    NSMutableDictionary<NSString *, id> *payload = [[NSMutableDictionary alloc] initWithDictionary:@{
        @"schema_version": @1,
        @"operation": @"disposable_project_bootstrap",
        @"status": FCPCCDisposableProjectBootstrapBoundedProvenanceString(session.status, @"project_bootstrap_status_unavailable"),
        @"reason": FCPCCDisposableProjectBootstrapBoundedProvenanceString(session.reason, @"project_bootstrap_reason_unavailable"),
        @"project_name": FCPCCDisposableProjectBootstrapProjectName,
        @"observation_turns": @(session.observationTurns),
        @"project_creation_invocation_count": @(session.projectCreationInvocationCount),
        @"import_invocation_count": @(session.importInvocationCount),
        @"append_invocation_count": @(session.appendInvocationCount),
        @"library_open_invocation_count": @(session.libraryOpenInvocationCount),
        @"library_open_status": FCPCCDisposableProjectBootstrapBoundedProvenanceString(session.libraryOpenStatus, @"library_open_status_unavailable"),
        @"library_open_reason": FCPCCDisposableProjectBootstrapBoundedProvenanceString(session.libraryOpenReason, @"library_open_reason_unavailable"),
        @"no_auto_retry": @YES,
        @"rollback": @"not_attempted_no_rollback_claimed",
        @"fixtures": FCPCCDisposableProjectBootstrapFixturePayloads(session),
    }];
    if (FCPCCBoundedNonemptyString(session.sequenceIdentifier) && session.sequenceIdentifier.length <= 256) {
        payload[@"sequence_identifier"] = session.sequenceIdentifier;
    }
    if (session.hasObservedProjectFormat
        && isfinite(session.observedFrameSize.width)
        && isfinite(session.observedFrameSize.height)
        && session.observedFrameSize.width > 0.0
        && session.observedFrameSize.height > 0.0
        && CMTIME_IS_VALID(session.observedFrameDuration)
        && CMTIME_IS_NUMERIC(session.observedFrameDuration)
        && session.observedFrameDuration.value > 0
        && session.observedFrameDuration.timescale > 0) {
        payload[@"actual_project_format"] = @{
            @"frame_width": @(session.observedFrameSize.width),
            @"frame_height": @(session.observedFrameSize.height),
            @"frame_duration": FCPCCDisposableProjectBootstrapCMTimePayload(session.observedFrameDuration),
        };
    }

    NSError *serializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&serializationError];
    if (data == nil || serializationError != nil || data.length == 0 || data.length > 16384) {
        return NO;
    }
    NSString *fileName = [FCPCCDisposableProjectBootstrapProvenancePrefix stringByAppendingFormat:@"%@.json", NSUUID.UUID.UUIDString];
    NSString *filePath = [FCPCCDisposableLibraryBootstrapProvenanceDirectory stringByAppendingPathComponent:fileName];
    int descriptor = open(filePath.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (descriptor < 0) {
        return NO;
    }
    ssize_t written = write(descriptor, data.bytes, data.length);
    int closeResult = close(descriptor);
    return written == (ssize_t)data.length && closeResult == 0;
}

static BOOL FCPCCDisposableProjectBootstrapHasMutated(FCPCCDisposableProjectBootstrapSession *session) {
    return session.projectCreationInvocationCount > 0
        || session.importInvocationCount > 0
        || session.appendInvocationCount > 0;
}

static void FCPCCFinishDisposableProjectBootstrap(FCPCCDisposableProjectBootstrapSession *session,
                                                   NSString *status,
                                                   NSString *reason) {
    if (session == nil || session.state == FCPCCDisposableProjectBootstrapStateFinished) {
        return;
    }
    BOOL mutationMayHaveOccurred = FCPCCDisposableProjectBootstrapHasMutated(session);
    if (mutationMayHaveOccurred && ![status isEqualToString:@"verified"]) {
        status = @"partial_unverified";
    }
    session.status = FCPCCDisposableProjectBootstrapBoundedProvenanceString(status, @"partial_unverified");
    session.reason = FCPCCDisposableProjectBootstrapBoundedProvenanceString(reason, @"project_bootstrap_failure_reason_unavailable");
    session.currentPasteboard = nil;
    session.currentPasteboardName = nil;
    if (session.libraryOpenCompletionTimeoutSource != nil) {
        dispatch_source_cancel(session.libraryOpenCompletionTimeoutSource);
        session.libraryOpenCompletionTimeoutSource = nil;
    }
    session.state = FCPCCDisposableProjectBootstrapStateFinished;
    (void)FCPCCWriteDisposableProjectBootstrapProvenance(session);
    (void)FCPCCDisposableProjectBootstrapReleaseActiveSessionIfMatching(session);
    FCPCCFinishDisposableProjectBootstrapScheduling();
}

static void FCPCCScheduleDisposableProjectBootstrapObservation(FCPCCDisposableProjectBootstrapSession *session) {
    if (session == nil || session.state == FCPCCDisposableProjectBootstrapStateFinished) {
        return;
    }
    if (session.observationTurns >= FCPCCDisposableProjectBootstrapMaximumObservationTurns) {
        if (session.state == FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenCompletion
            || session.state == FCPCCDisposableProjectBootstrapStateWaitingForOpenedLibrary) {
            session.libraryOpenStatus = @"timed_out";
            session.libraryOpenReason = session.state == FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenCompletion
                ? @"project_bootstrap_public_library_open_completion_timeout"
                : @"project_bootstrap_public_library_open_postopen_verification_timeout";
            FCPCCFinishDisposableProjectBootstrap(session,
                                                   @"rejected",
                                                   session.libraryOpenReason);
            return;
        }
        FCPCCFinishDisposableProjectBootstrap(session,
                                               @"partial_unverified",
                                               @"project_bootstrap_bounded_observation_exhausted");
        return;
    }
    session.observationTurns += 1;
    dispatch_async(dispatch_get_main_queue(), ^{
        FCPCCAdvanceDisposableProjectBootstrap(session);
    });
}

static FCPCCDisposableProjectBootstrapLibraryOpenDecision FCPCCDisposableProjectBootstrapLibraryOpenDecisionForEnumeration(BOOL completeTraversal,
                                                                                                                               NSUInteger openLibraryCount,
                                                                                                                               BOOL exactEnrolledLibraryIsOpen,
                                                                                                                               BOOL manifestIsComplete) {
    if (!completeTraversal || !manifestIsComplete) {
        return FCPCCDisposableProjectBootstrapLibraryOpenDecisionReject;
    }
    if (openLibraryCount == 0) {
        return FCPCCDisposableProjectBootstrapLibraryOpenDecisionOpenEnrolledLibrary;
    }
    if (openLibraryCount == 1 && exactEnrolledLibraryIsOpen) {
        return FCPCCDisposableProjectBootstrapLibraryOpenDecisionContinueWithoutOpening;
    }
    return FCPCCDisposableProjectBootstrapLibraryOpenDecisionReject;
}

static FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecision FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionForEnumeration(BOOL completeTraversal,
                                                                                                                                                            NSUInteger openLibraryCount,
                                                                                                                                                            BOOL exactEnrolledLibraryIsOpen,
                                                                                                                                                            BOOL manifestIsComplete) {
    if (!completeTraversal || !manifestIsComplete) {
        return FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionReject;
    }
    if (openLibraryCount == 0) {
        return FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionPending;
    }
    if (openLibraryCount == 1 && exactEnrolledLibraryIsOpen) {
        return FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionVerified;
    }
    return FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionReject;
}

static BOOL FCPCCDisposableProjectBootstrapValidateCanonicalEnrolledLibraryForPublicOpen(FCPCCLibraryManifestRecord *manifest,
                                                                                            NSURL **libraryURL,
                                                                                            NSString **reason) {
    if (libraryURL == NULL) {
        *reason = @"project_bootstrap_library_open_url_storage_unavailable";
        return NO;
    }
    *libraryURL = nil;
    if (manifest == nil || !manifest.isComplete) {
        *reason = manifest.verificationState.length > 0
            ? manifest.verificationState
            : @"project_bootstrap_library_manifest_incomplete";
        return NO;
    }
    if (![manifest.canonicalPath isEqualToString:FCPCCDisposableLibraryBootstrapTargetPath]) {
        *reason = @"project_bootstrap_enrolled_library_path_not_fixed_target";
        return NO;
    }
    NSString *pathReason = nil;
    if (!FCPCCDisposableLibraryBootstrapPathHasNoSymlinkComponents(manifest.canonicalPath, YES, &pathReason)) {
        *reason = pathReason.length > 0
            ? pathReason
            : @"project_bootstrap_enrolled_library_path_unverified";
        return NO;
    }
    struct stat metadata = {0};
    if (lstat(manifest.canonicalPath.fileSystemRepresentation, &metadata) != 0
        || !S_ISDIR(metadata.st_mode)
        || metadata.st_dev == 0
        || metadata.st_ino == 0) {
        *reason = @"project_bootstrap_enrolled_library_directory_device_or_inode_unverified";
        return NO;
    }
    if (metadata.st_dev != (dev_t)manifest.expectedDevice.unsignedLongLongValue
        || metadata.st_ino != (ino_t)manifest.expectedInode.unsignedLongLongValue) {
        *reason = @"project_bootstrap_enrolled_library_device_or_inode_mismatch";
        return NO;
    }
    // The manifest's persistent UID is deliberately pinned to the enrolled
    // bundle inode for this disposable target. The FCP persistent UID itself
    // is independently re-read from the complete active-library traversal
    // after the public document open completes.
    NSString *manifestPersistentUID = [NSString stringWithFormat:@"%llu", (unsigned long long)metadata.st_ino];
    if (![manifest.persistentUID isEqualToString:manifestPersistentUID]) {
        *reason = @"project_bootstrap_enrolled_library_persistent_uid_mismatch";
        return NO;
    }
    *libraryURL = [NSURL fileURLWithPath:manifest.canonicalPath isDirectory:YES];
    if (*libraryURL == nil || !(*libraryURL).isFileURL) {
        *reason = @"project_bootstrap_enrolled_library_file_url_unavailable";
        return NO;
    }
    return YES;
}

static FCPCCDisposableProjectBootstrapLibraryOpenDecision FCPCCDisposableProjectBootstrapInitialLibraryOpenDecision(FCPCCReadOnlyLibrarySet *activeSet,
                                                                                                                       FCPCCLibraryManifestRecord *manifest,
                                                                                                                       NSString **reason) {
    if (activeSet == nil || !activeSet.isCompleteTraversal) {
        *reason = activeSet.reason.length > 0
            ? activeSet.reason
            : @"project_bootstrap_active_library_traversal_incomplete";
        return FCPCCDisposableProjectBootstrapLibraryOpenDecisionReject;
    }
    if (manifest == nil || !manifest.isComplete) {
        *reason = manifest.verificationState.length > 0
            ? manifest.verificationState
            : @"project_bootstrap_library_manifest_incomplete";
        return FCPCCDisposableProjectBootstrapLibraryOpenDecisionReject;
    }
    FCPCCLibraryInvariantResult *invariant = FCPCCEvaluateLibraryInvariant(activeSet, manifest);
    FCPCCDisposableProjectBootstrapLibraryOpenDecision decision = FCPCCDisposableProjectBootstrapLibraryOpenDecisionForEnumeration(activeSet.isCompleteTraversal,
                                                                                                                                       activeSet.libraries.count,
                                                                                                                                       invariant.isVerified,
                                                                                                                                       manifest.isComplete);
    if (decision == FCPCCDisposableProjectBootstrapLibraryOpenDecisionReject) {
        *reason = invariant.reason.length > 0
            ? invariant.reason
            : @"project_bootstrap_initial_open_library_state_unverified";
    }
    return decision;
}

static void FCPCCDisposableProjectBootstrapInvokePublicEnrolledLibraryOpen(FCPCCDisposableProjectBootstrapSession *session,
                                                                            NSURL *libraryURL) {
    if (session == nil || session.state != FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenInvocation) {
        return;
    }
    if (![NSThread isMainThread]) {
        session.libraryOpenStatus = @"rejected";
        session.libraryOpenReason = @"project_bootstrap_public_library_open_requires_main_queue";
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", session.libraryOpenReason);
        return;
    }
    if (libraryURL == nil || !libraryURL.isFileURL || session.libraryOpenInvocationCount != 0) {
        session.libraryOpenStatus = @"rejected";
        session.libraryOpenReason = @"project_bootstrap_public_library_open_retry_or_url_unverified";
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", session.libraryOpenReason);
        return;
    }
    NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
    if (documentController == nil) {
        session.libraryOpenStatus = @"rejected";
        session.libraryOpenReason = @"project_bootstrap_public_document_controller_unavailable";
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", session.libraryOpenReason);
        return;
    }

    session.libraryOpenInvocationCount += 1;
    session.libraryOpenStatus = @"invoked";
    session.libraryOpenReason = @"project_bootstrap_public_enrolled_library_open_requested";
    session.state = FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenCompletion;
    __weak FCPCCDisposableProjectBootstrapSession *weakSession = session;
    dispatch_source_t timeoutSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                              0,
                                                              0,
                                                              dispatch_get_main_queue());
    if (timeoutSource == nil) {
        session.libraryOpenStatus = @"rejected";
        session.libraryOpenReason = @"project_bootstrap_public_library_open_timeout_source_unavailable";
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", session.libraryOpenReason);
        return;
    }
    session.libraryOpenCompletionTimeoutSource = timeoutSource;
    dispatch_source_set_timer(timeoutSource,
                              dispatch_time(DISPATCH_TIME_NOW,
                                            (int64_t)(FCPCCDisposableProjectBootstrapLibraryOpenCompletionTimeoutSeconds * NSEC_PER_SEC)),
                              DISPATCH_TIME_FOREVER,
                              0);
    dispatch_source_set_event_handler(timeoutSource, ^{
        FCPCCDisposableProjectBootstrapSession *timedSession = weakSession;
        if (timedSession != nil
            && timedSession.state == FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenCompletion
            && !timedSession.libraryOpenCompletionDelivered) {
            timedSession.libraryOpenStatus = @"timed_out";
            timedSession.libraryOpenReason = @"project_bootstrap_public_library_open_completion_timeout";
            FCPCCFinishDisposableProjectBootstrap(timedSession,
                                                   @"rejected",
                                                   timedSession.libraryOpenReason);
        }
    });
    dispatch_resume(timeoutSource);
    // This is the only project-bootstrap library-open surface: a typed public
    // AppKit document open and presentation of the fixed, prevalidated enrolled
    // bundle. It neither displays an open panel nor creates, removes, or
    // overwrites a library.
    [documentController openDocumentWithContentsOfURL:libraryURL
                                               display:YES
                                     completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
        (void)documentWasAlreadyOpen;
        FCPCCDisposableProjectBootstrapSession *completedSession = weakSession;
        if (completedSession == nil
            || completedSession.state != FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenCompletion) {
            return;
        }
        if (completedSession.libraryOpenCompletionTimeoutSource != nil) {
            dispatch_source_cancel(completedSession.libraryOpenCompletionTimeoutSource);
            completedSession.libraryOpenCompletionTimeoutSource = nil;
        }
        completedSession.libraryOpenCompletionDelivered = YES;
        completedSession.libraryOpenCompletionSucceeded = document != nil && error == nil && [NSThread isMainThread];
        completedSession.libraryOpenStatus = completedSession.libraryOpenCompletionSucceeded
            ? @"completion_succeeded"
            : @"completion_failed";
        completedSession.libraryOpenReason = completedSession.libraryOpenCompletionSucceeded
            ? @"project_bootstrap_public_enrolled_library_open_completed"
            : @"project_bootstrap_public_enrolled_library_open_unverified";
        if (!completedSession.libraryOpenCompletionSucceeded) {
            FCPCCFinishDisposableProjectBootstrap(completedSession,
                                                   @"rejected",
                                                   completedSession.libraryOpenReason);
            return;
        }
        completedSession.state = FCPCCDisposableProjectBootstrapStateWaitingForOpenedLibrary;
        completedSession.observationTurns = 0;
        FCPCCScheduleDisposableProjectBootstrapObservation(completedSession);
    }];
}

static void FCPCCDisposableProjectBootstrapDispatchPublicEnrolledLibraryOpen(FCPCCDisposableProjectBootstrapSession *session,
                                                                              NSURL *libraryURL) {
    if (session == nil || libraryURL == nil || session.libraryOpenInvocationCount != 0) {
        if (session != nil) {
            session.libraryOpenStatus = @"rejected";
            session.libraryOpenReason = @"project_bootstrap_public_library_open_retry_or_url_unverified";
            FCPCCFinishDisposableProjectBootstrap(session, @"rejected", session.libraryOpenReason);
        }
        return;
    }
    session.state = FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenInvocation;
    session.libraryOpenStatus = @"scheduled";
    session.libraryOpenReason = @"project_bootstrap_public_enrolled_library_open_scheduled";
    dispatch_async(dispatch_get_main_queue(), ^{
        FCPCCDisposableProjectBootstrapInvokePublicEnrolledLibraryOpen(session, libraryURL);
    });
}

static id FCPCCDisposableProjectBootstrapResolveExactEnrolledLibrary(FCPCCDisposableProjectBootstrapSession *session,
                                                                       NSString **reason) {
    FCPCCFixedModelTraversalAdapter *adapter = [[FCPCCFixedModelTraversalAdapter alloc] init];
    FCPCCReadOnlyLibrarySet *activeSet = [adapter enumerateCompleteOpenLibrarySet];
    FCPCCLibraryManifestRecord *manifest = [FCPCCLibraryManifestRecord bundledManifest];
    FCPCCLibraryInvariantResult *invariant = FCPCCEvaluateLibraryInvariant(activeSet, manifest);
    if (!invariant.isVerified) {
        *reason = invariant.reason.length > 0 ? invariant.reason : @"project_bootstrap_enrolled_library_invariant_unverified";
        return nil;
    }

    CFTypeRef copiedLibraries = ((FCPCCCopiedObjectGetter)session.contracts.copyActiveLibraries.implementation)(
        (id)session.contracts.copyActiveLibraries.targetClass,
        session.contracts.copyActiveLibraries.selector);
    id activeLibraries = copiedLibraries == NULL ? nil : CFBridgingRelease(copiedLibraries);
    if (![activeLibraries isKindOfClass:[NSArray class]] || [activeLibraries count] != 1) {
        *reason = @"project_bootstrap_active_library_count_not_exactly_one";
        return nil;
    }
    id library = [(NSArray *)activeLibraries firstObject];
    if (!FCPCCReceiverUsesValidatedMethod(library, &session->_contracts.libraryEvents, reason)
        || !FCPCCReceiverUsesValidatedMethod(library, &session->_contracts.deepLoadedSequences, reason)) {
        return nil;
    }
    return library;
}

static BOOL FCPCCDisposableProjectBootstrapPreflight(FCPCCDisposableProjectBootstrapSession *session,
                                                      id *eventLibraryItem,
                                                      NSString **reason) {
    if (eventLibraryItem == NULL) {
        *reason = @"project_bootstrap_event_library_item_storage_unavailable";
        return NO;
    }
    *eventLibraryItem = nil;
    session.library = FCPCCDisposableProjectBootstrapResolveExactEnrolledLibrary(session, reason);
    if (session.library == nil) {
        return NO;
    }
    id eventsValue = ((FCPCCObjectGetter)session.contracts.libraryEvents.implementation)(session.library,
                                                                                            session.contracts.libraryEvents.selector);
    if (![eventsValue isKindOfClass:[NSArray class]] || [eventsValue count] != 1) {
        *reason = @"project_bootstrap_event_count_not_exactly_one";
        return NO;
    }
    id eventRecord = [(NSArray *)eventsValue firstObject];
    if (!FCPCCReceiverUsesValidatedMethod(eventRecord, &session->_contracts.eventProject, reason)
        || !FCPCCReceiverUsesValidatedMethod(eventRecord, &session->_contracts.eventDefaultLibraryItem, reason)) {
        return NO;
    }
    id mediaEventProject = ((FCPCCObjectGetter)session.contracts.eventProject.implementation)(eventRecord,
                                                                                                 session.contracts.eventProject.selector);
    if (!FCPCCReceiverUsesValidatedMethod(mediaEventProject, &session->_contracts.mediaEventOwnedClips, reason)
        || !FCPCCReceiverUsesValidatedMethod(mediaEventProject, &session->_contracts.mediaEventProjectSet, reason)
        || !FCPCCReceiverUsesValidatedMethod(mediaEventProject, &session->_contracts.newClipFromURL, reason)
        || !FCPCCReceiverUsesValidatedMethod(mediaEventProject, &session->_contracts.addOwnedClip, reason)) {
        return NO;
    }
    id ownedClips = ((FCPCCObjectGetter)session.contracts.mediaEventOwnedClips.implementation)(mediaEventProject,
                                                                                                  session.contracts.mediaEventOwnedClips.selector);
    id projectSet = ((FCPCCObjectGetter)session.contracts.mediaEventProjectSet.implementation)(mediaEventProject,
                                                                                                  session.contracts.mediaEventProjectSet.selector);
    id deepSequences = ((FCPCCObjectGetter)session.contracts.deepLoadedSequences.implementation)(session.library,
                                                                                                     session.contracts.deepLoadedSequences.selector);
    if (!FCPCCDisposableProjectBootstrapCollectionIsEmpty(ownedClips)
        || !FCPCCDisposableProjectBootstrapCollectionIsEmpty(projectSet)
        || !FCPCCDisposableProjectBootstrapCollectionIsEmpty(deepSequences)) {
        *reason = @"project_bootstrap_disposable_library_not_empty";
        return NO;
    }
    id defaultLibraryItem = ((FCPCCObjectGetter)session.contracts.eventDefaultLibraryItem.implementation)(eventRecord,
                                                                                                             session.contracts.eventDefaultLibraryItem.selector);
    if (defaultLibraryItem == nil) {
        *reason = @"project_bootstrap_event_default_library_item_unavailable";
        return NO;
    }
    session.eventRecord = eventRecord;
    session.mediaEventProject = mediaEventProject;
    *eventLibraryItem = defaultLibraryItem;
    return YES;
}

static BOOL FCPCCDisposableProjectBootstrapBeginProjectCreation(FCPCCDisposableProjectBootstrapSession *session,
                                                                 NSString **reason) {
    id eventLibraryItem = nil;
    if (!FCPCCDisposableProjectBootstrapPreflight(session, &eventLibraryItem, reason)) {
        return NO;
    }
    if (session.libraryOpenInvocationCount == 1) {
        session.libraryOpenStatus = @"postopen_exact_enrolled_library_verified";
        session.libraryOpenReason = @"project_bootstrap_exact_enrolled_library_verified_after_public_open";
    }
    if (session.projectCreationInvocationCount != 0) {
        *reason = @"project_bootstrap_project_creation_retry_forbidden";
        return NO;
    }
    NSError *creationError = nil;
    session.projectCreationInvocationCount += 1;
    id createdProject = ((FCPCCProjectDocumentActionNewProject)session.contracts.createProject.implementation)(
        (id)session.contracts.createProject.targetClass,
        session.contracts.createProject.selector,
        eventLibraryItem,
        FCPCCDisposableProjectBootstrapProjectName,
        nil,
        @"FCPCommandConsole Disposable Project Bootstrap",
        &creationError);
    if (createdProject == nil || creationError != nil) {
        *reason = @"project_bootstrap_native_project_creation_unverified";
        return NO;
    }
    return YES;
}

static BOOL FCPCCDisposableProjectBootstrapValidateImportedMedia(FCPCCDisposableProjectBootstrapSession *session,
                                                                  id media,
                                                                  NSString *expectedSourcePath,
                                                                  FCPCCDisposableProjectClipEvidence **evidenceOut,
                                                                  NSString **reason) {
    if (evidenceOut == NULL
        || !FCPCCReceiverUsesValidatedMethod(media, &session->_contracts.mediaClippedRange, reason)
        || !FCPCCReceiverUsesValidatedMethod(media, &session->_contracts.mediaIdentifier, reason)
        || !FCPCCReceiverUsesValidatedMethod(media, &session->_contracts.mediaOriginalMediaURL, reason)) {
        return NO;
    }
    CMTimeRange clippedRange = ((FCPCCCMTimeRangeGetter)session.contracts.mediaClippedRange.implementation)(
        media,
        session.contracts.mediaClippedRange.selector);
    if (!FCPCCDisposableProjectBootstrapValidRange(clippedRange)) {
        *reason = @"project_bootstrap_imported_media_clipped_range_invalid";
        return NO;
    }
    NSString *mediaIdentifier = FCPCCDisposableProjectBootstrapValidatedIdentifier(media,
                                                                                     &session->_contracts.mediaIdentifier,
                                                                                     reason);
    id originalURLValue = ((FCPCCObjectGetter)session.contracts.mediaOriginalMediaURL.implementation)(
        media,
        session.contracts.mediaOriginalMediaURL.selector);
    if (mediaIdentifier == nil
        || ![originalURLValue isKindOfClass:[NSURL class]]
        || ![(NSURL *)originalURLValue isFileURL]) {
        *reason = @"project_bootstrap_imported_media_source_identity_unavailable";
        return NO;
    }
    NSString *canonicalSourcePath = FCPCCCanonicalFilePath([(NSURL *)originalURLValue path]);
    if (canonicalSourcePath == nil || ![canonicalSourcePath isEqualToString:expectedSourcePath]) {
        *reason = @"project_bootstrap_imported_media_source_path_mismatch";
        return NO;
    }
    *evidenceOut = [[FCPCCDisposableProjectClipEvidence alloc] initWithMedia:media
                                                               mediaIdentifier:mediaIdentifier
                                                           canonicalSourcePath:canonicalSourcePath
                                                                  clippedRange:clippedRange];
    return YES;
}

static NSArray *FCPCCDisposableProjectBootstrapPrimaryStorylineItems(FCPCCDisposableProjectBootstrapSession *session,
                                                                       NSString **reason) {
    if (!FCPCCReceiverUsesValidatedMethod(session.sequence, &session->_contracts.primaryObject, reason)) {
        return nil;
    }
    id primaryObject = ((FCPCCObjectGetter)session.contracts.primaryObject.implementation)(session.sequence,
                                                                                              session.contracts.primaryObject.selector);
    if (!FCPCCReceiverUsesValidatedMethod(primaryObject, &session->_contracts.containedItems, reason)) {
        return nil;
    }
    id itemsValue = ((FCPCCObjectGetter)session.contracts.containedItems.implementation)(primaryObject,
                                                                                            session.contracts.containedItems.selector);
    if (![itemsValue isKindOfClass:[NSArray class]]) {
        *reason = @"project_bootstrap_primary_storyline_items_order_not_proven";
        return nil;
    }
    return (NSArray *)itemsValue;
}

typedef NS_ENUM(NSUInteger, FCPCCDisposableProjectBootstrapObservationResult) {
    FCPCCDisposableProjectBootstrapObservationResultPending = 0,
    FCPCCDisposableProjectBootstrapObservationResultVerified,
    FCPCCDisposableProjectBootstrapObservationResultFailed,
};

static FCPCCDisposableProjectBootstrapObservationResult FCPCCDisposableProjectBootstrapObservePostopenEnrolledLibrary(FCPCCDisposableProjectBootstrapSession *session,
                                                                                                                        NSString **reason) {
    FCPCCFixedModelTraversalAdapter *adapter = [[FCPCCFixedModelTraversalAdapter alloc] init];
    FCPCCReadOnlyLibrarySet *activeSet = [adapter enumerateCompleteOpenLibrarySet];
    if (activeSet == nil || !activeSet.isCompleteTraversal) {
        *reason = activeSet.reason.length > 0
            ? activeSet.reason
            : @"project_bootstrap_postopen_library_traversal_incomplete";
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    FCPCCLibraryManifestRecord *manifest = [FCPCCLibraryManifestRecord bundledManifest];
    if (manifest == nil || !manifest.isComplete) {
        *reason = manifest.verificationState.length > 0
            ? manifest.verificationState
            : @"project_bootstrap_postopen_library_manifest_incomplete";
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    FCPCCLibraryInvariantResult *invariant = FCPCCEvaluateLibraryInvariant(activeSet, manifest);
    FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecision decision = FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionForEnumeration(activeSet.isCompleteTraversal,
                                                                                                                                                                      activeSet.libraries.count,
                                                                                                                                                                      invariant.isVerified,
                                                                                                                                                                      manifest.isComplete);
    switch (decision) {
        case FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionPending:
            session.libraryOpenStatus = @"postopen_library_pending";
            session.libraryOpenReason = @"project_bootstrap_public_enrolled_library_open_pending";
            *reason = session.libraryOpenReason;
            return FCPCCDisposableProjectBootstrapObservationResultPending;
        case FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionVerified:
            session.libraryOpenStatus = @"postopen_exact_enrolled_library_verified";
            session.libraryOpenReason = @"project_bootstrap_exact_enrolled_library_verified_after_public_open";
            return FCPCCDisposableProjectBootstrapObservationResultVerified;
        case FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionReject:
            *reason = invariant.reason.length > 0
                ? invariant.reason
                : @"project_bootstrap_postopen_library_state_unverified";
            session.libraryOpenStatus = @"postopen_library_verification_failed";
            session.libraryOpenReason = *reason;
            return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
}

static FCPCCDisposableProjectBootstrapObservationResult FCPCCDisposableProjectBootstrapResolveCreatedSequence(FCPCCDisposableProjectBootstrapSession *session,
                                                                                                                NSString **reason) {
    if (!FCPCCReceiverUsesValidatedMethod(session.library, &session->_contracts.deepLoadedSequences, reason)) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    id sequencesValue = ((FCPCCObjectGetter)session.contracts.deepLoadedSequences.implementation)(
        session.library,
        session.contracts.deepLoadedSequences.selector);
    NSArray *sequences = FCPCCDisposableProjectBootstrapArrayFromSetOrArray(sequencesValue);
    if (sequences == nil) {
        *reason = @"project_bootstrap_deep_loaded_sequences_type_unsupported";
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    id exactSequence = nil;
    for (id candidate in sequences) {
        if (!FCPCCReceiverUsesValidatedMethod(candidate, &session->_contracts.displayName, reason)
            || !FCPCCReceiverUsesValidatedMethod(candidate, &session->_contracts.identifier, reason)) {
            return FCPCCDisposableProjectBootstrapObservationResultFailed;
        }
        id displayNameValue = ((FCPCCObjectGetter)session.contracts.displayName.implementation)(
            candidate,
            session.contracts.displayName.selector);
        if (![displayNameValue isKindOfClass:[NSString class]]) {
            *reason = @"project_bootstrap_created_sequence_display_name_unavailable";
            return FCPCCDisposableProjectBootstrapObservationResultFailed;
        }
        if ([(NSString *)displayNameValue isEqualToString:FCPCCDisposableProjectBootstrapProjectName]) {
            if (exactSequence != nil) {
                *reason = @"project_bootstrap_created_sequence_exact_name_not_unique";
                return FCPCCDisposableProjectBootstrapObservationResultFailed;
            }
            exactSequence = candidate;
        }
    }
    if (exactSequence == nil) {
        *reason = @"project_bootstrap_created_sequence_pending";
        return FCPCCDisposableProjectBootstrapObservationResultPending;
    }
    NSString *identifier = FCPCCDisposableProjectBootstrapValidatedIdentifier(exactSequence,
                                                                                &session->_contracts.identifier,
                                                                                reason);
    if (identifier == nil) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    session.sequence = exactSequence;
    session.sequenceIdentifier = identifier;
    return FCPCCDisposableProjectBootstrapObservationResultVerified;
}

static FCPCCDisposableProjectBootstrapObservationResult FCPCCDisposableProjectBootstrapLoadExactSequenceInEditor(FCPCCDisposableProjectBootstrapSession *session,
                                                                                                                   NSString **reason) {
    id appController = NSApp.delegate;
    if (!FCPCCReceiverUsesValidatedMethod(appController, &session->_contracts.activeEditorContainer, reason)) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    id editorContainer = ((FCPCCObjectGetter)session.contracts.activeEditorContainer.implementation)(
        appController,
        session.contracts.activeEditorContainer.selector);
    if (editorContainer == nil) {
        *reason = @"project_bootstrap_active_editor_container_pending";
        return FCPCCDisposableProjectBootstrapObservationResultPending;
    }
    if (!FCPCCReceiverUsesValidatedMethod(editorContainer, &session->_contracts.loadEditorForSequence, reason)
        || !FCPCCReceiverUsesValidatedMethod(editorContainer, &session->_contracts.editorTimelineModule, reason)) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    ((FCPCCVoidObjectMethod)session.contracts.loadEditorForSequence.implementation)(
        editorContainer,
        session.contracts.loadEditorForSequence.selector,
        session.sequence);
    return FCPCCDisposableProjectBootstrapObservationResultVerified;
}

static FCPCCDisposableProjectBootstrapObservationResult FCPCCDisposableProjectBootstrapObserveExactLoadedEditor(FCPCCDisposableProjectBootstrapSession *session,
                                                                                                                  NSString **reason) {
    id appController = NSApp.delegate;
    if (!FCPCCReceiverUsesValidatedMethod(appController, &session->_contracts.activeEditorContainer, reason)) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    id editorContainer = ((FCPCCObjectGetter)session.contracts.activeEditorContainer.implementation)(
        appController,
        session.contracts.activeEditorContainer.selector);
    if (editorContainer == nil) {
        *reason = @"project_bootstrap_active_editor_container_pending";
        return FCPCCDisposableProjectBootstrapObservationResultPending;
    }
    if (!FCPCCReceiverUsesValidatedMethod(editorContainer, &session->_contracts.editorTimelineModule, reason)) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    id timeline = ((FCPCCObjectGetter)session.contracts.editorTimelineModule.implementation)(
        editorContainer,
        session.contracts.editorTimelineModule.selector);
    if (timeline == nil) {
        *reason = @"project_bootstrap_timeline_module_pending";
        return FCPCCDisposableProjectBootstrapObservationResultPending;
    }
    if (!FCPCCReceiverUsesValidatedMethod(timeline, &session->_contracts.timelineSequence, reason)
        || !FCPCCReceiverUsesValidatedMethod(timeline, &session->_contracts.timelinePerformEdit, reason)) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    id loadedSequence = ((FCPCCObjectGetter)session.contracts.timelineSequence.implementation)(
        timeline,
        session.contracts.timelineSequence.selector);
    if (loadedSequence == nil) {
        *reason = @"project_bootstrap_loaded_sequence_pending";
        return FCPCCDisposableProjectBootstrapObservationResultPending;
    }
    NSString *loadedIdentifier = FCPCCDisposableProjectBootstrapValidatedIdentifier(loadedSequence,
                                                                                     &session->_contracts.identifier,
                                                                                      reason);
    if (loadedIdentifier == nil) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    if (![loadedIdentifier isEqualToString:session.sequenceIdentifier]) {
        *reason = @"project_bootstrap_exact_sequence_not_loaded_pending";
        return FCPCCDisposableProjectBootstrapObservationResultPending;
    }
    // Continue the empty-primary check against the exact editor-loaded object,
    // not merely the earlier deep-loaded object whose identifier matched.
    session.sequence = loadedSequence;
    if (!FCPCCReceiverUsesValidatedMethod(loadedSequence, &session->_contracts.frameSize, reason)
        || !FCPCCReceiverUsesValidatedMethod(loadedSequence, &session->_contracts.frameDuration, reason)) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    CGSize frameSize = ((FCPCCCGSizeGetter)session.contracts.frameSize.implementation)(
        loadedSequence,
        session.contracts.frameSize.selector);
    CMTime frameDuration = ((FCPCCCMTimeGetter)session.contracts.frameDuration.implementation)(
        loadedSequence,
        session.contracts.frameDuration.selector);
    if (!isfinite(frameSize.width)
        || !isfinite(frameSize.height)
        || frameSize.width <= 0.0
        || frameSize.height <= 0.0
        || !CMTIME_IS_VALID(frameDuration)
        || !CMTIME_IS_NUMERIC(frameDuration)
        || frameDuration.value <= 0
        || frameDuration.timescale <= 0) {
        *reason = @"project_bootstrap_actual_project_format_unavailable";
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    NSArray *primaryItems = FCPCCDisposableProjectBootstrapPrimaryStorylineItems(session, reason);
    if (primaryItems == nil) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    if (primaryItems.count != 0) {
        *reason = @"project_bootstrap_new_sequence_primary_storyline_not_empty";
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    session.timeline = timeline;
    session.observedFrameSize = frameSize;
    session.observedFrameDuration = frameDuration;
    session.hasObservedProjectFormat = YES;
    return FCPCCDisposableProjectBootstrapObservationResultVerified;
}

static BOOL FCPCCDisposableProjectBootstrapImportFixedFixtures(FCPCCDisposableProjectBootstrapSession *session,
                                                               NSString **reason) {
    if (session.mediaEventProject == nil || session.clipEvidence.count != 0) {
        *reason = @"project_bootstrap_import_precondition_invalid";
        return NO;
    }
    NSMutableSet<NSString *> *seenIdentifiers = [[NSMutableSet alloc] initWithCapacity:3];
    for (NSUInteger index = 0; index < 3; index += 1) {
        NSString *sourcePath = FCPCCDisposableProjectBootstrapFixturePathAtIndex(index);
        NSURL *sourceURL = [NSURL fileURLWithPath:sourcePath];
        session.importInvocationCount += 1;
        id importedMedia = ((FCPCCMediaEventProjectNewClip)session.contracts.newClipFromURL.implementation)(
            session.mediaEventProject,
            session.contracts.newClipFromURL.selector,
            sourceURL,
            0);
        if (importedMedia == nil) {
            *reason = @"project_bootstrap_new_clip_from_fixed_fixture_returned_nil";
            return NO;
        }
        ((FCPCCVoidObjectMethod)session.contracts.addOwnedClip.implementation)(
            session.mediaEventProject,
            session.contracts.addOwnedClip.selector,
            importedMedia);
        FCPCCDisposableProjectClipEvidence *evidence = nil;
        if (!FCPCCDisposableProjectBootstrapValidateImportedMedia(session,
                                                                    importedMedia,
                                                                    sourcePath,
                                                                    &evidence,
                                                                    reason)) {
            return NO;
        }
        if ([seenIdentifiers containsObject:evidence.mediaIdentifier]) {
            *reason = @"project_bootstrap_imported_media_identifiers_not_unique";
            return NO;
        }
        [seenIdentifiers addObject:evidence.mediaIdentifier];
        [session.clipEvidence addObject:evidence];
    }
    return YES;
}

static FCPCCDisposableProjectBootstrapObservationResult FCPCCDisposableProjectBootstrapVerifyImportedFixtures(FCPCCDisposableProjectBootstrapSession *session,
                                                                                                                NSString **reason) {
    if (!FCPCCReceiverUsesValidatedMethod(session.mediaEventProject, &session->_contracts.mediaEventOwnedClips, reason)) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    id ownedClipsValue = ((FCPCCObjectGetter)session.contracts.mediaEventOwnedClips.implementation)(
        session.mediaEventProject,
        session.contracts.mediaEventOwnedClips.selector);
    NSArray *ownedClips = FCPCCDisposableProjectBootstrapArrayFromSetOrArray(ownedClipsValue);
    if (ownedClips == nil) {
        *reason = @"project_bootstrap_owned_clips_type_unsupported";
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    if (ownedClips.count < 3) {
        *reason = @"project_bootstrap_imported_media_pending";
        return FCPCCDisposableProjectBootstrapObservationResultPending;
    }
    if (ownedClips.count != 3 || session.clipEvidence.count != 3) {
        *reason = @"project_bootstrap_owned_clips_count_not_exactly_three";
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    NSMutableSet<NSString *> *observedIdentifiers = [[NSMutableSet alloc] initWithCapacity:3];
    for (id candidate in ownedClips) {
        FCPCCDisposableProjectClipEvidence *observed = nil;
        NSString *validationReason = nil;
        BOOL matchedKnownPath = NO;
        for (NSUInteger index = 0; index < 3; index += 1) {
            if (FCPCCDisposableProjectBootstrapValidateImportedMedia(session,
                                                                       candidate,
                                                                       FCPCCDisposableProjectBootstrapFixturePathAtIndex(index),
                                                                       &observed,
                                                                       &validationReason)) {
                matchedKnownPath = YES;
                break;
            }
        }
        if (!matchedKnownPath || observed == nil || [observedIdentifiers containsObject:observed.mediaIdentifier]) {
            *reason = @"project_bootstrap_owned_clips_source_identity_mismatch";
            return FCPCCDisposableProjectBootstrapObservationResultFailed;
        }
        [observedIdentifiers addObject:observed.mediaIdentifier];
    }
    for (FCPCCDisposableProjectClipEvidence *evidence in session.clipEvidence) {
        if (![observedIdentifiers containsObject:evidence.mediaIdentifier]) {
            *reason = @"project_bootstrap_imported_media_identifier_not_persisted";
            return FCPCCDisposableProjectBootstrapObservationResultPending;
        }
    }
    return FCPCCDisposableProjectBootstrapObservationResultVerified;
}

static BOOL FCPCCDisposableProjectBootstrapBeginAppendAtCurrentIndex(FCPCCDisposableProjectBootstrapSession *session,
                                                                      NSString **reason) {
    if (session.appendIndex >= session.clipEvidence.count
        || session.appendIndex >= 3
        || !FCPCCReceiverUsesValidatedMethod(session.timeline, &session->_contracts.timelinePerformEdit, reason)) {
        if (session.appendIndex >= session.clipEvidence.count || session.appendIndex >= 3) {
            *reason = @"project_bootstrap_append_index_out_of_range";
        }
        return NO;
    }
    FCPCCDisposableProjectClipEvidence *evidence = session.clipEvidence[session.appendIndex];
    FCPCCDisposableProjectClipEvidence *validatedEvidence = nil;
    if (!FCPCCDisposableProjectBootstrapValidateImportedMedia(session,
                                                                evidence.media,
                                                                evidence.canonicalSourcePath,
                                                                &validatedEvidence,
                                                                reason)
        || ![validatedEvidence.mediaIdentifier isEqualToString:evidence.mediaIdentifier]) {
        if (validatedEvidence != nil) {
            *reason = @"project_bootstrap_append_source_identifier_changed";
        }
        return NO;
    }
    id allocatedPasteboard = [session.contracts.pasteboardInitWithName.targetClass alloc];
    if (!FCPCCReceiverUsesValidatedMethod(allocatedPasteboard, &session->_contracts.pasteboardInitWithName, reason)) {
        return NO;
    }
    NSString *pasteboardName = [FCPCCDisposableProjectBootstrapPasteboardPrefix stringByAppendingString:NSUUID.UUID.UUIDString];
    id pasteboard = ((FCPCCPasteboardInitializer)session.contracts.pasteboardInitWithName.implementation)(
        allocatedPasteboard,
        session.contracts.pasteboardInitWithName.selector,
        pasteboardName);
    if (!FCPCCReceiverUsesValidatedMethod(pasteboard, &session->_contracts.pasteboardWriteRanges, reason)) {
        return NO;
    }
    id mediaRange = ((FCPCCFigTimeRangeAndObjectFactory)session.contracts.figTimeRangeAndObjectFactory.implementation)(
        (id)session.contracts.figTimeRangeAndObjectFactory.targetClass,
        session.contracts.figTimeRangeAndObjectFactory.selector,
        evidence.clippedRange,
        evidence.media);
    if (mediaRange == nil) {
        *reason = @"project_bootstrap_fig_time_range_and_object_factory_returned_nil";
        return NO;
    }
    BOOL wroteRanges = ((FCPCCPasteboardWriteRanges)session.contracts.pasteboardWriteRanges.implementation)(
        pasteboard,
        session.contracts.pasteboardWriteRanges.selector,
        @[mediaRange],
        nil);
    if (!wroteRanges) {
        *reason = @"project_bootstrap_pasteboard_write_ranges_failed";
        return NO;
    }
    id editAction = ((FCPCCEditActionFactory)session.contracts.editActionFactory.implementation)(
        (id)session.contracts.editActionFactory.targetClass,
        session.contracts.editActionFactory.selector,
        2,
        NO,
        @"all");
    if (editAction == nil) {
        *reason = @"project_bootstrap_fixed_append_edit_action_unavailable";
        return NO;
    }
    session.currentPasteboard = pasteboard;
    session.currentPasteboardName = pasteboardName;
    session.appendInvocationCount += 1;
    ((FCPCCTimelinePerformEdit)session.contracts.timelinePerformEdit.implementation)(
        session.timeline,
        session.contracts.timelinePerformEdit.selector,
        editAction,
        pasteboardName,
        NO);
    return YES;
}

static FCPCCDisposableProjectBootstrapObservationResult FCPCCDisposableProjectBootstrapVerifyPrimaryStoryline(FCPCCDisposableProjectBootstrapSession *session,
                                                                                                                NSUInteger expectedCount,
                                                                                                                NSString **reason) {
    NSArray *items = FCPCCDisposableProjectBootstrapPrimaryStorylineItems(session, reason);
    if (items == nil) {
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }
    if (items.count < expectedCount) {
        *reason = @"project_bootstrap_primary_storyline_pending";
        return FCPCCDisposableProjectBootstrapObservationResultPending;
    }
    if (!FCPCCDisposableProjectBootstrapHasExactExpectedPrimaryStorylineCount(items.count,
                                                                                expectedCount,
                                                                                session.clipEvidence.count)) {
        *reason = @"project_bootstrap_primary_storyline_count_mismatch";
        return FCPCCDisposableProjectBootstrapObservationResultFailed;
    }

    CMTime previousEnd = kCMTimeInvalid;
    for (NSUInteger index = 0; index < expectedCount; index += 1) {
        id item = items[index];
        FCPCCDisposableProjectClipEvidence *evidence = session.clipEvidence[index];
        NSString *timelineItemIdentifier = FCPCCDisposableProjectBootstrapValidatedIdentifier(item,
                                                                                                &session->_contracts.identifier,
                                                                                                reason);
        if (timelineItemIdentifier == nil
            || !FCPCCReceiverUsesValidatedMethod(item, &session->_contracts.representedToolObject, reason)
            || !FCPCCReceiverUsesValidatedMethod(item, &session->_contracts.timelineRange, reason)) {
            return FCPCCDisposableProjectBootstrapObservationResultFailed;
        }
        id representedMedia = ((FCPCCObjectGetter)session.contracts.representedToolObject.implementation)(
            item,
            session.contracts.representedToolObject.selector);
        FCPCCDisposableProjectClipEvidence *representedEvidence = nil;
        if (!FCPCCDisposableProjectBootstrapValidateImportedMedia(session,
                                                                    representedMedia,
                                                                    evidence.canonicalSourcePath,
                                                                    &representedEvidence,
                                                                    reason)
            || ![representedEvidence.mediaIdentifier isEqualToString:evidence.mediaIdentifier]) {
            if (representedEvidence != nil) {
                *reason = @"project_bootstrap_primary_storyline_source_identifier_mismatch";
            }
            return FCPCCDisposableProjectBootstrapObservationResultFailed;
        }
        CMTimeRange timelineRange = ((FCPCCCMTimeRangeGetter)session.contracts.timelineRange.implementation)(
            item,
            session.contracts.timelineRange.selector);
        if (!FCPCCDisposableProjectBootstrapValidRange(timelineRange)) {
            *reason = @"project_bootstrap_primary_storyline_timeline_range_invalid";
            return FCPCCDisposableProjectBootstrapObservationResultFailed;
        }
        if (index > 0 && CMTimeCompare(timelineRange.start, previousEnd) != 0) {
            *reason = @"project_bootstrap_primary_storyline_items_not_adjacent";
            return FCPCCDisposableProjectBootstrapObservationResultFailed;
        }
        evidence.timelineItemIdentifier = timelineItemIdentifier;
        evidence.timelineRange = timelineRange;
        evidence.hasTimelineRange = YES;
        previousEnd = CMTimeAdd(timelineRange.start, timelineRange.duration);
    }
    return FCPCCDisposableProjectBootstrapObservationResultVerified;
}

static void FCPCCAdvanceDisposableProjectBootstrap(FCPCCDisposableProjectBootstrapSession *session) {
    if (session == nil
        || session.state == FCPCCDisposableProjectBootstrapStateFinished
        || ![NSThread isMainThread]) {
        if (session != nil && session.state != FCPCCDisposableProjectBootstrapStateFinished) {
            FCPCCFinishDisposableProjectBootstrap(session,
                                                   @"partial_unverified",
                                                   @"project_bootstrap_main_queue_delivery_failed");
        }
        return;
    }
    NSString *reason = nil;
    FCPCCDisposableProjectBootstrapObservationResult observation = FCPCCDisposableProjectBootstrapObservationResultFailed;
    switch (session.state) {
        case FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenCompletion:
            if (!session.libraryOpenCompletionDelivered) {
                FCPCCScheduleDisposableProjectBootstrapObservation(session);
                return;
            }
            if (!session.libraryOpenCompletionSucceeded) {
                FCPCCFinishDisposableProjectBootstrap(session,
                                                       @"rejected",
                                                       session.libraryOpenReason.length > 0
                                                       ? session.libraryOpenReason
                                                       : @"project_bootstrap_public_enrolled_library_open_unverified");
                return;
            }
            session.state = FCPCCDisposableProjectBootstrapStateWaitingForOpenedLibrary;
            FCPCCScheduleDisposableProjectBootstrapObservation(session);
            return;

        case FCPCCDisposableProjectBootstrapStateWaitingForOpenedLibrary:
            observation = FCPCCDisposableProjectBootstrapObservePostopenEnrolledLibrary(session, &reason);
            if (observation == FCPCCDisposableProjectBootstrapObservationResultPending) {
                FCPCCScheduleDisposableProjectBootstrapObservation(session);
                return;
            }
            if (observation != FCPCCDisposableProjectBootstrapObservationResultVerified) {
                FCPCCFinishDisposableProjectBootstrap(session, @"rejected", reason);
                return;
            }
            if (!FCPCCDisposableProjectBootstrapBeginProjectCreation(session, &reason)) {
                FCPCCFinishDisposableProjectBootstrap(session, @"rejected", reason);
                return;
            }
            session.state = FCPCCDisposableProjectBootstrapStateWaitingForSequence;
            FCPCCScheduleDisposableProjectBootstrapObservation(session);
            return;

        case FCPCCDisposableProjectBootstrapStateWaitingForSequence:
            observation = FCPCCDisposableProjectBootstrapResolveCreatedSequence(session, &reason);
            if (observation == FCPCCDisposableProjectBootstrapObservationResultPending) {
                FCPCCScheduleDisposableProjectBootstrapObservation(session);
                return;
            }
            if (observation != FCPCCDisposableProjectBootstrapObservationResultVerified) {
                FCPCCFinishDisposableProjectBootstrap(session, @"partial_unverified", reason);
                return;
            }
            observation = FCPCCDisposableProjectBootstrapLoadExactSequenceInEditor(session, &reason);
            if (observation == FCPCCDisposableProjectBootstrapObservationResultPending) {
                FCPCCScheduleDisposableProjectBootstrapObservation(session);
                return;
            }
            if (observation != FCPCCDisposableProjectBootstrapObservationResultVerified) {
                FCPCCFinishDisposableProjectBootstrap(session, @"partial_unverified", reason);
                return;
            }
            session.state = FCPCCDisposableProjectBootstrapStateWaitingForEditor;
            FCPCCScheduleDisposableProjectBootstrapObservation(session);
            return;

        case FCPCCDisposableProjectBootstrapStateWaitingForEditor:
            observation = FCPCCDisposableProjectBootstrapObserveExactLoadedEditor(session, &reason);
            if (observation == FCPCCDisposableProjectBootstrapObservationResultPending) {
                FCPCCScheduleDisposableProjectBootstrapObservation(session);
                return;
            }
            if (observation != FCPCCDisposableProjectBootstrapObservationResultVerified) {
                FCPCCFinishDisposableProjectBootstrap(session, @"partial_unverified", reason);
                return;
            }
            if (!FCPCCDisposableProjectBootstrapImportFixedFixtures(session, &reason)) {
                FCPCCFinishDisposableProjectBootstrap(session, @"partial_unverified", reason);
                return;
            }
            session.state = FCPCCDisposableProjectBootstrapStateWaitingForImports;
            FCPCCScheduleDisposableProjectBootstrapObservation(session);
            return;

        case FCPCCDisposableProjectBootstrapStateWaitingForImports:
            observation = FCPCCDisposableProjectBootstrapVerifyImportedFixtures(session, &reason);
            if (observation == FCPCCDisposableProjectBootstrapObservationResultPending) {
                FCPCCScheduleDisposableProjectBootstrapObservation(session);
                return;
            }
            if (observation != FCPCCDisposableProjectBootstrapObservationResultVerified) {
                FCPCCFinishDisposableProjectBootstrap(session, @"partial_unverified", reason);
                return;
            }
            session.state = FCPCCDisposableProjectBootstrapStateAppending;
            FCPCCScheduleDisposableProjectBootstrapObservation(session);
            return;

        case FCPCCDisposableProjectBootstrapStateAppending:
            if (!FCPCCDisposableProjectBootstrapBeginAppendAtCurrentIndex(session, &reason)) {
                FCPCCFinishDisposableProjectBootstrap(session, @"partial_unverified", reason);
                return;
            }
            session.state = FCPCCDisposableProjectBootstrapStateWaitingForAppendVerification;
            FCPCCScheduleDisposableProjectBootstrapObservation(session);
            return;

        case FCPCCDisposableProjectBootstrapStateWaitingForAppendVerification:
            observation = FCPCCDisposableProjectBootstrapVerifyPrimaryStoryline(session,
                                                                                  session.appendIndex + 1,
                                                                                  &reason);
            if (observation == FCPCCDisposableProjectBootstrapObservationResultPending) {
                FCPCCScheduleDisposableProjectBootstrapObservation(session);
                return;
            }
            if (observation != FCPCCDisposableProjectBootstrapObservationResultVerified) {
                FCPCCFinishDisposableProjectBootstrap(session, @"partial_unverified", reason);
                return;
            }
            session.currentPasteboard = nil;
            session.currentPasteboardName = nil;
            session.appendIndex += 1;
            if (session.appendIndex < session.clipEvidence.count) {
                session.state = FCPCCDisposableProjectBootstrapStateAppending;
                FCPCCScheduleDisposableProjectBootstrapObservation(session);
                return;
            }
            FCPCCFinishDisposableProjectBootstrap(session,
                                                   @"verified",
                                                   @"project_created_imported_appended_primary_storyline_verified");
            return;

        case FCPCCDisposableProjectBootstrapStatePreflight:
        case FCPCCDisposableProjectBootstrapStateWaitingForLibraryOpenInvocation:
        case FCPCCDisposableProjectBootstrapStateFinished:
            FCPCCFinishDisposableProjectBootstrap(session,
                                                   FCPCCDisposableProjectBootstrapHasMutated(session) ? @"partial_unverified" : @"rejected",
                                                   @"project_bootstrap_invalid_state_transition");
            return;
    }
}

static void FCPCCRunDisposableProjectBootstrap(FCPCCDisposableProjectBootstrapSession *session) {
    NSString *reason = nil;
    if (session == nil || FCPCCDisposableProjectBootstrapActiveSession != session) {
        if (session != nil) {
            FCPCCFinishDisposableProjectBootstrap(session,
                                                   @"rejected",
                                                   @"project_bootstrap_active_session_root_unavailable");
        } else {
            FCPCCFinishDisposableProjectBootstrapScheduling();
        }
        return;
    }
    if (![NSThread isMainThread]) {
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", @"project_bootstrap_requires_main_thread");
        return;
    }
    if (!FCPCCDisposableProjectBootstrapEnvironmentIsExact()) {
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", @"project_bootstrap_environment_flag_not_exact");
        return;
    }
    if (!FCPCCReadOnlyHostGatePasses(&reason)) {
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", reason ?: @"project_bootstrap_host_containment_unverified");
        return;
    }
    if (!FCPCCDisposableProjectBootstrapValidateAllFixtures(&reason)) {
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", reason);
        return;
    }
    session.fixtureHashesVerifiedBeforeMutation = YES;
    FCPCCDisposableProjectBootstrapContracts contracts = {0};
    if (!FCPCCResolveDisposableProjectBootstrapContracts(&contracts, &reason)) {
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", reason);
        return;
    }
    session.contracts = contracts;
    FCPCCLibraryManifestRecord *manifest = [FCPCCLibraryManifestRecord bundledManifest];
    FCPCCFixedModelTraversalAdapter *adapter = [[FCPCCFixedModelTraversalAdapter alloc] init];
    FCPCCReadOnlyLibrarySet *activeSet = [adapter enumerateCompleteOpenLibrarySet];
    FCPCCDisposableProjectBootstrapLibraryOpenDecision libraryOpenDecision = FCPCCDisposableProjectBootstrapInitialLibraryOpenDecision(activeSet,
                                                                                                                                           manifest,
                                                                                                                                           &reason);
    if (libraryOpenDecision == FCPCCDisposableProjectBootstrapLibraryOpenDecisionReject) {
        session.libraryOpenStatus = @"not_invoked";
        session.libraryOpenReason = reason.length > 0
            ? reason
            : @"project_bootstrap_initial_open_library_state_unverified";
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", session.libraryOpenReason);
        return;
    }
    if (libraryOpenDecision == FCPCCDisposableProjectBootstrapLibraryOpenDecisionOpenEnrolledLibrary) {
        NSURL *enrolledLibraryURL = nil;
        if (!FCPCCDisposableProjectBootstrapValidateCanonicalEnrolledLibraryForPublicOpen(manifest,
                                                                                            &enrolledLibraryURL,
                                                                                            &reason)) {
            session.libraryOpenStatus = @"not_invoked";
            session.libraryOpenReason = reason.length > 0
                ? reason
                : @"project_bootstrap_enrolled_library_preopen_validation_failed";
            FCPCCFinishDisposableProjectBootstrap(session, @"rejected", session.libraryOpenReason);
            return;
        }
        FCPCCDisposableProjectBootstrapDispatchPublicEnrolledLibraryOpen(session, enrolledLibraryURL);
        return;
    }

    session.libraryOpenStatus = @"not_required_exact_enrolled_library_already_open";
    session.libraryOpenReason = @"project_bootstrap_exact_enrolled_library_already_open";
    if (!FCPCCDisposableProjectBootstrapBeginProjectCreation(session, &reason)) {
        FCPCCFinishDisposableProjectBootstrap(session, @"rejected", reason);
        return;
    }
    session.state = FCPCCDisposableProjectBootstrapStateWaitingForSequence;
    FCPCCScheduleDisposableProjectBootstrapObservation(session);
}

#if defined(FCPCC_RUNTIME_TESTING)
BOOL FCPCCDisposableLibraryBootstrapTestEnvironmentIsExact(NSString *value) {
    return [value isEqualToString:FCPCCDisposableLibraryBootstrapEnvironmentValue];
}

BOOL FCPCCDisposableLibraryBootstrapTestActiveLibraryCountAllowsCreation(NSUInteger activeLibraryCount) {
    return activeLibraryCount == 0;
}

BOOL FCPCCDisposableProjectBootstrapTestPrimaryStorylineCountIsExact(NSUInteger observedCount,
                                                                       NSUInteger expectedCount,
                                                                       NSUInteger importedCount) {
    return FCPCCDisposableProjectBootstrapHasExactExpectedPrimaryStorylineCount(observedCount,
                                                                                  expectedCount,
                                                                                  importedCount);
}

NSUInteger FCPCCDisposableProjectBootstrapTestLibraryOpenInvocationCountForInitialState(BOOL completeTraversal,
                                                                                           NSUInteger openLibraryCount,
                                                                                           BOOL exactEnrolledLibraryIsOpen,
                                                                                           BOOL manifestIsComplete) {
    return FCPCCDisposableProjectBootstrapLibraryOpenDecisionForEnumeration(completeTraversal,
                                                                              openLibraryCount,
                                                                              exactEnrolledLibraryIsOpen,
                                                                              manifestIsComplete)
        == FCPCCDisposableProjectBootstrapLibraryOpenDecisionOpenEnrolledLibrary ? 1 : 0;
}

BOOL FCPCCDisposableProjectBootstrapTestInitialLibraryStateRejects(BOOL completeTraversal,
                                                                     NSUInteger openLibraryCount,
                                                                     BOOL exactEnrolledLibraryIsOpen,
                                                                     BOOL manifestIsComplete) {
    return FCPCCDisposableProjectBootstrapLibraryOpenDecisionForEnumeration(completeTraversal,
                                                                              openLibraryCount,
                                                                              exactEnrolledLibraryIsOpen,
                                                                              manifestIsComplete)
        == FCPCCDisposableProjectBootstrapLibraryOpenDecisionReject;
}

BOOL FCPCCDisposableProjectBootstrapTestPostopenLibraryObservationIsPending(BOOL completeTraversal,
                                                                              NSUInteger openLibraryCount,
                                                                              BOOL exactEnrolledLibraryIsOpen,
                                                                              BOOL manifestIsComplete) {
    return FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionForEnumeration(completeTraversal,
                                                                                             openLibraryCount,
                                                                                             exactEnrolledLibraryIsOpen,
                                                                                             manifestIsComplete)
        == FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionPending;
}

BOOL FCPCCDisposableProjectBootstrapTestPostopenLibraryObservationIsVerified(BOOL completeTraversal,
                                                                               NSUInteger openLibraryCount,
                                                                               BOOL exactEnrolledLibraryIsOpen,
                                                                               BOOL manifestIsComplete) {
    return FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionForEnumeration(completeTraversal,
                                                                                             openLibraryCount,
                                                                                             exactEnrolledLibraryIsOpen,
                                                                                             manifestIsComplete)
        == FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionVerified;
}

BOOL FCPCCDisposableProjectBootstrapTestPostopenLibraryObservationRejects(BOOL completeTraversal,
                                                                            NSUInteger openLibraryCount,
                                                                            BOOL exactEnrolledLibraryIsOpen,
                                                                            BOOL manifestIsComplete) {
    return FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionForEnumeration(completeTraversal,
                                                                                             openLibraryCount,
                                                                                             exactEnrolledLibraryIsOpen,
                                                                                             manifestIsComplete)
        == FCPCCDisposableProjectBootstrapPostopenLibraryObservationDecisionReject;
}

BOOL FCPCCDisposableProjectBootstrapTestFailedLibraryOpenLeavesProjectMutationsAtZero(BOOL completionHasDocument,
                                                                                        BOOL completionErrorIsNil,
                                                                                        NSUInteger projectCreationInvocationCount,
                                                                                        NSUInteger importInvocationCount,
                                                                                        NSUInteger appendInvocationCount) {
    return !(completionHasDocument && completionErrorIsNil)
        && projectCreationInvocationCount == 0
        && importInvocationCount == 0
        && appendInvocationCount == 0;
}

BOOL FCPCCDisposableProjectBootstrapTestActiveSessionOwnershipStartsAsyncBranch(void) {
    FCPCCDisposableProjectBootstrapSession *session = [[FCPCCDisposableProjectBootstrapSession alloc] init];
    BOOL retained = FCPCCDisposableProjectBootstrapRetainActiveSessionIfAbsent(session);
    BOOL owned = retained && FCPCCDisposableProjectBootstrapActiveSession == session;
    BOOL released = FCPCCDisposableProjectBootstrapReleaseActiveSessionIfMatching(session);
    return owned && released && FCPCCDisposableProjectBootstrapActiveSession == nil;
}

BOOL FCPCCDisposableProjectBootstrapTestDuplicateActiveSessionStartFailsClosed(void) {
    FCPCCDisposableProjectBootstrapSession *firstSession = [[FCPCCDisposableProjectBootstrapSession alloc] init];
    FCPCCDisposableProjectBootstrapSession *duplicateSession = [[FCPCCDisposableProjectBootstrapSession alloc] init];
    BOOL firstRetained = FCPCCDisposableProjectBootstrapRetainActiveSessionIfAbsent(firstSession);
    BOOL duplicateRejected = !FCPCCDisposableProjectBootstrapRetainActiveSessionIfAbsent(duplicateSession)
        && FCPCCDisposableProjectBootstrapActiveSession == firstSession;
    BOOL released = FCPCCDisposableProjectBootstrapReleaseActiveSessionIfMatching(firstSession);
    return firstRetained && duplicateRejected && released && FCPCCDisposableProjectBootstrapActiveSession == nil;
}

BOOL FCPCCDisposableProjectBootstrapTestFinishReleasesIdentityMatchingSession(void) {
    FCPCCDisposableProjectBootstrapSession *activeSession = [[FCPCCDisposableProjectBootstrapSession alloc] init];
    FCPCCDisposableProjectBootstrapSession *otherSession = [[FCPCCDisposableProjectBootstrapSession alloc] init];
    BOOL retained = FCPCCDisposableProjectBootstrapRetainActiveSessionIfAbsent(activeSession);
    BOOL wrongIdentityPreserved = !FCPCCDisposableProjectBootstrapReleaseActiveSessionIfMatching(otherSession)
        && FCPCCDisposableProjectBootstrapActiveSession == activeSession;
    BOOL matchingIdentityReleased = FCPCCDisposableProjectBootstrapReleaseActiveSessionIfMatching(activeSession)
        && FCPCCDisposableProjectBootstrapActiveSession == nil;
    return retained && wrongIdentityPreserved && matchingIdentityReleased;
}

BOOL FCPCCDisposableProjectBootstrapTestWeakCompletionIsBackedByActiveSessionRoot(void) {
    FCPCCDisposableProjectBootstrapSession *session = [[FCPCCDisposableProjectBootstrapSession alloc] init];
    BOOL retained = FCPCCDisposableProjectBootstrapRetainActiveSessionIfAbsent(session);
    __weak FCPCCDisposableProjectBootstrapSession *weakSession = session;
    session = nil;
    FCPCCDisposableProjectBootstrapSession *rootedSession = FCPCCDisposableProjectBootstrapActiveSession;
    BOOL weakCompletionIsBacked = retained
        && weakSession != nil
        && weakSession == rootedSession;
    BOOL released = FCPCCDisposableProjectBootstrapReleaseActiveSessionIfMatching(rootedSession);
    return weakCompletionIsBacked && released && FCPCCDisposableProjectBootstrapActiveSession == nil;
}

BOOL FCPCCDisposableLibraryBootstrapTestValidateAbsentCanonicalTarget(NSString *parentPath,
                                                                        NSString *targetPath,
                                                                        NSString **reason) {
    NSString *localReason = nil;
    BOOL valid = FCPCCDisposableLibraryBootstrapValidateAbsentCanonicalTarget(parentPath, targetPath, &localReason);
    if (reason != NULL) {
        *reason = localReason;
    }
    return valid;
}
#endif

static NSString *FCPCCCanonicalCMTimeToken(CMTime time) {
    return [NSString stringWithFormat:@"%lld/%d/%u/%lld",
            (long long)time.value,
            (int)time.timescale,
            (unsigned int)time.flags,
            (long long)time.epoch];
}

static NSString *FCPCCCanonicalCMTimeRangeToken(CMTimeRange range) {
    return [NSString stringWithFormat:@"%@|%@",
            FCPCCCanonicalCMTimeToken(range.start),
            FCPCCCanonicalCMTimeToken(range.duration)];
}

static void FCPCCAppendLengthDelimitedRevisionToken(NSMutableString *material, NSString *token) {
    [material appendFormat:@"%lu:", (unsigned long)token.length];
    [material appendString:token];
}

static NSString *FCPCCSHA256HexForRevisionMaterial(NSString *material) {
    NSData *data = [material dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        return nil;
    }
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    static const char hexadecimal[] = "0123456789abcdef";
    char characters[CC_SHA256_DIGEST_LENGTH * 2 + 1] = {0};
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index += 1) {
        characters[index * 2] = hexadecimal[(digest[index] >> 4) & 0x0F];
        characters[index * 2 + 1] = hexadecimal[digest[index] & 0x0F];
    }
    return [[NSString alloc] initWithBytes:characters length:sizeof(characters) - 1 encoding:NSASCIIStringEncoding];
}

static NSString *FCPCCStableIdentifierForAnchoredObject(id object,
                                                         const FCPCCValidatedFixedMethod *identifierMethod,
                                                         NSString **reason) {
    if (!FCPCCReceiverUsesValidatedMethod(object, identifierMethod, reason)) {
        return nil;
    }
    NSString *identifier = FCPCCNormalizedTypedIdentifier(((FCPCCObjectGetter)identifierMethod->implementation)(object,
                                                                                                                   identifierMethod->selector));
    if (identifier == nil) {
        *reason = @"selected_timeline_item_identifier_type_or_length_unsupported";
    }
    return identifier;
}

static BOOL FCPCCTimelineRangeForAnchoredObject(id object,
                                                const FCPCCValidatedFixedMethod *rangeMethod,
                                                CMTimeRange *range,
                                                NSString **reason) {
    if (!FCPCCReceiverUsesValidatedMethod(object, rangeMethod, reason)) {
        return NO;
    }
    CMTimeRange observedRange = ((FCPCCCMTimeRangeGetter)rangeMethod->implementation)(object, rangeMethod->selector);
    if (!FCPCCValidTimelineRange(observedRange)) {
        *reason = @"timeline_item_range_invalid";
        return NO;
    }
    *range = observedRange;
    return YES;
}

static NSString *FCPCCDerivedSelectionRevision(NSArray<FCPCCTimelineItemSnapshot *> *selectedItems) {
    if (selectedItems.count == 0) {
        return nil;
    }
    NSMutableString *material = [[NSMutableString alloc] initWithString:@"selection-v1|"];
    for (FCPCCTimelineItemSnapshot *item in selectedItems) {
        if (!FCPCCBoundedNonemptyString(item.stableItemIdentifier)) {
            return nil;
        }
        FCPCCAppendLengthDelimitedRevisionToken(material, item.stableItemIdentifier);
        FCPCCAppendLengthDelimitedRevisionToken(material, item.hasTimelineRange
            ? FCPCCCanonicalCMTimeRangeToken(item.timelineRange)
            : @"range-unavailable");
        [material appendFormat:@"%ld;", (long)item.primaryStorylineIndex];
    }
    return FCPCCSHA256HexForRevisionMaterial(material);
}

static NSString *FCPCCDerivedTimelineRevision(NSArray *primaryItems,
                                              NSString *projectName,
                                              CGSize frameSize,
                                              CMTime frameDuration,
                                              const FCPCCValidatedFixedMethod *identifierMethod,
                                              const FCPCCValidatedFixedMethod *rangeMethod,
                                              NSString **reason) {
    if (primaryItems == nil || !FCPCCBoundedNonemptyString(projectName)) {
        *reason = @"timeline_revision_primary_storyline_or_project_unavailable";
        return nil;
    }
    NSMutableString *material = [[NSMutableString alloc] initWithString:@"timeline-v1|"];
    FCPCCAppendLengthDelimitedRevisionToken(material, projectName);
    [material appendFormat:@"%.17g/%.17g|", frameSize.width, frameSize.height];
    FCPCCAppendLengthDelimitedRevisionToken(material, FCPCCCanonicalCMTimeToken(frameDuration));
    for (id item in primaryItems) {
        NSString *itemIdentifier = FCPCCStableIdentifierForAnchoredObject(item, identifierMethod, reason);
        if (itemIdentifier == nil) {
            return nil;
        }
        CMTimeRange itemRange = kCMTimeRangeInvalid;
        if (!FCPCCTimelineRangeForAnchoredObject(item, rangeMethod, &itemRange, reason)) {
            return nil;
        }
        FCPCCAppendLengthDelimitedRevisionToken(material, itemIdentifier);
        FCPCCAppendLengthDelimitedRevisionToken(material, FCPCCCanonicalCMTimeRangeToken(itemRange));
    }
    NSString *revision = FCPCCSHA256HexForRevisionMaterial(material);
    if (!FCPCCLowercaseSHA256HexStringIsValid(revision)) {
        *reason = @"timeline_revision_hash_unavailable";
        return nil;
    }
    return revision;
}

@interface FCPCCFixedModelTraversalAdapter (ContextCapture)
- (FCPCCReadOnlyContextSnapshot *)captureContextForVerifiedLibraryInvariant:(FCPCCLibraryInvariantResult *)libraryInvariant;
@end

@implementation FCPCCFixedModelTraversalAdapter (ContextCapture)

- (FCPCCReadOnlyContextSnapshot *)captureContextForVerifiedLibraryInvariant:(FCPCCLibraryInvariantResult *)libraryInvariant {
    if (libraryInvariant == nil || !libraryInvariant.isVerified) {
        NSString *reason = libraryInvariant.reason.length > 0
            ? [@"library_invariant_" stringByAppendingString:libraryInvariant.reason]
            : @"library_invariant_unverified";
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:reason];
    }

    NSString *reason = nil;
    if (!FCPCCReadOnlyHostGatePasses(&reason)) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:reason];
    }

    FCPCCValidatedFixedMethod activeEditorContainer = {0};
    FCPCCValidatedFixedMethod editorTimelineModule = {0};
    FCPCCValidatedFixedMethod timelineSequence = {0};
    FCPCCValidatedFixedMethod selectedItems = {0};
    FCPCCValidatedFixedMethod primaryObject = {0};
    FCPCCValidatedFixedMethod containedItems = {0};
    FCPCCValidatedFixedMethod displayName = {0};
    FCPCCValidatedFixedMethod identifier = {0};
    FCPCCValidatedFixedMethod frameSize = {0};
    FCPCCValidatedFixedMethod frameDuration = {0};
    FCPCCValidatedFixedMethod timelineRange = {0};
    if (!FCPCCResolveFixedMethod(&FCPCCActiveEditorContainerContract, &activeEditorContainer, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCEditorTimelineModuleContract, &editorTimelineModule, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCTimelineSequenceContract, &timelineSequence, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCSelectedItemsContract, &selectedItems, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCPrimaryObjectContract, &primaryObject, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCContainedItemsContract, &containedItems, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCDisplayNameContract, &displayName, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCIdentifierContract, &identifier, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCFrameSizeContract, &frameSize, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCFrameDurationContract, &frameDuration, &reason)
        || !FCPCCResolveFixedMethod(&FCPCCRangeContract, &timelineRange, &reason)) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:reason];
    }

    id appController = NSApp.delegate;
    if (!FCPCCReceiverUsesValidatedMethod(appController, &activeEditorContainer, &reason)) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:reason];
    }
    id editorContainer = ((FCPCCObjectGetter)activeEditorContainer.implementation)(appController, activeEditorContainer.selector);
    if (!FCPCCReceiverUsesValidatedMethod(editorContainer, &editorTimelineModule, &reason)) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:reason];
    }
    id timelineModule = ((FCPCCObjectGetter)editorTimelineModule.implementation)(editorContainer, editorTimelineModule.selector);
    if (!FCPCCReceiverUsesValidatedMethod(timelineModule, &timelineSequence, &reason)
        || !FCPCCReceiverUsesValidatedMethod(timelineModule, &selectedItems, &reason)) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:reason];
    }
    id sequence = ((FCPCCObjectGetter)timelineSequence.implementation)(timelineModule, timelineSequence.selector);
    if (!FCPCCReceiverUsesValidatedMethod(sequence, &primaryObject, &reason)
        || !FCPCCReceiverUsesValidatedMethod(sequence, &displayName, &reason)
        || !FCPCCReceiverUsesValidatedMethod(sequence, &frameSize, &reason)
        || !FCPCCReceiverUsesValidatedMethod(sequence, &frameDuration, &reason)) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:reason];
    }

    id projectNameValue = ((FCPCCObjectGetter)displayName.implementation)(sequence, displayName.selector);
    NSString *projectName = [projectNameValue isKindOfClass:[NSString class]] && FCPCCBoundedNonemptyString(projectNameValue)
        ? [projectNameValue copy]
        : nil;
    CGSize observedFrameSize = ((FCPCCCGSizeGetter)frameSize.implementation)(sequence, frameSize.selector);
    CMTime observedFrameDuration = ((FCPCCCMTimeGetter)frameDuration.implementation)(sequence, frameDuration.selector);
    if (projectName == nil
        || !isfinite(observedFrameSize.width)
        || !isfinite(observedFrameSize.height)
        || observedFrameSize.width <= 0.0
        || observedFrameSize.height <= 0.0
        || !CMTIME_IS_VALID(observedFrameDuration)
        || observedFrameDuration.value <= 0
        || observedFrameDuration.timescale <= 0) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:@"active_project_name_resolution_or_frame_rate_unavailable"];
    }

    id selectedItemsValue = ((FCPCCSelectedItemsGetter)selectedItems.implementation)(timelineModule,
                                                                                         selectedItems.selector,
                                                                                         NO,
                                                                                         NO);
    if (![selectedItemsValue isKindOfClass:[NSArray class]]) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:@"timeline_selection_type_unsupported"];
    }

    id primaryObjectValue = ((FCPCCObjectGetter)primaryObject.implementation)(sequence, primaryObject.selector);
    NSArray *primaryItems = nil;
    NSString *primaryStorylineReason = nil;
    if (FCPCCReceiverUsesValidatedMethod(primaryObjectValue, &containedItems, &primaryStorylineReason)) {
        id primaryItemsValue = ((FCPCCObjectGetter)containedItems.implementation)(primaryObjectValue, containedItems.selector);
        if ([primaryItemsValue isKindOfClass:[NSArray class]]) {
            primaryItems = primaryItemsValue;
        } else {
            primaryStorylineReason = @"primary_storyline_items_type_unsupported";
        }
    }

    if ([selectedItemsValue count] == 0) {
        return [FCPCCReadOnlyContextSnapshot snapshotWithDisposition:FCPCCReadOnlyContextDispositionNoSelection
                                                               reason:@"no_timeline_selection"
                                                    activeProjectName:projectName
                                                            frameSize:observedFrameSize
                                                        hasFrameSize:YES
                                                        frameDuration:observedFrameDuration
                                                    hasFrameDuration:YES
                                                selectedTimelineItems:@[]
                                                    selectionRevision:nil
                                                     timelineRevision:nil];
    }

    NSMutableArray<FCPCCTimelineItemSnapshot *> *snapshots = [[NSMutableArray alloc] initWithCapacity:[selectedItemsValue count]];
    BOOL selectedRangesComplete = YES;
    BOOL primaryNeighborsComplete = primaryItems != nil;
    for (id selectedItem in selectedItemsValue) {
        NSString *stableIdentifier = FCPCCStableIdentifierForAnchoredObject(selectedItem, &identifier, &reason);
        if (stableIdentifier == nil) {
            return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:reason];
        }

        CMTimeRange itemRange = kCMTimeRangeInvalid;
        NSString *rangeReason = nil;
        BOOL hasRange = FCPCCTimelineRangeForAnchoredObject(selectedItem, &timelineRange, &itemRange, &rangeReason);
        if (!hasRange) {
            selectedRangesComplete = NO;
        }

        NSInteger primaryIndex = (NSInteger)NSNotFound;
        NSString *previousIdentifier = nil;
        NSString *nextIdentifier = nil;
        if (primaryItems != nil) {
            NSUInteger selectedIndex = [primaryItems indexOfObjectIdenticalTo:selectedItem];
            if (selectedIndex != NSNotFound) {
                primaryIndex = (NSInteger)selectedIndex;
                if (selectedIndex > 0) {
                    NSString *neighborReason = nil;
                    previousIdentifier = FCPCCStableIdentifierForAnchoredObject(primaryItems[selectedIndex - 1], &identifier, &neighborReason);
                    if (previousIdentifier == nil) {
                        primaryNeighborsComplete = NO;
                    }
                }
                if (selectedIndex + 1 < primaryItems.count) {
                    NSString *neighborReason = nil;
                    nextIdentifier = FCPCCStableIdentifierForAnchoredObject(primaryItems[selectedIndex + 1], &identifier, &neighborReason);
                    if (nextIdentifier == nil) {
                        primaryNeighborsComplete = NO;
                    }
                }
            }
        }

        FCPCCTimelineItemSnapshot *snapshot = [[FCPCCTimelineItemSnapshot alloc]
            initWithStableItemIdentifier:stableIdentifier
                       canonicalSourcePath:nil
                             sourceSHA256:nil
                     sourceIdentityReason:@"source_identity_unavailable_media_url_contract_not_admitted"
                    primaryStorylineIndex:primaryIndex
    previousPrimaryStorylineItemIdentifier:previousIdentifier
        nextPrimaryStorylineItemIdentifier:nextIdentifier
                            timelineRange:itemRange
                         hasTimelineRange:hasRange
                            leadingHandle:kCMTimeInvalid
                     hasLeadingHandle:NO
                           trailingHandle:kCMTimeInvalid
                    hasTrailingHandle:NO];
        [snapshots addObject:snapshot];
    }

    NSString *selectionRevision = FCPCCDerivedSelectionRevision(snapshots);
    if (selectionRevision == nil) {
        return [FCPCCReadOnlyContextSnapshot unsupportedWithReason:@"selection_revision_unavailable"];
    }
    NSString *timelineRevisionReason = nil;
    NSString *timelineRevision = FCPCCDerivedTimelineRevision(primaryItems,
                                                               projectName,
                                                               observedFrameSize,
                                                               observedFrameDuration,
                                                               &identifier,
                                                               &timelineRange,
                                                               &timelineRevisionReason);
    NSString *partialReason = @"partial_unsupported_source_identity_unavailable_media_url_contract_not_admitted_and_handles_unavailable_no_exact_contract";
    BOOL timelineRevisionUnavailable = timelineRevision == nil || timelineRevisionReason.length > 0;
    if (!selectedRangesComplete || !primaryNeighborsComplete || timelineRevisionUnavailable) {
        partialReason = @"partial_unsupported_source_identity_unavailable_media_url_contract_not_admitted_handles_unavailable_no_exact_contract_and_primary_storyline_or_timeline_revision_unavailable";
    }
    FCPCCReadOnlyContextSnapshot *snapshot = [FCPCCReadOnlyContextSnapshot
        snapshotWithDisposition:FCPCCReadOnlyContextDispositionPartialUnsupported
                          reason:partialReason
               activeProjectName:projectName
                       frameSize:observedFrameSize
                   hasFrameSize:YES
                   frameDuration:observedFrameDuration
               hasFrameDuration:YES
           selectedTimelineItems:snapshots
               selectionRevision:selectionRevision
                timelineRevision:timelineRevision];
    if (snapshot.timelineRevision.length > 0) {
        return FCPCCValidateReadOnlySnapshotAgainstTimelineRevision(snapshot, snapshot.timelineRevision);
    }
    return snapshot;
}

@end

@interface FCPCCCapabilityStatus : NSObject
@property (nonatomic, copy, readonly) NSString *selectionSummary;
@property (nonatomic, copy, readonly) NSString *capabilitySummary;
+ (instancetype)statusForReadOnlySnapshot:(FCPCCReadOnlyContextSnapshot *)snapshot;
@end

@implementation FCPCCCapabilityStatus

+ (instancetype)statusForReadOnlySnapshot:(FCPCCReadOnlyContextSnapshot *)snapshot {
    FCPCCCapabilityStatus *status = [[self alloc] init];
    NSString *projectName = snapshot.activeProjectName ?: @"unavailable";
    switch (snapshot.disposition) {
        case FCPCCReadOnlyContextDispositionNoSelection:
            status->_selectionSummary = [NSString stringWithFormat:@"Current project: %@; selection: no_timeline_selection.", projectName];
            break;
        case FCPCCReadOnlyContextDispositionReady:
        case FCPCCReadOnlyContextDispositionPartialUnsupported: {
            NSString *format = @"format unavailable";
            if (snapshot.hasFrameSize && snapshot.hasFrameDuration) {
                double framesPerSecond = (double)snapshot.frameDuration.timescale / (double)snapshot.frameDuration.value;
                format = [NSString stringWithFormat:@"%.0f×%.0f %.3f fps", snapshot.frameSize.width, snapshot.frameSize.height, framesPerSecond];
            }
            status->_selectionSummary = [NSString stringWithFormat:@"Current project: %@; selection: %lu item(s); %@.",
                                        projectName,
                                        (unsigned long)snapshot.selectedTimelineItems.count,
                                        format];
            break;
        }
        case FCPCCReadOnlyContextDispositionStaleRevision:
        case FCPCCReadOnlyContextDispositionUnsupportedAPI:
            status->_selectionSummary = [NSString stringWithFormat:@"Current selection: unavailable (%@).", snapshot.reason];
            break;
    }
    status->_capabilitySummary = [NSString stringWithFormat:@"Capabilities: read_only_context=%@; planning_apply_undo=disabled.", snapshot.reason];
    return status;
}

@end

@implementation FCPCCBeforeAfterTransaction

- (instancetype)initWithPayload:(FCPCCMutationPayload *)payload
                   contextSnapshot:(FCPCCReadOnlyContextSnapshot *)contextSnapshot
                  libraryInvariant:(FCPCCLibraryInvariantResult *)libraryInvariant {
    self = [super init];
    if (self != nil) {
        _transactionIdentifier = NSUUID.UUID.UUIDString;
        _payload = payload;
        _effectKind = payload.effectKind;
        _contextSnapshot = contextSnapshot;
        _libraryInvariant = libraryInvariant;
    }
    return self;
}

@end

@implementation FCPCCMutationPayload

- (instancetype)initWithEffectKind:(FCPCCEffectKind)effectKind {
    self = [super init];
    if (self != nil) {
        _effectKind = effectKind;
    }
    return self;
}

@end

@implementation FCPCCNativeTargetedRotateZoomRequest

- (instancetype)initWithNormalizedTargetPoint:(CGPoint)normalizedTargetPoint
                                   scaleStart:(CGFloat)scaleStart
                                     scaleEnd:(CGFloat)scaleEnd
                         rotationStartDegrees:(CGFloat)rotationStartDegrees
                           rotationEndDegrees:(CGFloat)rotationEndDegrees
                                     duration:(CMTime)duration
                                       easing:(FCPCCNativeKeyframeEasing)easing {
    self = [super initWithEffectKind:FCPCCEffectKindNativeTargetedRotateZoom];
    if (self != nil) {
        _normalizedTargetPoint = normalizedTargetPoint;
        _scaleStart = scaleStart;
        _scaleEnd = scaleEnd;
        _rotationStartDegrees = rotationStartDegrees;
        _rotationEndDegrees = rotationEndDegrees;
        _duration = duration;
        _easing = easing;
    }
    return self;
}

@end

@implementation FCPCCNativeTransformKeyframe

- (instancetype)initWithClipLocalTime:(CMTime)clipLocalTime
                   normalizedPosition:(CGPoint)normalizedPosition
         candidateNativePixelPosition:(CGPoint)candidateNativePixelPosition
 nativePixelPositionConversionVerified:(BOOL)nativePixelPositionConversionVerified
                         uniformScale:(CGFloat)uniformScale
                      rotationDegrees:(CGFloat)rotationDegrees
                        easedProgress:(CGFloat)easedProgress {
    self = [super init];
    if (self != nil) {
        _clipLocalTime = clipLocalTime;
        _normalizedPosition = normalizedPosition;
        _candidateNativePixelPosition = candidateNativePixelPosition;
        _nativePixelPositionConversionVerified = nativePixelPositionConversionVerified;
        _uniformScale = uniformScale;
        _rotationDegrees = rotationDegrees;
        _easedProgress = easedProgress;
    }
    return self;
}

- (instancetype)initWithClipLocalTime:(CMTime)clipLocalTime
                   normalizedPosition:(CGPoint)normalizedPosition
 nativePixelPositionConversionVerified:(BOOL)nativePixelPositionConversionVerified
                         uniformScale:(CGFloat)uniformScale
                      rotationDegrees:(CGFloat)rotationDegrees
                        easedProgress:(CGFloat)easedProgress {
    return [self initWithClipLocalTime:clipLocalTime
                     normalizedPosition:normalizedPosition
          candidateNativePixelPosition:CGPointZero
   nativePixelPositionConversionVerified:NO
                          uniformScale:uniformScale
                       rotationDegrees:rotationDegrees
                         easedProgress:easedProgress];
}

@end

@implementation FCPCCNativeTargetedRotateZoomTransaction

- (instancetype)initWithRequest:(FCPCCNativeTargetedRotateZoomRequest *)request
                 contextSnapshot:(FCPCCReadOnlyContextSnapshot *)contextSnapshot
                libraryInvariant:(FCPCCLibraryInvariantResult *)libraryInvariant {
    self = [super initWithPayload:request
                   contextSnapshot:contextSnapshot
                  libraryInvariant:libraryInvariant];
    if (self != nil) {
        _request = request;
        _nativeUndoActionName = @"FCPCommandConsole: Targeted Rotate + Zoom";
    }
    return self;
}

@end

@implementation FCPCCNativeTransformState

- (instancetype)initWithStableItemIdentifier:(NSString *)stableItemIdentifier
                            selectionRevision:(NSString *)selectionRevision
                             timelineRevision:(NSString *)timelineRevision
                                    frameSize:(CGSize)frameSize
                                    keyframes:(NSArray<FCPCCNativeTransformKeyframe *> *)keyframes {
    self = [super init];
    if (self != nil) {
        _stableItemIdentifier = [stableItemIdentifier copy];
        _selectionRevision = [selectionRevision copy];
        _timelineRevision = [timelineRevision copy];
        _frameSize = frameSize;
        _keyframes = [keyframes copy];
    }
    return self;
}

@end

@interface FCPCCMutationResult ()
+ (instancetype)resultWithDisposition:(FCPCCMutationDisposition)disposition
                               reason:(NSString *)reason
                    plannedAfterState:(nullable FCPCCNativeTransformState *)plannedAfterState
                          beforeState:(nullable FCPCCNativeTransformState *)beforeState
                           afterState:(nullable FCPCCNativeTransformState *)afterState
              nativeMutationPerformed:(BOOL)nativeMutationPerformed;
+ (instancetype)unavailableWithoutPanelBinding;
@end

@implementation FCPCCMutationResult

+ (instancetype)unsupportedUnverified {
    return [self resultWithDisposition:FCPCCMutationDispositionUnsupportedUnverifiedFCP123
                                reason:FCPCCMutationErrorUnsupportedUnverifiedFCP123
                     plannedAfterState:nil
                           beforeState:nil
                            afterState:nil
               nativeMutationPerformed:NO];
}

+ (instancetype)resultWithDisposition:(FCPCCMutationDisposition)disposition
                               reason:(NSString *)reason
                    plannedAfterState:(FCPCCNativeTransformState *)plannedAfterState
                          beforeState:(FCPCCNativeTransformState *)beforeState
                           afterState:(FCPCCNativeTransformState *)afterState
              nativeMutationPerformed:(BOOL)nativeMutationPerformed {
    FCPCCMutationResult *result = [[self alloc] init];
    result->_disposition = disposition;
    result->_reason = [reason copy];
    result->_plannedAfterState = plannedAfterState;
    result->_beforeState = beforeState;
    result->_afterState = afterState;
    result->_nativeMutationPerformed = nativeMutationPerformed;
    return result;
}

+ (instancetype)unavailableWithoutPanelBinding {
    return [self resultWithDisposition:FCPCCMutationDispositionUnsupportedUnverifiedFCP123
                                reason:@"native_targeted_rotate_zoom_panel_binding_unavailable"
                     plannedAfterState:nil
                           beforeState:nil
                            afterState:nil
               nativeMutationPerformed:NO];
}

@end

// Direct-transform and transaction methods below are immutable records from
// the locally inspected Final Cut Pro 12.3 Flexo image. Every entry records
// exact class/instance placement, full ABI, image identity, and an IMP offset
// for both slices that were inspected. The route has no generic discovery:
// these literal contracts are the complete native surface admitted to
// Workflow 1.
#if defined(__arm64__)
static const char * const FCPCCNativeOnSpineTypeEncoding = "B16@0:8";
static const char * const FCPCCNativeBooleanReturnType = "B";
static const char * const FCPCCNativeActionBeginTypeEncoding = "v36@0:8@16@24B32";
static const char * const FCPCCNativeActionEndTypeEncoding = "B36@0:8@16B24^@28";
#elif defined(__x86_64__)
static const char * const FCPCCNativeOnSpineTypeEncoding = "c16@0:8";
static const char * const FCPCCNativeBooleanReturnType = "c";
static const char * const FCPCCNativeActionBeginTypeEncoding = "v36@0:8@16@24c32";
static const char * const FCPCCNativeActionEndTypeEncoding = "c36@0:8@16c24^@28";
#else
static const char * const FCPCCNativeOnSpineTypeEncoding = "";
static const char * const FCPCCNativeBooleanReturnType = "";
static const char * const FCPCCNativeActionBeginTypeEncoding = "";
static const char * const FCPCCNativeActionEndTypeEncoding = "";
#endif

static const FCPCCFixedObjCMethodContract FCPCCNativeTargetedRotateZoomStaticContracts[] = {
    // Reacquire exactly one spine clip by its immutable anchored-object ID.
    { "FFAnchoredObject", "identifier", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0xa7a50, 0xe75d0 },
    { "FFAnchoredObject", "onSpine", FCPCCNativeOnSpineTypeEncoding, FCPCCNativeBooleanReturnType, 2, NO, FCPCCFixedMethodImageFlexo, 0xb0b90, 0xf4f20 },
    // The inspected FFInspectableObject category remains an instance method
    // on FFAnchoredObject. It may not be replaced with selector probing.
    { "FFAnchoredObject", "representedToolObject", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x61265c, 0x859350 },
    { "FFAnchoredClip", "videoEffects", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x7be58, 0xa7750 },
    { "FFEffectStack", "xform3DEffect", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x158eec, 0x1f7750 },
    { "FFEffectStack", "undoHandler", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x15a130, 0x1f8ce0 },
    { "FFHeXForm3DEffect", "getPixelPositionAtTime:x:y:z:", "v64@0:8{?=qiIq}16^d40^d48^d56", "v", 6, NO, FCPCCFixedMethodImageFlexo, 0x3e6a10, 0x57b020 },
    { "FFHeXForm3DEffect", "getRotationAtTime:x:y:z:", "v64@0:8{?=qiIq}16^d40^d48^d56", "v", 6, NO, FCPCCFixedMethodImageFlexo, 0x3e6a84, 0x57b0a0 },
    { "FFHeXForm3DEffect", "getScaleAtTime:x:y:z:", "v64@0:8{?=qiIq}16^d40^d48^d56", "v", 6, NO, FCPCCFixedMethodImageFlexo, 0x3e6ac0, 0x57b0c0 },
    { "FFHeXForm3DEffect", "setPixelPositionAtTime:curveX:curveY:curveZ:options:", "v68@0:8{?=qiIq}16d40d48d56I64", "v", 7, NO, FCPCCFixedMethodImageFlexo, 0x3e6c2c, 0x57b210 },
    { "FFHeXForm3DEffect", "setRotationAtTime:curveX:curveY:curveZ:options:", "v68@0:8{?=qiIq}16d40d48d56I64", "v", 7, NO, FCPCCFixedMethodImageFlexo, 0x3e6ce8, 0x57b2c0 },
    { "FFHeXForm3DEffect", "setScaleAtTime:curveX:curveY:curveZ:options:", "v68@0:8{?=qiIq}16d40d48d56I64", "v", 7, NO, FCPCCFixedMethodImageFlexo, 0x3e6d24, 0x57b2e0 },
    { "FFEffectStack", "actionBegin:animationHint:deferUpdates:", FCPCCNativeActionBeginTypeEncoding, "v", 5, NO, FCPCCFixedMethodImageFlexo, 0x156684, 0x1f4150 },
    { "FFEffectStack", "actionEnd:save:error:", FCPCCNativeActionEndTypeEncoding, FCPCCNativeBooleanReturnType, 5, NO, FCPCCFixedMethodImageFlexo, 0x1566c0, 0x1f41a0 },
    { "FFUndoHandler", "undoManager", "@16@0:8", "@", 2, NO, FCPCCFixedMethodImageFlexo, 0x32c508, 0x483ad0 },
    { "FFUndoHandler", "undoableBegin:", "v24@0:8@16", "v", 3, NO, FCPCCFixedMethodImageFlexo, 0x32cdc4, 0x4845e0 },
    { "FFUndoHandler", "undoableEnd:save:error:", FCPCCNativeActionEndTypeEncoding, FCPCCNativeBooleanReturnType, 5, NO, FCPCCFixedMethodImageFlexo, 0x32cf84, 0x484840 },
};

static BOOL FCPCCFiniteCGFloat(CGFloat value) {
    return isfinite((double)value);
}

static const CGFloat FCPCCNativeTargetedRotateZoomMinimumScale = 0.1;
static const CGFloat FCPCCNativeTargetedRotateZoomMaximumScale = 4.0;
static const CGFloat FCPCCNativeTargetedRotateZoomMinimumRotationDegrees = -180.0;
static const CGFloat FCPCCNativeTargetedRotateZoomMaximumRotationDegrees = 180.0;

static BOOL FCPCCPositiveNumericCMTime(CMTime time) {
    return CMTIME_IS_VALID(time)
        && CMTIME_IS_NUMERIC(time)
        && time.value > 0
        && time.timescale > 0;
}

static BOOL FCPCCNumericCMTime(CMTime time) {
    return CMTIME_IS_VALID(time) && CMTIME_IS_NUMERIC(time) && time.timescale > 0;
}

static CGFloat FCPCCNaturalPreviewProgress(CGFloat progress) {
    // Product-owned smoothstep preview. It is not a claimed FCP curve value.
    return progress * progress * (3.0 - (2.0 * progress));
}

static BOOL FCPCCNativeMutationLiveContractProven(NSString **reason) {
    // Resolve only the literal array above. The resolver enforces class and
    // instance placement, full ABI, exact Flexo path/SHA-256/UUID, and current
    // architecture IMP offset before any native receiver could be touched.
    for (NSUInteger index = 0; index < sizeof(FCPCCNativeTargetedRotateZoomStaticContracts) / sizeof(FCPCCNativeTargetedRotateZoomStaticContracts[0]); index += 1) {
        const FCPCCFixedObjCMethodContract *contract = &FCPCCNativeTargetedRotateZoomStaticContracts[index];
        FCPCCValidatedFixedMethod resolved = {0};
        if (!FCPCCResolveFixedMethod(contract, &resolved, reason)) {
            return NO;
        }
    }

    // Static inspection proves that Final Cut itself calls the three setters
    // with options == 0. That is only a no-invented-easing proof: it does not
    // establish interpolation semantics, full keyframe enumeration/deletion,
    // or that FFUndoHandler's scope owns this exact project edit. Without
    // those contracts, writing even one property could not be rolled back to
    // its exact previous keyframe topology, so the adapter remains closed.
    *reason = FCPCCMutationErrorUnsupportedPendingLiveContract;
    return NO;
}

static BOOL FCPCCNativeTargetedRotateZoomRecaptureMatchesTransaction(
    FCPCCReadOnlyContextSnapshot *liveSnapshot,
    FCPCCNativeTargetedRotateZoomTransaction *transaction,
    NSString **reason) {
    FCPCCReadOnlyContextSnapshot *expectedSnapshot = transaction.contextSnapshot;
    if (liveSnapshot.disposition != FCPCCReadOnlyContextDispositionReady
        || !liveSnapshot.isReadOnlyCapable
        || liveSnapshot.selectedTimelineItems.count != 1
        || expectedSnapshot.selectedTimelineItems.count != 1
        || ![liveSnapshot.selectionRevision isEqualToString:expectedSnapshot.selectionRevision]
        || ![liveSnapshot.timelineRevision isEqualToString:expectedSnapshot.timelineRevision]
        || !liveSnapshot.hasFrameSize
        || !expectedSnapshot.hasFrameSize
        || !CGSizeEqualToSize(liveSnapshot.frameSize, expectedSnapshot.frameSize)
        || !liveSnapshot.hasFrameDuration
        || !expectedSnapshot.hasFrameDuration
        || CMTimeCompare(liveSnapshot.frameDuration, expectedSnapshot.frameDuration) != 0) {
        *reason = @"native_targeted_rotate_zoom_preapply_selection_or_revision_recapture_mismatch";
        return NO;
    }

    FCPCCTimelineItemSnapshot *liveItem = liveSnapshot.selectedTimelineItems.firstObject;
    FCPCCTimelineItemSnapshot *expectedItem = expectedSnapshot.selectedTimelineItems.firstObject;
    if (![liveItem isKindOfClass:[FCPCCTimelineItemSnapshot class]]
        || ![expectedItem isKindOfClass:[FCPCCTimelineItemSnapshot class]]
        || ![liveItem.stableItemIdentifier isEqualToString:expectedItem.stableItemIdentifier]
        || ![liveItem.canonicalSourcePath isEqualToString:expectedItem.canonicalSourcePath]
        || ![liveItem.sourceSHA256 isEqualToString:expectedItem.sourceSHA256]
        || ![liveItem.sourceIdentityReason isEqualToString:@"source_identity_available"]
        || liveItem.primaryStorylineIndex != expectedItem.primaryStorylineIndex
        || !liveItem.hasTimelineRange
        || !expectedItem.hasTimelineRange
        || CMTimeCompare(liveItem.timelineRange.start, expectedItem.timelineRange.start) != 0
        || CMTimeCompare(liveItem.timelineRange.duration, expectedItem.timelineRange.duration) != 0) {
        *reason = @"native_targeted_rotate_zoom_preapply_stable_id_source_identity_or_spine_recapture_mismatch";
        return NO;
    }
    return YES;
}

@interface FCPCCNativeTargetedRotateZoomAdapter : NSObject
- (FCPCCMutationResult *)applyTransaction:(FCPCCNativeTargetedRotateZoomTransaction *)transaction
                         plannedAfterState:(FCPCCNativeTransformState *)plannedAfterState;
- (FCPCCMutationResult *)undoLastTransaction;
@end

@implementation FCPCCNativeTargetedRotateZoomAdapter

- (FCPCCMutationResult *)applyTransaction:(FCPCCNativeTargetedRotateZoomTransaction *)transaction
                         plannedAfterState:(FCPCCNativeTransformState *)plannedAfterState {
    // This is intentionally immediate and single-pass: no timer, polling, or
    // cached selection can bridge the validation/write boundary.
    FCPCCFixedModelTraversalAdapter *modelAdapter = [[FCPCCFixedModelTraversalAdapter alloc] init];
    FCPCCReadOnlyLibrarySet *liveLibrarySet = [modelAdapter enumerateCompleteOpenLibrarySet];
    FCPCCLibraryInvariantResult *liveLibraryInvariant = FCPCCEvaluateLibraryInvariant(liveLibrarySet,
                                                                                       [FCPCCLibraryManifestRecord bundledManifest]);
    if (!liveLibraryInvariant.isVerified
        || !transaction.libraryInvariant.isVerified
        || ![liveLibraryInvariant.reason isEqualToString:transaction.libraryInvariant.reason]) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedLibraryInvariant
                                                    reason:@"native_targeted_rotate_zoom_preapply_enrolled_disposable_library_recapture_mismatch"
                                         plannedAfterState:plannedAfterState
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }

    FCPCCReadOnlyContextSnapshot *liveSnapshot = [modelAdapter captureContextForVerifiedLibraryInvariant:liveLibraryInvariant];
    NSString *recaptureReason = nil;
    if (!FCPCCNativeTargetedRotateZoomRecaptureMatchesTransaction(liveSnapshot, transaction, &recaptureReason)) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedContextInvariant
                                                    reason:recaptureReason
                                         plannedAfterState:plannedAfterState
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }

    NSString *liveContractReason = nil;
    if (!FCPCCNativeMutationLiveContractProven(&liveContractReason)) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionUnsupportedPendingLiveContract
                                                    reason:liveContractReason
                                         plannedAfterState:plannedAfterState
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    // Kept structurally unreachable until the missing full-keyframe rollback
    // and project-owned undo contracts are independently proven. There is no
    // fallback write, mock success, or partial native mutation route.
    return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionUnsupportedPendingLiveContract
                                                reason:FCPCCMutationErrorUnsupportedPendingLiveContract
                                     plannedAfterState:plannedAfterState
                                           beforeState:nil
                                            afterState:nil
                               nativeMutationPerformed:NO];
}

- (FCPCCMutationResult *)undoLastTransaction {
    return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionUnsupportedPendingLiveContract
                                                reason:FCPCCMutationErrorUnsupportedPendingLiveContract
                                     plannedAfterState:nil
                                           beforeState:nil
                                            afterState:nil
                               nativeMutationPerformed:NO];
}

@end

@interface FCPCCMutationController ()
@property (nonatomic, strong) FCPCCNativeTargetedRotateZoomAdapter *nativeTargetedRotateZoomAdapter;
@end

@implementation FCPCCMutationController

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _nativeTargetedRotateZoomAdapter = [[FCPCCNativeTargetedRotateZoomAdapter alloc] init];
    }
    return self;
}

- (FCPCCMutationResult *)planTransaction:(FCPCCBeforeAfterTransaction *)transaction {
    if (![transaction isKindOfClass:[FCPCCBeforeAfterTransaction class]]) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedInvalidRequest
                                                    reason:@"native_targeted_rotate_zoom_transaction_invalid"
                                         plannedAfterState:nil
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    if (transaction.effectKind != FCPCCEffectKindNativeTargetedRotateZoom) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionUnsupportedEffect
                                                    reason:@"effect_not_admitted_for_native_mutation"
                                         plannedAfterState:nil
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    if (![transaction isKindOfClass:[FCPCCNativeTargetedRotateZoomTransaction class]]) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedInvalidRequest
                                                    reason:@"native_targeted_rotate_zoom_transaction_type_unverified"
                                         plannedAfterState:nil
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    FCPCCNativeTargetedRotateZoomTransaction *nativeTransaction = (FCPCCNativeTargetedRotateZoomTransaction *)transaction;
    FCPCCNativeTargetedRotateZoomRequest *request = nativeTransaction.request;
    if (![request isKindOfClass:[FCPCCNativeTargetedRotateZoomRequest class]]
        || transaction.payload != request
        || request.effectKind != FCPCCEffectKindNativeTargetedRotateZoom
        || request.easing != FCPCCNativeKeyframeEasingNatural
        || !FCPCCFiniteCGFloat(request.normalizedTargetPoint.x)
        || !FCPCCFiniteCGFloat(request.normalizedTargetPoint.y)
        || request.normalizedTargetPoint.x < 0.0 || request.normalizedTargetPoint.x > 1.0
        || request.normalizedTargetPoint.y < 0.0 || request.normalizedTargetPoint.y > 1.0
        || !FCPCCFiniteCGFloat(request.scaleStart)
        || !FCPCCFiniteCGFloat(request.scaleEnd)
        || request.scaleStart < FCPCCNativeTargetedRotateZoomMinimumScale
        || request.scaleStart > FCPCCNativeTargetedRotateZoomMaximumScale
        || request.scaleEnd <= request.scaleStart
        || request.scaleEnd > FCPCCNativeTargetedRotateZoomMaximumScale
        || !FCPCCFiniteCGFloat(request.rotationStartDegrees)
        || !FCPCCFiniteCGFloat(request.rotationEndDegrees)
        || request.rotationStartDegrees < FCPCCNativeTargetedRotateZoomMinimumRotationDegrees
        || request.rotationStartDegrees > FCPCCNativeTargetedRotateZoomMaximumRotationDegrees
        || request.rotationEndDegrees < FCPCCNativeTargetedRotateZoomMinimumRotationDegrees
        || request.rotationEndDegrees > FCPCCNativeTargetedRotateZoomMaximumRotationDegrees
        || !FCPCCPositiveNumericCMTime(request.duration)) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedInvalidRequest
                                                    reason:@"native_targeted_rotate_zoom_request_invalid"
                                         plannedAfterState:nil
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    FCPCCLibraryInvariantResult *libraryInvariant = transaction.libraryInvariant;
    if (![libraryInvariant isKindOfClass:[FCPCCLibraryInvariantResult class]] || !libraryInvariant.isVerified) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedLibraryInvariant
                                                    reason:@"native_targeted_rotate_zoom_library_manifest_invariant_unverified"
                                         plannedAfterState:nil
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    FCPCCReadOnlyContextSnapshot *contextSnapshot = transaction.contextSnapshot;
    if (![contextSnapshot isKindOfClass:[FCPCCReadOnlyContextSnapshot class]]
        || contextSnapshot.disposition != FCPCCReadOnlyContextDispositionReady
        || !contextSnapshot.isReadOnlyCapable
        || !contextSnapshot.hasFrameSize
        || !contextSnapshot.hasFrameDuration
        || !FCPCCFiniteCGFloat(contextSnapshot.frameSize.width)
        || !FCPCCFiniteCGFloat(contextSnapshot.frameSize.height)
        || contextSnapshot.frameSize.width <= 0.0 || contextSnapshot.frameSize.height <= 0.0
        || !FCPCCPositiveNumericCMTime(contextSnapshot.frameDuration)
        || !FCPCCBoundedNonemptyString(contextSnapshot.selectionRevision)
        || !FCPCCBoundedNonemptyString(contextSnapshot.timelineRevision)
        || contextSnapshot.selectedTimelineItems.count != 1) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedContextInvariant
                                                    reason:@"native_targeted_rotate_zoom_context_invariant_unverified"
                                         plannedAfterState:nil
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    id selectedValue = contextSnapshot.selectedTimelineItems.firstObject;
    if (![selectedValue isKindOfClass:[FCPCCTimelineItemSnapshot class]]) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedContextInvariant
                                                    reason:@"native_targeted_rotate_zoom_selected_item_type_unverified"
                                         plannedAfterState:nil
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    FCPCCTimelineItemSnapshot *selectedItem = selectedValue;
    CMTimeRange selectedRange = selectedItem.timelineRange;
    if (!FCPCCBoundedNonemptyString(selectedItem.stableItemIdentifier)
        || !FCPCCBoundedNonemptyString(selectedItem.canonicalSourcePath)
        || !FCPCCLowercaseSHA256HexStringIsValid(selectedItem.sourceSHA256)
        || ![selectedItem.sourceIdentityReason isEqualToString:@"source_identity_available"]
        || selectedItem.primaryStorylineIndex < 0
        || selectedItem.primaryStorylineIndex == NSNotFound
        || !selectedItem.hasTimelineRange
        || !FCPCCNumericCMTime(selectedRange.start)
        || !FCPCCPositiveNumericCMTime(selectedRange.duration)
        || CMTimeCompare(request.duration, selectedRange.duration) > 0) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedContextInvariant
                                                    reason:@"native_targeted_rotate_zoom_selected_spine_item_or_range_unverified"
                                         plannedAfterState:nil
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    CMTime minimumDuration = CMTimeMultiplyByRatio(contextSnapshot.frameDuration, 4, 1);
    if (!FCPCCPositiveNumericCMTime(minimumDuration)
        || CMTimeCompare(request.duration, minimumDuration) < 0) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedContextInvariant
                                                    reason:@"native_targeted_rotate_zoom_duration_shorter_than_four_frames"
                                         plannedAfterState:nil
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }

    // These calculations retain the product-space preview and additionally
    // materialize the explicit *candidate* native pixel convention. For each
    // progress p, the desired source point moves toward the center, then
    // position compensates the scaled/rotated source point. The candidate is
    // never executable until a disposable-library live proof admits its axis
    // convention and native keyframe semantics.
    CGFloat sourceX = request.normalizedTargetPoint.x - 0.5;
    CGFloat sourceY = request.normalizedTargetPoint.y - 0.5;
    CGPoint candidateSourcePixels = FCPCCProductNormalizedPointToCandidateFCPPixels(request.normalizedTargetPoint,
                                                                                      contextSnapshot.frameSize);
    NSMutableArray<FCPCCNativeTransformKeyframe *> *keyframes = [[NSMutableArray alloc] initWithCapacity:5];
    CMTime previousTime = kCMTimeInvalid;
    for (int index = 0; index < 5; index += 1) {
        CGFloat linearProgress = (CGFloat)index / 4.0;
        CGFloat easedProgress = FCPCCNaturalPreviewProgress(linearProgress);
        CGFloat uniformScale = request.scaleStart + (easedProgress * (request.scaleEnd - request.scaleStart));
        CGFloat rotationDegrees = request.rotationStartDegrees + (easedProgress * (request.rotationEndDegrees - request.rotationStartDegrees));
        CGFloat radians = rotationDegrees * (CGFloat)(M_PI / 180.0);
        CGFloat cosine = cos(radians);
        CGFloat sine = sin(radians);
        CGFloat transformedX = uniformScale * ((sourceX * cosine) - (sourceY * sine));
        CGFloat transformedY = uniformScale * ((sourceX * sine) + (sourceY * cosine));
        CGFloat desiredX = sourceX + (easedProgress * (0.0 - sourceX));
        CGFloat desiredY = sourceY + (easedProgress * (0.0 - sourceY));
        CGPoint normalizedPosition = CGPointMake(desiredX - transformedX, desiredY - transformedY);
        CGFloat candidateTransformedX = uniformScale * ((candidateSourcePixels.x * cosine) - (candidateSourcePixels.y * sine));
        CGFloat candidateTransformedY = uniformScale * ((candidateSourcePixels.x * sine) + (candidateSourcePixels.y * cosine));
        CGFloat candidateDesiredX = candidateSourcePixels.x * (1.0 - easedProgress);
        CGFloat candidateDesiredY = candidateSourcePixels.y * (1.0 - easedProgress);
        CGPoint candidateNativePixelPosition = CGPointMake(candidateDesiredX - candidateTransformedX,
                                                            candidateDesiredY - candidateTransformedY);
        CMTime clipLocalTime = CMTimeMultiplyByRatio(request.duration, index, 4);
        if (!FCPCCNumericCMTime(clipLocalTime)
            || (index > 0 && CMTimeCompare(clipLocalTime, previousTime) <= 0)
            || !FCPCCFiniteCGFloat(uniformScale)
            || !FCPCCFiniteCGFloat(rotationDegrees)
            || !FCPCCFiniteCGFloat(normalizedPosition.x)
            || !FCPCCFiniteCGFloat(normalizedPosition.y)
            || !FCPCCFiniteCGFloat(candidateNativePixelPosition.x)
            || !FCPCCFiniteCGFloat(candidateNativePixelPosition.y)) {
            return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedContextInvariant
                                                        reason:@"native_targeted_rotate_zoom_keyframe_plan_unrepresentable"
                                             plannedAfterState:nil
                                                   beforeState:nil
                                                    afterState:nil
                                       nativeMutationPerformed:NO];
        }
        [keyframes addObject:[[FCPCCNativeTransformKeyframe alloc]
            initWithClipLocalTime:clipLocalTime
               normalizedPosition:normalizedPosition
    candidateNativePixelPosition:candidateNativePixelPosition
nativePixelPositionConversionVerified:NO
                     uniformScale:uniformScale
                  rotationDegrees:rotationDegrees
                    easedProgress:easedProgress]];
        previousTime = clipLocalTime;
    }
    FCPCCNativeTransformState *plannedAfterState = [[FCPCCNativeTransformState alloc]
        initWithStableItemIdentifier:selectedItem.stableItemIdentifier
                    selectionRevision:contextSnapshot.selectionRevision
                     timelineRevision:contextSnapshot.timelineRevision
                            frameSize:contextSnapshot.frameSize
                            keyframes:keyframes];
    return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionPlanReady
                                                reason:@"native_targeted_rotate_zoom_preview_plan_ready"
                                     plannedAfterState:plannedAfterState
                                           beforeState:nil
                                            afterState:nil
                               nativeMutationPerformed:NO];
}

- (FCPCCMutationResult *)applyTransaction:(FCPCCBeforeAfterTransaction *)transaction {
    FCPCCMutationResult *planResult = [self planTransaction:transaction];
    if (planResult.disposition != FCPCCMutationDispositionPlanReady) {
        return planResult;
    }
    if (![NSThread isMainThread]) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedHostContainment
                                                    reason:@"native_targeted_rotate_zoom_requires_main_thread"
                                         plannedAfterState:planResult.plannedAfterState
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }
    NSString *hostReason = nil;
    if (!FCPCCReadOnlyHostGatePasses(&hostReason)) {
        return [FCPCCMutationResult resultWithDisposition:FCPCCMutationDispositionRejectedHostContainment
                                                    reason:[@"native_targeted_rotate_zoom_host_containment_unverified_" stringByAppendingString:hostReason ?: @"unknown"]
                                         plannedAfterState:planResult.plannedAfterState
                                               beforeState:nil
                                                afterState:nil
                                   nativeMutationPerformed:NO];
    }

    return [self.nativeTargetedRotateZoomAdapter
        applyTransaction:(FCPCCNativeTargetedRotateZoomTransaction *)transaction
        plannedAfterState:planResult.plannedAfterState];
}

- (FCPCCMutationResult *)undoLastTransaction {
    return [self.nativeTargetedRotateZoomAdapter undoLastTransaction];
}

@end

@interface FCPCCPanelController : NSWindowController
@property (nonatomic, strong) NSTextField *containmentField;
@property (nonatomic, strong) NSTextField *compatibilityField;
@property (nonatomic, strong) NSTextField *libraryField;
@property (nonatomic, strong) NSTextField *capabilityField;
@property (nonatomic, strong) NSTextField *historyField;
@property (nonatomic, strong) NSButton *applyButton;
@property (nonatomic, strong) NSButton *undoButton;
@property (nonatomic, strong) FCPCCMutationController *mutationController;
- (void)refreshContext;
- (void)showPanel:(id)sender;
@end

@implementation FCPCCPanelController

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 620, 540);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    window.title = @"FCP Command Console";
    self = [super initWithWindow:window];
    if (self != nil) {
        _mutationController = [[FCPCCMutationController alloc] init];
        [self buildPanel];
    }
    return self;
}

- (NSTextField *)label:(NSString *)text frame:(NSRect)frame weight:(NSFontWeight)weight {
    NSTextField *field = [NSTextField labelWithString:text];
    field.frame = frame;
    field.font = [NSFont systemFontOfSize:13 weight:weight];
    field.lineBreakMode = NSLineBreakByWordWrapping;
    field.maximumNumberOfLines = 3;
    return field;
}

- (void)buildPanel {
    NSView *content = self.window.contentView;
    CGFloat width = content.bounds.size.width;
    [content addSubview:[self label:@"FCP Command Console — isolated runtime shell" frame:NSMakeRect(20, 500, width - 40, 24) weight:NSFontWeightSemibold]];

    NSString *onboardingQueryCompatibility = FCPCCInstallOnboardingQueryCompatibility();
    self.containmentField = [self label:@"Copied app/runtime: not_yet_refreshed" frame:NSMakeRect(20, 462, width - 40, 30) weight:NSFontWeightRegular];
    self.compatibilityField = [self label:[@"Onboarding compatibility: " stringByAppendingString:onboardingQueryCompatibility] frame:NSMakeRect(20, 426, width - 40, 30) weight:NSFontWeightRegular];
    self.libraryField = [self label:@"Library invariant: not_yet_refreshed" frame:NSMakeRect(20, 390, width - 40, 30) weight:NSFontWeightRegular];
    self.capabilityField = [self label:@"Current selection: not_yet_refreshed\nCapabilities: read_only_context=not_yet_refreshed; planning_apply_undo=disabled." frame:NSMakeRect(20, 346, width - 40, 38) weight:NSFontWeightRegular];
    [content addSubview:self.containmentField];
    [content addSubview:self.compatibilityField];
    [content addSubview:self.libraryField];
    [content addSubview:self.capabilityField];

    [content addSubview:[self label:@"Command" frame:NSMakeRect(20, 308, 100, 18) weight:NSFontWeightMedium]];
    NSTextField *commandField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 279, width - 40, 24)];
    commandField.placeholderString = @"Describe a future command; no execution is available in this build.";
    [content addSubview:commandField];

    [content addSubview:[self label:@"Plan / editability" frame:NSMakeRect(20, 250, 160, 18) weight:NSFontWeightMedium]];
    NSTextField *planField = [self label:@"No edit plan is available. Canonical source path and SHA-256 are required before planning, and Apply/Undo remain disabled." frame:NSMakeRect(20, 216, width - 40, 30) weight:NSFontWeightRegular];
    [content addSubview:planField];

    [content addSubview:[self label:@"Target point: unavailable" frame:NSMakeRect(20, 184, width - 40, 18) weight:NSFontWeightMedium]];
    [content addSubview:[self label:@"Preview: unavailable until a separately reviewed live spike." frame:NSMakeRect(20, 158, width - 40, 18) weight:NSFontWeightRegular]];

    self.historyField = [self label:@"History / error: read_only_context_not_yet_refreshed" frame:NSMakeRect(20, 106, width - 40, 38) weight:NSFontWeightRegular];
    [content addSubview:self.historyField];

    self.applyButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 270, 28, 80, 30)];
    self.applyButton.title = @"Apply";
    self.applyButton.target = self;
    self.applyButton.action = @selector(apply:);
    [self.applyButton setEnabled:NO];
    [content addSubview:self.applyButton];

    self.undoButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 180, 28, 80, 30)];
    self.undoButton.title = @"Undo";
    self.undoButton.target = self;
    self.undoButton.action = @selector(undo:);
    [self.undoButton setEnabled:NO];
    [content addSubview:self.undoButton];

    NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 90, 28, 70, 30)];
    cancelButton.title = @"Cancel";
    cancelButton.target = self;
    cancelButton.action = @selector(cancel:);
    [content addSubview:cancelButton];
}

- (void)refreshContext {
    FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
    FCPCCFixedModelTraversalAdapter *modelAdapter = [[FCPCCFixedModelTraversalAdapter alloc] init];
    FCPCCReadOnlyLibrarySet *librarySet = [modelAdapter enumerateCompleteOpenLibrarySet];
    FCPCCLibraryInvariantResult *libraryInvariant = FCPCCEvaluateLibraryInvariant(librarySet, [FCPCCLibraryManifestRecord bundledManifest]);
    FCPCCGateStatus *library = FCPCCGateStatusFromLibraryInvariantResult(libraryInvariant);
    FCPCCReadOnlyContextSnapshot *contextSnapshot = [modelAdapter captureContextForVerifiedLibraryInvariant:libraryInvariant];
    FCPCCCapabilityStatus *capabilities = [FCPCCCapabilityStatus statusForReadOnlySnapshot:contextSnapshot];
    self.containmentField.stringValue = [@"Copied app/runtime: " stringByAppendingString:containment.summary];
    self.libraryField.stringValue = [@"Library invariant: " stringByAppendingString:library.summary];
    self.capabilityField.stringValue = [capabilities.selectionSummary stringByAppendingFormat:@"\n%@", capabilities.capabilitySummary];
    self.historyField.stringValue = [@"History / error: " stringByAppendingString:contextSnapshot.reason];
    [self.applyButton setEnabled:NO];
    [self.undoButton setEnabled:NO];
}

- (void)showPanel:(id)sender {
    (void)sender;
    [self refreshContext];
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)apply:(id)sender {
    (void)sender;
    FCPCCMutationResult *result = [FCPCCMutationResult unavailableWithoutPanelBinding];
    self.historyField.stringValue = [@"History / error: " stringByAppendingString:result.reason];
}

- (void)undo:(id)sender {
    (void)sender;
    FCPCCMutationResult *result = [self.mutationController undoLastTransaction];
    self.historyField.stringValue = [@"History / error: " stringByAppendingString:result.reason];
}

- (void)cancel:(id)sender {
    (void)sender;
    [self.window orderOut:nil];
}

@end

@interface FCPCCRuntime : NSObject
@property (nonatomic, strong) FCPCCPanelController *panelController;
+ (instancetype)sharedRuntime;
- (void)installMenuWhenReady;
@end

@implementation FCPCCRuntime

+ (instancetype)sharedRuntime {
    static FCPCCRuntime *runtime;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        runtime = [[self alloc] init];
    });
    return runtime;
}

- (void)installMenuWhenReady {
    FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
    if (!containment.isVerified) {
        return;
    }
    if (NSApp == nil || NSApp.mainMenu == nil) {
        [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:NSOperationQueue.mainQueue
                                                      usingBlock:^(__unused NSNotification *note) {
            [self installMenuWhenReady];
        }];
        return;
    }

    if ([NSApp.mainMenu itemWithTitle:@"FCP Command Console"] != nil) {
        return;
    }

    NSMenuItem *rootItem = [[NSMenuItem alloc] initWithTitle:@"FCP Command Console" action:nil keyEquivalent:@""];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"FCP Command Console"];
    NSMenuItem *openItem = [[NSMenuItem alloc] initWithTitle:@"Open Command Console" action:@selector(showPanel:) keyEquivalent:@""];
    openItem.target = self.panelController;
    [menu addItem:openItem];
    rootItem.submenu = menu;
    [NSApp.mainMenu addItem:rootItem];
}

- (FCPCCPanelController *)panelController {
    if (_panelController == nil) {
        _panelController = [[FCPCCPanelController alloc] init];
    }
    return _panelController;
}

@end

typedef NS_ENUM(NSUInteger, FCPCCDisposableLibraryBootstrapLifecycleState) {
    FCPCCDisposableLibraryBootstrapLifecycleStateNew = 0,
    FCPCCDisposableLibraryBootstrapLifecycleStateWaitingForDidFinishLaunching,
    FCPCCDisposableLibraryBootstrapLifecycleStateRunning,
    FCPCCDisposableLibraryBootstrapLifecycleStateFinished,
};

static FCPCCDisposableLibraryBootstrapLifecycleState FCPCCDisposableLibraryBootstrapState = FCPCCDisposableLibraryBootstrapLifecycleStateNew;
static id FCPCCDisposableLibraryBootstrapDidFinishLaunchingObserver;

static void FCPCCFinishDisposableLibraryBootstrapScheduling(void) {
    if (FCPCCDisposableLibraryBootstrapDidFinishLaunchingObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:FCPCCDisposableLibraryBootstrapDidFinishLaunchingObserver];
        FCPCCDisposableLibraryBootstrapDidFinishLaunchingObserver = nil;
    }
    FCPCCDisposableLibraryBootstrapState = FCPCCDisposableLibraryBootstrapLifecycleStateFinished;
}

static void FCPCCHandleDisposableLibraryBootstrapDidFinishLaunching(void) {
    if (![NSThread isMainThread]
        || FCPCCDisposableLibraryBootstrapState != FCPCCDisposableLibraryBootstrapLifecycleStateWaitingForDidFinishLaunching) {
        FCPCCFinishDisposableLibraryBootstrapScheduling();
        return;
    }
    FCPCCDisposableLibraryBootstrapState = FCPCCDisposableLibraryBootstrapLifecycleStateRunning;
    FCPCCDisposableLibraryBootstrapResult *result = FCPCCRunDisposableLibraryBootstrap();
    (void)FCPCCWriteDisposableLibraryBootstrapProvenance(result);
    FCPCCFinishDisposableLibraryBootstrapScheduling();
}

static void FCPCCBeginDisposableLibraryBootstrapAfterApplicationDidFinishLaunching(void) {
    // The constructor never creates a library. An observer is enrolled only
    // when the exact launcher-supplied flag is already present, and its one
    // callback is the sole route to the model initializer.
    if (![NSThread isMainThread] || !FCPCCDisposableLibraryBootstrapEnvironmentIsExact()) {
        return;
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FCPCCDisposableLibraryBootstrapDidFinishLaunchingObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:NSApplicationDidFinishLaunchingNotification
                        object:NSApp
                         queue:nil
                    usingBlock:^(__unused NSNotification *note) {
                        FCPCCHandleDisposableLibraryBootstrapDidFinishLaunching();
                    }];
        if (FCPCCDisposableLibraryBootstrapDidFinishLaunchingObserver == nil) {
            FCPCCDisposableLibraryBootstrapState = FCPCCDisposableLibraryBootstrapLifecycleStateFinished;
            return;
        }
        FCPCCDisposableLibraryBootstrapState = FCPCCDisposableLibraryBootstrapLifecycleStateWaitingForDidFinishLaunching;
    });
}

typedef NS_ENUM(NSUInteger, FCPCCDisposableProjectBootstrapLifecycleState) {
    FCPCCDisposableProjectBootstrapLifecycleStateNew = 0,
    FCPCCDisposableProjectBootstrapLifecycleStateWaitingForDidFinishLaunching,
    FCPCCDisposableProjectBootstrapLifecycleStateRunning,
    FCPCCDisposableProjectBootstrapLifecycleStateFinished,
};

static FCPCCDisposableProjectBootstrapLifecycleState FCPCCDisposableProjectBootstrapLifecycle = FCPCCDisposableProjectBootstrapLifecycleStateNew;
static id FCPCCDisposableProjectBootstrapDidFinishLaunchingObserver;

static void FCPCCFinishDisposableProjectBootstrapScheduling(void) {
    if (FCPCCDisposableProjectBootstrapDidFinishLaunchingObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:FCPCCDisposableProjectBootstrapDidFinishLaunchingObserver];
        FCPCCDisposableProjectBootstrapDidFinishLaunchingObserver = nil;
    }
    FCPCCDisposableProjectBootstrapLifecycle = FCPCCDisposableProjectBootstrapLifecycleStateFinished;
}

static void FCPCCHandleDisposableProjectBootstrapDidFinishLaunching(void) {
    if (![NSThread isMainThread]) {
        FCPCCFinishDisposableProjectBootstrapScheduling();
        return;
    }
    if (FCPCCDisposableProjectBootstrapLifecycle != FCPCCDisposableProjectBootstrapLifecycleStateWaitingForDidFinishLaunching) {
        if (FCPCCDisposableProjectBootstrapActiveSession != nil) {
            FCPCCFinishDisposableProjectBootstrap(FCPCCDisposableProjectBootstrapActiveSession,
                                                   @"rejected",
                                                   @"project_bootstrap_duplicate_active_session_start");
        } else {
            FCPCCFinishDisposableProjectBootstrapScheduling();
        }
        return;
    }
    if (!FCPCCDisposableProjectBootstrapEnvironmentIsExact()) {
        FCPCCFinishDisposableProjectBootstrapScheduling();
        return;
    }
    FCPCCDisposableProjectBootstrapSession *session = [[FCPCCDisposableProjectBootstrapSession alloc] init];
    FCPCCDisposableProjectBootstrapLifecycle = FCPCCDisposableProjectBootstrapLifecycleStateRunning;
    if (!FCPCCDisposableProjectBootstrapRetainActiveSessionIfAbsent(session)) {
        if (FCPCCDisposableProjectBootstrapActiveSession != nil) {
            FCPCCFinishDisposableProjectBootstrap(FCPCCDisposableProjectBootstrapActiveSession,
                                                   @"rejected",
                                                   @"project_bootstrap_duplicate_active_session_start");
        } else {
            FCPCCFinishDisposableProjectBootstrap(session,
                                                   @"rejected",
                                                   @"project_bootstrap_active_session_root_unavailable");
        }
        return;
    }
    FCPCCRunDisposableProjectBootstrap(session);
}

static void FCPCCBeginDisposableProjectBootstrapAfterApplicationDidFinishLaunching(void) {
    // Project creation and all subsequent model calls remain behind a single
    // exact launcher flag. The observer only starts the bounded state machine.
    if (![NSThread isMainThread] || !FCPCCDisposableProjectBootstrapEnvironmentIsExact()) {
        return;
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FCPCCDisposableProjectBootstrapDidFinishLaunchingObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:NSApplicationDidFinishLaunchingNotification
                        object:NSApp
                         queue:nil
                    usingBlock:^(__unused NSNotification *note) {
                        FCPCCHandleDisposableProjectBootstrapDidFinishLaunching();
                    }];
        if (FCPCCDisposableProjectBootstrapDidFinishLaunchingObserver == nil) {
            FCPCCDisposableProjectBootstrapLifecycle = FCPCCDisposableProjectBootstrapLifecycleStateFinished;
            return;
        }
        FCPCCDisposableProjectBootstrapLifecycle = FCPCCDisposableProjectBootstrapLifecycleStateWaitingForDidFinishLaunching;
    });
}

__attribute__((constructor))
static void FCPCCInstallRuntime(void) {
    FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
    if (!containment.isVerified || !FCPCCCopiedHostImageUUIDMatches()) {
        return;
    }
    (void)FCPCCInstallOnboardingQueryCompatibility();
    FCPCCBeginCloudFirstLaunchRegistrationSuppression();
    FCPCCBeginDisposableLibraryBootstrapAfterApplicationDidFinishLaunching();
    FCPCCBeginDisposableProjectBootstrapAfterApplicationDidFinishLaunching();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FCPCCRuntime sharedRuntime] installMenuWhenReady];
    });
}
