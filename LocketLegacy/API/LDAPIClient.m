#import "LDAPIClient.h"
#import "../Config.h"

@interface LDAPIClient ()
- (void)POST:(NSString *)path body:(nullable NSDictionary *)body retried:(BOOL)retried completion:(LDJSONCompletion)completion;
- (void)POSTRaw:(NSString *)path body:(nullable NSDictionary *)body completion:(LDJSONCompletion)completion;
- (void)POSTURL:(NSString *)urlStr body:(NSDictionary *)body completion:(void(^)(NSDictionary * _Nullable json, NSInteger status, NSError * _Nullable error))completion;
- (void)POSTURL:(NSString *)urlStr body:(NSDictionary *)body retried:(BOOL)retried completion:(void(^)(NSDictionary * _Nullable json, NSInteger status, NSError * _Nullable error))completion;
- (void)POSTURLRaw:(NSString *)urlStr body:(NSDictionary *)body completion:(void(^)(NSDictionary * _Nullable json, NSInteger status, NSError * _Nullable error))completion;
- (void)GETURL:(NSString *)urlStr retried:(BOOL)retried completion:(void(^)(NSDictionary * _Nullable json, NSInteger status, NSError * _Nullable error))completion;
- (NSDictionary *)normalizedGrant:(NSDictionary *)data;
- (void)applyDioHeaders:(NSMutableURLRequest *)req;
- (BOOL)needsRefreshForJSON:(NSDictionary *)json status:(NSInteger)code;
- (BOOL)tryRefreshThen:(void(^)(void))retry;
- (void)finishLoginWithJSON:(NSDictionary *)json error:(NSError *)err completion:(LDJSONCompletion)completion;
- (void)postOfficialMomentWithPayload:(NSDictionary *)payload retried:(BOOL)retried completion:(LDJSONCompletion)completion;
@end

@implementation LDAPIClient

+ (instancetype)shared {
    static LDAPIClient *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[LDAPIClient alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _idToken = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyIDToken];
    }
    return self;
}

- (NSString *)baseURL {
    return [[LDConfig effectiveBaseAPIURL] stringByAppendingString:@"/locket"];
}

- (void)applyDioHeaders:(NSMutableURLRequest *)req {
    for (NSString *k in [LDConfig dioHeaders]) {
        [req setValue:[LDConfig dioHeaders][k] forHTTPHeaderField:k];
    }
    // Member session (production): every Dio request also carries the member
    // token under its header (default X-LocketDio-Member). Without it the API
    // rejects even valid Bearer calls — the classic "auth state" failure.
    NSString *mt = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyMemberToken];
    if ([mt isKindOfClass:[NSString class]] && mt.length > 0) {
        NSString *mh = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyMemberHeader];
        if (![mh isKindOfClass:[NSString class]] || !mh.length) mh = kLDDefaultMemberHeader;
        [req setValue:mt forHTTPHeaderField:mh];
    }
}

- (void)POST:(NSString *)path body:(nullable NSDictionary *)body completion:(LDJSONCompletion)completion {
    [self POST:path body:body retried:NO completion:completion];
}

// Raw POST with NO refresh logic — used by the refresh call itself so an
// expired refresh token can never recurse forever (that hang looked exactly
// like "moment still didn't get uploaded").
- (void)POSTRaw:(NSString *)path body:(nullable NSDictionary *)body completion:(LDJSONCompletion)completion {
    NSString *urlStr = [[self baseURL] stringByAppendingString:path];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [self applyDioHeaders:req];
    if (self.idToken.length > 0) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.idToken] forHTTPHeaderField:@"Authorization"];
    }
    if (body) {
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (e) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, e); }); return; }
        NSDictionary *json = nil;
        if (d.length) json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if (!json) json = @{};
        NSDictionary *j = json;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(j, nil); });
    }];
    [t resume];
}

- (void)POST:(NSString *)path body:(nullable NSDictionary *)body retried:(BOOL)retried completion:(LDJSONCompletion)completion {
    NSString *urlStr = [[self baseURL] stringByAppendingString:path];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [self applyDioHeaders:req];
    if (self.idToken.length > 0) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.idToken] forHTTPHeaderField:@"Authorization"];
    }
    if (body) {
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (e) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, e); }); return; }
        NSDictionary *json = nil;
        if (d.length) json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if (!json) json = @{};
        NSInteger code = [r isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)r).statusCode : 0;
        if (!retried && [self needsRefreshForJSON:json status:code] && [self tryRefreshThen:^{
            [self POST:path body:body retried:YES completion:completion];
        }]) return;
        NSDictionary *j = json;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(j, nil); });
    }];
    [t resume];
}

// YES if a refresh was started (caller must return without completing).
- (BOOL)needsRefreshForJSON:(NSDictionary *)json status:(NSInteger)code {
    if (code == 401) return YES;
    id err = json[@"error"];
    if ([err isKindOfClass:[NSDictionary class]] && [err[@"code"] isKindOfClass:[NSString class]] &&
        [err[@"code"] isEqualToString:@"UNAUTHORIZED"]) return YES;
    return NO;
}

