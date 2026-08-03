// Product-owned bridge to the signed, local planner-helper payload.
//
// The bridge is deliberately a closed process boundary.  Callers provide only
// request bytes; the executable, bundle, manifest, environment, and working
// directory are all selected by this implementation from the product-owned
// payload root.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FCPCCPlannerHelperBridgeErrorCode) {
    FCPCCPlannerHelperBridgeErrorNone = 0,
    FCPCCPlannerHelperBridgeErrorMainThreadInvocationRejected,
    FCPCCPlannerHelperBridgeErrorInvalidPayloadRoot,
    FCPCCPlannerHelperBridgeErrorMissingPayloadEntry,
    FCPCCPlannerHelperBridgeErrorSymlinkRejected,
    FCPCCPlannerHelperBridgeErrorNonRegularExecutable,
    FCPCCPlannerHelperBridgeErrorNonDirectoryBundle,
    FCPCCPlannerHelperBridgeErrorManifestOversized,
    FCPCCPlannerHelperBridgeErrorManifestMalformed,
    FCPCCPlannerHelperBridgeErrorManifestIdentityMismatch,
    FCPCCPlannerHelperBridgeErrorExecutableArchitectureMismatch,
    FCPCCPlannerHelperBridgeErrorSignatureInvalid,
    FCPCCPlannerHelperBridgeErrorExecutableHashMismatch,
    FCPCCPlannerHelperBridgeErrorBundleHashMismatch,
    FCPCCPlannerHelperBridgeErrorResourceSetMismatch,
    FCPCCPlannerHelperBridgeErrorResourceHashMismatch,
    FCPCCPlannerHelperBridgeErrorPathEscape,
    FCPCCPlannerHelperBridgeErrorInputOversized,
    FCPCCPlannerHelperBridgeErrorInputMalformed,
    FCPCCPlannerHelperBridgeErrorProcessLaunchFailed,
    FCPCCPlannerHelperBridgeErrorProcessExitFailed,
    FCPCCPlannerHelperBridgeErrorOutputOversized,
    FCPCCPlannerHelperBridgeErrorOutputMalformed,
    FCPCCPlannerHelperBridgeErrorTimeout,
    FCPCCPlannerHelperBridgeErrorCancelled,
    FCPCCPlannerHelperBridgeErrorInternal,
};

FOUNDATION_EXPORT NSString * const FCPCCPlannerHelperBridgeErrorDomain;

@interface FCPCCPlannerHelperBridgeResult : NSObject

@property (nonatomic, readonly, getter=isSuccess) BOOL success;
@property (nonatomic, readonly) FCPCCPlannerHelperBridgeErrorCode errorCode;
@property (nonatomic, copy, readonly) NSString *errorMessage;
/// The helper's single JSON response line, without its trailing newline.
/// This is present for both helper-level success and helper-level typed error
/// envelopes.  It is nil when the bridge itself rejected the invocation.
@property (nonatomic, copy, readonly, nullable) NSData *responseData;

- (instancetype)init NS_UNAVAILABLE;

@end

/// A cancellable one-shot invocation.  Cancellation is fail-closed and can
/// terminate only the exact child process created for this invocation.
@interface FCPCCPlannerHelperInvocation : NSObject

- (void)cancel;

@end

typedef void (^FCPCCPlannerHelperCompletion)(FCPCCPlannerHelperBridgeResult *result);

@interface FCPCCPlannerHelperBridge : NSObject

/// Uses the product-owned payload at the fixed relative location
/// `Versions/A/Resources/PlannerHelperPayload` beneath the framework bundle
/// containing this class.  Callers cannot select an executable or payload
/// root.
- (instancetype)init NS_DESIGNATED_INITIALIZER;

#if defined(FCPCC_PLANNER_HELPER_BRIDGE_TESTING)
/// Testing-only fixture initializer.  This symbol is not present in the
/// production header or binary; it exists solely for isolated tamper tests.
- (instancetype)initForTestingWithPayloadRootURL:(NSURL *)payloadRootURL NS_DESIGNATED_INITIALIZER;
#endif

/// Performs the complete payload verification and invokes the exact helper on
/// a private non-main queue.  Calls made on the main thread are rejected and
/// return nil; their completion is delivered asynchronously off-main.
/// `timeout` is bounded to a finite positive interval by the implementation.
- (nullable FCPCCPlannerHelperInvocation *)invokeRequestData:(NSData *)requestData
                                                     timeout:(NSTimeInterval)timeout
                                                  completion:(FCPCCPlannerHelperCompletion)completion;

/// Synchronous verification helper for preflight tooling.  Invocation remains
/// asynchronous and rejects main-thread calls; this method does not launch a
/// process and never accepts a caller-supplied executable or path.
- (BOOL)verifyPayloadWithError:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
