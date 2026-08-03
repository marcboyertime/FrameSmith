#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <limits.h>
#import <unistd.h>

#import "FCPCCPlannerHelperBridge.h"

static int FCPCCRequire(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "PlannerHelperBridgeTests: %s\n", message.UTF8String);
        return 1;
    }
    return 0;
}

static NSData *FCPCCValidRequest(BOOL injectUnknownField) {
    NSString *request = @"{\"schema_version\":\"1.0\",\"operation_id\":\"00000000-0000-0000-0000-000000000701\",\"request\":{\"original_text\":\"Make this look like old black-and-white television footage with static, grain, scanlines, and subtle image instability.\"},\"selection\":{\"token_id\":\"bridge-token\",\"selection_type\":\"single-clip\",\"timeline_id\":\"bridge-timeline\",\"clip_ids\":[\"bridge-clip\"],\"source_identities\":[{\"item_id\":\"bridge-clip\",\"canonical_path\":\"/tmp/fcpcc-bridge-source\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000000\"}],\"revision\":\"bridge-revision\",\"start_frame\":0,\"end_frame\":24,\"source_duration_frames\":240,\"handle_before_frames\":0,\"handle_after_frames\":0,\"is_spine\":true,\"adjacent\":true},\"target\":null}";
    if (injectUnknownField) {
        request = [[request stringByReplacingOccurrencesOfString:@"\"target\":null}" withString:@"\"target\":null,\"injected_key\":\"must-fail\"}"] copy];
    }
    return [request dataUsingEncoding:NSUTF8StringEncoding];
}

static FCPCCPlannerHelperBridgeResult *FCPCCInvokeOffMain(FCPCCPlannerHelperBridge *bridge,
                                                            NSData *request,
                                                            NSTimeInterval timeout,
                                                            FCPCCPlannerHelperInvocation **invocationOut) {
    dispatch_semaphore_t started = dispatch_semaphore_create(0);
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    __block FCPCCPlannerHelperInvocation *invocation = nil;
    __block FCPCCPlannerHelperBridgeResult *result = nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        invocation = [bridge invokeRequestData:request timeout:timeout completion:^(FCPCCPlannerHelperBridgeResult *completionResult) {
            result = completionResult;
            dispatch_semaphore_signal(finished);
        }];
        dispatch_semaphore_signal(started);
    });
    dispatch_semaphore_wait(started, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    if (invocationOut != NULL) {
        *invocationOut = invocation;
    }
    dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
    return result;
}

static NSDictionary *FCPCCResponseObject(FCPCCPlannerHelperBridgeResult *result) {
    if (result == nil || !result.success || result.responseData == nil) return nil;
    return [NSJSONSerialization JSONObjectWithData:result.responseData options:0 error:nil];
}

static NSString *FCPCCTemporaryRoot(void) {
    NSString *template = [NSTemporaryDirectory() stringByAppendingPathComponent:@"fcpcc-planner-bridge-tests.XXXXXX"];
    char path[PATH_MAX];
    strlcpy(path, template.fileSystemRepresentation, sizeof(path));
    return mkdtemp(path) == NULL ? nil : [NSString stringWithUTF8String:path];
}

static BOOL FCPCCCopyPayload(NSString *sourceRoot, NSString **destinationOut) {
    NSString *destination = FCPCCTemporaryRoot();
    if (destination == nil) return NO;
    NSError *error = nil;
    BOOL copied = [[NSFileManager defaultManager] copyItemAtPath:sourceRoot toPath:[destination stringByAppendingPathComponent:@"payload"] error:&error];
    if (!copied) return NO;
    if (destinationOut != NULL) *destinationOut = [destination stringByAppendingPathComponent:@"payload"];
    return YES;
}

static void FCPCCRemoveTemporaryParent(NSString *payloadRoot) {
    NSString *parent = [payloadRoot stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] removeItemAtPath:parent error:nil];
}

