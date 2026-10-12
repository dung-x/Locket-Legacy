#import "Config.h"

@implementation LDConfig
+ (NSString *)baseAPIURL {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyBaseAPIURL];
    if (v.length == 0) return kLDDefaultBaseAPIURL;
    return v;
}
+ (void)setBaseAPIURL:(NSString *)url {
    if (url.length == 0) return;
    [[NSUserDefaults standardUserDefaults] setObject:url forKey:kLDKeyBaseAPIURL];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
+ (NSString *)storageAPIURL { return kLDDefaultStorageAPIURL; }
@end
