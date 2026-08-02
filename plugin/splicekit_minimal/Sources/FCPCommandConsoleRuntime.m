// FCPCommandConsole minimal runtime.
//
// The only factual candidate strings below were manually transcribed from the
// locked SpliceKit symbol snapshot at f4f6618121309a69b66272b441f34cf8ad57f306.
// They are constants only: this framework does not turn input into selectors
// and does not invoke those candidates.

#import "FCPCommandConsoleRuntime.h"

#import <dlfcn.h>
#import <objc/runtime.h>
#import <os/log.h>
#import <stdint.h>
#import <stdlib.h>
#import <string.h>

NSString * const FCPCCMutationErrorUnsupportedUnverifiedFCP123 = @"unsupported_unverified_fcp_12_3";

static NSString * const FCPCCExpectedHostBundleIdentifier = @"com.local.fcpcommandconsole.FinalCut";
static NSString * const FCPCCExpectedHostVersion = @"12.3";
static NSString * const FCPCCExpectedHostBuild = @"450152";
static NSString * const FCPCCExpectedRuntimeFrameworkName = @"FCPCommandConsoleRuntime.framework";
static NSString * const FCPCCCloudContentFirstLaunchCompletedKey = @"CloudContentFirstLaunchCompleted";
static NSString * const FCPCCFFCloudContentDisabledKey = @"FFCloudContentDisabled";
static NSString * const FCPCCCloudContentUnavailableErrorDomain = @"com.local.fcpcommandconsole.cloud-content";
static const NSInteger FCPCCCloudContentUnavailableErrorCode = 1;

// Offline-inspected candidates. These values are intentionally fixed and have
// no execution path in this build.
static NSString * const FCPCCCandidateSelectorShowLibrary = @"showLibrary";
static NSString * const FCPCCCandidateSelectorShowLibraryProperties = @"showLibraryProperties:";
static NSString * const FCPCCCandidateSelectorAddEffects = @"actionAddEffects:withEdits:rootItem:error:";
static NSString * const FCPCCCandidateSelectorEndTransaction = @"actionEnd:save:error:";

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

@interface FCPCCLibraryManifest : NSObject
@property (nonatomic, copy, readonly) NSString *canonicalPath;
@property (nonatomic, strong, readonly, nullable) NSNumber *expectedDevice;
@property (nonatomic, strong, readonly, nullable) NSNumber *expectedInode;
@property (nonatomic, copy, readonly, nullable) NSString *persistentUID;
@property (nonatomic, copy, readonly) NSString *verificationState;
+ (nullable instancetype)bundledManifest;
- (BOOL)isComplete;
@end

@implementation FCPCCLibraryManifest

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

    FCPCCLibraryManifest *manifest = [[self alloc] init];
    manifest->_canonicalPath = [path copy];
    manifest->_expectedDevice = [device isKindOfClass:[NSNumber class]] ? device : nil;
    manifest->_expectedInode = [inode isKindOfClass:[NSNumber class]] ? inode : nil;
    manifest->_persistentUID = [uid isKindOfClass:[NSString class]] ? [uid copy] : nil;
    manifest->_verificationState = [state copy];
    return manifest;
}

- (BOOL)isComplete {
    return self.canonicalPath.length > 0 && self.expectedDevice != nil && self.expectedInode != nil && self.persistentUID.length > 0;
}

@end

@interface FCPCCObservedLibrary : NSObject
@property (nonatomic, copy, readonly) NSString *canonicalPath;
@property (nonatomic, strong, readonly) NSNumber *device;
@property (nonatomic, strong, readonly) NSNumber *inode;
@property (nonatomic, copy, readonly) NSString *persistentUID;
@end

@implementation FCPCCObservedLibrary
@end

@interface FCPCCOpenLibrarySet : NSObject
@property (nonatomic, copy, readonly) NSArray<FCPCCObservedLibrary *> *libraries;
@property (nonatomic, readonly, getter=isCompleteTraversal) BOOL completeTraversal;
@property (nonatomic, copy, readonly) NSString *reason;
- (instancetype)initWithLibraries:(NSArray<FCPCCObservedLibrary *> *)libraries
                completeTraversal:(BOOL)completeTraversal
                           reason:(NSString *)reason;
@end

@implementation FCPCCOpenLibrarySet

- (instancetype)initWithLibraries:(NSArray<FCPCCObservedLibrary *> *)libraries
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

// This is intentionally the only future extension seam for a private-model
// traversal. The adapter is fixed at compile time and does not use runtime
// discovery. It returns unverified until a separately reviewed live spike can
// establish a supported Final Cut 12.3 traversal.
@interface FCPCCFixedModelTraversalAdapter : NSObject
- (FCPCCOpenLibrarySet *)enumerateCompleteOpenLibrarySet;
@end

