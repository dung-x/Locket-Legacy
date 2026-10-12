#import "LDFriend.h"
@implementation LDFriend
+ (instancetype)fromJSON:(NSDictionary *)json {
    LDFriend *f = [[LDFriend alloc] init];
    id v = json[@"uid"]; if (!v) v = json[@"localId"];
    f.uid = [v isKindOfClass:[NSString class]] ? v : @"";
    v = json[@"displayName"]; if (!v) v = json[@"name"];
    f.displayName = [v isKindOfClass:[NSString class]] ? v : @"";
    v = json[@"profilePicture"]; if (!v) v = json[@"avatar"];
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
