#import "FCPCCPlannerHelperBridge.h"

#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Security/Security.h>
#import <mach/machine.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <dispatch/dispatch.h>
#import <sys/stat.h>
#import <sys/types.h>

#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

NSString * const FCPCCPlannerHelperBridgeErrorDomain = @"com.fcpcommandconsole.planner-helper-bridge";

static const NSUInteger FCPCCPlannerHelperManifestMaximumBytes = 64 * 1024;
static const NSUInteger FCPCCPlannerHelperInputMaximumBytes = 256 * 1024;
static const NSUInteger FCPCCPlannerHelperOutputMaximumBytes = 512 * 1024;
static const NSUInteger FCPCCPlannerHelperStderrMaximumBytes = 64 * 1024;
static const NSUInteger FCPCCPlannerHelperMaximumBundleBytes = 100 * 1000 * 1000;
static const NSUInteger FCPCCPlannerHelperMaximumResourceBytes = 10 * 1000 * 1000;
static const NSTimeInterval FCPCCPlannerHelperDefaultTimeout = 5.0;
static const NSTimeInterval FCPCCPlannerHelperMaximumTimeout = 60.0;

static NSString * const FCPCCPlannerHelperExecutableName = @"fcpcommandconsole-planner-helper";
static NSString * const FCPCCPlannerHelperBundleName = @"FCPCommandConsole_FCPCommandConsolePlannerHelper.bundle";
static NSString * const FCPCCPlannerHelperManifestName = @"planner-helper-manifest.json";
static NSString * const FCPCCPlannerHelperTeamIdentifier = @"KDV9RC892F";
static NSArray<NSString *> *FCPCCPlannerHelperImmutableResources(void) {
    return @[
        @"Resources/registry/effects/look.old_television.json",
        @"Resources/registry/effects/motion.living_still.json",
        @"Resources/registry/effects/native.targeted_rotate_zoom.json",
        @"Resources/registry/effects/transition.natural_dissolve.json",
        @"Resources/schemas/effect-plan.schema.json",
    ];
}

static NSString *FCPCCMessageForCode(FCPCCPlannerHelperBridgeErrorCode code) {
    switch (code) {
        case FCPCCPlannerHelperBridgeErrorNone: return @"ok";
        case FCPCCPlannerHelperBridgeErrorMainThreadInvocationRejected: return @"main_thread_invocation_rejected";
        case FCPCCPlannerHelperBridgeErrorInvalidPayloadRoot: return @"invalid_payload_root";
        case FCPCCPlannerHelperBridgeErrorMissingPayloadEntry: return @"missing_or_unexpected_payload_entry";
        case FCPCCPlannerHelperBridgeErrorSymlinkRejected: return @"symlink_rejected";
        case FCPCCPlannerHelperBridgeErrorNonRegularExecutable: return @"executable_is_not_a_regular_file";
        case FCPCCPlannerHelperBridgeErrorNonDirectoryBundle: return @"resource_bundle_is_not_a_directory";
        case FCPCCPlannerHelperBridgeErrorManifestOversized: return @"manifest_exceeds_byte_limit";
        case FCPCCPlannerHelperBridgeErrorManifestMalformed: return @"manifest_is_malformed";
        case FCPCCPlannerHelperBridgeErrorManifestIdentityMismatch: return @"manifest_identity_mismatch";
        case FCPCCPlannerHelperBridgeErrorExecutableArchitectureMismatch: return @"executable_architecture_mismatch";
        case FCPCCPlannerHelperBridgeErrorSignatureInvalid: return @"signature_is_invalid_or_not_apple_development";
        case FCPCCPlannerHelperBridgeErrorExecutableHashMismatch: return @"executable_hash_mismatch";
        case FCPCCPlannerHelperBridgeErrorBundleHashMismatch: return @"resource_bundle_hash_mismatch";
        case FCPCCPlannerHelperBridgeErrorResourceSetMismatch: return @"immutable_resource_set_mismatch";
        case FCPCCPlannerHelperBridgeErrorResourceHashMismatch: return @"immutable_resource_hash_mismatch";
        case FCPCCPlannerHelperBridgeErrorPathEscape: return @"payload_path_escape";
        case FCPCCPlannerHelperBridgeErrorInputOversized: return @"request_exceeds_byte_limit";
        case FCPCCPlannerHelperBridgeErrorInputMalformed: return @"request_data_is_malformed";
        case FCPCCPlannerHelperBridgeErrorProcessLaunchFailed: return @"helper_process_launch_failed";
        case FCPCCPlannerHelperBridgeErrorProcessExitFailed: return @"helper_process_exit_failed";
        case FCPCCPlannerHelperBridgeErrorOutputOversized: return @"helper_output_exceeds_byte_limit";
        case FCPCCPlannerHelperBridgeErrorOutputMalformed: return @"helper_output_is_not_one_json_line";
        case FCPCCPlannerHelperBridgeErrorTimeout: return @"helper_timeout";
        case FCPCCPlannerHelperBridgeErrorCancelled: return @"helper_cancelled";
        case FCPCCPlannerHelperBridgeErrorInternal: return @"internal_bridge_error";
    }
    return @"internal_bridge_error";
}

static NSError *FCPCCNSError(FCPCCPlannerHelperBridgeErrorCode code) {
    return [NSError errorWithDomain:FCPCCPlannerHelperBridgeErrorDomain
                                code:code
                            userInfo:@{NSLocalizedDescriptionKey: FCPCCMessageForCode(code)}];
}

@interface FCPCCPlannerHelperBridgeResult ()
- (instancetype)initWithCode:(FCPCCPlannerHelperBridgeErrorCode)code responseData:(NSData * _Nullable)data;
@end

@implementation FCPCCPlannerHelperBridgeResult

- (instancetype)initWithCode:(FCPCCPlannerHelperBridgeErrorCode)code responseData:(NSData *)data {
    self = [super init];
    if (self != nil) {
        _errorCode = code;
        _errorMessage = [FCPCCMessageForCode(code) copy];
        _responseData = [data copy];
        _success = (code == FCPCCPlannerHelperBridgeErrorNone);
    }
    return self;
}

@end

static BOOL FCPCCIsSymlink(NSString *path) {
    struct stat st;
    return lstat(path.fileSystemRepresentation, &st) == 0 && S_ISLNK(st.st_mode);
}

