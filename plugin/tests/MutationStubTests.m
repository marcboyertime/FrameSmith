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
