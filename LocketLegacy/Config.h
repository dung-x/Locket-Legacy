// LDConfig.h — central configuration (iOS 12 compatible, ObjC)
// Mirrors web .env (VITE_*_API_URL) from Client-Locket-Dio self-hosted/web/.env.example
#import <Foundation/Foundation.h>

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

@interface LDConfig : NSObject
+ (NSString *)baseAPIURL;
+ (void)setBaseAPIURL:(NSString *)url;
+ (NSString *)storageAPIURL;
@end

NS_ASSUME_NONNULL_END
