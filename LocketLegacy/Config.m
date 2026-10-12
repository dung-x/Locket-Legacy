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
+ (UIColor *)themeAccentColor {
    NSString *t = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyCameraTheme];
    if ([t isEqualToString:@"violet"]) return [UIColor colorWithRed:0.7 green:0.4 blue:1.0 alpha:1];
    if ([t isEqualToString:@"ocean"]) return [UIColor colorWithRed:0.3 green:0.8 blue:1.0 alpha:1];
    return [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1]; // gold default
}
@end
