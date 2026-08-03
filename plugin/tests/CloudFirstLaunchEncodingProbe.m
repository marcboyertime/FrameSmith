// Offline regression probe for the exact Cloud first-launch method encoding.
// It creates no Final Cut objects and does not load a Final Cut framework.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <stdio.h>
#include <string.h>

static void FCPCCCloudFirstLaunchEncodingProbeImplementation(id self __attribute__((unused)),
                                                              SEL command __attribute__((unused)),
                                                              id completion __attribute__((unused))) {
}

int main(void) {
    @autoreleasepool {
        const char *expectedEncoding = "v24@0:8@?<v@?@\"NSError\">16";
        Class probeClass = objc_allocateClassPair([NSObject class], "FCPCCCloudFirstLaunchEncodingProbe", 0);
        if (probeClass == Nil) {
            return 2;
        }
        SEL selector = sel_registerName("setupAndPresentFirstLaunchIfNeededWithCompletionHandler:");
        if (selector == NULL
            || !class_addMethod(probeClass,
                                selector,
                                (IMP)FCPCCCloudFirstLaunchEncodingProbeImplementation,
                                expectedEncoding)) {
            return 3;
        }
        objc_registerClassPair(probeClass);

        Method method = class_getInstanceMethod(probeClass, selector);
        const char *observedEncoding = method == NULL ? NULL : method_getTypeEncoding(method);
        unsigned int parsedArgumentCount = method == NULL ? 0 : method_getNumberOfArguments(method);
        if (observedEncoding == NULL || strcmp(observedEncoding, expectedEncoding) != 0) {
            return 4;
        }
        // The supported runtime expands the nested block signature when it
        // parses this string. This demonstrates why Cloud must use the exact
        // encoding rather than a method_getNumberOfArguments == 3 gate.
        if (parsedArgumentCount != 12) {
            return 5;
        }
        printf("encoding=%s\n", observedEncoding);
        printf("method_get_number_of_arguments=%u\n", parsedArgumentCount);
    }
    return 0;
}