static BOOL FCPCCIsRegularFile(NSString *path) {
    struct stat st;
    return lstat(path.fileSystemRepresentation, &st) == 0 && S_ISREG(st.st_mode);
}

static BOOL FCPCCIsDirectory(NSString *path) {
    struct stat st;
    return lstat(path.fileSystemRepresentation, &st) == 0 && S_ISDIR(st.st_mode);
}

static BOOL FCPCCIsCanonicalExistingPath(NSString *path) {
    if (path.length == 0 || ![path isAbsolutePath]) {
        return NO;
    }
    NSString *standard = [path stringByStandardizingPath];
    NSString *resolved = [standard stringByResolvingSymlinksInPath];
    return [path isEqualToString:standard] && [standard isEqualToString:resolved];
}

static BOOL FCPCCChildPathIsContained(NSString *root, NSString *child) {
    NSString *prefix = [root hasSuffix:@"/"] ? root : [root stringByAppendingString:@"/"];
    if (![child hasPrefix:prefix]) {
        return NO;
    }
    NSString *resolved = [child stringByResolvingSymlinksInPath];
    return [child isEqualToString:resolved] && ![resolved containsString:@"/../"];
}

static BOOL FCPCCHexString(NSString *value, NSUInteger length, BOOL lowerCaseOnly) {
    if (![value isKindOfClass:[NSString class]] || value.length != length) {
        return NO;
    }
    for (NSUInteger index = 0; index < value.length; index += 1) {
        unichar c = [value characterAtIndex:index];
        BOOL digit = (c >= '0' && c <= '9');
        BOOL lower = (c >= 'a' && c <= 'f');
        BOOL upper = (c >= 'A' && c <= 'F');
        if (!digit && !lower && (!upper || lowerCaseOnly)) {
            return NO;
        }
    }
    return YES;
}

static BOOL FCPCCIsStrictInteger(NSNumber *number) {
    if (![number isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID()) {
        return NO;
    }
    double value = number.doubleValue;
    return isfinite(value) && floor(value) == value && value >= 0.0;
}

static BOOL FCPCCIsStrictBool(NSNumber *number) {
    return [number isKindOfClass:[NSNumber class]] &&
        CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID();
}

static BOOL FCPCCDictionaryHasOnlyKeys(NSDictionary *dictionary, NSSet<NSString *> *allowed) {
    for (id key in dictionary) {
        if (![key isKindOfClass:[NSString class]] || ![allowed containsObject:key]) {
            return NO;
        }
    }
    return YES;
}

static BOOL FCPCCRequireString(NSDictionary *dictionary, NSString *key, NSString **value) {
    id candidate = dictionary[key];
    if (![candidate isKindOfClass:[NSString class]] || ((NSString *)candidate).length == 0) {
        return NO;
    }
    if (value != NULL) {
        *value = candidate;
    }
    return YES;
}

static BOOL FCPCCRequireInteger(NSDictionary *dictionary, NSString *key, NSUInteger *value) {
    id candidate = dictionary[key];
    if (!FCPCCIsStrictInteger(candidate)) {
        return NO;
    }
    unsigned long long number = [candidate unsignedLongLongValue];
    if (number > NSUIntegerMax) {
        return NO;
    }
    if (value != NULL) {
        *value = (NSUInteger)number;
    }
    return YES;
}

static BOOL FCPCCReadFileSHA256(NSString *path, uint8_t output[CC_SHA256_DIGEST_LENGTH]) {
    if (!FCPCCIsRegularFile(path)) {
        return NO;
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (handle == nil) {
        return NO;
    }
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    BOOL success = YES;
    @try {
        while (YES) {
            NSData *chunk = [handle readDataOfLength:64 * 1024];
            if (chunk.length == 0) {
                break;
            }
            CC_SHA256_Update(&context, chunk.bytes, (CC_LONG)chunk.length);
        }
    } @catch (__unused NSException *exception) {
        success = NO;
    }
    [handle closeFile];
    if (!success) {
        return NO;
    }
    CC_SHA256_Final(output, &context);
    return YES;
}

static NSString *FCPCCHexFromBytes(const uint8_t *bytes, NSUInteger count) {
    static const char digits[] = "0123456789abcdef";
    NSMutableString *result = [NSMutableString stringWithCapacity:count * 2];
    for (NSUInteger index = 0; index < count; index += 1) {
        [result appendFormat:@"%c%c", digits[(bytes[index] >> 4) & 0xf], digits[bytes[index] & 0xf]];
    }
    return result;
}

static BOOL FCPCCReadDirectoryHash(NSString *root, NSUInteger *totalBytes, NSString **hash) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:root];
    NSMutableArray<NSString *> *files = [NSMutableArray array];
    NSUInteger total = 0;
    for (NSString *relative in enumerator) {
        NSString *path = [root stringByAppendingPathComponent:relative];
        if (FCPCCIsSymlink(path)) {
            return NO;
        }
        if (FCPCCIsRegularFile(path)) {
            struct stat st;
            if (lstat(path.fileSystemRepresentation, &st) != 0 || st.st_size < 0 ||
                (uint64_t)st.st_size > FCPCCPlannerHelperMaximumResourceBytes) {
                return NO;
            }
            total += (NSUInteger)st.st_size;
            if (total > FCPCCPlannerHelperMaximumBundleBytes) {
                return NO;
            }
            [files addObject:relative];
        } else if (!FCPCCIsDirectory(path)) {
            return NO;
        }
    }
    [files sortUsingSelector:@selector(compare:)];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    for (NSString *relative in files) {
        uint8_t digest[CC_SHA256_DIGEST_LENGTH];
        NSString *path = [root stringByAppendingPathComponent:relative];
        if (!FCPCCReadFileSHA256(path, digest)) {
            return NO;
        }
        NSString *line = [NSString stringWithFormat:@"%@  %@\n", FCPCCHexFromBytes(digest, sizeof(digest)), relative];
        NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];
        CC_SHA256_Update(&context, lineData.bytes, (CC_LONG)lineData.length);
    }
    uint8_t finalDigest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(finalDigest, &context);
    if (totalBytes != NULL) {
        *totalBytes = total;
    }
    if (hash != NULL) {
        *hash = FCPCCHexFromBytes(finalDigest, sizeof(finalDigest));
    }
    return YES;
}

