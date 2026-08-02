// FCPCommandConsole minimal runtime.
//
// The only factual candidate strings below were manually transcribed from the
// locked SpliceKit symbol snapshot at f4f6618121309a69b66272b441f34cf8ad57f306.
// They are constants only: this framework does not turn input into selectors
// and does not invoke those candidates.

#import "FCPCommandConsoleRuntime.h"

NSString * const FCPCCMutationErrorUnsupportedUnverifiedFCP123 = @"unsupported_unverified_fcp_12_3";

static NSString * const FCPCCExpectedHostBundleIdentifier = @"com.local.fcpcommandconsole.FinalCut";
static NSString * const FCPCCExpectedHostVersion = @"12.3";
static NSString * const FCPCCExpectedHostBuild = @"450152";
static NSString * const FCPCCExpectedRuntimeFrameworkName = @"FCPCommandConsoleRuntime.framework";

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
    FCPCCGateStatus *library = [[[FCPCCLibraryInvariantGate alloc] init] evaluate];
    FCPCCCapabilityStatus *capabilities = FCPCCCapabilityStatus.unverifiedPlaceholder;
    self.containmentField = [self label:[@"Copied app/runtime: " stringByAppendingString:containment.summary] frame:NSMakeRect(20, 462, width - 40, 30) weight:NSFontWeightRegular];
    self.libraryField = [self label:[@"Library invariant: " stringByAppendingString:library.summary] frame:NSMakeRect(20, 426, width - 40, 30) weight:NSFontWeightRegular];
    self.capabilityField = [self label:[capabilities.selectionSummary stringByAppendingFormat:@"\n%@", capabilities.capabilitySummary] frame:NSMakeRect(20, 382, width - 40, 38) weight:NSFontWeightRegular];
    [content addSubview:self.containmentField];
    [content addSubview:self.libraryField];
    [content addSubview:self.capabilityField];

    [content addSubview:[self label:@"Command" frame:NSMakeRect(20, 344, 100, 18) weight:NSFontWeightMedium]];
    NSTextField *commandField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 315, width - 40, 24)];
    commandField.placeholderString = @"Describe a future command; no execution is available in this build.";
    [content addSubview:commandField];

    [content addSubview:[self label:@"Plan / editability" frame:NSMakeRect(20, 286, 160, 18) weight:NSFontWeightMedium]];
    NSTextField *planField = [self label:@"No edit plan is available. The live capability and exactly-one-library gates remain unverified." frame:NSMakeRect(20, 252, width - 40, 30) weight:NSFontWeightRegular];
    [content addSubview:planField];

    [content addSubview:[self label:@"Target point: unavailable" frame:NSMakeRect(20, 220, width - 40, 18) weight:NSFontWeightMedium]];
    [content addSubview:[self label:@"Preview: unavailable until a separately reviewed live spike." frame:NSMakeRect(20, 194, width - 40, 18) weight:NSFontWeightRegular]];

    self.historyField = [self label:@"History / error: unsupported_unverified_fcp_12_3" frame:NSMakeRect(20, 142, width - 40, 38) weight:NSFontWeightRegular];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FCPCCRuntime sharedRuntime] installMenuWhenReady];
    });
}
