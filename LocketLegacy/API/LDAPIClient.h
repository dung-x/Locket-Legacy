// LDAPIClient.h — NSURLSession wrapper for self-hosted Locket Dio API
// Base: http://localhost:5001/locket  (see API_DOCS.md upstream)
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LDJSONCompletion)(NSDictionary * _Nullable json, NSError * _Nullable error);

@interface LDAPIClient : NSObject
+ (instancetype)shared;
- (NSString *)baseURL;

// Auth
- (void)loginWithEmail:(NSString *)email password:(NSString *)password completion:(LDJSONCompletion)completion;
- (void)refreshToken:(NSString *)refreshToken completion:(LDJSONCompletion)completion;
- (void)logoutWithCompletion:(LDJSONCompletion)completion;

// User / friends / moments (all POST per locket.route.js, Bearer idToken)
- (void)getInfoUserWithCompletion:(LDJSONCompletion)completion;
- (void)getAllFriendsWithCompletion:(LDJSONCompletion)completion;
- (void)getMomentsWithCompletion:(LDJSONCompletion)completion;
- (void)getInfoMoment:(NSString *)momentId completion:(LDJSONCompletion)completion;
- (void)getAllMessagesWithCompletion:(LDJSONCompletion)completion;

// Upload — V1 multipart file+optionsData, V2 JSON mediaInfo+options
- (void)postMomentV1WithFileURL:(NSURL *)fileURL
                       isVideo:(BOOL)isVideo
                       caption:(NSString *)caption
                    completion:(LDJSONCompletion)completion;
- (void)postMomentV2WithMediaInfo:(NSDictionary *)mediaInfo
                          options:(NSDictionary *)options
                       completion:(LDJSONCompletion)completion;

@property (nonatomic, copy, nullable) NSString *idToken;
@end

NS_ASSUME_NONNULL_END