@implementation FCPCCFixedModelTraversalAdapter

- (FCPCCOpenLibrarySet *)enumerateCompleteOpenLibrarySet {
    (void)FCPCCCandidateSelectorShowLibrary;
    (void)FCPCCCandidateSelectorShowLibraryProperties;
    (void)FCPCCCandidateSelectorAddEffects;
    (void)FCPCCCandidateSelectorEndTransaction;
    return [[FCPCCOpenLibrarySet alloc] initWithLibraries:@[]
                                        completeTraversal:NO
                                                   reason:FCPCCMutationErrorUnsupportedUnverifiedFCP123];
}

@end

@interface FCPCCLibraryInvariantGate : NSObject
- (FCPCCGateStatus *)evaluate;
@end

@implementation FCPCCLibraryInvariantGate

- (FCPCCGateStatus *)evaluate {
    FCPCCFixedModelTraversalAdapter *adapter = [[FCPCCFixedModelTraversalAdapter alloc] init];
    FCPCCOpenLibrarySet *openLibrarySet = [adapter enumerateCompleteOpenLibrarySet];
    if (!openLibrarySet.isCompleteTraversal) {
        return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionTraversalUnverified
                                                    summary:openLibrarySet.reason];
    }

    if (openLibrarySet.libraries.count != 1) {
        return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionOpenLibraryCountInvalid
                                                    summary:@"exactly_one_open_library_required"];
    }

    FCPCCLibraryManifest *manifest = [FCPCCLibraryManifest bundledManifest];
    if (manifest == nil) {
        return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionManifestAbsent
                                                    summary:@"library_manifest_absent"];
    }
    if (![manifest isComplete]) {
        return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionManifestUnverifiable
                                                    summary:manifest.verificationState];
    }

    FCPCCObservedLibrary *observed = openLibrarySet.libraries.firstObject;
    BOOL matches = [observed.canonicalPath isEqualToString:manifest.canonicalPath]
        && [observed.device isEqualToNumber:manifest.expectedDevice]
        && [observed.inode isEqualToNumber:manifest.expectedInode]
        && [observed.persistentUID isEqualToString:manifest.persistentUID];
    if (!matches) {
        return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionLibraryIdentityMismatch
                                                    summary:@"library_path_device_inode_or_persistent_uid_mismatch"];
    }

    return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionVerified
                                                summary:@"exactly_one_library_verified"];
}

@end

@interface FCPCCRuntimeContainmentGate : NSObject
- (FCPCCGateStatus *)evaluate;
@end

@implementation FCPCCRuntimeContainmentGate