static uint32_t FCPCCReadBE32(const uint8_t *bytes) {
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
        ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static uint64_t FCPCCReadBE64(const uint8_t *bytes) {
    return ((uint64_t)FCPCCReadBE32(bytes) << 32) | FCPCCReadBE32(bytes + 4);
}

static uint32_t FCPCCReadLE32(const uint8_t *bytes) {
    return ((uint32_t)bytes[3] << 24) | ((uint32_t)bytes[2] << 16) |
        ((uint32_t)bytes[1] << 8) | (uint32_t)bytes[0];
}

static NSData *FCPCCArm64MachSlice(NSString *path) {
    struct stat st;
    if (lstat(path.fileSystemRepresentation, &st) != 0 || st.st_size <= 0 ||
        (uint64_t)st.st_size > FCPCCPlannerHelperMaximumBundleBytes) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (data.length < sizeof(uint32_t)) {
        return nil;
    }
    const uint8_t *bytes = data.bytes;
    uint32_t firstBE = FCPCCReadBE32(bytes);
    uint32_t firstLE = FCPCCReadLE32(bytes);
    if (firstLE == MH_MAGIC_64) {
        if (data.length < sizeof(struct mach_header_64)) {
            return nil;
        }
        const struct mach_header_64 *header = data.bytes;
        if (header->cputype != CPU_TYPE_ARM64 || header->filetype != MH_EXECUTE) {
            return nil;
        }
        return data;
    }
    if (firstBE != FAT_MAGIC && firstBE != FAT_MAGIC_64) {
        return nil;
    }
    if (data.length < sizeof(struct fat_header)) {
        return nil;
    }
    uint32_t count = FCPCCReadBE32(bytes + 4);
    if (count != 1) {
        return nil;
    }
    uint64_t entrySize = firstBE == FAT_MAGIC_64 ? sizeof(struct fat_arch_64) : sizeof(struct fat_arch);
    uint64_t entriesEnd = sizeof(struct fat_header) + entrySize * count;
    if (entriesEnd > data.length) {
        return nil;
    }
    const uint8_t *entry = bytes + sizeof(struct fat_header);
    uint32_t cpu = FCPCCReadBE32(entry);
    if (cpu != CPU_TYPE_ARM64) {
        return nil;
    }
    uint64_t offset;
    uint64_t size;
    if (firstBE == FAT_MAGIC_64) {
        offset = FCPCCReadBE64(entry + 8);
        size = FCPCCReadBE64(entry + 16);
    } else {
        offset = FCPCCReadBE32(entry + 8);
        size = FCPCCReadBE32(entry + 12);
    }
    if (offset > data.length || size > data.length - offset || size < sizeof(struct mach_header_64)) {
        return nil;
    }
    NSData *slice = [data subdataWithRange:NSMakeRange((NSUInteger)offset, (NSUInteger)size)];
    const struct mach_header_64 *header = slice.bytes;
    if (FCPCCReadLE32(slice.bytes) != MH_MAGIC_64 || header->cputype != CPU_TYPE_ARM64 || header->filetype != MH_EXECUTE) {
        return nil;
    }
    return slice;
}

static BOOL FCPCCCodeDirectoryHashes(NSString *path, NSString **candidateFull, NSString **cdhash) {
    NSData *slice = FCPCCArm64MachSlice(path);
    if (slice.length < sizeof(struct mach_header_64)) {
        return NO;
    }
    const uint8_t *bytes = slice.bytes;
    const struct mach_header_64 *header = (const struct mach_header_64 *)bytes;
    uint64_t commandsEnd = sizeof(struct mach_header_64) + header->sizeofcmds;
    if (header->magic != MH_MAGIC_64 || header->ncmds > 4096 || commandsEnd > slice.length) {
        return NO;
    }
    uint32_t signatureOffset = 0;
    uint32_t signatureSize = 0;
    const uint8_t *command = bytes + sizeof(struct mach_header_64);
    for (uint32_t index = 0; index < header->ncmds; index += 1) {
        if ((size_t)(command - bytes) + sizeof(struct load_command) > commandsEnd) {
            return NO;
        }
        const struct load_command *load = (const struct load_command *)command;
        if (load->cmdsize < sizeof(struct load_command) ||
            (size_t)(command - bytes) + load->cmdsize > commandsEnd) {
            return NO;
        }
        if (load->cmd == LC_CODE_SIGNATURE && load->cmdsize >= sizeof(struct linkedit_data_command)) {
            const struct linkedit_data_command *link = (const struct linkedit_data_command *)command;
            signatureOffset = link->dataoff;
            signatureSize = link->datasize;
        }
        command += load->cmdsize;
    }
    if (signatureSize < 12 || (uint64_t)signatureOffset + signatureSize > slice.length) {
        return NO;
    }
    const uint8_t *super = bytes + signatureOffset;
    if (FCPCCReadBE32(super) != 0xfade0cc0 || FCPCCReadBE32(super + 4) < 12) {
        return NO;
    }
    uint32_t count = FCPCCReadBE32(super + 8);
    if (count == 0 || count > 32 || 12ULL + count * 8ULL > signatureSize) {
        return NO;
    }
    const uint8_t *codeDirectory = NULL;
    uint32_t codeDirectoryLength = 0;
    for (uint32_t index = 0; index < count; index += 1) {
        const uint8_t *entry = super + 12 + index * 8;
        uint32_t slot = FCPCCReadBE32(entry);
        uint32_t offset = FCPCCReadBE32(entry + 4);
        if (slot != 0 || offset > signatureSize - 8) {
            continue;
        }
        const uint8_t *blob = super + offset;
        uint32_t length = FCPCCReadBE32(blob + 4);
        if (length < 8 || offset + length > signatureSize || FCPCCReadBE32(blob) != 0xfade0c02) {
            return NO;
        }
        codeDirectory = blob;
        codeDirectoryLength = length;
        break;
    }
    if (codeDirectory == NULL) {
        return NO;
    }
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(codeDirectory, codeDirectoryLength, digest);
    if (candidateFull != NULL) {
        *candidateFull = FCPCCHexFromBytes(digest, sizeof(digest));
    }
    if (cdhash != NULL) {
        *cdhash = FCPCCHexFromBytes(digest, 20);
    }
    return YES;
}

static BOOL FCPCCValidateAppleDevelopmentSignature(NSString *path) {
    NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
    SecStaticCodeRef staticCode = NULL;
    OSStatus status = SecStaticCodeCreateWithPath((__bridge CFURLRef)url, kSecCSDefaultFlags, &staticCode);
    if (status != errSecSuccess || staticCode == NULL) {
        if (staticCode != NULL) CFRelease(staticCode);
        return NO;
    }
    SecRequirementRef requirement = NULL;
    status = SecRequirementCreateWithString(CFSTR("anchor apple generic"), kSecCSDefaultFlags, &requirement);
    if (status != errSecSuccess || requirement == NULL) {
        if (requirement != NULL) CFRelease(requirement);
        CFRelease(staticCode);
        return NO;
    }
    status = SecStaticCodeCheckValidity(staticCode, kSecCSStrictValidate | kSecCSCheckAllArchitectures, requirement);
    CFRelease(requirement);
    if (status != errSecSuccess) {
        CFRelease(staticCode);
        return NO;
    }
    CFDictionaryRef information = NULL;
    status = SecCodeCopySigningInformation(staticCode, kSecCSSigningInformation, &information);
    if (status != errSecSuccess || information == NULL) {
        if (information != NULL) CFRelease(information);
        CFRelease(staticCode);
        return NO;
    }
    CFArrayRef certificates = CFDictionaryGetValue(information, kSecCodeInfoCertificates);
    CFStringRef teamIdentifier = CFDictionaryGetValue(information, kSecCodeInfoTeamIdentifier);
    BOOL teamMatches = teamIdentifier != NULL && CFGetTypeID(teamIdentifier) == CFStringGetTypeID() &&
        [(__bridge NSString *)teamIdentifier isEqualToString:FCPCCPlannerHelperTeamIdentifier];
    BOOL development = NO;
    if (certificates != NULL && CFGetTypeID(certificates) == CFArrayGetTypeID() && CFArrayGetCount(certificates) > 0) {
        SecCertificateRef leaf = (SecCertificateRef)CFArrayGetValueAtIndex(certificates, 0);
        if (leaf != NULL && CFGetTypeID(leaf) == SecCertificateGetTypeID()) {
            CFStringRef subject = SecCertificateCopySubjectSummary(leaf);
            if (subject != NULL) {
                NSString *summary = [(__bridge NSString *)subject copy];
                development = [summary hasPrefix:@"Apple Development:"];
                CFRelease(subject);
            }
        }
    }
    CFRelease(information);
    CFRelease(staticCode);
    return development && teamMatches;
}

@interface FCPCCPlannerPayloadPaths : NSObject
@property (nonatomic, copy) NSString *root;
@property (nonatomic, copy) NSString *executable;
@property (nonatomic, copy) NSString *bundle;
@property (nonatomic, copy) NSString *manifest;
@end

@implementation FCPCCPlannerPayloadPaths
@end

static FCPCCPlannerHelperBridgeErrorCode FCPCCValidatePayloadAtRoot(NSURL *rootURL, FCPCCPlannerPayloadPaths **pathsOut) {
    if (rootURL == nil || !rootURL.isFileURL || rootURL.path.length == 0 ||
        !rootURL.path.isAbsolutePath || !FCPCCIsCanonicalExistingPath(rootURL.path) || !FCPCCIsDirectory(rootURL.path) ||
        FCPCCIsSymlink(rootURL.path)) {
        return FCPCCPlannerHelperBridgeErrorInvalidPayloadRoot;
    }
    NSString *root = [rootURL.path stringByStandardizingPath];
    NSSet<NSString *> *expected = [NSSet setWithObjects:FCPCCPlannerHelperExecutableName, FCPCCPlannerHelperBundleName, FCPCCPlannerHelperManifestName, nil];
    NSArray<NSString *> *children = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:nil];
    if (children == nil || children.count != expected.count || ![[NSSet setWithArray:children] isEqualToSet:expected]) {
        return FCPCCPlannerHelperBridgeErrorMissingPayloadEntry;
    }
    NSString *executable = [root stringByAppendingPathComponent:FCPCCPlannerHelperExecutableName];
    NSString *bundle = [root stringByAppendingPathComponent:FCPCCPlannerHelperBundleName];
    NSString *manifest = [root stringByAppendingPathComponent:FCPCCPlannerHelperManifestName];
    if (!FCPCCChildPathIsContained(root, executable) || !FCPCCChildPathIsContained(root, bundle) || !FCPCCChildPathIsContained(root, manifest)) {
        return FCPCCPlannerHelperBridgeErrorPathEscape;
    }
    if (FCPCCIsSymlink(executable) || FCPCCIsSymlink(bundle) || FCPCCIsSymlink(manifest)) {
        return FCPCCPlannerHelperBridgeErrorSymlinkRejected;
    }
    if (!FCPCCIsRegularFile(executable)) {
        return FCPCCPlannerHelperBridgeErrorNonRegularExecutable;
    }
    if (!FCPCCIsDirectory(bundle)) {
        return FCPCCPlannerHelperBridgeErrorNonDirectoryBundle;
    }
    if (!FCPCCIsRegularFile(manifest)) {
        return FCPCCPlannerHelperBridgeErrorManifestMalformed;
    }

    struct stat manifestStat;
    if (lstat(manifest.fileSystemRepresentation, &manifestStat) != 0 || manifestStat.st_size < 0) {
        return FCPCCPlannerHelperBridgeErrorManifestMalformed;
    }
    if ((uint64_t)manifestStat.st_size > FCPCCPlannerHelperManifestMaximumBytes) {
        return FCPCCPlannerHelperBridgeErrorManifestOversized;
    }
    NSData *manifestData = [NSData dataWithContentsOfFile:manifest options:0 error:nil];
    NSDictionary *manifestObject = manifestData.length > 0 ? [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil] : nil;
    if (![manifestObject isKindOfClass:[NSDictionary class]]) {
        return FCPCCPlannerHelperBridgeErrorManifestMalformed;
    }
    if (!FCPCCDictionaryHasOnlyKeys(manifestObject, [NSSet setWithArray:@[@"schema_version", @"product", @"configuration", @"architecture", @"executable", @"resource_bundle"]])) {
        return FCPCCPlannerHelperBridgeErrorManifestMalformed;
    }
    NSUInteger schema = 0;
    NSString *product = nil;
    NSString *configuration = nil;
    NSString *architecture = nil;
    if (!FCPCCRequireInteger(manifestObject, @"schema_version", &schema) ||
        !FCPCCRequireString(manifestObject, @"product", &product) ||
        !FCPCCRequireString(manifestObject, @"configuration", &configuration) ||
        !FCPCCRequireString(manifestObject, @"architecture", &architecture) ||
        schema != 1 || ![product isEqualToString:FCPCCPlannerHelperExecutableName] ||
        ![configuration isEqualToString:@"release"] || ![architecture isEqualToString:@"arm64"]) {
        return FCPCCPlannerHelperBridgeErrorManifestIdentityMismatch;
    }
    NSDictionary *executableManifest = manifestObject[@"executable"];
    NSDictionary *bundleManifest = manifestObject[@"resource_bundle"];
    if (![executableManifest isKindOfClass:[NSDictionary class]] || ![bundleManifest isKindOfClass:[NSDictionary class]] ||
        !FCPCCDictionaryHasOnlyKeys(executableManifest, [NSSet setWithArray:@[@"relative_path", @"sha256", @"size_bytes", @"candidate_cdhash_full", @"cdhash", @"architectures", @"team_identifier"]]) ||
        !FCPCCDictionaryHasOnlyKeys(bundleManifest, [NSSet setWithArray:@[@"relative_path", @"sha256", @"size_bytes", @"signed", @"resources"]])) {
        return FCPCCPlannerHelperBridgeErrorManifestMalformed;
    }
    NSString *relativeExecutable = nil;
    NSString *executableHash = nil;
    NSString *candidateHash = nil;
    NSString *cdHash = nil;
    NSString *teamIdentifier = nil;
    NSUInteger executableSize = 0;
    if (!FCPCCRequireString(executableManifest, @"relative_path", &relativeExecutable) ||
        !FCPCCRequireString(executableManifest, @"sha256", &executableHash) ||
        !FCPCCRequireInteger(executableManifest, @"size_bytes", &executableSize) ||
        !FCPCCRequireString(executableManifest, @"candidate_cdhash_full", &candidateHash) ||
        !FCPCCRequireString(executableManifest, @"cdhash", &cdHash) ||
        !FCPCCRequireString(executableManifest, @"team_identifier", &teamIdentifier) ||
        !FCPCCHexString(executableHash, 64, YES) || !FCPCCHexString(candidateHash, 64, NO) || !FCPCCHexString(cdHash, 40, NO) ||
        ![relativeExecutable isEqualToString:FCPCCPlannerHelperExecutableName] ||
        ![teamIdentifier isEqualToString:FCPCCPlannerHelperTeamIdentifier]) {
        return FCPCCPlannerHelperBridgeErrorManifestIdentityMismatch;
    }
    NSArray *architectures = executableManifest[@"architectures"];
    if (![architectures isKindOfClass:[NSArray class]] || architectures.count != 1 || ![architectures.firstObject isEqualToString:@"arm64"]) {
        return FCPCCPlannerHelperBridgeErrorExecutableArchitectureMismatch;
    }
    NSString *relativeBundle = nil;
    NSString *bundleHash = nil;
    NSUInteger bundleSize = 0;
    NSNumber *bundleSigned = bundleManifest[@"signed"];
    if (!FCPCCRequireString(bundleManifest, @"relative_path", &relativeBundle) ||
        !FCPCCRequireString(bundleManifest, @"sha256", &bundleHash) ||
        !FCPCCRequireInteger(bundleManifest, @"size_bytes", &bundleSize) ||
        !FCPCCIsStrictBool(bundleSigned) || !FCPCCHexString(bundleHash, 64, YES) ||
        ![relativeBundle isEqualToString:FCPCCPlannerHelperBundleName]) {
        return FCPCCPlannerHelperBridgeErrorManifestIdentityMismatch;
    }
    NSArray *resourceManifest = bundleManifest[@"resources"];
    NSArray<NSString *> *immutableResources = FCPCCPlannerHelperImmutableResources();
    if (![resourceManifest isKindOfClass:[NSArray class]] || resourceManifest.count != immutableResources.count) {
        return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
    }
    NSMutableDictionary<NSString *, NSDictionary *> *resourcesByPath = [NSMutableDictionary dictionary];
    for (NSDictionary *resource in resourceManifest) {
        if (![resource isKindOfClass:[NSDictionary class]] ||
            !FCPCCDictionaryHasOnlyKeys(resource, [NSSet setWithArray:@[@"relative_path", @"sha256", @"size_bytes"]])) {
            return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
        }
        NSString *relative = nil;
        NSString *hash = nil;
        NSUInteger size = 0;
        if (!FCPCCRequireString(resource, @"relative_path", &relative) || !FCPCCRequireString(resource, @"sha256", &hash) ||
            !FCPCCRequireInteger(resource, @"size_bytes", &size) || !FCPCCHexString(hash, 64, YES) ||
            ![immutableResources containsObject:relative] || resourcesByPath[relative] != nil) {
            return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
        }
        resourcesByPath[relative] = resource;
    }
    for (NSString *relative in immutableResources) {
        if (resourcesByPath[relative] == nil) {
            return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
        }
    }
    if (!FCPCCArm64MachSlice(executable)) {
        return FCPCCPlannerHelperBridgeErrorExecutableArchitectureMismatch;
    }
    if (!FCPCCValidateAppleDevelopmentSignature(executable)) {
        return FCPCCPlannerHelperBridgeErrorSignatureInvalid;
    }
    if (bundleSigned.boolValue && !FCPCCValidateAppleDevelopmentSignature(bundle)) {
        return FCPCCPlannerHelperBridgeErrorSignatureInvalid;
    }
    NSSet<NSString *> *allowedTopLevel = bundleSigned.boolValue ? [NSSet setWithObjects:@"Resources", @"_CodeSignature", nil] : [NSSet setWithObject:@"Resources"];
    NSArray<NSString *> *bundleChildren = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundle error:nil];
    for (NSString *child in bundleChildren) {
        NSString *childPath = [bundle stringByAppendingPathComponent:child];
        if (![allowedTopLevel containsObject:child] || FCPCCIsSymlink(childPath) || !FCPCCIsDirectory(childPath)) {
            return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
        }
    }
    if (!FCPCCIsDirectory([bundle stringByAppendingPathComponent:@"Resources"])) {
        return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
    }
    NSDirectoryEnumerator *bundleEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:bundle];
    for (NSString *relative in bundleEnumerator) {
        NSString *filePath = [bundle stringByAppendingPathComponent:relative];
        if (FCPCCIsSymlink(filePath)) {
            return FCPCCPlannerHelperBridgeErrorSymlinkRejected;
        }
    }
    for (NSString *relative in immutableResources) {
        NSString *resourcePath = [bundle stringByAppendingPathComponent:relative];
        if (!FCPCCChildPathIsContained(bundle, resourcePath) || !FCPCCIsRegularFile(resourcePath)) {
            return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
        }
        struct stat resourceStat;
        if (lstat(resourcePath.fileSystemRepresentation, &resourceStat) != 0 || resourceStat.st_size < 0 ||
            (uint64_t)resourceStat.st_size > FCPCCPlannerHelperMaximumResourceBytes) {
            return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
        }
        NSDictionary *entry = resourcesByPath[relative];
        NSUInteger expectedSize = 0;
        if (!FCPCCRequireInteger(entry, @"size_bytes", &expectedSize) || expectedSize != (NSUInteger)resourceStat.st_size) {
            return FCPCCPlannerHelperBridgeErrorResourceHashMismatch;
        }
        uint8_t digest[CC_SHA256_DIGEST_LENGTH];
        if (!FCPCCReadFileSHA256(resourcePath, digest) || ![FCPCCHexFromBytes(digest, sizeof(digest)) isEqualToString:entry[@"sha256"]]) {
            return FCPCCPlannerHelperBridgeErrorResourceHashMismatch;
        }
    }
    NSDirectoryEnumerator *resourceEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:[bundle stringByAppendingPathComponent:@"Resources"]];
    NSMutableArray<NSString *> *actualResources = [NSMutableArray array];
    for (NSString *relative in resourceEnumerator) {
        NSString *resourcePath = [[bundle stringByAppendingPathComponent:@"Resources"] stringByAppendingPathComponent:relative];
        if (FCPCCIsSymlink(resourcePath)) {
            return FCPCCPlannerHelperBridgeErrorSymlinkRejected;
        }
        if (FCPCCIsRegularFile(resourcePath)) {
            [actualResources addObject:[@"Resources/" stringByAppendingString:relative]];
        } else if (FCPCCIsDirectory(resourcePath)) {
            NSSet *allowedDirectories = [NSSet setWithArray:@[
                @"registry", @"registry/effects", @"schemas"
            ]];
            if (![allowedDirectories containsObject:relative]) {
                return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
            }
        } else {
            return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
        }
    }
    [actualResources sortUsingSelector:@selector(compare:)];
    NSArray *sortedImmutable = [immutableResources sortedArrayUsingSelector:@selector(compare:)];
    if (![actualResources isEqualToArray:sortedImmutable]) {
        return FCPCCPlannerHelperBridgeErrorResourceSetMismatch;
    }
    struct stat executableStat;
    if (lstat(executable.fileSystemRepresentation, &executableStat) != 0 || executableStat.st_size < 0 ||
        (uint64_t)executableStat.st_size != executableSize) {
        return FCPCCPlannerHelperBridgeErrorExecutableHashMismatch;
    }
    uint8_t executableDigest[CC_SHA256_DIGEST_LENGTH];
    if (!FCPCCReadFileSHA256(executable, executableDigest) || ![FCPCCHexFromBytes(executableDigest, sizeof(executableDigest)) isEqualToString:executableHash]) {
        return FCPCCPlannerHelperBridgeErrorExecutableHashMismatch;
    }
    NSString *actualCandidate = nil;
    NSString *actualCDHash = nil;
    if (!FCPCCCodeDirectoryHashes(executable, &actualCandidate, &actualCDHash) ||
        [actualCandidate caseInsensitiveCompare:candidateHash] != NSOrderedSame ||
        [actualCDHash caseInsensitiveCompare:cdHash] != NSOrderedSame) {
        return FCPCCPlannerHelperBridgeErrorManifestIdentityMismatch;
    }
    NSUInteger actualBundleSize = 0;
    NSString *actualBundleHash = nil;
    if (!FCPCCReadDirectoryHash(bundle, &actualBundleSize, &actualBundleHash) || actualBundleSize != bundleSize) {
        return FCPCCPlannerHelperBridgeErrorBundleHashMismatch;
    }
    if (![actualBundleHash isEqualToString:bundleHash]) {
        return FCPCCPlannerHelperBridgeErrorBundleHashMismatch;
    }
    if (pathsOut != NULL) {
        FCPCCPlannerPayloadPaths *paths = [FCPCCPlannerPayloadPaths new];
        paths.root = root;
        paths.executable = executable;
        paths.bundle = bundle;
        paths.manifest = manifest;
        *pathsOut = paths;
    }
    return FCPCCPlannerHelperBridgeErrorNone;
}

