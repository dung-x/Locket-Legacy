#import "LDUser.h"
@implementation LDUser
+ (instancetype)fromJSON:(NSDictionary *)json {
    LDUser *u = [[LDUser alloc] init];
    id v;
    v = json[@"uid"]; if (!v) v = json[@"localId"];
    u.uid = [v isKindOfClass:[NSString class]] ? v : @"";
    v = json[@"email"]; u.email = [v isKindOfClass:[NSString class]] ? v : @"";
    v = json[@"displayName"]; u.displayName = [v isKindOfClass:[NSString class]] ? v : @"";
    v = json[@"profilePicture"]; u.profilePicture = [v isKindOfClass:[NSString class]] ? v : @"";
    v = json[@"username"]; u.username = [v isKindOfClass:[NSString class]] ? v : @"";
    return u;
}
@end