- (FCPCCGateStatus *)evaluate {
    NSBundle *hostBundle = NSBundle.mainBundle;
    NSString *hostIdentifier = hostBundle.bundleIdentifier ?: @"";
    NSString *hostVersion = [hostBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    NSString *hostBuild = [hostBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
    NSString *runtimePath = [[NSBundle bundleForClass:[self class]].bundlePath stringByStandardizingPath];
    NSString *requiredSuffix = [@"/Contents/Frameworks/" stringByAppendingString:FCPCCExpectedRuntimeFrameworkName];
    BOOL contained = [runtimePath hasSuffix:requiredSuffix];
    BOOL valid = [hostIdentifier isEqualToString:FCPCCExpectedHostBundleIdentifier]
        && [hostVersion isEqualToString:FCPCCExpectedHostVersion]
        && [hostBuild isEqualToString:FCPCCExpectedHostBuild]
        && contained;
    if (!valid) {
        return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionHostUnverified
                                                    summary:@"copied_app_or_runtime_containment_unverified"];
    }
    return [[FCPCCGateStatus alloc] initWithDisposition:FCPCCGateDispositionVerified
                                                summary:@"copied_app_runtime_containment_verified"];
}

@end

typedef NS_ENUM(NSInteger, FCPCCCloudContentCompatibilityDisposition) {
    FCPCCCloudContentCompatibilityDispositionSynchronized = 0,
    FCPCCCloudContentCompatibilityDispositionHostUnverified = 1,
    FCPCCCloudContentCompatibilityDispositionSynchronizationFailed = 2,
};

@interface FCPCCCloudContentCompatibilityStatus : NSObject
@property (nonatomic, readonly) FCPCCCloudContentCompatibilityDisposition disposition;
@property (nonatomic, copy, readonly) NSString *summary;
@property (nonatomic, readonly, getter=isSynchronized) BOOL synchronized;
- (instancetype)initWithDisposition:(FCPCCCloudContentCompatibilityDisposition)disposition summary:(NSString *)summary;
@end

@implementation FCPCCCloudContentCompatibilityStatus

- (instancetype)initWithDisposition:(FCPCCCloudContentCompatibilityDisposition)disposition summary:(NSString *)summary {
    self = [super init];
    if (self != nil) {
        _disposition = disposition;
        _summary = [summary copy];
        _synchronized = disposition == FCPCCCloudContentCompatibilityDispositionSynchronized;
    }
    return self;
}

@end

// These fixed, manually transcribed flags are the only compatibility writes in
// this runtime. They are applied only after the exact copied-host and runtime
// containment gate succeeds. kCFPreferencesCurrentApplication resolves to the
// running isolated app domain; no production Final Cut preference domain is named.
static FCPCCCloudContentCompatibilityStatus *FCPCCInitializeIsolatedCloudContentCompatibility(void) {
    static FCPCCCloudContentCompatibilityStatus *status;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
        if (!containment.isVerified) {
            status = [[FCPCCCloudContentCompatibilityStatus alloc] initWithDisposition:FCPCCCloudContentCompatibilityDispositionHostUnverified
                                                                                summary:@"isolated_cloud_content_host_unverified"];
            return;
        }

        CFPreferencesSetAppValue((__bridge CFStringRef)FCPCCCloudContentFirstLaunchCompletedKey,
                                 kCFBooleanTrue,
                                 kCFPreferencesCurrentApplication);
        CFPreferencesSetAppValue((__bridge CFStringRef)FCPCCFFCloudContentDisabledKey,
                                 kCFBooleanTrue,
                                 kCFPreferencesCurrentApplication);
        Boolean synchronized = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
        Boolean firstLaunchValueIsValid = false;
        Boolean firstLaunchCompleted = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)FCPCCCloudContentFirstLaunchCompletedKey,
                                                                        kCFPreferencesCurrentApplication,
                                                                        &firstLaunchValueIsValid);
        Boolean disabledValueIsValid = false;
        Boolean cloudContentDisabled = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)FCPCCFFCloudContentDisabledKey,
                                                                         kCFPreferencesCurrentApplication,
                                                                         &disabledValueIsValid);
        if (synchronized && firstLaunchValueIsValid && firstLaunchCompleted && disabledValueIsValid && cloudContentDisabled) {
            status = [[FCPCCCloudContentCompatibilityStatus alloc] initWithDisposition:FCPCCCloudContentCompatibilityDispositionSynchronized
                                                                                summary:@"isolated_cloud_content_flags_synchronized"];
            return;
        }
        status = [[FCPCCCloudContentCompatibilityStatus alloc] initWithDisposition:FCPCCCloudContentCompatibilityDispositionSynchronizationFailed
                                                                            summary:@"isolated_cloud_content_flag_synchronization_failed"];
    });
    return status;
}

// FCP 12.3 exposes these exact Objective-C runtime names and method contracts.
// The entries are compile-time constants, not resource-driven configuration: the
// bundled policy is an auditable statement of this fixed implementation, never
// input to it. No class or method discovery is performed.
typedef NS_ENUM(NSUInteger, FCPCCCloudContentMethodKind) {
    FCPCCCloudContentMethodKindInstance = 0,
    FCPCCCloudContentMethodKindClass = 1,
};

typedef NS_ENUM(NSUInteger, FCPCCCloudContentReplacementDisposition) {
    FCPCCCloudContentReplacementDispositionPending = 0,
    FCPCCCloudContentReplacementDispositionInstalled = 1,
    FCPCCCloudContentReplacementDispositionClassUnavailable = 2,
    FCPCCCloudContentReplacementDispositionMethodUnavailable = 3,
    FCPCCCloudContentReplacementDispositionMethodPlacementMismatch = 4,
    FCPCCCloudContentReplacementDispositionArgumentCountMismatch = 5,
    FCPCCCloudContentReplacementDispositionReturnTypeMismatch = 6,
    FCPCCCloudContentReplacementDispositionTypeEncodingMismatch = 7,
    FCPCCCloudContentReplacementDispositionOriginalImplementationMismatch = 8,
    FCPCCCloudContentReplacementDispositionVerificationFailed = 9,
};

typedef NS_ENUM(NSUInteger, FCPCCCloudContentAttemptPhase) {
    FCPCCCloudContentAttemptPhaseConstructor = 0,
    FCPCCCloudContentAttemptPhaseWillFinishLaunching = 1,
    FCPCCCloudContentAttemptPhaseMainQueue = 2,
};

static const NSUInteger FCPCCCloudContentCompatibilityMaximumAttempts = 3;

typedef struct {
    const char *runtimeClassName;
    const char *selectorName;
    FCPCCCloudContentMethodKind methodKind;
    NSUInteger argumentCount;
    const char *returnType;
    const char *typeEncoding;
    uintptr_t expectedArm64OriginalImplementationOffset;
    uintptr_t expectedX86_64OriginalImplementationOffset;
    IMP replacement;
    const char *auditLabel;
} FCPCCCloudContentCompatibilityEntry;

