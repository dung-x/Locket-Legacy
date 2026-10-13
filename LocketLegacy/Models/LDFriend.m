#import "LDFriend.h"
@implementation LDFriend
+ (instancetype)fromJSON:(NSDictionary *)json {
    LDFriend *f = [[LDFriend alloc] init];
    id v = json[@"uid"]; if (!v) v = json[@"localId"];
    f.uid = [v isKindOfClass:[NSString class]] ? v : @"";
    v = json[@"displayName"]; if (!v) v = json[@"name"];
    if (!v) {
        // Official shape: first_name / last_name / username.
        NSString *fn = [json[@"firstName"] isKindOfClass:[NSString class]] ? json[@"firstName"] : json[@"first_name"];
        if (![fn isKindOfClass:[NSString class]]) fn = @"";
        NSString *ln = [json[@"lastName"] isKindOfClass:[NSString class]] ? json[@"lastName"] : json[@"last_name"];
        if (![ln isKindOfClass:[NSString class]]) ln = @"";
        NSString *full = [[NSString stringWithFormat:@"%@ %@", fn, ln] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        v = full.length ? full : json[@"username"];
    }
    f.displayName = [v isKindOfClass:[NSString class]] ? v : @"";
    v = json[@"profilePicture"]; if (!v) v = json[@"avatar"];
    if (!v) v = json[@"profile_picture_url"];
    f.profilePicture = [v isKindOfClass:[NSString class]] ? v : @"";
    return f;
}
+ (NSArray<LDFriend *> *)listFromJSON:(id)json {
    NSArray *arr = nil;
    if ([json isKindOfClass:[NSArray class]]) arr = json;
    else if ([json isKindOfClass:[NSDictionary class]]) {
        id d = json[@"data"];
        if ([d isKindOfClass:[NSArray class]]) arr = d;
        else if ([d isKindOfClass:[NSDictionary class]] && [d[@"friends"] isKindOfClass:[NSArray class]]) arr = d[@"friends"];
    }
    NSMutableArray *out = [NSMutableArray array];
    for (id o in arr ?: @[]) { if ([o isKindOfClass:[NSDictionary class]]) [out addObject:[self fromJSON:o]]; }
    return out;
}
@end
