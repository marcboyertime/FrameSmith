// FCPCommandConsole minimal runtime.
//
// The candidate strings below were manually transcribed from the locked
// SpliceKit symbol snapshot at f4f6618121309a69b66272b441f34cf8ad57f306.
// Candidate strings remain constants only; the separately documented exact
// onboarding gate below uses one fixed selector after its image and ABI checks.

#import "FCPCommandConsoleRuntime.h"

#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>
#import <fcntl.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import <stdint.h>
#import <stdlib.h>
#import <string.h>
#import <unistd.h>

NSString * const FCPCCMutationErrorUnsupportedUnverifiedFCP123 = @"unsupported_unverified_fcp_12_3";

static NSString * const FCPCCExpectedHostBundleIdentifier = @"com.local.fcpcommandconsole.FinalCut";
static NSString * const FCPCCExpectedHostVersion = @"12.3";
static NSString * const FCPCCExpectedHostBuild = @"450152";
static NSString * const FCPCCExpectedRuntimeFrameworkName = @"FCPCommandConsoleRuntime.framework";
static NSString * const FCPCCCloudContentFirstLaunchCompletedKey = @"CloudContentFirstLaunchCompleted";
static NSString * const FCPCCFFCloudContentDisabledKey = @"FFCloudContentDisabled";
static NSString * const FCPCCExpectedOnboardingFrameworkRelativeExecutablePath = @"Contents/Frameworks/ProOnboardingFlowModelOne.framework/Versions/A/ProOnboardingFlowModelOne";
static NSString * const FCPCCExpectedOnboardingCoordinatorClassName = @"POFDesktopOnboardingCoordinator";
static NSString * const FCPCCExpectedOnboardingQuerySetterName = @"setQueryDemoProjectInfo:";
static const char * const FCPCCExpectedOnboardingQuerySetterTypeEncoding = "v24@0:8@?16";
static const char * const FCPCCExpectedOnboardingFrameworkSHA256 = "636cc140036217ab1f39d998ac53faaf2dd8682c091f3c041dbde594d1f2dfce";

// The copied executable intentionally has one additional LC_LOAD_DYLIB and a
// new signature, so its whole-file hash cannot equal the stock executable
// hash. The patcher binds that stock hash before each deployment; the runtime
// independently verifies the copied host's preserved active-slice UUID and the
// untouched nested framework's whole-file hash and UUID.
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