static void FCPCCCloudContentReturnVoid(id self, SEL command) {
    (void)self;
    (void)command;
}

static BOOL FCPCCCloudContentReturnFalse(id self, SEL command) {
    (void)self;
    (void)command;
    return NO;
}

// This IMP is reachable only after the exact three-argument completion-handler
// encoding has been confirmed. A nonnull completion receives the documented
// successful no-error result; no exception suppression or fallback invocation is used.
static void FCPCCCloudContentCompleteFirstLaunch(id self, SEL command, void (^completion)(NSError *)) {
    (void)self;
    (void)command;
    if (completion != nil) {
        completion(nil);
    }
}

// The exact FCP 12.3 Objective-C bridge has the reviewed type encoding
// v24@0:8@?<v@?@"_TtC13Final_Cut_Pro23CloudContentDemoProject"@"NSError">16.
// Its generated Swift bridge reports its own failure path as (nil, NSError *).
// This replacement preserves that Objective-C result contract without creating a
// Swift task, fabricating a demo project, invoking CloudKit, or retaining work
// that would need cancellation.
static void FCPCCCloudContentCompleteDemoProjectUnavailable(id self,
                                                            SEL command,
                                                            void (^completion)(id, NSError *)) {
    (void)self;
    (void)command;
    if (completion != nil) {
        NSError *error = [NSError errorWithDomain:FCPCCCloudContentUnavailableErrorDomain
                                             code:FCPCCCloudContentUnavailableErrorCode
                                         userInfo:nil];
        completion(nil, error);
    }
}

static const FCPCCCloudContentCompatibilityEntry FCPCCCloudContentCompatibilityEntries[] = {
    {
        "_TtC13Final_Cut_Pro25DemoProjectDownloadHelper",
        "fetchDefaultDemoProjectWithCompletionHandler:",
        FCPCCCloudContentMethodKindInstance,
        3,
        "v",
        "v24@0:8@?<v@?@\"_TtC13Final_Cut_Pro23CloudContentDemoProject\"@\"NSError\">16",
        0xce540,
        0x107ca0,
        (IMP)FCPCCCloudContentCompleteDemoProjectUnavailable,
        "demo_project.fetch_default_completion"
    },
    {
        "_TtC13Final_Cut_Pro19CloudContentCatalog",
        "isCloudContentEnabled",
        FCPCCCloudContentMethodKindInstance,
        2,
        "B",
        "B16@0:8",
        0,
        0,
        (IMP)FCPCCCloudContentReturnFalse,
        "catalog.enabled"
    },
    {
        "_TtC13Final_Cut_Pro19CloudContentCatalog",
        "isRunningSubscriptionApp",
        FCPCCCloudContentMethodKindInstance,
        2,
        "B",
        "B16@0:8",
        0,
        0,
        (IMP)FCPCCCloudContentReturnFalse,
        "catalog.subscription"
    },
    {
        "_TtC13Final_Cut_Pro19CloudContentCatalog",
        "startListeningForApplicationDidBecomeActiveNotifications",
        FCPCCCloudContentMethodKindInstance,
        2,
        "v",
        "v16@0:8",
        0,
        0,
        (IMP)FCPCCCloudContentReturnVoid,
        "catalog.listener"
    },
    {
        "_TtC13Final_Cut_Pro23CloudContentFeatureFlag",
        "isEnabled",
        FCPCCCloudContentMethodKindClass,
        2,
        "B",
        "B16@0:8",
        0,
        0,
        (IMP)FCPCCCloudContentReturnFalse,
        "feature.enabled"
    },
    {
        "_TtC13Final_Cut_Pro23CloudContentFeatureFlag",
        "shouldShowFirstLaunchExperience",
        FCPCCCloudContentMethodKindClass,
        2,
        "B",
        "B16@0:8",
        0,
        0,
        (IMP)FCPCCCloudContentReturnFalse,
        "feature.first_launch"
    },
    {
        "CCFirstLaunchHelper",
        "setupAndPresentFirstLaunchIfNeededWithCompletionHandler:",
        FCPCCCloudContentMethodKindInstance,
        3,
        "v",
        "v24@0:8@?<v@?@\"NSError\">16",
        0,
        0,
        (IMP)FCPCCCloudContentCompleteFirstLaunch,
        "first_launch.setup_completion"
    },
};

static const NSUInteger FCPCCCloudContentCompatibilityEntryCount = sizeof(FCPCCCloudContentCompatibilityEntries) / sizeof(FCPCCCloudContentCompatibilityEntries[0]);

