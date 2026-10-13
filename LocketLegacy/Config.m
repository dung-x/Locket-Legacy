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

+ (NSString *)locketOfficialBaseURL { return kLDLocketOfficialAPIURL; }
+ (NSDictionary *)locketHeaders {
    // iOS Firebase/Locket client headers, same static set the web client uses.
    // If official calls start failing on AppCheck, this token is suspect #1.
    return @{@"Content-Type": @"application/json",
             @"Accept-Language": @"en-US",
             @"X-Ios-Bundle-Identifier": @"com.locket.Locket",
             @"X-Client-Version": @"iOS/FirebaseSDK/10.23.1/FirebaseCore-iOS",
             @"X-Firebase-GMPID": @"1:641029076083:ios:cc8eb46290d69b234fa606",
             @"X-Firebase-Client": @"H4sIAAAAAAAAAKtWykhNLCpJSk0sKVayio7VUSpLLSrOzM9TslIyUqoFAFyivEQfAAAA",
             @"X-Firebase-AppCheck": @"eyJraWQiOiJNbjVDS1EiLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxOjY0MTAyOTA3NjA4Mzppb3M6Y2M4ZWI0NjI5MGQ2OWIyMzRmYTYwNiIsImF1ZCI6WyJwcm9qZWN0c1wvNjQxMDI5MDc2MDgzIiwicHJvamVjdHNcL2xvY2tldC00MjUyYSJdLCJwcm92aWRlciI6ImRldmljZV9jaGVja19kZXZpY2VfaWRlbnRpZmljYXRpb24iLCJpc3MiOiJodHRwczpcL1wvZmlyZWJhc2VhcHBjaGVjay5nb29nbGVhcGlzLmNvbVwvNjQxMDI5MDc2MDgzIiwiZXhwIjoxNzIyMTY3ODk4LCJpYXQiOjE3MjIxNjQyOTgsImp0aSI6ImlHUGlsT1dDZGg4Mll3UTJXRC1neEpXeWY5TU9RRFhHcU5OR3AzTjFmRGcifQ.lqTOJfdoYLpZwYeeXtRliCdkVT7HMd7_Lj-d44BNTGuxSYPIa9yVAR4upu3vbZSh9mVHYS8kJGYtMqjP-L6YXsk_qsV_gzKC2IhVAV6KbPDRHdevMfBC6fRiOSVn7vt749GVFdZqAuDCXhCILsaMhvgDBgZoDilgAPtpNwyjz-VtRB7OdOUbuKTCqdoSOX0SJWVUMyuI8nH0-unY--YRctunK8JHZDxBaM_ahVggYPWBCpzxq9Yeq8VSPhadG_tGNaADStYPaeeUkZ7DajwWqH5ze6ESpuFNgAigwPxCM735_ZiPeD7zHYwppQA9uqTWszK9v9OvWtFCsgCEe22O8awbNbuEBTKJpDQ8xvZe8iEYyhfUPncER3S-b1CmuXR7tFCdTgQe5j7NGWjFvN_CnL7D2nudLwxWlpqwASCHvHyi8HBaJ5GpgriTLXAAinY48RukRDBi9HwEzpRecELX05KTD2lTOfQCjKyGpfG2VUHP5Xm36YbA3iqTDoDXWMvV"};
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
