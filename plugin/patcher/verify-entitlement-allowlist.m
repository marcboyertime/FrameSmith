// Product-owned entitlement-diff verifier.
//
// The normal mode accepts only the five-key local-signing policy committed in
// patch-entitlement-allowlist.json.  The explicitly named legacy mode exists
// solely to identify a v1 sandboxed copy as a migration input; it is never a
// valid final-policy verification result.

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
        fail([@"policy key is not an array: " stringByAppendingString:key]);
    }
    NSMutableSet<NSString *> *result = [NSMutableSet set];
    for (id item in (NSArray *)object) {
        if (![item isKindOfClass:[NSString class]] || [(NSString *)item length] == 0) {
            fail([@"policy array item is not a nonempty string: " stringByAppendingString:key]);
        }
        if ([result containsObject:item]) {
            fail([@"duplicate policy item: " stringByAppendingString:item]);
        }
        [result addObject:item];
    }
    return result;
}

static NSDictionary<NSString *, id> *objectDictionary(NSDictionary<NSString *, id> *dictionary, NSString *key) {
    id object = dictionary[key];
    if (![object isKindOfClass:[NSDictionary class]]) {
        fail([@"policy key is not an object: " stringByAppendingString:key]);
    }
    for (id objectKey in ((NSDictionary *)object).allKeys) {
        if (![objectKey isKindOfClass:[NSString class]] || [(NSString *)objectKey length] == 0) {
            fail([@"policy object key is not a nonempty string: " stringByAppendingString:key]);
        }
    }
    return object;
}

static NSSet<NSString *> *setOf(NSArray<NSString *> *items) {
    return [NSSet setWithArray:items];
}

static void requireEqual(id left, id right, NSString *message) {
    if ((left == nil) != (right == nil) || (left != nil && ![left isEqual:right])) {
        fail(message);
    }
}

static void requireSetEqual(NSSet<NSString *> *actual, NSSet<NSString *> *expected, NSString *message) {
    if (![actual isEqualToSet:expected]) {
        fail(message);
    }
}

static void requireBoolean(id value, BOOL expected, NSString *message) {
    if (![value isKindOfClass:[NSNumber class]] || CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID() || [value boolValue] != expected) {
        fail(message);
    }
}

static NSSet<NSString *> *dictionaryKeySet(NSDictionary<NSString *, id> *dictionary) {
    return [NSSet setWithArray:dictionary.allKeys];
}

static NSSet<NSString *> *reviewedStockKeys(void) {
    return setOf(@[
        @"com.apple.application-identifier",
        @"com.apple.developer.aps-environment",
        @"com.apple.developer.icloud-container-environment",
        @"com.apple.developer.icloud-container-identifiers",
        @"com.apple.developer.icloud-services",
        @"com.apple.developer.team-identifier",
        @"com.apple.security.app-sandbox",
        @"com.apple.security.application-groups",
        @"com.apple.security.assets.movies.read-write",
        @"com.apple.security.assets.music.read-only",
        @"com.apple.security.assets.pictures.read-only",
        @"com.apple.security.automation.apple-events",
        @"com.apple.security.device.audio-input",
        @"com.apple.security.device.camera",
        @"com.apple.security.device.microphone",
        @"com.apple.security.device.usb",
        @"com.apple.security.files.bookmarks.app-scope",
        @"com.apple.security.files.bookmarks.document-scope",
        @"com.apple.security.files.user-selected.read-write",
        @"com.apple.security.network.client",
        @"com.apple.security.network.server",
        @"com.apple.security.personal-information.photos-library",
        @"com.apple.security.scripting-targets",
        @"com.apple.security.temporary-exception.apple-events",
        @"com.apple.security.temporary-exception.audio-unit-host",
        @"com.apple.security.temporary-exception.files.absolute-path.read-write",
        @"com.apple.security.temporary-exception.mach-lookup.global-name",
        @"com.apple.security.temporary-exception.sbpl",
        @"com.apple.security.temporary-exception.shared-preference.read-write",
        @"keychain-access-groups"
    ]);
}

static NSSet<NSString *> *reviewedFinalKeys(void) {
    return setOf(@[
        @"com.apple.security.app-sandbox",
        @"com.apple.security.cs.disable-library-validation",
        @"com.apple.security.device.audio-input",
        @"com.apple.security.device.camera",
        @"com.apple.security.device.microphone"
    ]);
}