static NSString *FCPCCCloudContentReplacementDispositionSummary(FCPCCCloudContentReplacementDisposition disposition) {
    switch (disposition) {
        case FCPCCCloudContentReplacementDispositionPending:
            return @"pending";
        case FCPCCCloudContentReplacementDispositionInstalled:
            return @"installed";
        case FCPCCCloudContentReplacementDispositionClassUnavailable:
            return @"class_unavailable";
        case FCPCCCloudContentReplacementDispositionMethodUnavailable:
            return @"method_unavailable";
        case FCPCCCloudContentReplacementDispositionMethodPlacementMismatch:
            return @"method_kind_mismatch";
        case FCPCCCloudContentReplacementDispositionArgumentCountMismatch:
            return @"argument_count_mismatch";
        case FCPCCCloudContentReplacementDispositionReturnTypeMismatch:
            return @"return_type_mismatch";
        case FCPCCCloudContentReplacementDispositionTypeEncodingMismatch:
            return @"type_encoding_mismatch";
        case FCPCCCloudContentReplacementDispositionOriginalImplementationMismatch:
            return @"pre_replacement_imp_mismatch";
        case FCPCCCloudContentReplacementDispositionVerificationFailed:
            return @"replacement_verification_failed";
    }
    return @"unknown";
}

@interface FCPCCCloudContentMethodCompatibilityStatus : NSObject
@property (nonatomic, strong) NSMutableArray<NSNumber *> *entryDispositions;
@property (nonatomic) NSUInteger constructorAttempts;
@property (nonatomic) NSUInteger willFinishLaunchingAttempts;
@property (nonatomic) NSUInteger mainQueueAttempts;
@property (nonatomic) BOOL hostVerified;
- (void)recordDisposition:(FCPCCCloudContentReplacementDisposition)disposition atIndex:(NSUInteger)index;
- (NSString *)summary;
- (NSArray<NSString *> *)entryAuditSummaries;
@end

@implementation FCPCCCloudContentMethodCompatibilityStatus

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _entryDispositions = [[NSMutableArray alloc] initWithCapacity:FCPCCCloudContentCompatibilityEntryCount];
        for (NSUInteger index = 0; index < FCPCCCloudContentCompatibilityEntryCount; index += 1) {
            [_entryDispositions addObject:@(FCPCCCloudContentReplacementDispositionPending)];
        }
    }
    return self;
}

- (void)recordDisposition:(FCPCCCloudContentReplacementDisposition)disposition atIndex:(NSUInteger)index {
    if (index < self.entryDispositions.count) {
        self.entryDispositions[index] = @(disposition);
    }
}

- (NSString *)summary {
    if (!self.hostVerified) {
        return @"method_guard_host_unverified";
    }

    NSUInteger installed = 0;
    for (NSNumber *number in self.entryDispositions) {
        if (number.unsignedIntegerValue == FCPCCCloudContentReplacementDispositionInstalled) {
            installed += 1;
        }
    }
    NSUInteger attempts = self.constructorAttempts + self.willFinishLaunchingAttempts + self.mainQueueAttempts;
    return [NSString stringWithFormat:@"method_guard=%lu/%lu attempts=%lu",
            (unsigned long)installed,
            (unsigned long)FCPCCCloudContentCompatibilityEntryCount,
            (unsigned long)attempts];
}

- (NSArray<NSString *> *)entryAuditSummaries {
    NSMutableArray<NSString *> *summaries = [[NSMutableArray alloc] initWithCapacity:FCPCCCloudContentCompatibilityEntryCount];
    for (NSUInteger index = 0; index < FCPCCCloudContentCompatibilityEntryCount; index += 1) {
        FCPCCCloudContentReplacementDisposition disposition = self.entryDispositions[index].unsignedIntegerValue;
        NSString *label = [NSString stringWithUTF8String:FCPCCCloudContentCompatibilityEntries[index].auditLabel];
        [summaries addObject:[label stringByAppendingFormat:@"=%@", FCPCCCloudContentReplacementDispositionSummary(disposition)]];
    }
    return summaries;
}

@end

static FCPCCCloudContentMethodCompatibilityStatus *FCPCCCloudContentMethodCompatibilityStatusShared(void) {
    static FCPCCCloudContentMethodCompatibilityStatus *status;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        status = [[FCPCCCloudContentMethodCompatibilityStatus alloc] init];
    });
    return status;
}

static const char *FCPCCCloudContentAttemptPhaseName(FCPCCCloudContentAttemptPhase phase) {
    switch (phase) {
        case FCPCCCloudContentAttemptPhaseConstructor:
            return "constructor";
        case FCPCCCloudContentAttemptPhaseWillFinishLaunching:
            return "will_finish_launching_once";
        case FCPCCCloudContentAttemptPhaseMainQueue:
            return "main_queue_once";
    }
    return "unknown";
}

static os_log_t FCPCCCloudContentMethodCompatibilityLog(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.local.fcpcommandconsole.runtime", "cloud_content_method_guard");
    });
    return log;
}