- (BOOL)tryRefreshThen:(void(^)(void))retry {
    NSString *rt = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyRefreshToken];
    if (![rt isKindOfClass:[NSString class]] || !rt.length) return NO;
    [self refreshToken:rt completion:^(NSDictionary *json, NSError *error) {
        NSDictionary *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
        NSString *tok = [data isKindOfClass:[NSDictionary class]] ?
            ([data[@"id_token"] isKindOfClass:[NSString class]] ? data[@"id_token"] :
             ([data[@"access_token"] isKindOfClass:[NSString class]] ? data[@"access_token"] : nil)) : nil;
        if (!error && [tok isKindOfClass:[NSString class]] && tok.length > 0) {
            self.idToken = tok;
            [[NSUserDefaults standardUserDefaults] setObject:tok forKey:kLDKeyIDToken];
            NSString *nr = data[@"refresh_token"];
            if ([nr isKindOfClass:[NSString class]] && nr.length > 0) {
                [[NSUserDefaults standardUserDefaults] setObject:nr forKey:kLDKeyRefreshToken];
            }
            NSString *nu = data[@"user_id"];
            if ([nu isKindOfClass:[NSString class]] && nu.length > 0) {
                [[NSUserDefaults standardUserDefaults] setObject:nu forKey:kLDKeyUserID];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
            retry();
        } else {
            // Refresh failed — surface auth expiration to the caller path.
            retry();
        }
    }];
    return YES;
}

- (void)loginWithEmail:(NSString *)email password:(NSString *)password completion:(LDJSONCompletion)completion {
    // Original production auth lives on auth.locket-dio.com as locket/loginV2
    // (captchaToken empty = Turnstile off, same as the web default config).
    if ([[LDConfig backendMode] isEqualToString:@"original"]) {
        NSString *u = [[LDConfig authBaseURL] stringByAppendingString:@"/locket/loginV2"];
        [self POSTURL:u body:@{@"email": email ?: @"", @"password": password ?: @"", @"captchaToken": @""} completion:^(NSDictionary *json, NSInteger status, NSError *err) {
            [self finishLoginWithJSON:json error:err completion:^(NSDictionary *j2, NSError *e2) {
                // Production calls also need the member session (/api/me);
                // fetch it before entering the app so data calls don't 401.
                if (!e2 && self.idToken.length > 0) {
                    [self fetchMemberSessionWithCompletion:^(NSDictionary *j3, NSError *e3) {
                        completion(j2, e2);
                    }];
                    return;
                }
                completion(j2, e2);
            }];
        }];
        return;
    }
    [self POST:@"/login" body:@{@"email": email ?: @"", @"password": password ?: @""} completion:^(NSDictionary *json, NSError *err) {
        [self finishLoginWithJSON:json error:err completion:completion];
    }];
}

- (void)finishLoginWithJSON:(NSDictionary *)json error:(NSError *)err completion:(LDJSONCompletion)completion {
    if (!err) {
        NSDictionary *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
        if (![data isKindOfClass:[NSDictionary class]] && [json isKindOfClass:[NSDictionary class]]) data = json;
        NSString *tok = data[@"idToken"];
        if (![tok isKindOfClass:[NSString class]]) tok = data[@"access_token"];
        if (![tok isKindOfClass:[NSString class]]) tok = data[@"id_token"];
        NSString *refresh = data[@"refreshToken"];
        if (![refresh isKindOfClass:[NSString class]]) refresh = data[@"refresh_token"];
        if ([tok isKindOfClass:[NSString class]]) {
            self.idToken = tok;
            [[NSUserDefaults standardUserDefaults] setObject:tok forKey:kLDKeyIDToken];
        }
        if ([refresh isKindOfClass:[NSString class]]) {
            [[NSUserDefaults standardUserDefaults] setObject:refresh forKey:kLDKeyRefreshToken];
        }
        NSString *uid = data[@"localId"];
        if (![uid isKindOfClass:[NSString class]]) uid = data[@"user_id"];
        if ([uid isKindOfClass:[NSString class]]) {
            [[NSUserDefaults standardUserDefaults] setObject:uid forKey:kLDKeyUserID];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    completion(json, err);
}

- (void)GETURL:(NSString *)urlStr retried:(BOOL)retried completion:(void(^)(NSDictionary * _Nullable json, NSInteger status, NSError * _Nullable error))completion {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"GET";
    [self applyDioHeaders:req];
    if (self.idToken.length > 0) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.idToken] forHTTPHeaderField:@"Authorization"];
    }
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSInteger code = [r isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)r).statusCode : 0;
        if (e) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, code, e); }); return; }
        NSDictionary *json = d.length ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) json = @{};
        if (!retried && [self needsRefreshForJSON:json status:code] && [self tryRefreshThen:^{
            [self GETURL:urlStr retried:YES completion:completion];
        }]) return;
        NSDictionary *j = json;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(j, code, nil); });
    }];
    [t resume];
}