@interface FCPCCPlannerHelperInvocation ()
@property (nonatomic, strong) NSLock *stateLock;
@property (nonatomic, copy) NSURL *rootURL;
@property (nonatomic, copy) NSData *requestData;
@property (nonatomic, copy) FCPCCPlannerHelperCompletion completion;
@property (nonatomic) NSTimeInterval timeout;
@property (nonatomic, strong, nullable) NSTask *task;
@property (nonatomic, strong, nullable) dispatch_source_t timer;
@property (nonatomic, strong) NSMutableData *stdoutData;
@property (nonatomic, strong) NSMutableData *stderrData;
@property (nonatomic) BOOL stdoutTooLarge;
@property (nonatomic) BOOL stderrTooLarge;
@property (nonatomic) BOOL cancelled;
@property (nonatomic) BOOL timedOut;
@property (nonatomic) BOOL completed;
- (instancetype)initWithRootURL:(NSURL *)rootURL requestData:(NSData *)requestData timeout:(NSTimeInterval)timeout completion:(FCPCCPlannerHelperCompletion)completion;
- (void)start;
@end

@implementation FCPCCPlannerHelperInvocation

- (instancetype)initWithRootURL:(NSURL *)rootURL requestData:(NSData *)requestData timeout:(NSTimeInterval)timeout completion:(FCPCCPlannerHelperCompletion)completion {
    self = [super init];
    if (self != nil) {
        _stateLock = [NSLock new];
        _rootURL = [rootURL copy];
        _requestData = [requestData copy];
        _timeout = timeout;
        _completion = [completion copy];
        _stdoutData = [NSMutableData data];
        _stderrData = [NSMutableData data];
    }
    return self;
}