// This is one fixed ObjC caller gate, not a general CloudContent hook. The
// runtime never derives a selector or class name from input or a bundled
// resource. It simply discards the reviewed optional query block after every
// image, ABI, and implementation check below has passed.
typedef NS_ENUM(NSUInteger, FCPCCOnboardingFrameworkIdentityDisposition) {
    FCPCCOnboardingFrameworkIdentityDispositionMatches = 0,
    FCPCCOnboardingFrameworkIdentityDispositionImageUnavailable = 1,
    FCPCCOnboardingFrameworkIdentityDispositionPathMismatch = 2,
    FCPCCOnboardingFrameworkIdentityDispositionHashMismatch = 3,
    FCPCCOnboardingFrameworkIdentityDispositionUUIDMismatch = 4,
    FCPCCOnboardingFrameworkIdentityDispositionImplementationMismatch = 5,
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
    NSString *expectedPath = [NSBundle.mainBundle.executablePath stringByStandardizingPath];
    NSString *loadedPath = mainImageName == NULL ? nil : [[NSString alloc] initWithUTF8String:mainImageName];
    if (expectedUUID == NULL || expectedPath.length == 0 || loadedPath == nil
        || ![[loadedPath stringByStandardizingPath] isEqualToString:expectedPath]) {
        return NO;
    }
    return FCPCCLoadedMachOImageHasExpectedUUID(mainImageHeader, expectedUUID);
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

static void FCPCCDiscardOnboardingQueryDemoProjectInfo(id self, SEL command, id queryDemoProjectInfo) {
    (void)self;
    (void)command;
    (void)queryDemoProjectInfo;
}

static NSString *FCPCCInstallOnboardingQueryGate(void) {
    static NSString *summary;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FCPCCGateStatus *containment = [[[FCPCCRuntimeContainmentGate alloc] init] evaluate];
        if (!containment.isVerified) {
            summary = @"onboarding_query_gate=host_containment_unverified";
            return;
        }
        if (!FCPCCCopiedHostImageUUIDMatches()) {
            summary = @"onboarding_query_gate=host_uuid_unverified";
            return;
        }

        Class targetClass = objc_getClass(FCPCCExpectedOnboardingCoordinatorClassName.UTF8String);
        if (targetClass == Nil) {
            summary = @"onboarding_query_gate=class_unavailable";
            return;
        }
        SEL selector = sel_registerName(FCPCCExpectedOnboardingQuerySetterName.UTF8String);
        if (selector == NULL) {
            summary = @"onboarding_query_gate=selector_unavailable";
            return;
        }

        Method method = class_getInstanceMethod(targetClass, selector);
        if (method == NULL) {
            summary = class_getClassMethod(targetClass, selector) == NULL
                ? @"onboarding_query_gate=method_unavailable"
                : @"onboarding_query_gate=method_placement_mismatch";
            return;
        }
        if (method_getNumberOfArguments(method) != 3) {
            summary = @"onboarding_query_gate=argument_count_mismatch";
            return;
        }
        char *returnType = method_copyReturnType(method);
        BOOL returnTypeMatches = returnType != NULL && strcmp(returnType, "v") == 0;
        if (returnType != NULL) {
            free(returnType);
        }
        if (!returnTypeMatches) {
            summary = @"onboarding_query_gate=return_type_mismatch";
            return;
        }
        const char *typeEncoding = method_getTypeEncoding(method);
        if (typeEncoding == NULL || strcmp(typeEncoding, FCPCCExpectedOnboardingQuerySetterTypeEncoding) != 0) {
            summary = @"onboarding_query_gate=type_encoding_mismatch";
            return;
        }

        IMP originalImplementation = method_getImplementation(method);
        switch (FCPCCOnboardingFrameworkIdentityForImplementation(originalImplementation)) {
            case FCPCCOnboardingFrameworkIdentityDispositionMatches:
                break;
            case FCPCCOnboardingFrameworkIdentityDispositionImageUnavailable:
                summary = @"onboarding_query_gate=framework_image_unavailable";
                return;
            case FCPCCOnboardingFrameworkIdentityDispositionPathMismatch:
                summary = @"onboarding_query_gate=framework_path_mismatch";
                return;
            case FCPCCOnboardingFrameworkIdentityDispositionHashMismatch:
                summary = @"onboarding_query_gate=framework_hash_mismatch";
                return;
            case FCPCCOnboardingFrameworkIdentityDispositionUUIDMismatch:
                summary = @"onboarding_query_gate=framework_uuid_mismatch";
                return;
            case FCPCCOnboardingFrameworkIdentityDispositionImplementationMismatch:
                summary = @"onboarding_query_gate=original_imp_mismatch";
                return;
        }

        class_replaceMethod(targetClass,
                            selector,
                            (IMP)FCPCCDiscardOnboardingQueryDemoProjectInfo,
                            FCPCCExpectedOnboardingQuerySetterTypeEncoding);
        Method installedMethod = class_getInstanceMethod(targetClass, selector);
        const char *installedTypeEncoding = installedMethod == NULL ? NULL : method_getTypeEncoding(installedMethod);
        if (installedMethod == NULL
            || method_getImplementation(installedMethod) != (IMP)FCPCCDiscardOnboardingQueryDemoProjectInfo
            || method_getNumberOfArguments(installedMethod) != 3
            || installedTypeEncoding == NULL
            || strcmp(installedTypeEncoding, FCPCCExpectedOnboardingQuerySetterTypeEncoding) != 0) {
            summary = @"onboarding_query_gate=post_replacement_verification_failed";
            return;
        }
        summary = @"onboarding_query_gate=installed";
    });
    return summary ?: @"onboarding_query_gate=unavailable";
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
    NSString *onboardingQueryGate = FCPCCInstallOnboardingQueryGate();
    FCPCCGateStatus *library = [[[FCPCCLibraryInvariantGate alloc] init] evaluate];
    FCPCCCapabilityStatus *capabilities = FCPCCCapabilityStatus.unverifiedPlaceholder;
    self.containmentField = [self label:[@"Copied app/runtime: " stringByAppendingString:containment.summary] frame:NSMakeRect(20, 462, width - 40, 30) weight:NSFontWeightRegular];
    self.compatibilityField = [self label:[NSString stringWithFormat:@"Isolated cloud compatibility: %@; %@", compatibility.summary, onboardingQueryGate] frame:NSMakeRect(20, 426, width - 40, 30) weight:NSFontWeightRegular];
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
    (void)FCPCCInstallOnboardingQueryGate();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FCPCCRuntime sharedRuntime] installMenuWhenReady];
    });
}