// Each phase is hard one-shot, so this produces at most three fixed-shape
// unified-log records. The audit labels and dispositions come only from the
// compile-time descriptor array and contain no caller-controlled data.
static void FCPCCLogCloudContentMethodCompatibilityAttempt(FCPCCCloudContentAttemptPhase phase,
                                                            FCPCCCloudContentMethodCompatibilityStatus *status) {
    NSString *dispositions = [[status entryAuditSummaries] componentsJoinedByString:@","];
    const char *dispositionCString = dispositions.UTF8String;
    if (dispositionCString == NULL) {
        dispositionCString = "unavailable";
    }
    os_log_info(FCPCCCloudContentMethodCompatibilityLog(),
                "phase=%{public}s dispositions=%{public}s",
                FCPCCCloudContentAttemptPhaseName(phase),
                dispositionCString);
}

// This evaluates only the predeclared method selected by one fixed descriptor.
// It does not discover classes, selectors, methods, or images. The relative
// implementation offset is ASLR-stable and ties the crash-path replacement to
// the exact inspected FCP 12.3 executable slice.
static BOOL FCPCCCloudContentOriginalImplementationMatches(const FCPCCCloudContentCompatibilityEntry *entry,
                                                            Method method) {
#if defined(__arm64__)
    uintptr_t expectedOffset = entry->expectedArm64OriginalImplementationOffset;
#elif defined(__x86_64__)
    uintptr_t expectedOffset = entry->expectedX86_64OriginalImplementationOffset;
#else
    return NO;
#endif
    if (expectedOffset == 0) {
        return YES;
    }

    IMP originalImplementation = method_getImplementation(method);
    Dl_info implementationImage = {0};
    if (originalImplementation == NULL
        || dladdr((const void *)originalImplementation, &implementationImage) == 0
        || implementationImage.dli_fbase == NULL
        || implementationImage.dli_fname == NULL) {
        return NO;
    }

    NSString *hostExecutablePath = [NSBundle.mainBundle.executablePath stringByStandardizingPath];
    NSString *implementationImagePath = [[NSString alloc] initWithUTF8String:implementationImage.dli_fname];
    if (hostExecutablePath.length == 0
        || implementationImagePath == nil
        || ![[implementationImagePath stringByStandardizingPath] isEqualToString:hostExecutablePath]) {
        return NO;
    }

    uintptr_t actualOffset = (uintptr_t)originalImplementation - (uintptr_t)implementationImage.dli_fbase;
    return actualOffset == expectedOffset;
}

static void FCPCCInstallCloudContentCompatibilityEntry(const FCPCCCloudContentCompatibilityEntry *entry,
                                                        NSUInteger index,
                                                        FCPCCCloudContentMethodCompatibilityStatus *status) {
    // runtimeClassName originates only from the fixed array above; it is never
    // supplied by a caller, resource, environment, or notification payload.
    Class targetClass = objc_getClass(entry->runtimeClassName);
    if (targetClass == Nil) {
        [status recordDisposition:FCPCCCloudContentReplacementDispositionClassUnavailable atIndex:index];
        return;
    }

    SEL selector = sel_registerName(entry->selectorName);
    if (selector == NULL) {
        [status recordDisposition:FCPCCCloudContentReplacementDispositionMethodUnavailable atIndex:index];
        return;
    }

    Method expectedMethod = entry->methodKind == FCPCCCloudContentMethodKindInstance
        ? class_getInstanceMethod(targetClass, selector)
        : class_getClassMethod(targetClass, selector);
    if (expectedMethod == NULL) {
        Method oppositePlacement = entry->methodKind == FCPCCCloudContentMethodKindInstance
            ? class_getClassMethod(targetClass, selector)
            : class_getInstanceMethod(targetClass, selector);
        [status recordDisposition:oppositePlacement == NULL
                                      ? FCPCCCloudContentReplacementDispositionMethodUnavailable
                                      : FCPCCCloudContentReplacementDispositionMethodPlacementMismatch
                           atIndex:index];
        return;
    }

    if (method_getNumberOfArguments(expectedMethod) != entry->argumentCount) {
        [status recordDisposition:FCPCCCloudContentReplacementDispositionArgumentCountMismatch atIndex:index];
        return;
    }

    char *actualReturnType = method_copyReturnType(expectedMethod);
    BOOL returnTypeMatches = actualReturnType != NULL && strcmp(actualReturnType, entry->returnType) == 0;
    if (actualReturnType != NULL) {
        free(actualReturnType);
    }
    if (!returnTypeMatches) {
        [status recordDisposition:FCPCCCloudContentReplacementDispositionReturnTypeMismatch atIndex:index];
        return;
    }

    const char *actualTypeEncoding = method_getTypeEncoding(expectedMethod);
    if (actualTypeEncoding == NULL || strcmp(actualTypeEncoding, entry->typeEncoding) != 0) {
        [status recordDisposition:FCPCCCloudContentReplacementDispositionTypeEncodingMismatch atIndex:index];
        return;
    }

    if (method_getImplementation(expectedMethod) == entry->replacement) {
        [status recordDisposition:FCPCCCloudContentReplacementDispositionInstalled atIndex:index];
        return;
    }

    if (!FCPCCCloudContentOriginalImplementationMatches(entry, expectedMethod)) {
        [status recordDisposition:FCPCCCloudContentReplacementDispositionOriginalImplementationMismatch atIndex:index];
        return;
    }

    Class replacementTarget = entry->methodKind == FCPCCCloudContentMethodKindInstance
        ? targetClass
        : object_getClass(targetClass);
    if (replacementTarget == Nil) {
        [status recordDisposition:FCPCCCloudContentReplacementDispositionMethodPlacementMismatch atIndex:index];
        return;
    }
    class_replaceMethod(replacementTarget, selector, entry->replacement, entry->typeEncoding);

    Method installedMethod = entry->methodKind == FCPCCCloudContentMethodKindInstance
        ? class_getInstanceMethod(targetClass, selector)
        : class_getClassMethod(targetClass, selector);
    if (installedMethod == NULL || method_getImplementation(installedMethod) != entry->replacement) {
        [status recordDisposition:FCPCCCloudContentReplacementDispositionVerificationFailed atIndex:index];
        return;
    }
    [status recordDisposition:FCPCCCloudContentReplacementDispositionInstalled atIndex:index];
}

