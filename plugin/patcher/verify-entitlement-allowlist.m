// Product-owned entitlement-diff verifier.
//
// It compares the captured stock entitlement plist, a generated local signing
// plist, and the signed copied-app entitlement plist against the committed JSON
// allowlist. It never edits an entitlement file.

#import <Foundation/Foundation.h>

static void fail(NSString *message) {
    fprintf(stderr, "fcpcc-entitlement-verify: %s\n", message.UTF8String);
    exit(1);
}

static id propertyListAtPath(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:nil];
    if (data == nil) {
        fail([@"cannot read " stringByAppendingString:path]);
    }
    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];
    if (plist == nil || ![plist isKindOfClass:[NSDictionary class]]) {
        fail([@"invalid property list: " stringByAppendingString:error.localizedDescription ?: path]);
    }
    return plist;
}

static NSDictionary<NSString *, id> *jsonObjectAtPath(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:nil];
    if (data == nil) {
        fail([@"cannot read " stringByAppendingString:path]);
    }
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (json == nil || ![json isKindOfClass:[NSDictionary class]]) {
        fail([@"invalid JSON: " stringByAppendingString:error.localizedDescription ?: path]);
    }
    return json;
}

static NSSet<NSString *> *stringSet(NSDictionary<NSString *, id> *dictionary, NSString *key) {
    id object = dictionary[key];
    if (![object isKindOfClass:[NSArray class]]) {
        fail([@"allowlist key is not an array: " stringByAppendingString:key]);
    }
    NSMutableSet<NSString *> *result = [NSMutableSet set];
    for (id item in (NSArray *)object) {
        if (![item isKindOfClass:[NSString class]]) {
            fail([@"allowlist item is not a string: " stringByAppendingString:key]);
        }
        [result addObject:item];
    }
    return result;
}

static void requireEqual(id left, id right, NSString *message) {
    if ((left == nil) != (right == nil) || (left != nil && ![left isEqual:right])) {
        fail(message);
    }
}

int main(int argc, const char *argv[]) {
    if (argc != 5) {
        fprintf(stderr, "usage: fcpcc-entitlement-verify <stock.plist> <expected.plist> <signed-copy.plist> <allowlist.json>\n");
        return 64;
    }

    NSDictionary<NSString *, id> *stock = propertyListAtPath([NSString stringWithUTF8String:argv[1]]);
    NSDictionary<NSString *, id> *expected = propertyListAtPath([NSString stringWithUTF8String:argv[2]]);
    NSDictionary<NSString *, id> *signedCopy = propertyListAtPath([NSString stringWithUTF8String:argv[3]]);
    NSDictionary<NSString *, id> *allowlist = jsonObjectAtPath([NSString stringWithUTF8String:argv[4]]);
    NSSet<NSString *> *removed = stringSet(allowlist, @"removed");
    NSSet<NSString *> *added = stringSet(allowlist, @"added");
    NSSet<NSString *> *changed = stringSet(allowlist, @"changed");

    NSMutableSet<NSString *> *allKeys = [NSMutableSet setWithArray:stock.allKeys];
    [allKeys addObjectsFromArray:expected.allKeys];
    [allKeys addObjectsFromArray:signedCopy.allKeys];

    NSUInteger observedRemoved = 0;
    for (NSString *key in allKeys) {
        id stockValue = stock[key];
        id expectedValue = expected[key];
        id signedValue = signedCopy[key];
        if (stockValue != nil && expectedValue == nil) {
            if (![removed containsObject:key]) {
                fail([@"unallowed removed entitlement: " stringByAppendingString:key]);
            }
            observedRemoved += 1;
        } else if (stockValue == nil && expectedValue != nil) {
            if (![added containsObject:key]) {
                fail([@"unallowed added entitlement in expected plist: " stringByAppendingString:key]);
            }
        } else if (stockValue != nil && ![stockValue isEqual:expectedValue]) {
            if (![changed containsObject:key]) {
                fail([@"unallowed changed entitlement in expected plist: " stringByAppendingString:key]);
            }
        }
        requireEqual(expectedValue, signedValue, [@"signed copied-app entitlement does not exactly match expected plist: " stringByAppendingString:key]);
    }

    if (observedRemoved != removed.count) {
        fail(@"allowlisted removed entitlement set does not exactly match stock-to-expected diff");
    }
    if (added.count != 0 || changed.count != 0) {
        fail(@"this offline build permits no entitlement additions or changes");
    }
    NSDictionary<NSString *, id> *requiredUnchanged = allowlist[@"required_unchanged"];
    if (![requiredUnchanged isKindOfClass:[NSDictionary class]]) {
        fail(@"required_unchanged is not an object");
    }
    for (NSString *key in requiredUnchanged) {
        requireEqual(requiredUnchanged[key], signedCopy[key], [@"required entitlement does not match policy: " stringByAppendingString:key]);
    }
    NSArray<NSString *> *forbiddenAdded = allowlist[@"forbidden_added"];
    if (![forbiddenAdded isKindOfClass:[NSArray class]]) {
        fail(@"forbidden_added is not an array");
    }
    for (NSString *key in forbiddenAdded) {
        if (stock[key] == nil && signedCopy[key] != nil) {
            fail([@"forbidden added entitlement present: " stringByAppendingString:key]);
        }
    }

    printf("entitlement_allowlist=pass removed=%lu added=0 changed=0 sandbox=true\n", (unsigned long)observedRemoved);
    return 0;
}
