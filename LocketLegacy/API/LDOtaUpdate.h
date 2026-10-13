// LDOtaUpdate — over-the-air update check + download for sideloaded builds.
// Source of truth: GitHub Releases (latest tag vs bundle version).
// iOS sandbox cannot install an IPA by itself, so "install" means:
// download the .ipa and hand it to the system share sheet (Files, TrollStore,
// AltStore). No new permissions or backends required.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LDOtaCheckCompletion)(NSDictionary * _Nullable info, NSError * _Nullable error);
typedef void (^LDOtaProgressBlock)(double fraction);
typedef void (^LDOtaDownloadCompletion)(NSURL * _Nullable fileURL, NSError * _Nullable error);

@interface LDOtaUpdate : NSObject
// info keys when an update is available:
// @"current", @"latest", @"notes", @"ipaURL", @"htmlURL". info == nil => up to date.
+ (void)checkForUpdatesWithCompletion:(LDOtaCheckCompletion)completion;
+ (void)downloadIPAFromURL:(NSString *)urlString
                  progress:(nullable LDOtaProgressBlock)progress
                completion:(LDOtaDownloadCompletion)completion;
// Numeric dotted-version compare: 1 if a > b, -1 if a < b, 0 if equal.
+ (NSInteger)compareVersion:(NSString *)a toVersion:(NSString *)b;
+ (NSString *)currentVersion;
@end

NS_ASSUME_NONNULL_END