- (void)refreshToken:(NSString *)refreshToken completion:(LDJSONCompletion)completion {
    // Production refresh lives on the auth host; self-host serves it on the API host.
    if ([[LDConfig backendMode] isEqualToString:@"original"]) {
        NSString *u = [[LDConfig authBaseURL] stringByAppendingString:@"/locket/refresh-token"];
        [self POSTURLRaw:u body:@{@"refreshToken": refreshToken ?: @""} completion:^(NSDictionary *json, NSInteger status, NSError *error) {
            completion(json, error);
        }];
        return;
    }
    [self POSTRaw:@"/refresh-token" body:@{@"refreshToken": refreshToken ?: @""} completion:completion];
}

- (void)logoutWithCompletion:(LDJSONCompletion)completion {
    // Production logout lives on the auth host (GET); self-host mirrors it.
    NSString *host = [[LDConfig backendMode] isEqualToString:@"original"] ? [LDConfig authBaseURL] : [LDConfig baseAPIURL];
    NSString *urlStr = [host stringByAppendingString:@"/locket/logout"];
    [self GETURL:urlStr retried:NO completion:^(NSDictionary *json, NSInteger status, NSError *e) {
        self.idToken = nil;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLDKeyIDToken];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLDKeyRefreshToken];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLDKeyMemberToken];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLDKeyMemberHeader];
        [[NSUserDefaults standardUserDefaults] synchronize];
        completion(json ?: @{}, e);
    }];
}

- (void)getInfoUserWithCompletion:(LDJSONCompletion)completion {
    // Production serves GET {auth}/locket/getInfoUser; self-host mock serves
    // POST {base}/locket/getInfoUser. Try the native shape first, fall back.
    if ([[LDConfig backendMode] isEqualToString:@"original"]) {
        NSString *u = [[LDConfig authBaseURL] stringByAppendingString:@"/locket/getInfoUser"];
        [self GETURL:u retried:NO completion:^(NSDictionary *json, NSInteger status, NSError *e) {
            if (!e && status >= 200 && status < 300) { completion(json, nil); return; }
            [self POST:@"/getInfoUser" body:@{} completion:completion];
        }];
        return;
    }
    [self POST:@"/getInfoUser" body:@{} completion:^(NSDictionary *json, NSError *error) {
        if (!error) { completion(json, nil); return; }
        NSString *u = [[LDConfig baseAPIURL] stringByAppendingString:@"/locket/getInfoUser"];
        [self GETURL:u retried:NO completion:^(NSDictionary *j2, NSInteger s2, NSError *e2) {
            completion(j2, e2);
        }];
    }];
}
- (void)getAllFriendsWithCompletion:(LDJSONCompletion)completion {
    [self POST:@"/getAllFriendsV2" body:@{} completion:completion];
}
- (void)getMomentsWithCompletion:(LDJSONCompletion)completion {
    [self POST:@"/getMomentV2" body:@{} completion:completion];
}
- (void)getInfoMoment:(NSString *)momentId completion:(LDJSONCompletion)completion {
    [self POST:@"/getInfoMomentV2" body:@{@"idMoment": momentId ?: @""} completion:completion];
}
- (void)getAllMessagesWithCompletion:(LDJSONCompletion)completion {
    [self POST:@"/getAllMessageV2" body:@{} completion:completion];
}

- (void)postMomentV1WithFileURL:(NSURL *)fileURL
                       isVideo:(BOOL)isVideo
                  thumbnailURL:(NSURL *)thumbnailURL
                       caption:(NSString *)caption
                      audience:(NSString *)audience
                  extraOptions:(NSDictionary *)extra
                    completion:(LDJSONCompletion)completion {
    NSString *urlStr = [[self baseURL] stringByAppendingString:@"/postMomentV1"];
    NSString *boundary = @"----LocketLegacyBoundary1234";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    [self applyDioHeaders:req];
    if (self.idToken.length > 0) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.idToken] forHTTPHeaderField:@"Authorization"];
    }
    NSMutableDictionary *opts = [@{@"caption": caption ?: @"",
                                   @"audience": ([audience isKindOfClass:[NSString class]] && audience.length) ? audience : @"all",
                                   @"recipients": @[]} mutableCopy];
    if ([extra isKindOfClass:[NSDictionary class]]) {
        for (id k in extra) { if ([k isKindOfClass:[NSString class]]) opts[k] = extra[k] ?: @""; }
    }
    NSData *optsData = [NSJSONSerialization dataWithJSONObject:opts options:0 error:nil];
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"optionsData\"\r\nContent-Type: application/json\r\n\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:optsData ?: [NSData data]];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    if (!fileData) { completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Cannot read media file"}]); return; }
    NSString *fname = isVideo ? @"clip.mp4" : @"photo.jpg";
    NSString *mime = isVideo ? @"video/mp4" : @"image/jpeg";
    [body appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n", boundary, fname, mime] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:fileData];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *thumbData = thumbnailURL ? [NSData dataWithContentsOfURL:thumbnailURL] : nil;
    if (thumbData.length) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"thumbnail\"; filename=\"thumb.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:thumbData];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    req.HTTPBody = body;
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSDictionary *json = (d.length && !e) ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) json = @{};
        if (!e && [self needsRefreshForJSON:json status:[r isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)r).statusCode : 0]) {
            NSString *rt = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyRefreshToken];
            if ([rt isKindOfClass:[NSString class]] && rt.length) {
                [self refreshToken:rt completion:^(NSDictionary *rj, NSError *re) {
                    NSDictionary *data = [rj isKindOfClass:[NSDictionary class]] ? rj[@"data"] : nil;
                    NSString *tok = [data isKindOfClass:[NSDictionary class]] ? (data[@"id_token"] ?: data[@"access_token"]) : nil;
                    if (!re && [tok isKindOfClass:[NSString class]] && tok.length) {
                        self.idToken = tok;
                        [[NSUserDefaults standardUserDefaults] setObject:tok forKey:kLDKeyIDToken];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        [self postMomentV1WithFileURL:fileURL isVideo:isVideo thumbnailURL:thumbnailURL caption:caption audience:audience extraOptions:extra completion:completion];
                        return;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{ completion(json, nil); });
                }];
                return;
            }
        }
        NSDictionary *j = json;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(j, e); });
    }];
    [t resume];
}