static NSSet<NSString *> *reviewedRemovedKeys(void) {
    NSMutableSet<NSString *> *removed = [reviewedStockKeys() mutableCopy];
    [removed minusSet:setOf(@[
        @"com.apple.security.app-sandbox",
        @"com.apple.security.device.audio-input",
        @"com.apple.security.device.camera",
        @"com.apple.security.device.microphone"
    ])];
    return removed;
}

static NSSet<NSString *> *legacyRemovedKeys(void) {
    return setOf(@[
        @"com.apple.application-identifier",
        @"com.apple.developer.aps-environment",
        @"com.apple.developer.icloud-container-environment",
        @"com.apple.developer.icloud-container-identifiers",
        @"com.apple.developer.icloud-services",
        @"com.apple.developer.team-identifier",
        @"com.apple.security.application-groups",
        @"com.apple.security.automation.apple-events",
        @"com.apple.security.scripting-targets",
        @"com.apple.security.temporary-exception.apple-events",
        @"keychain-access-groups"
    ]);
}

static void requireReviewedStock(NSDictionary<NSString *, id> *stock) {
    requireSetEqual(dictionaryKeySet(stock), reviewedStockKeys(), @"stock entitlement keys drift from the reviewed Final Cut Pro 12.3 contract");
    requireBoolean(stock[@"com.apple.security.app-sandbox"], YES, @"reviewed stock app-sandbox value is not true");
    requireBoolean(stock[@"com.apple.security.device.audio-input"], YES, @"reviewed stock audio-input value is not true");
    requireBoolean(stock[@"com.apple.security.device.camera"], YES, @"reviewed stock camera value is not true");
    requireBoolean(stock[@"com.apple.security.device.microphone"], YES, @"reviewed stock microphone value is not true");
}

static void requireCanonicalPolicy(NSDictionary<NSString *, id> *allowlist) {
    requireEqual(allowlist[@"schema_version"], @2, @"canonical policy schema_version must be 2");
    NSDictionary<NSString *, id> *canonical = objectDictionary(allowlist, @"canonical_final_values");
    requireSetEqual(dictionaryKeySet(canonical), reviewedFinalKeys(), @"canonical final entitlement key set is not exactly five keys");
    requireBoolean(canonical[@"com.apple.security.app-sandbox"], NO, @"canonical app-sandbox value must be false");
    requireBoolean(canonical[@"com.apple.security.cs.disable-library-validation"], YES, @"canonical disable-library-validation value must be true");
    requireBoolean(canonical[@"com.apple.security.device.audio-input"], YES, @"canonical audio-input value must be true");
    requireBoolean(canonical[@"com.apple.security.device.camera"], YES, @"canonical camera value must be true");
    requireBoolean(canonical[@"com.apple.security.device.microphone"], YES, @"canonical microphone value must be true");

    requireSetEqual(stringSet(allowlist, @"removed"), reviewedRemovedKeys(), @"canonical removed entitlement set is not the exact reviewed stock-to-copy diff");
    requireSetEqual(stringSet(allowlist, @"added"), setOf(@[@"com.apple.security.cs.disable-library-validation"]), @"canonical added entitlement set is not exact");
    requireSetEqual(stringSet(allowlist, @"changed"), setOf(@[@"com.apple.security.app-sandbox"]), @"canonical changed entitlement set is not exact");

    NSDictionary<NSString *, id> *addedValues = objectDictionary(allowlist, @"required_added_values");
    requireSetEqual(dictionaryKeySet(addedValues), setOf(@[@"com.apple.security.cs.disable-library-validation"]), @"canonical added value map is not exact");
    requireBoolean(addedValues[@"com.apple.security.cs.disable-library-validation"], YES, @"canonical added entitlement value must be true");

    NSDictionary<NSString *, id> *changedValues = objectDictionary(allowlist, @"required_changed_values");
    requireSetEqual(dictionaryKeySet(changedValues), setOf(@[@"com.apple.security.app-sandbox"]), @"canonical changed value map is not exact");
    NSDictionary<NSString *, id> *sandboxChange = objectDictionary(changedValues, @"com.apple.security.app-sandbox");
    requireSetEqual(dictionaryKeySet(sandboxChange), setOf(@[@"from", @"to"]), @"canonical sandbox change map is not exact");
    requireBoolean(sandboxChange[@"from"], YES, @"canonical app-sandbox source value must be true");
    requireBoolean(sandboxChange[@"to"], NO, @"canonical app-sandbox destination value must be false");

    NSDictionary<NSString *, id> *unchanged = objectDictionary(allowlist, @"required_unchanged");
    requireSetEqual(dictionaryKeySet(unchanged), setOf(@[
        @"com.apple.security.device.audio-input",
        @"com.apple.security.device.camera",
        @"com.apple.security.device.microphone"
    ]), @"canonical unchanged entitlement set is not exact");
    for (NSString *key in unchanged) {
        requireBoolean(unchanged[key], YES, [@"canonical unchanged entitlement value must be true: " stringByAppendingString:key]);
    }
}