static void FCPCCAttemptIsolatedCloudContentMethodCompatibility(FCPCCCloudContentAttemptPhase phase) {
    FCPCCCloudContentMethodCompatibilityStatus *status = FCPCCCloudContentMethodCompatibilityStatusShared();
    @synchronized (status) {
        NSUInteger attempts = status.constructorAttempts + status.willFinishLaunchingAttempts + status.mainQueueAttempts;
        if (attempts >= FCPCCCloudContentCompatibilityMaximumAttempts) {
            return;
        }
        switch (phase) {
            case FCPCCCloudContentAttemptPhaseConstructor:
                if (status.constructorAttempts != 0) {
                    return;
                }
                status.constructorAttempts = 1;
                break;
            case FCPCCCloudContentAttemptPhaseWillFinishLaunching:
                if (status.willFinishLaunchingAttempts != 0) {
                    return;
                }
                status.willFinishLaunchingAttempts = 1;
                break;
            case FCPCCCloudContentAttemptPhaseMainQueue:
                if (status.mainQueueAttempts != 0) {
                    return;
                }
                status.mainQueueAttempts = 1;
                break;
        }

        FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
        if (!containment.isVerified) {
            status.hostVerified = NO;
            FCPCCLogCloudContentMethodCompatibilityAttempt(phase, status);
            return;
        }
        status.hostVerified = YES;

        for (NSUInteger index = 0; index < FCPCCCloudContentCompatibilityEntryCount; index += 1) {
            FCPCCInstallCloudContentCompatibilityEntry(&FCPCCCloudContentCompatibilityEntries[index], index, status);
        }
        FCPCCLogCloudContentMethodCompatibilityAttempt(phase, status);
    }
}

static void FCPCCInstallIsolatedCloudContentMethodCompatibility(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
        if (!containment.isVerified) {
            return;
        }
        FCPCCAttemptIsolatedCloudContentMethodCompatibility(FCPCCCloudContentAttemptPhaseConstructor);
        [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationWillFinishLaunchingNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(__unused NSNotification *note) {
            FCPCCAttemptIsolatedCloudContentMethodCompatibility(FCPCCCloudContentAttemptPhaseWillFinishLaunching);
        }];
        // This is enqueued before FCPCCInstallRuntime enqueues menu installation.
        // It only attempts the fixed compatibility guard; it performs no UI or
        // library operation and cannot reschedule itself.
        dispatch_async(dispatch_get_main_queue(), ^{
            FCPCCAttemptIsolatedCloudContentMethodCompatibility(FCPCCCloudContentAttemptPhaseMainQueue);
        });
    });
}

@interface FCPCCCapabilityStatus : NSObject
@property (nonatomic, copy, readonly) NSString *selectionSummary;
@property (nonatomic, copy, readonly) NSString *capabilitySummary;
+ (instancetype)unverifiedPlaceholder;
@end

@implementation FCPCCCapabilityStatus

+ (instancetype)unverifiedPlaceholder {
    FCPCCCapabilityStatus *status = [[self alloc] init];
    status->_selectionSummary = @"Current selection: unavailable until a live capability probe is approved.";
    status->_capabilitySummary = @"Capabilities: unsupported_unverified_fcp_12_3";
    return status;
}

@end