- (void)postMomentV1WithFileURL:(NSURL *)fileURL
                       isVideo:(BOOL)isVideo
                       caption:(NSString *)caption
                    completion:(LDJSONCompletion)completion {
    [self postMomentV1WithFileURL:fileURL isVideo:isVideo thumbnailURL:nil caption:caption audience:@"all" extraOptions:nil completion:completion];
}

- (void)postMomentV2WithMediaInfo:(NSDictionary *)mediaInfo options:(NSDictionary *)options completion:(LDJSONCompletion)completion {
    [self POST:@"/postMomentV2" body:@{@"model": @"Version-UploadmediaV3.1", @"mediaInfo": mediaInfo ?: @{}, @"options": options ?: @{}} completion:completion];
}

#pragma mark - Original send flow (presigned PUT + postMomentV2)

static NSString * const kLDClientVersion = @"iOS1.0";

+ (NSString *)isoNow {
    static NSDateFormatter *f = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        f = [[NSDateFormatter alloc] init];
        f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        f.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    });
    return [f stringFromDate:[NSDate date]];
}

// Storage hosts to try, in order (see LDConfig: self-host API host, then the
// upstream split-host layout; original preset pins storage.locket-dio.com).
- (NSArray<NSString *> *)storageBaseCandidates {
    return [LDConfig storageBaseCandidates];
}

- (void)POSTURL:(NSString *)urlStr body:(NSDictionary *)body completion:(void(^)(NSDictionary * _Nullable json, NSInteger status, NSError * _Nullable error))completion {
    [self POSTURL:urlStr body:body retried:NO completion:completion];
}

- (void)POSTURLRaw:(NSString *)urlStr body:(NSDictionary *)body completion:(void(^)(NSDictionary * _Nullable json, NSInteger status, NSError * _Nullable error))completion {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [self applyDioHeaders:req];
    if (self.idToken.length > 0) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.idToken] forHTTPHeaderField:@"Authorization"];
    }
    if (body) req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSInteger code = [r isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)r).statusCode : 0;
        if (e) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, code, e); }); return; }
        NSDictionary *json = d.length ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) json = @{};
        NSDictionary *j = json;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(j, code, nil); });
    }];
    [t resume];
}

- (void)POSTURL:(NSString *)urlStr body:(NSDictionary *)body retried:(BOOL)retried completion:(void(^)(NSDictionary * _Nullable json, NSInteger status, NSError * _Nullable error))completion {
    [self POSTURLRaw:urlStr body:body completion:^(NSDictionary *json, NSInteger status, NSError *e) {
        if (e) { completion(nil, status, e); return; }
        if (!retried && [self needsRefreshForJSON:json status:status] && [self tryRefreshThen:^{
            [self POSTURL:urlStr body:body retried:YES completion:completion];
        }]) return;
        completion(json, status, nil);
    }];
}