static void requireExactFinal(NSDictionary<NSString *, id> *entitlements, NSString *label) {
    requireSetEqual(dictionaryKeySet(entitlements), reviewedFinalKeys(), [label stringByAppendingString:@" has entitlement keys outside the canonical five-key policy"]);
    requireBoolean(entitlements[@"com.apple.security.app-sandbox"], NO, [label stringByAppendingString:@" does not set app-sandbox=false"]);
    requireBoolean(entitlements[@"com.apple.security.cs.disable-library-validation"], YES, [label stringByAppendingString:@" does not set disable-library-validation=true"]);
    requireBoolean(entitlements[@"com.apple.security.device.audio-input"], YES, [label stringByAppendingString:@" does not retain audio-input=true"]);
    requireBoolean(entitlements[@"com.apple.security.device.camera"], YES, [label stringByAppendingString:@" does not retain camera=true"]);
    requireBoolean(entitlements[@"com.apple.security.device.microphone"], YES, [label stringByAppendingString:@" does not retain microphone=true"]);
}

static void verifyCanonical(NSDictionary<NSString *, id> *stock, NSDictionary<NSString *, id> *expected, NSDictionary<NSString *, id> *signedCopy, NSDictionary<NSString *, id> *allowlist) {
    requireCanonicalPolicy(allowlist);
    requireReviewedStock(stock);
    requireExactFinal(expected, @"expected local signing plist");
    requireExactFinal(signedCopy, @"signed copied-app plist");
    requireEqual(expected, signedCopy, @"signed copied-app entitlement plist does not exactly match the canonical local signing plist");

    NSSet<NSString *> *removed = stringSet(allowlist, @"removed");
    NSSet<NSString *> *added = stringSet(allowlist, @"added");
    NSSet<NSString *> *changed = stringSet(allowlist, @"changed");
    NSMutableSet<NSString *> *observedRemoved = [NSMutableSet set];
    NSMutableSet<NSString *> *observedAdded = [NSMutableSet set];
    NSMutableSet<NSString *> *observedChanged = [NSMutableSet set];
    NSMutableSet<NSString *> *allKeys = [NSMutableSet setWithSet:dictionaryKeySet(stock)];
    [allKeys unionSet:dictionaryKeySet(expected)];
    for (NSString *key in allKeys) {
        id stockValue = stock[key];
        id expectedValue = expected[key];
        if (stockValue != nil && expectedValue == nil) {
            [observedRemoved addObject:key];
        } else if (stockValue == nil && expectedValue != nil) {
            [observedAdded addObject:key];
        } else if (stockValue != nil && ![stockValue isEqual:expectedValue]) {
            [observedChanged addObject:key];
        }
    }
    requireSetEqual(observedRemoved, removed, @"stock-to-copy removed entitlement diff is not exact");
    requireSetEqual(observedAdded, added, @"stock-to-copy added entitlement diff is not exact");
    requireSetEqual(observedChanged, changed, @"stock-to-copy changed entitlement diff is not exact");

    for (NSString *key in stringSet(allowlist, @"forbidden_final_keys")) {
        if (signedCopy[key] != nil) {
            fail([@"forbidden final entitlement present: " stringByAppendingString:key]);
        }
    }
    printf("entitlement_allowlist=pass removed=26 added=1 changed=1 app-sandbox=true->false disable-library-validation=added device-entitlements=unchanged\n");
}

