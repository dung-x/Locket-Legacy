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

typedef void (^LDProgressBlock)(NSString *stage);

// Step 1 of the original flow, exposed for diagnostics: asks a storage host
// for a one-time PUT grant. Completion: presigned data dict or error.
- (void)requestUploadGrantWithFilename:(NSString *)fileName
                           contentType:(NSString *)mime
                                  type:(NSString *)type
                                  size:(NSUInteger)size
                           uploadedAt:(NSString *)isoDate
                            completion:(void(^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion;

// Social / extras (mirror upstream UX on self-host)
- (void)getOverlaysWithCompletion:(LDJSONCompletion)completion;
- (void)reactToMoment:(NSString *)momentId emoji:(NSString *)emoji completion:(LDJSONCompletion)completion;
- (void)getMomentReactions:(NSString *)momentId completion:(LDJSONCompletion)completion;
- (void)createMomentPayloadWithMediaInfo:(NSDictionary *)mediaInfo
                                options:(NSDictionary *)options
                            contentType:(NSString *)type
                             completion:(LDJSONCompletion)completion;
// Final hop on the original flow: POST the Dio-built payload straight to
// official Locket (mirrors the web client's ks() call).
- (void)postOfficialMomentWithPayload:(NSDictionary *)payload completion:(LDJSONCompletion)completion;
// Production member session: GET {api}/api/me -> session {member_token, header}.
// Must run after login (and when the token exists but member is missing);
// the member header rides on every Dio call via applyDioHeaders.
- (void)fetchMemberSessionWithCompletion:(LDJSONCompletion)completion;
- (void)sendMessageWithText:(NSString *)text completion:(LDJSONCompletion)completion;
- (void)registerPushToken:(NSString *)token completion:(LDJSONCompletion)completion;

// Original web-client method (mirrors createRequestPayloadV5 + PostMoments):
//  1/3 POST {storage}/api/presignedV3  -> {url, publicURL, key}
//  2/3 PUT raw bytes to the presigned url
//  3/3 POST /locket/postMomentV2 {model, mediaInfo, options, contentType}
// Storage hosts tried in order: the API host itself, then the same host with
// :5001 swapped to :5003 (upstream split-host layout). Works with the bundled
// mock (single host) and with upstream self-host (api :5001 + storage :5003).
- (void)sendMomentOriginalFlowWithFileURL:(NSURL *)fileURL
                                 isVideo:(BOOL)isVideo
                                 caption:(NSString *)caption
                                audience:(NSString *)audience
                             extraOptions:(nullable NSDictionary *)extra
                                progress:(nullable LDProgressBlock)progress
                              completion:(LDJSONCompletion)completion;

@property (nonatomic, copy, nullable) NSString *idToken;
@end

NS_ASSUME_NONNULL_END