// Unify the two presigned shapes into {url, publicURL, key, mediaSignature, owner}:
// self-host mock  -> {url, publicURL, key}
// production      -> {uploadUrl, publicUrl, folder, mediaSignature, owner}
// (key/folder + server-side filename rebuild the storage path for step 3).
- (NSDictionary *)normalizedGrant:(NSDictionary *)data {
    if (![data isKindOfClass:[NSDictionary class]]) return @{};
    NSMutableDictionary *g = [NSMutableDictionary dictionary];
    id putURL = data[@"url"];
    if (![putURL isKindOfClass:[NSString class]]) putURL = data[@"uploadUrl"];
    if ([putURL isKindOfClass:[NSString class]]) g[@"url"] = putURL;
    id pub = data[@"publicURL"];
    for (NSString *k in @[@"publicUrl", @"public_url", @"downloadURL", @"download_url", @"fileUrl", @"file_url"]) {
        if (![pub isKindOfClass:[NSString class]]) {
            id v = data[k];
            if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length > 0) pub = v;
        }
    }
    if ([pub isKindOfClass:[NSString class]]) g[@"publicURL"] = pub;
    NSString *key = [data[@"key"] isKindOfClass:[NSString class]] ? data[@"key"] : nil;
    NSString *folder = [data[@"folder"] isKindOfClass:[NSString class]] ? data[@"folder"] : nil;
    NSString *base = nil;
    if ([pub isKindOfClass:[NSString class]]) {
        NSURL *u = [NSURL URLWithString:pub];
        base = u.path.lastPathComponent;
        if (![base isKindOfClass:[NSString class]] || !base.length) {
            NSArray *parts = [pub componentsSeparatedByString:@"/"];
            base = parts.lastObject;
        }
        if ([base rangeOfString:@"?"].location != NSNotFound) {
            base = [base substringToIndex:[base rangeOfString:@"?"].location];
        }
    }
    if (!key.length) {
        // Prefer the R2 signed PUT URL: its path IS the object key
        // (/{bucket}/{key}?X-Amz-…), ground truth regardless of folder shape.
        NSString *putStr = [putURL isKindOfClass:[NSString class]] ? putURL : nil;
        NSURL *pu = putStr ? [NSURL URLWithString:putStr] : nil;
        NSString *ppath = [pu.path isKindOfClass:[NSString class]] ? pu.path : @"";
        NSMutableArray *segs = [NSMutableArray array];
        for (NSString *s in [ppath componentsSeparatedByString:@"/"]) {
            if (s.length) [segs addObject:s];
        }
        if (segs.count >= 2) {
            [segs removeObjectAtIndex:0]; // bucket name
            key = [segs componentsJoinedByString:@"/"];
        }
    }
    if (!key.length) {
        // Fallback: folder + server-chosen filename.
        if ([folder isKindOfClass:[NSString class]] && folder.length > 0 && [base isKindOfClass:[NSString class]] && base.length > 0) {
            while (folder.length > 1 && [folder hasSuffix:@"/"]) folder = [folder substringToIndex:folder.length - 1];
            key = [folder stringByAppendingPathComponent:base];
        }
    }
    if ([key isKindOfClass:[NSString class]] && key.length > 0) g[@"key"] = key;
    for (NSString *k in @[@"mediaSignature", @"owner"]) {
        id v = data[k];
        if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length > 0) g[k] = v;
    }
    return g;
}