static void verifyLegacyMigrationInput(NSDictionary<NSString *, id> *stock, NSDictionary<NSString *, id> *signedCopy, NSDictionary<NSString *, id> *allowlist) {
    requireReviewedStock(stock);
    id legacyObject = allowlist[@"legacy_sandboxed_copy_migration_input"];
    if (![legacyObject isKindOfClass:[NSDictionary class]]) {
        fail(@"legacy migration policy object is missing");
    }
    NSDictionary<NSString *, id> *legacy = (NSDictionary<NSString *, id> *)legacyObject;
    requireEqual(legacy[@"schema_version"], @1, @"legacy migration policy schema_version must be 1");
    requireEqual(legacy[@"allowlist_sha256"], @"4c368a47bad91519fb6ed6c9a4683648d4e95b60a3a16f7de8cc327db5011252", @"legacy migration policy hash is not reviewed");
    requireSetEqual(stringSet(legacy, @"removed"), legacyRemovedKeys(), @"legacy migration removed entitlement set is not exact");
    requireSetEqual(stringSet(legacy, @"added"), setOf(@[@"com.apple.security.cs.disable-library-validation"]), @"legacy migration added entitlement set is not exact");
    requireSetEqual(stringSet(legacy, @"changed"), [NSSet set], @"legacy migration policy must not allow changed values");
    NSDictionary<NSString *, id> *addedValues = objectDictionary(legacy, @"required_added_values");
    requireSetEqual(dictionaryKeySet(addedValues), setOf(@[@"com.apple.security.cs.disable-library-validation"]), @"legacy migration added value map is not exact");
    requireBoolean(addedValues[@"com.apple.security.cs.disable-library-validation"], YES, @"legacy migration disable-library-validation must be true");
    NSDictionary<NSString *, id> *unchanged = objectDictionary(legacy, @"required_unchanged");
    requireSetEqual(dictionaryKeySet(unchanged), setOf(@[@"com.apple.security.app-sandbox"]), @"legacy migration unchanged entitlement set is not exact");
    requireBoolean(unchanged[@"com.apple.security.app-sandbox"], YES, @"legacy migration requires app-sandbox=true");

    NSMutableDictionary<NSString *, id> *expected = [stock mutableCopy];
    [expected removeObjectsForKeys:legacyRemovedKeys().allObjects];
    expected[@"com.apple.security.cs.disable-library-validation"] = @YES;
    requireEqual(expected, signedCopy, @"copied app is not the exact retired sandboxed entitlement policy");
    requireBoolean(signedCopy[@"com.apple.security.app-sandbox"], YES, @"legacy migration input must retain app-sandbox=true");
    printf("legacy_sandboxed_migration_input=pass removed=11 added=1 changed=0 app-sandbox=true\n");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 5 && strcmp(argv[1], "--verify-legacy-migration-input") == 0) {
            NSDictionary<NSString *, id> *stock = propertyListAtPath([NSString stringWithUTF8String:argv[2]]);
            NSDictionary<NSString *, id> *signedCopy = propertyListAtPath([NSString stringWithUTF8String:argv[3]]);
            NSDictionary<NSString *, id> *allowlist = jsonObjectAtPath([NSString stringWithUTF8String:argv[4]]);
            verifyLegacyMigrationInput(stock, signedCopy, allowlist);
            return 0;
        }
        if (argc != 5) {
            fprintf(stderr, "usage: fcpcc-entitlement-verify <stock.plist> <expected.plist> <signed-copy.plist> <allowlist.json>\n");
            fprintf(stderr, "   or: fcpcc-entitlement-verify --verify-legacy-migration-input <stock.plist> <signed-copy.plist> <allowlist.json>\n");
            return 64;
        }
        NSDictionary<NSString *, id> *stock = propertyListAtPath([NSString stringWithUTF8String:argv[1]]);
        NSDictionary<NSString *, id> *expected = propertyListAtPath([NSString stringWithUTF8String:argv[2]]);
        NSDictionary<NSString *, id> *signedCopy = propertyListAtPath([NSString stringWithUTF8String:argv[3]]);
        NSDictionary<NSString *, id> *allowlist = jsonObjectAtPath([NSString stringWithUTF8String:argv[4]]);
        verifyCanonical(stock, expected, signedCopy, allowlist);
    }
    return 0;
}