- (void)cancel {
    NSTask *task = nil;
    [self.stateLock lock];
    if (!self.completed) {
        self.cancelled = YES;
        task = self.task;
    }
    [self.stateLock unlock];
    if (task != nil && task.isRunning) {
        [task terminate];
    }
}

- (void)deliverResult:(FCPCCPlannerHelperBridgeResult *)result {
    FCPCCPlannerHelperCompletion completion = nil;
    [self.stateLock lock];
    if (self.completed) {
        [self.stateLock unlock];
        return;
    }
    self.completed = YES;
    completion = [self.completion copy];
    self.completion = nil;
    dispatch_source_t timer = self.timer;
    self.timer = nil;
    [self.stateLock unlock];
    if (timer != nil) {
        dispatch_source_cancel(timer);
    }
    if (completion != nil) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            completion(result);
        });
    }
}

- (BOOL)appendData:(NSData *)data toStream:(BOOL)stdoutStream {
    if (data.length == 0) {
        return YES;
    }
    [self.stateLock lock];
    NSMutableData *target = stdoutStream ? self.stdoutData : self.stderrData;
    NSUInteger limit = stdoutStream ? FCPCCPlannerHelperOutputMaximumBytes : FCPCCPlannerHelperStderrMaximumBytes;
    if (target.length > limit || data.length > limit - target.length) {
        if (stdoutStream) self.stdoutTooLarge = YES; else self.stderrTooLarge = YES;
        NSTask *task = self.task;
        [self.stateLock unlock];
        if (task != nil && task.isRunning) [task terminate];
        return NO;
    }
    [target appendData:data];
    [self.stateLock unlock];
    return YES;
}