- (void)sendMomentOriginalFlowWithFileURL:(NSURL *)fileURL
                                 isVideo:(BOOL)isVideo
                                 caption:(NSString *)caption
                                audience:(NSString *)audience
                             extraOptions:(NSDictionary *)extra
                                progress:(LDProgressBlock)progress
                              completion:(LDJSONCompletion)completion {
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    if (!fileData.length) {
        completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Cannot read media file"}]);
        return;
    }
    // Production requires the member session on data calls; repair it if absent.
    // Its presence is reported so a missing one is visible, not cryptic.
    if ([[LDConfig backendMode] isEqualToString:@"original"]) {
        NSString *mt = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyMemberToken];
        if (![mt isKindOfClass:[NSString class]] || !mt.length) {
            if (progress) progress(@"Refreshing session (no member token)…");
            [self fetchMemberSessionWithCompletion:^(NSDictionary *json, NSError *error) {
                [self sendMomentOriginalFlowWithFileURL:fileURL isVideo:isVideo caption:caption audience:audience extraOptions:extra progress:progress completion:completion];
            }];
            return;
        }
    }
    // Mirrors PayloadServices.createRequestPayloadV5 naming.
    NSString *type = isVideo ? @"video" : @"image";
    NSString *mime = isVideo ? @"video/quicktime" : @"image/jpeg";
    NSString *ext = isVideo ? @"mov" : @"jpg";
    NSString *localId = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyUserID];
    if (![localId isKindOfClass:[NSString class]] || !localId.length) localId = @"unknown";
    long long ms = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSString *fileName = [NSString stringWithFormat:@"locketdio_%lld_%@_cli%@.%@", ms, localId, kLDClientVersion, ext];
    NSString *uploadedAt = [[self class] isoNow];
    NSDictionary *preBody = @{@"filename": fileName, @"contentType": mime, @"type": type,
                              @"size": @(fileData.length), @"uploadedAt": uploadedAt};
    if (progress) progress(@"1/3 requesting upload URL…");
    [self requestUploadGrantWithFilename:fileName contentType:mime type:type size:fileData.length uploadedAt:uploadedAt completion:^(NSDictionary *predata, NSError *preError) {
        if (preError || ![predata isKindOfClass:[NSDictionary class]]) {
            completion(nil, preError ?: [NSError errorWithDomain:@"LocketLegacy" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Upload failed at step 1/3 (presigned URL)"}]);
            return;
        }
        [self continueOriginalFlowWithGrant:predata fileData:fileData fileName:fileName mime:mime type:type caption:caption audience:audience extra:extra progress:progress completion:completion];
    }];
}

- (void)requestUploadGrantWithFilename:(NSString *)fileName
                           contentType:(NSString *)mime
                                  type:(NSString *)type
                                  size:(NSUInteger)size
                           uploadedAt:(NSString *)isoDate
                            completion:(void(^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion {
    NSDictionary *preBody = @{@"filename": fileName ?: @"", @"contentType": mime ?: @"", @"type": type ?: @"",
                              @"size": @(size), @"uploadedAt": isoDate ?: @""};
    NSArray<NSString *> *hosts = [self storageBaseCandidates];
    __block NSInteger hi = 0;
    __block void (^tryNext)(NSError *lastErr);
    tryNext = ^(NSError *lastErr) {
        if (hi >= hosts.count) {
            completion(nil, lastErr ?: [NSError errorWithDomain:@"LocketLegacy" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Upload failed at step 1/3 (presigned URL)"}]);
            return;
        }
        NSString *u = [hosts[hi++] stringByAppendingString:@"/api/presignedV3"];
        [self POSTURL:u body:preBody completion:^(NSDictionary *json, NSInteger status, NSError *error) {
            NSDictionary *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
            BOOL ok = !error && [json[@"status"] isKindOfClass:[NSString class]] &&
                      [json[@"status"] isEqualToString:@"success"] && [data isKindOfClass:[NSDictionary class]];
            if (ok) { completion([self normalizedGrant:data], nil); return; }
            NSString *msg = @"";
            if ([json isKindOfClass:[NSDictionary class]]) {
                id m = json[@"message"];
                if ([m isKindOfClass:[NSString class]] && ((NSString *)m).length) msg = m;
                else {
                    id eobj = json[@"error"];
                    if ([eobj isKindOfClass:[NSDictionary class]] && [eobj[@"message"] isKindOfClass:[NSString class]]) {
                        msg = [NSString stringWithFormat:@"%@: %@", eobj[@"code"] ?: @"error", eobj[@"message"]];
                    }
                }
            }
            if (!msg.length) msg = error ? error.localizedDescription : [NSString stringWithFormat:@"%@ → HTTP %ld", u, (long)status];
            else msg = [NSString stringWithFormat:@"%@ → %@", u, msg];
            tryNext([NSError errorWithDomain:@"LocketLegacy" code:-2 userInfo:@{NSLocalizedDescriptionKey: msg}]);
        }];
    };
    tryNext(nil);
}

- (void)continueOriginalFlowWithGrant:(NSDictionary *)data
                            fileData:(NSData *)fileData
                            fileName:(NSString *)fileName
                                mime:(NSString *)mime
                                type:(NSString *)type
                             caption:(NSString *)caption
                            audience:(NSString *)audience
                               extra:(NSDictionary *)extra
                            progress:(LDProgressBlock)progress
                          completion:(LDJSONCompletion)completion {
        NSString *putURL = [data[@"url"] isKindOfClass:[NSString class]] ? data[@"url"] : nil;
        // Production field names have drifted before; accept known variants.
        NSString *publicURL = nil;
        for (NSString *k in @[@"publicURL", @"publicUrl", @"public_url", @"downloadURL", @"download_url", @"fileUrl", @"file_url"]) {
            id v = data[k];
            if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length > 0) { publicURL = v; break; }
        }
        NSString *key = [data[@"key"] isKindOfClass:[NSString class]] ? data[@"key"] : nil;
        if (!putURL.length || !publicURL.length || !key.length) {
            // Report the actual payload (truncated) so a field rename is diagnosable on-screen.
            NSString *dump = @"{}";
            NSData *jd = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
            if (jd.length) {
                dump = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding] ?: @"{}";
                if (dump.length > 400) dump = [[dump substringToIndex:400] stringByAppendingString:@"…"];
            }
            NSLog(@"presigned response missing fields. putURL=%@ publicURL=%@ key=%@ raw=%@", putURL, publicURL, key, dump);
            NSString *missing = !putURL.length ? @"put-url" : (!key.length ? @"key" : @"public-url");
            NSString *msg = [NSString stringWithFormat:@"Upload failed at step 1/3 (presigned reply lacks %@). Got: %@",
                missing, dump];
            completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-2 userInfo:@{NSLocalizedDescriptionKey: msg}]);
            return;
        }
        // Step 2/3: PUT raw bytes (mirrors StorageServices fetch PUT).
        if (progress) progress(@"2/3 uploading file…");
        NSMutableURLRequest *put = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:putURL]];
        put.HTTPMethod = @"PUT";
        [put setValue:mime forHTTPHeaderField:@"Content-Type"];
        NSURLSessionUploadTask *up = [[NSURLSession sharedSession] uploadTaskWithRequest:put fromData:fileData completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
            NSInteger code = [r isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)r).statusCode : 0;
            if (e || code < 200 || code >= 300) {
                NSString *msg = e ? e.localizedDescription : [NSString stringWithFormat:@"Upload failed at step 2/3 (PUT HTTP %ld)", (long)code];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-3 userInfo:@{NSLocalizedDescriptionKey: msg}]);
                });
                return;
            }
            // Step 3/3: finalize the post.
            if (progress) progress(@"3/3 posting moment…");
            // Prefer the server-chosen object name (basename of its public URL):
            // production stores the file under a renamed object, not our filename.
            NSString *objName = fileName;
            NSURL *pubU = [NSURL URLWithString:publicURL];
            if ([pubU.path.lastPathComponent isKindOfClass:[NSString class]] && pubU.path.lastPathComponent.length > 0) {
                objName = pubU.path.lastPathComponent;
            }
            NSDictionary *mediaInfo = @{@"url": publicURL, @"path": key, @"name": objName,
                                        @"size": @(fileData.length), @"uploadedAt": [[self class] isoNow], @"type": type};
            // Production-issued grant extras the payload builder may require.
            // Sent BOTH inside mediaInfo and top-level: the server half of this
            // contract isn't public, and either location must validate.
            NSMutableDictionary *fullMedia = [mediaInfo mutableCopy];
            for (NSString *k in @[@"mediaSignature", @"owner"]) {
                id v = data[k];
                if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length > 0) { fullMedia[k] = v; }
            }
            mediaInfo = fullMedia;
            NSString *aud = ([audience isKindOfClass:[NSString class]] && audience.length) ? audience : @"all";
            NSMutableDictionary *options = [@{@"caption": caption ?: @"", @"overlay_id": @"standard", @"type": @"default",
                                              @"icon": @"", @"text_color": @"#FFFFFF", @"color_top": @"", @"color_bottom": @"",
                                              @"audience": aud, @"recipients": @[], @"music": @""} mutableCopy];
            if ([extra isKindOfClass:[NSDictionary class]]) {
                for (id k in extra) { if ([k isKindOfClass:[NSString class]]) options[k] = extra[k] ?: @""; }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([[LDConfig backendMode] isEqualToString:@"original"]) {
                    // Production: Dio builds the official payload, then it goes
                    // straight to Locket (markMomentPayloadAsUsed is best-effort
                    // and skipped — no Dio-side moment id is available here).
                    if (progress) progress(@"3/3 asking Dio to build the payload…");
                    NSString *mt = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyMemberToken];
                    NSString *member = ([mt isKindOfClass:[NSString class]] && mt.length) ? @"member:yes" : @"member:NO";
                    [self createMomentPayloadWithMediaInfo:mediaInfo options:options contentType:type completion:^(NSDictionary *json, NSError *error) {
                        if (error) {
                            completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-4 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"step 3/3 (Dio payload, %@): %@", member, error.localizedDescription]}]);
                            return;
                        }
                        id payload = json[@"payload"];
                        if (!payload) {
                            // Surface Dio's own reason (code + message) verbatim.
                            NSString *m = json[@"message"];
                            if (![m isKindOfClass:[NSString class]]) m = json[@"error"];
                            if (![m isKindOfClass:[NSString class]] || !((NSString *)m).length) m = @"Dio built no payload";
                            completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-4 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"step 3/3 (Dio payload, %@): %@", member, m]}]);
                            return;
                        }
                        if (progress) progress(@"4/4 posting to Locket…");
                        [self postOfficialMomentWithPayload:payload completion:^(NSDictionary *j2, NSError *e2) {
                            if (e2) {
                                completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-5 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"step 4/4 (Locket): %@", e2.localizedDescription]}]);
                                return;
                            }
                            completion(j2, nil);
                        }];
                    }];
                    return;
                }
                [self POST:@"/postMomentV2" body:@{@"model": @"Version-UploadmediaV3.1", @"mediaInfo": mediaInfo,
                                                   @"options": options, @"contentType": type} completion:completion];
            });
        }];
        [up resume];
}