@implementation FCPCCBeforeAfterTransaction

- (instancetype)initWithEffectKind:(FCPCCEffectKind)effectKind
                       beforeState:(NSDictionary<NSString *,id> *)beforeState
                        afterState:(NSDictionary<NSString *,id> *)afterState {
    self = [super init];
    if (self != nil) {
        _transactionIdentifier = NSUUID.UUID.UUIDString;
        _effectKind = effectKind;
        _beforeState = [beforeState copy];
        _afterState = [afterState copy];
    }
    return self;
}

@end

@implementation FCPCCMutationResult

+ (instancetype)unsupportedUnverified {
    FCPCCMutationResult *result = [[self alloc] init];
    result->_disposition = FCPCCMutationDispositionUnsupportedUnverifiedFCP123;
    result->_reason = FCPCCMutationErrorUnsupportedUnverifiedFCP123;
    return result;
}

@end

@implementation FCPCCMutationController

- (FCPCCMutationResult *)applyTransaction:(FCPCCBeforeAfterTransaction *)transaction {
    (void)transaction;
    return FCPCCMutationResult.unsupportedUnverified;
}

- (FCPCCMutationResult *)undoLastTransaction {
    return FCPCCMutationResult.unsupportedUnverified;
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

    FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
    FCPCCCloudContentCompatibilityStatus *compatibility = FCPCCInitializeIsolatedCloudContentCompatibility();
    FCPCCCloudContentMethodCompatibilityStatus *methodCompatibility = FCPCCCloudContentMethodCompatibilityStatusShared();
    FCPCCGateStatus *library = [[[FCPCCLibraryInvariantGate alloc] init] evaluate];
    FCPCCCapabilityStatus *capabilities = FCPCCCapabilityStatus.unverifiedPlaceholder;
    self.containmentField = [self label:[@"Copied app/runtime: " stringByAppendingString:containment.summary] frame:NSMakeRect(20, 462, width - 40, 30) weight:NSFontWeightRegular];
    self.compatibilityField = [self label:[NSString stringWithFormat:@"Isolated cloud compatibility: %@; %@", compatibility.summary, methodCompatibility.summary] frame:NSMakeRect(20, 426, width - 40, 30) weight:NSFontWeightRegular];
    self.libraryField = [self label:[@"Library invariant: " stringByAppendingString:library.summary] frame:NSMakeRect(20, 390, width - 40, 30) weight:NSFontWeightRegular];
    self.capabilityField = [self label:[capabilities.selectionSummary stringByAppendingFormat:@"\n%@", capabilities.capabilitySummary] frame:NSMakeRect(20, 346, width - 40, 38) weight:NSFontWeightRegular];
    [content addSubview:self.containmentField];
    [content addSubview:self.compatibilityField];
    [content addSubview:self.libraryField];
    [content addSubview:self.capabilityField];

    [content addSubview:[self label:@"Command" frame:NSMakeRect(20, 308, 100, 18) weight:NSFontWeightMedium]];
    NSTextField *commandField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 279, width - 40, 24)];
    commandField.placeholderString = @"Describe a future command; no execution is available in this build.";
    [content addSubview:commandField];

    [content addSubview:[self label:@"Plan / editability" frame:NSMakeRect(20, 250, 160, 18) weight:NSFontWeightMedium]];
    NSTextField *planField = [self label:@"No edit plan is available. The live capability and exactly-one-library gates remain unverified." frame:NSMakeRect(20, 216, width - 40, 30) weight:NSFontWeightRegular];
    [content addSubview:planField];

    [content addSubview:[self label:@"Target point: unavailable" frame:NSMakeRect(20, 184, width - 40, 18) weight:NSFontWeightMedium]];
    [content addSubview:[self label:@"Preview: unavailable until a separately reviewed live spike." frame:NSMakeRect(20, 158, width - 40, 18) weight:NSFontWeightRegular]];

    self.historyField = [self label:@"History / error: unsupported_unverified_fcp_12_3" frame:NSMakeRect(20, 106, width - 40, 38) weight:NSFontWeightRegular];
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

- (void)showPanel:(id)sender {
    (void)sender;
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)apply:(id)sender {
    (void)sender;
    FCPCCBeforeAfterTransaction *transaction = [[FCPCCBeforeAfterTransaction alloc] initWithEffectKind:FCPCCEffectKindNativeTargetedRotateZoom beforeState:@{} afterState:@{}];
    FCPCCMutationResult *result = [self.mutationController applyTransaction:transaction];
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

__attribute__((constructor))
static void FCPCCInstallRuntime(void) {
    (void)FCPCCInitializeIsolatedCloudContentCompatibility();
    FCPCCInstallIsolatedCloudContentMethodCompatibility();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FCPCCRuntime sharedRuntime] installMenuWhenReady];
    });
}