- (FCPCCPlannerHelperBridgeResult *)resultForProcessWithStatus:(int)status terminationReason:(NSTaskTerminationReason)reason {
    [self.stateLock lock];
    BOOL cancelled = self.cancelled;
    BOOL timedOut = self.timedOut;
    BOOL stdoutTooLarge = self.stdoutTooLarge;
    BOOL stderrTooLarge = self.stderrTooLarge;
    NSData *stdoutData = [self.stdoutData copy];
    [self.stateLock unlock];
    if (timedOut) return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorTimeout responseData:nil];
    if (cancelled) return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorCancelled responseData:nil];
    if (stdoutTooLarge || stderrTooLarge) return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorOutputOversized responseData:nil];
    if (reason == NSTaskTerminationReasonUncaughtSignal || status != 0) return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorProcessExitFailed responseData:nil];
    if (stdoutData.length == 0 || stdoutData.length > FCPCCPlannerHelperOutputMaximumBytes) return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorOutputMalformed responseData:nil];
    const uint8_t *bytes = stdoutData.bytes;
    if (bytes[stdoutData.length - 1] != '\n') return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorOutputMalformed responseData:nil];
    NSData *lineData = [stdoutData subdataWithRange:NSMakeRange(0, stdoutData.length - 1)];
    if (lineData.length == 0 || memchr(lineData.bytes, '\n', lineData.length) != NULL || memchr(lineData.bytes, '\r', lineData.length) != NULL ||
        [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding] == nil) {
        return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorOutputMalformed responseData:nil];
    }
    id object = [NSJSONSerialization JSONObjectWithData:lineData options:NSJSONReadingAllowFragments error:nil];
    if (![object isKindOfClass:[NSDictionary class]]) return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorOutputMalformed responseData:nil];
    NSDictionary *envelope = object;
    NSSet *keys = [NSSet setWithArray:envelope.allKeys];
    NSSet *allowedKeys = [NSSet setWithArray:@[@"schema_version", @"status", @"plan", @"error"]];
    NSSet *requiredKeys = [NSSet setWithArray:@[@"schema_version", @"status"]];
    BOOL keysAllowed = YES;
    for (id key in keys) {
        if (![allowedKeys containsObject:key]) {
            keysAllowed = NO;
            break;
        }
    }
    BOOL requiredPresent = YES;
    for (id key in requiredKeys) {
        if (![keys containsObject:key]) {
            requiredPresent = NO;
            break;
        }
    }
    if (!keysAllowed || !requiredPresent) {
        return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorOutputMalformed responseData:nil];
    }
    if (![envelope[@"schema_version"] isEqual:@"1.0"] || ![envelope[@"status"] isKindOfClass:[NSString class]]) {
        return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorOutputMalformed responseData:nil];
    }
    NSString *statusText = envelope[@"status"];
    id plan = envelope[@"plan"];
    id error = envelope[@"error"];
    BOOL planAbsent = (plan == nil || plan == [NSNull null]);
    BOOL errorAbsent = (error == nil || error == [NSNull null]);
    BOOL validEnvelope = ([statusText isEqualToString:@"ok"] && [plan isKindOfClass:[NSDictionary class]] && errorAbsent) ||
        ([statusText isEqualToString:@"error"] && [error isKindOfClass:[NSDictionary class]] && planAbsent);
    if (!validEnvelope) return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorOutputMalformed responseData:nil];
    return [[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorNone responseData:lineData];
}