#pragma mark - Social / extras

- (void)getOverlaysWithCompletion:(LDJSONCompletion)completion {
    NSString *u = [[LDConfig effectiveBaseAPIURL] stringByAppendingString:@"/api/overlays"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:u]];
    req.HTTPMethod = @"GET";
    [self applyDioHeaders:req];
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSDictionary *json = (d.length && !e) ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) json = @{};
        NSDictionary *j = json;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(j, e); });
    }];
    [t resume];
}

- (void)reactToMoment:(NSString *)momentId emoji:(NSString *)emoji completion:(LDJSONCompletion)completion {
    [self POST:@"/reactToMoment" body:@{@"momentId": momentId ?: @"", @"emoji": emoji ?: @"❤️"} completion:completion];
}

- (void)getMomentReactions:(NSString *)momentId completion:(LDJSONCompletion)completion {
    // Production shape: POST {api}/locket/getMomentReactions {data:{moment_uid}}.
    [self POST:@"/getMomentReactions" body:@{@"data": @{@"moment_uid": momentId ?: @""}} completion:completion];
}

- (void)createMomentPayloadWithMediaInfo:(NSDictionary *)mediaInfo
                                options:(NSDictionary *)options
                            contentType:(NSString *)type
                             completion:(LDJSONCompletion)completion {
    // Production step: POST {api}/locket/createMomentPayloadV2 -> {payload}.
    // Grant extras ride inside mediaInfo AND top-level (server contract half
    // is unpublished; either location must validate).
    NSMutableDictionary *body = [@{@"model": @"Version-UploadmediaV3.1", @"mediaInfo": mediaInfo ?: @{},
                 @"options": options ?: @{}, @"contentType": type ?: @"image"} mutableCopy];
    if ([mediaInfo isKindOfClass:[NSDictionary class]]) {
        for (NSString *k in @[@"mediaSignature", @"owner"]) {
            id v = mediaInfo[k];
            if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length > 0) body[k] = v;
        }
    }
    [self POST:@"/createMomentPayloadV2" body:body completion:completion];
}

