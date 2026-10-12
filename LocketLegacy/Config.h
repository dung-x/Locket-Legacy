// LDConfig.h — central configuration (iOS 12 compatible, ObjC)
// Mirrors web .env (VITE_*_API_URL) from Client-Locket-Dio self-hosted/web/.env.example
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Default self-host endpoints. Override at runtime via Settings screen.
// Matches docker-compose: api :5001, storage :5003, web :5173
static NSString * const kLDDefaultBaseAPIURL    = @"http://localhost:5001";
static NSString * const kLDDefaultStorageAPIURL = @"http://localhost:5003";

static NSString * const kLDKeyBaseAPIURL   = @"LDBaseAPIURL";
static NSString * const kLDKeyIDToken      = @"LDIDToken";
static NSString * const kLDKeyRefreshToken = @"LDRefreshToken";
static NSString * const kLDKeyUserID       = @"LDUserID";
static NSString * const kLDKeyUserEmail    = @"LDUserEmail";
static NSString * const kLDKeyPushEnabled  = @"LDPushEnabled";
static NSString * const kLDKeyCameraTheme  = @"LDCameraTheme"; // gold | violet | ocean
static NSString * const kLDKeyBackendMode  = @"LDBackendMode"; // selfhost | original

// Original project endpoints (Client-Locket-Dio web .env defaults).
static NSString * const kLDOriginalBaseAPIURL    = @"https://api.locket-dio.com";
static NSString * const kLDOriginalAuthAPIURL     = @"https://auth.locket-dio.com";
static NSString * const kLDOriginalStorageAPIURL = @"https://storage.locket-dio.com";
// Public frontend key, same one the web client embeds (VITE_PUBLIC_API_KEY).
static NSString * const kLDDioPublicAPIKey = @"LKD-LOCKETDIO-AB02F55KYM55DD02MM03YY25-LKD";

@interface LDConfig : NSObject
+ (NSString *)baseAPIURL;
+ (void)setBaseAPIURL:(NSString *)url;
+ (NSString *)storageAPIURL;
+ (UIColor *)themeAccentColor;
// Backend preset: @"selfhost" (custom URL, default) or @"original" (api.locket-dio.com).
+ (NSString *)backendMode;
+ (void)setBackendMode:(NSString *)mode;
+ (NSString *)effectiveBaseAPIURL;
+ (NSString *)authBaseURL;
+ (NSArray<NSString *> *)storageBaseCandidates;
+ (NSDictionary *)dioHeaders;
@end

NS_ASSUME_NONNULL_END