- (void)start {
    dispatch_queue_t queue = dispatch_queue_create("com.fcpcommandconsole.planner-helper.invocation", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        [self.stateLock lock];
        BOOL cancelled = self.cancelled;
        [self.stateLock unlock];
        if (cancelled) {
            [self deliverResult:[[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorCancelled responseData:nil]];
            return;
        }
        if (self.requestData.length > FCPCCPlannerHelperInputMaximumBytes) {
            [self deliverResult:[[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorInputOversized responseData:nil]];
            return;
        }
        if (self.requestData.length == 0 || [[NSString alloc] initWithData:self.requestData encoding:NSUTF8StringEncoding] == nil ||
            ![[NSJSONSerialization JSONObjectWithData:self.requestData options:0 error:nil] isKindOfClass:[NSDictionary class]]) {
            [self deliverResult:[[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorInputMalformed responseData:nil]];
            return;
        }
        FCPCCPlannerPayloadPaths *paths = nil;
        FCPCCPlannerHelperBridgeErrorCode validation = FCPCCValidatePayloadAtRoot(self.rootURL, &paths);
        if (validation != FCPCCPlannerHelperBridgeErrorNone) {
            [self deliverResult:[[FCPCCPlannerHelperBridgeResult alloc] initWithCode:validation responseData:nil]];
            return;
        }
        NSTask *task = [NSTask new];
        NSPipe *input = [NSPipe pipe];
        NSPipe *output = [NSPipe pipe];
        NSPipe *error = [NSPipe pipe];
        task.executableURL = [NSURL fileURLWithPath:paths.executable isDirectory:NO];
        task.arguments = @[];
        task.environment = @{};
        task.currentDirectoryURL = [NSURL fileURLWithPath:paths.root isDirectory:YES];
        task.standardInput = input;
        task.standardOutput = output;
        task.standardError = error;
        [self.stateLock lock];
        self.task = task;
        cancelled = self.cancelled;
        [self.stateLock unlock];
        if (cancelled) {
            [self deliverResult:[[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorCancelled responseData:nil]];
            return;
        }
        __weak FCPCCPlannerHelperInvocation *weakSelf = self;
        output.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
            FCPCCPlannerHelperInvocation *strongSelf = weakSelf;
            if (strongSelf == nil) return;
            @autoreleasepool {
                NSData *data = [handle readDataOfLength:16 * 1024];
                if (data.length > 0) [strongSelf appendData:data toStream:YES];
            }
        };
        error.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
            FCPCCPlannerHelperInvocation *strongSelf = weakSelf;
            if (strongSelf == nil) return;
            @autoreleasepool {
                NSData *data = [handle readDataOfLength:16 * 1024];
                if (data.length > 0) [strongSelf appendData:data toStream:NO];
            }
        };
        task.terminationHandler = ^(NSTask *terminatedTask) {
            output.fileHandleForReading.readabilityHandler = nil;
            error.fileHandleForReading.readabilityHandler = nil;
            @try {
                NSData *remainingOutput = [output.fileHandleForReading readDataToEndOfFile];
                if (remainingOutput.length > 0) [self appendData:remainingOutput toStream:YES];
                NSData *remainingError = [error.fileHandleForReading readDataToEndOfFile];
                if (remainingError.length > 0) [self appendData:remainingError toStream:NO];
            } @catch (__unused NSException *exception) {
                [self deliverResult:[[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorOutputMalformed responseData:nil]];
                return;
            }
            FCPCCPlannerHelperBridgeResult *result = [self resultForProcessWithStatus:terminatedTask.terminationStatus terminationReason:terminatedTask.terminationReason];
            [self deliverResult:result];
        };
        NSError *launchError = nil;
        if (![task launchAndReturnError:&launchError]) {
            [self deliverResult:[[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorProcessLaunchFailed responseData:nil]];
            return;
        }
        @try {
            [input.fileHandleForWriting writeData:self.requestData];
            [input.fileHandleForWriting closeFile];
        } @catch (__unused NSException *exception) {
            [task terminate];
        }
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, (uint64_t)(0.01 * NSEC_PER_SEC));
        dispatch_source_set_event_handler(timer, ^{
            [self.stateLock lock];
            BOOL done = self.completed;
            BOOL alreadyCancelled = self.cancelled;
            if (!done && !alreadyCancelled) self.timedOut = YES;
            NSTask *runningTask = self.task;
            [self.stateLock unlock];
            if (!done && !alreadyCancelled && runningTask != nil && runningTask.isRunning) [runningTask terminate];
        });
        [self.stateLock lock];
        BOOL alreadyCompleted = self.completed;
        if (!alreadyCompleted) self.timer = timer;
        [self.stateLock unlock];
        if (alreadyCompleted) {
            dispatch_source_cancel(timer);
        } else {
            dispatch_resume(timer);
        }
    });
}

@end

@interface FCPCCPlannerHelperBridge ()
@property (nonatomic, copy) NSURL *payloadRootURL;
@end

@implementation FCPCCPlannerHelperBridge

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        NSURL *frameworkURL = [[NSBundle bundleForClass:[FCPCCPlannerHelperBridge class]] bundleURL];
        _payloadRootURL = [frameworkURL URLByAppendingPathComponent:@"Versions/A/Resources/PlannerHelperPayload" isDirectory:YES];
    }
    return self;
}