- (void)postOfficialMomentWithPayload:(NSDictionary *)payload completion:(LDJSONCompletion)completion {
    [self postOfficialMomentWithPayload:payload retried:NO completion:completion];
}

- (void)postOfficialMomentWithPayload:(NSDictionary *)payload retried:(BOOL)retried completion:(LDJSONCompletion)completion {
    if (![payload isKindOfClass:[NSDictionary class]]) {
        completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-4 userInfo:@{NSLocalizedDescriptionKey: @"Upload failed at step 3/3 (no payload built)"}]);
        return;
    }
    NSString *u = [[LDConfig locketOfficialBaseURL] stringByAppendingString:@"/postMomentV2"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:u]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 30;
    for (NSString *k in [LDConfig locketHeaders]) {
        [req setValue:[LDConfig locketHeaders][k] forHTTPHeaderField:k];
    }
    if (self.idToken.length > 0) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.idToken] forHTTPHeaderField:@"Authorization"];
    }
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSInteger code = [r isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)r).statusCode : 0;
        if (e) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, e); }); return; }
        NSDictionary *json = d.length ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) json = @{};
        // 401 -> refresh the Dio/Firebase token once and retry (mirrors I's interceptor).
        if (!retried && code == 401 && [self tryRefreshThen:^{
            [self postOfficialMomentWithPayload:payload retried:YES completion:completion];
        }]) return;
        NSDictionary *j = json;
        dispatch_async(dispatch_get_main_queue(), ^{
            // Mirrors the web client's ks() checks: errors[] -> message, status>=400, missing data.
            id result = j[@"result"] ?: j[@"data"];
            if ([result isKindOfClass:[NSDictionary class]]) {
                id errs = result[@"errors"];
                if ([errs isKindOfClass:[NSArray class]] && ((NSArray *)errs).count > 0) {
                    NSMutableArray *msgs = [NSMutableArray array];
                    for (id o in (NSArray *)errs) { if ([o isKindOfClass:[NSString class]]) [msgs addObject:o]; }
                    NSString *m = msgs.count ? [msgs componentsJoinedByString:@", "] : @"Locket rejected the post";
                    completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-5 userInfo:@{NSLocalizedDescriptionKey: m}]);
                    return;
                }
            }
            NSInteger st = [j[@"status"] integerValue];
            if (code >= 400 || st >= 400) {
                NSString *m = j[@"message"];
                if (![m isKindOfClass:[NSString class]]) m = j[@"error"];
                if (![m isKindOfClass:[NSString class]] || !((NSString *)m).length) {
                    m = [NSString stringWithFormat:@"HTTP %ld", (long)code];
                } else {
                    m = [NSString stringWithFormat:@"HTTP %ld: %@", (long)code, m];
                }
                completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-5 userInfo:@{NSLocalizedDescriptionKey: m}]);
                return;
            }
            if (!result) {
                completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-5 userInfo:@{NSLocalizedDescriptionKey: @"Locket returned no moment data"}]);
                return;
            }
            completion(j, nil);
        });
    }];
    [t resume];
}

- (void)fetchMemberSessionWithCompletion:(LDJSONCompletion)completion {
    NSString *u = [[LDConfig effectiveBaseAPIURL] stringByAppendingString:@"/api/me"];
    [self GETURL:u retried:NO completion:^(NSDictionary *json, NSInteger status, NSError *e) {
        if (!e && [json isKindOfClass:[NSDictionary class]]) {
            id data = json[@"data"];
            if (![data isKindOfClass:[NSDictionary class]]) data = json;
            id session = [data isKindOfClass:[NSDictionary class]] ? data[@"session"] : nil;
            if (![session isKindOfClass:[NSDictionary class]]) session = data;
            NSString *tok = [session isKindOfClass:[NSDictionary class]] ? session[@"member_token"] : nil;
            if (![tok isKindOfClass:[NSString class]]) {
                tok = [data isKindOfClass:[NSDictionary class]] ? data[@"member_token"] : nil;
            }
            if ([tok isKindOfClass:[NSString class]] && tok.length > 0) {
                [[NSUserDefaults standardUserDefaults] setObject:tok forKey:kLDKeyMemberToken];
                NSString *h = [session isKindOfClass:[NSDictionary class]] ? session[@"header"] : nil;
                [[NSUserDefaults standardUserDefaults] setObject:([h isKindOfClass:[NSString class]] && h.length ? h : kLDDefaultMemberHeader) forKey:kLDKeyMemberHeader];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
        completion(json, e);
    }];
}

- (void)sendMessageWithText:(NSString *)text completion:(LDJSONCompletion)completion {
    [self POST:@"/sendMessage" body:@{@"text": text ?: @""} completion:completion];
}

- (void)registerPushToken:(NSString *)token completion:(LDJSONCompletion)completion {
    NSString *u = [[LDConfig effectiveBaseAPIURL] stringByAppendingString:@"/api/push/register"];
    [self POSTURL:u body:@{@"token": token ?: @"", @"platform": @"ios"} completion:^(NSDictionary *json, NSInteger status, NSError *error) {
        completion(json, error);
    }];
}

@end
