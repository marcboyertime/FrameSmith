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
        if ([result containsObject:item]) {
            fail([@"duplicate allowlist item: " stringByAppendingString:item]);
        }
        [result addObject:item];
    }
    return result;
}

static NSDictionary<NSString *, id> *objectDictionary(NSDictionary<NSString *, id> *dictionary, NSString *key) {
    id object = dictionary[key];
    if (![object isKindOfClass:[NSDictionary class]]) {
        fail([@"allowlist key is not an object: " stringByAppendingString:key]);
    }
    for (id objectKey in ((NSDictionary *)object).allKeys) {
        if (![objectKey isKindOfClass:[NSString class]]) {
            fail([@"allowlist object key is not a string: " stringByAppendingString:key]);
        }
    }
    return object;
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
    NSDictionary<NSString *, id> *requiredAddedValues = objectDictionary(allowlist, @"required_added_values");
    NSString *requiredAddedKey = @"com.apple.security.cs.disable-library-validation";

    if (added.count != 1 || ![added containsObject:requiredAddedKey]) {
        fail(@"allowlist must permit exactly com.apple.security.cs.disable-library-validation as its only added entitlement");
    }
    if (requiredAddedValues.count != 1 || requiredAddedValues[requiredAddedKey] == nil || ![requiredAddedValues[requiredAddedKey] isEqual:@YES]) {
        fail(@"allowlist must require com.apple.security.cs.disable-library-validation=true");
    }
    if (![[NSSet setWithArray:requiredAddedValues.allKeys] isEqualToSet:added]) {
        fail(@"allowlist added entitlement keys and required values do not exactly agree");
    }
    if (changed.count != 0) {
        fail(@"this offline build permits no changed entitlement values");
    }

    NSMutableSet<NSString *> *allKeys = [NSMutableSet setWithArray:stock.allKeys];
    [allKeys addObjectsFromArray:expected.allKeys];
    [allKeys addObjectsFromArray:signedCopy.allKeys];

    NSUInteger observedRemoved = 0;
    NSUInteger observedAdded = 0;
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
            requireEqual(requiredAddedValues[key], expectedValue, [@"added entitlement value does not match policy: " stringByAppendingString:key]);
            observedAdded += 1;
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
    if (observedAdded != added.count) {
        fail(@"allowlisted added entitlement set does not exactly match stock-to-expected diff");
    }
    for (NSString *key in added) {
        if (stock[key] != nil) {
            fail([@"required added entitlement unexpectedly exists in stock policy: " stringByAppendingString:key]);
        }
    }
    NSDictionary<NSString *, id> *requiredUnchanged = objectDictionary(allowlist, @"required_unchanged");
    for (NSString *key in requiredUnchanged) {
        requireEqual(requiredUnchanged[key], signedCopy[key], [@"required entitlement does not match policy: " stringByAppendingString:key]);
    }
    NSSet<NSString *> *forbiddenAdded = stringSet(allowlist, @"forbidden_added");
    for (NSString *key in forbiddenAdded) {
        if (stock[key] == nil && signedCopy[key] != nil) {
            fail([@"forbidden added entitlement present: " stringByAppendingString:key]);
        }
    }

    printf("entitlement_allowlist=pass removed=%lu added=%lu changed=0 sandbox=true\n", (unsigned long)observedRemoved, (unsigned long)observedAdded);
    return 0;
}