#if defined(FCPCC_PLANNER_HELPER_BRIDGE_TESTING)
- (instancetype)initForTestingWithPayloadRootURL:(NSURL *)payloadRootURL {
    self = [super init];
    if (self != nil) {
        _payloadRootURL = [payloadRootURL copy];
    }
    return self;
}
#endif

- (BOOL)verifyPayloadWithError:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    FCPCCPlannerHelperBridgeErrorCode code = FCPCCValidatePayloadAtRoot(self.payloadRootURL, NULL);
    if (code != FCPCCPlannerHelperBridgeErrorNone && error != NULL) {
        *error = FCPCCNSError(code);
    }
    return code == FCPCCPlannerHelperBridgeErrorNone;
}

- (FCPCCPlannerHelperInvocation *)invokeRequestData:(NSData *)requestData timeout:(NSTimeInterval)timeout completion:(FCPCCPlannerHelperCompletion)completion {
    if (completion == nil) {
        return nil;
    }
    if ([NSThread isMainThread]) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            completion([[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorMainThreadInvocationRejected responseData:nil]);
        });
        return nil;
    }
    if (![requestData isKindOfClass:[NSData class]]) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            completion([[FCPCCPlannerHelperBridgeResult alloc] initWithCode:FCPCCPlannerHelperBridgeErrorInputMalformed responseData:nil]);
        });
        return nil;
    }
    NSTimeInterval boundedTimeout = timeout;
    if (!isfinite(boundedTimeout) || boundedTimeout <= 0.0) boundedTimeout = FCPCCPlannerHelperDefaultTimeout;
    boundedTimeout = MIN(boundedTimeout, FCPCCPlannerHelperMaximumTimeout);
    FCPCCPlannerHelperInvocation *invocation = [[FCPCCPlannerHelperInvocation alloc] initWithRootURL:self.payloadRootURL requestData:requestData timeout:boundedTimeout completion:completion];
    [invocation start];
    return invocation;
}

@end
