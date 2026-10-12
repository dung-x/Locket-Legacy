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
+ (NSString *)backendMode {
    NSString *m = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyBackendMode];
    if ([m isEqualToString:@"original"]) return @"original";
    return @"selfhost";
}
+ (void)setBackendMode:(NSString *)mode {
    [[NSUserDefaults standardUserDefaults] setObject:([mode isEqualToString:@"original"] ? @"original" : @"selfhost")
                                              forKey:kLDKeyBackendMode];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
+ (NSString *)effectiveBaseAPIURL {
    if ([[self backendMode] isEqualToString:@"original"]) return kLDOriginalBaseAPIURL;
    return [self baseAPIURL];
}
+ (NSString *)authBaseURL {
    if ([[self backendMode] isEqualToString:@"original"]) return kLDOriginalAuthAPIURL;
    return [self baseAPIURL];
}
+ (NSArray<NSString *> *)storageBaseCandidates {
    if ([[self backendMode] isEqualToString:@"original"]) return @[kLDOriginalStorageAPIURL];
    NSString *base = [self baseAPIURL];
    while (base.length > 1 && [base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    NSMutableArray *out = [NSMutableArray arrayWithObject:base];
    NSRange r = [base rangeOfString:@":5001"];
    if (r.location != NSNotFound) {
        NSString *alt = [base stringByReplacingCharactersInRange:r withString:@":5003"];
        if (![alt isEqualToString:base]) [out addObject:alt];
    }
    return out;
}
+ (NSDictionary *)dioHeaders {
    // Same public headers the web client sends on every call (axios.main.js).
    return @{@"x-api-key": kLDDioPublicAPIKey,
             @"x-app-author": @"dio",
             @"x-app-name": @"locketdio",
             @"x-app-client": @"iOS1.0",
             @"x-app-api": @"v2.2.1",
             @"x-app-env": @"production"};
}
@end