int main(void) {
    @autoreleasepool {
        NSString *payloadRoot = [[[NSProcessInfo processInfo] arguments] count] > 1 ? [[[NSProcessInfo processInfo] arguments] objectAtIndex:1] : nil;
        if (FCPCCRequire(payloadRoot.length > 0, @"payload root argument is required")) return 1;
        FCPCCPlannerHelperBridge *bridge = [[FCPCCPlannerHelperBridge alloc] initForTestingWithPayloadRootURL:[NSURL fileURLWithPath:payloadRoot isDirectory:YES]];
        NSError *verificationError = nil;
        if (FCPCCRequire([bridge verifyPayloadWithError:&verificationError], @"valid payload did not pass bridge verification")) return 1;

        __block FCPCCPlannerHelperBridgeResult *mainResult = nil;
        dispatch_semaphore_t mainFinished = dispatch_semaphore_create(0);
        FCPCCPlannerHelperInvocation *mainInvocation = [bridge invokeRequestData:FCPCCValidRequest(NO) timeout:5.0 completion:^(FCPCCPlannerHelperBridgeResult *result) {
            mainResult = result;
            dispatch_semaphore_signal(mainFinished);
        }];
        if (FCPCCRequire(mainInvocation == nil, @"main-thread invocation was not rejected")) return 1;
        dispatch_semaphore_wait(mainFinished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        if (FCPCCRequire(mainResult.errorCode == FCPCCPlannerHelperBridgeErrorMainThreadInvocationRejected, @"main-thread rejection code was not deterministic")) return 1;

        FCPCCPlannerHelperInvocation *smokeInvocation = nil;
        FCPCCPlannerHelperBridgeResult *smoke = FCPCCInvokeOffMain(bridge, FCPCCValidRequest(NO), 5.0, &smokeInvocation);
        NSDictionary *smokeObject = FCPCCResponseObject(smoke);
        if (FCPCCRequire(smoke.success && [smokeObject[@"schema_version"] isEqual:@"1.0"] && [smokeObject[@"status"] isEqual:@"ok"] && [smokeObject[@"plan"] isKindOfClass:[NSDictionary class]], @"valid smoke invocation did not return a typed plan")) return 1;

        FCPCCPlannerHelperBridgeResult *unknown = FCPCCInvokeOffMain(bridge, FCPCCValidRequest(YES), 5.0, NULL);
        NSDictionary *unknownObject = FCPCCResponseObject(unknown);
        if (FCPCCRequire(unknown.success && [unknownObject[@"status"] isEqual:@"error"] && [unknownObject[@"error"][@"code"] isEqual:@"unknown_field"] && (unknownObject[@"plan"] == nil || unknownObject[@"plan"] == [NSNull null]), @"unknown-key request did not fail closed")) return 1;

        NSString *tamperedRoot = nil;
        if (FCPCCRequire(FCPCCCopyPayload(payloadRoot, &tamperedRoot), @"could not create executable tamper fixture")) return 1;
        NSString *tamperedExecutable = [tamperedRoot stringByAppendingPathComponent:@"fcpcommandconsole-planner-helper"];
        NSMutableData *tamperedData = [NSMutableData dataWithContentsOfFile:tamperedExecutable];
        ((uint8_t *)tamperedData.mutableBytes)[tamperedData.length - 1] ^= 0x01;
        [tamperedData writeToFile:tamperedExecutable atomically:YES];
        FCPCCPlannerHelperBridgeResult *tampered = FCPCCInvokeOffMain([[FCPCCPlannerHelperBridge alloc] initForTestingWithPayloadRootURL:[NSURL fileURLWithPath:tamperedRoot isDirectory:YES]], FCPCCValidRequest(NO), 5.0, NULL);
        if (FCPCCRequire(tampered.errorCode == FCPCCPlannerHelperBridgeErrorExecutableHashMismatch || tampered.errorCode == FCPCCPlannerHelperBridgeErrorSignatureInvalid, @"helper tamper was not rejected")) return 1;
        FCPCCRemoveTemporaryParent(tamperedRoot);

        NSString *manifestRoot = nil;
        if (FCPCCRequire(FCPCCCopyPayload(payloadRoot, &manifestRoot), @"could not create manifest tamper fixture")) return 1;
        NSString *manifestPath = [manifestRoot stringByAppendingPathComponent:@"planner-helper-manifest.json"];
        NSString *manifestText = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:manifestPath] encoding:NSUTF8StringEncoding];
        manifestText = [manifestText stringByReplacingOccurrencesOfString:@"\"product\": \"fcpcommandconsole-planner-helper\"" withString:@"\"product\": \"tampered-helper\""];
        [[manifestText dataUsingEncoding:NSUTF8StringEncoding] writeToFile:manifestPath atomically:YES];
        FCPCCPlannerHelperBridgeResult *manifestTamper = FCPCCInvokeOffMain([[FCPCCPlannerHelperBridge alloc] initForTestingWithPayloadRootURL:[NSURL fileURLWithPath:manifestRoot isDirectory:YES]], FCPCCValidRequest(NO), 5.0, NULL);
        if (FCPCCRequire(manifestTamper.errorCode == FCPCCPlannerHelperBridgeErrorManifestIdentityMismatch || manifestTamper.errorCode == FCPCCPlannerHelperBridgeErrorManifestMalformed, @"manifest tamper was not rejected")) return 1;
        FCPCCRemoveTemporaryParent(manifestRoot);

        NSString *symlinkRoot = nil;
        if (FCPCCRequire(FCPCCCopyPayload(payloadRoot, &symlinkRoot), @"could not create symlink fixture")) return 1;
        NSString *symlinkExecutable = [symlinkRoot stringByAppendingPathComponent:@"fcpcommandconsole-planner-helper"];
        [[NSFileManager defaultManager] removeItemAtPath:symlinkExecutable error:nil];
        [[NSFileManager defaultManager] createSymbolicLinkAtPath:symlinkExecutable withDestinationPath:[payloadRoot stringByAppendingPathComponent:@"fcpcommandconsole-planner-helper"] error:nil];
        FCPCCPlannerHelperBridgeResult *symlink = FCPCCInvokeOffMain([[FCPCCPlannerHelperBridge alloc] initForTestingWithPayloadRootURL:[NSURL fileURLWithPath:symlinkRoot isDirectory:YES]], FCPCCValidRequest(NO), 5.0, NULL);
        if (FCPCCRequire(symlink.errorCode == FCPCCPlannerHelperBridgeErrorSymlinkRejected || symlink.errorCode == FCPCCPlannerHelperBridgeErrorPathEscape || symlink.errorCode == FCPCCPlannerHelperBridgeErrorMissingPayloadEntry, @"symlink fixture was not rejected")) return 1;
        FCPCCRemoveTemporaryParent(symlinkRoot);

        NSData *oversized = [NSMutableData dataWithLength:256 * 1024 + 1];
        FCPCCPlannerHelperBridgeResult *oversizedResult = FCPCCInvokeOffMain(bridge, oversized, 5.0, NULL);
        if (FCPCCRequire(oversizedResult.errorCode == FCPCCPlannerHelperBridgeErrorInputOversized, @"oversized request was not rejected before launch")) return 1;

        NSData *malformedRequest = [@"{\"schema_version\":" dataUsingEncoding:NSUTF8StringEncoding];
        FCPCCPlannerHelperBridgeResult *malformedResult = FCPCCInvokeOffMain(bridge, malformedRequest, 5.0, NULL);
        if (FCPCCRequire(malformedResult.errorCode == FCPCCPlannerHelperBridgeErrorInputMalformed, @"malformed JSON request was not rejected before launch")) return 1;

        NSString *resourceRoot = nil;
        if (FCPCCRequire(FCPCCCopyPayload(payloadRoot, &resourceRoot), @"could not create resource tamper fixture")) return 1;
        NSString *resourcePath = [resourceRoot stringByAppendingPathComponent:@"FCPCommandConsole_FCPCommandConsolePlannerHelper.bundle/Resources/registry/effects/look.old_television.json"];
        NSMutableData *resourceData = [NSMutableData dataWithContentsOfFile:resourcePath];
        ((uint8_t *)resourceData.mutableBytes)[resourceData.length - 1] ^= 0x01;
        [resourceData writeToFile:resourcePath atomically:YES];
        FCPCCPlannerHelperBridgeResult *resourceTamper = FCPCCInvokeOffMain([[FCPCCPlannerHelperBridge alloc] initForTestingWithPayloadRootURL:[NSURL fileURLWithPath:resourceRoot isDirectory:YES]], FCPCCValidRequest(NO), 5.0, NULL);
        if (FCPCCRequire(resourceTamper.errorCode == FCPCCPlannerHelperBridgeErrorResourceHashMismatch, @"immutable resource tamper was not rejected")) return 1;
        FCPCCRemoveTemporaryParent(resourceRoot);

        FCPCCPlannerHelperBridgeResult *timeout = FCPCCInvokeOffMain(bridge, FCPCCValidRequest(NO), 0.0001, NULL);
        if (FCPCCRequire(timeout.errorCode == FCPCCPlannerHelperBridgeErrorTimeout || timeout.errorCode == FCPCCPlannerHelperBridgeErrorCancelled || timeout.success, @"bounded timeout fixture did not complete deterministically")) return 1;

        __block FCPCCPlannerHelperInvocation *cancelInvocation = nil;
        dispatch_semaphore_t cancelTokenReady = dispatch_semaphore_create(0);
        dispatch_semaphore_t cancelStarted = dispatch_semaphore_create(0);
        __block FCPCCPlannerHelperBridgeResult *cancelResult = nil;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            cancelInvocation = [bridge invokeRequestData:FCPCCValidRequest(NO) timeout:5.0 completion:^(FCPCCPlannerHelperBridgeResult *result) {
                cancelResult = result;
                dispatch_semaphore_signal(cancelStarted);
            }];
            dispatch_semaphore_signal(cancelTokenReady);
        });
        dispatch_semaphore_wait(cancelTokenReady, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        [cancelInvocation cancel];
        dispatch_semaphore_wait(cancelStarted, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
        if (FCPCCRequire(cancelResult.errorCode == FCPCCPlannerHelperBridgeErrorCancelled || cancelResult.errorCode == FCPCCPlannerHelperBridgeErrorTimeout, @"cancellation did not terminate the exact invocation")) return 1;

        printf("planner-helper-bridge-tests: passed\n");
        return 0;
    }
}
