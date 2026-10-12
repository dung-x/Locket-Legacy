#import "LDAPIClient.h"
#import "../Config.h"

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
    return [[LDConfig baseAPIURL] stringByAppendingString:@"/locket"];
}

- (void)POST:(NSString *)path body:(nullable NSDictionary *)body completion:(LDJSONCompletion)completion {
    NSString *urlStr = [[self baseURL] stringByAppendingString:path];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
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
        dispatch_async(dispatch_get_main_queue(), ^{ completion(json, nil); });
    }];
    [t resume];
}

- (void)loginWithEmail:(NSString *)email password:(NSString *)password completion:(LDJSONCompletion)completion {
    [self POST:@"/login" body:@{@"email": email ?: @"", @"password": password ?: @""} completion:^(NSDictionary *json, NSError *err) {
        if (!err) {
            NSDictionary *data = json[@"data"];
            NSString *tok = data[@"idToken"];
            if (![tok isKindOfClass:[NSString class]]) tok = data[@"access_token"];
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
    }];
}

- (void)refreshToken:(NSString *)refreshToken completion:(LDJSONCompletion)completion {
    [self POST:@"/refresh-token" body:@{@"refreshToken": refreshToken ?: @""} completion:completion];
}

- (void)logoutWithCompletion:(LDJSONCompletion)completion {
    NSString *urlStr = [[self baseURL] stringByAppendingString:@"/logout"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"GET";
    if (self.idToken.length > 0) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.idToken] forHTTPHeaderField:@"Authorization"];
    }
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        self.idToken = nil;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLDKeyIDToken];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLDKeyRefreshToken];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSDictionary *json = d.length ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : @{};
        dispatch_async(dispatch_get_main_queue(), ^{ completion(json ?: @{}, e); });
    }];
    [t resume];
}

- (void)getInfoUserWithCompletion:(LDJSONCompletion)completion {
    [self POST:@"/getInfoUser" body:@{} completion:completion];
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

- (void)postMomentV1WithFileURL:(NSURL *)fileURL isVideo:(BOOL)isVideo caption:(NSString *)caption completion:(LDJSONCompletion)completion {
    NSString *urlStr = [[self baseURL] stringByAppendingString:@"/postMomentV1"];
    NSString *boundary = @"----LocketLegacyBoundary1234";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    if (self.idToken.length > 0) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.idToken] forHTTPHeaderField:@"Authorization"];
    }
    NSMutableData *body = [NSMutableData data];
    NSString *opts = [NSString stringWithFormat:@"{\"caption\":\"%@\"}", [[caption stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""] description]];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"optionsData\"\r\n\r\n%@\r\n", boundary, opts] dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    if (!fileData) { completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Cannot read media file"}]); return; }
    NSString *fname = isVideo ? @"clip.mp4" : @"photo.jpg";
    NSString *mime = isVideo ? @"video/mp4" : @"image/jpeg";
    [body appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n", boundary, fname, mime] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:fileData];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    req.HTTPBody = body;
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSDictionary *json = d.length ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : @{};
        dispatch_async(dispatch_get_main_queue(), ^{ completion(json ?: @{}, e); });
    }];
    [t resume];
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

// Storage hosts to try, in order: the API host itself (bundled mock), then the
// same host with :5001 -> :5003 (upstream split-host layout).
- (NSArray<NSString *> *)storageBaseCandidates {
    NSString *base = [LDConfig baseAPIURL];
    while (base.length > 1 && [base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    NSMutableArray *out = [NSMutableArray arrayWithObject:base];
    NSRange r = [base rangeOfString:@":5001"];
    if (r.location != NSNotFound) {
        NSString *alt = [base stringByReplacingCharactersInRange:r withString:@":5003"];
        if (![alt isEqualToString:base]) [out addObject:alt];
    }
    return out;
}

- (void)POSTURL:(NSString *)urlStr body:(NSDictionary *)body completion:(void(^)(NSDictionary * _Nullable json, NSInteger status, NSError * _Nullable error))completion {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
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

- (void)sendMomentOriginalFlowWithFileURL:(NSURL *)fileURL
                                 isVideo:(BOOL)isVideo
                                 caption:(NSString *)caption
                                audience:(NSString *)audience
                                progress:(LDProgressBlock)progress
                              completion:(LDJSONCompletion)completion {
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    if (!fileData.length) {
        completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Cannot read media file"}]);
        return;
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
    NSArray<NSString *> *hosts = [self storageBaseCandidates];
    __block NSInteger hi = 0;
    __block void (^tryNext)(NSError *lastErr);
    void (^finishPre)(NSDictionary *, NSError *) = ^(NSDictionary *data, NSError *err) {
        if (err || ![data isKindOfClass:[NSDictionary class]]) {
            completion(nil, err ?: [NSError errorWithDomain:@"LocketLegacy" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Upload failed at step 1/3 (presigned URL)"}]);
            return;
        }
        NSString *putURL = [data[@"url"] isKindOfClass:[NSString class]] ? data[@"url"] : nil;
        NSString *publicURL = [data[@"publicURL"] isKindOfClass:[NSString class]] ? data[@"publicURL"] : nil;
        NSString *key = [data[@"key"] isKindOfClass:[NSString class]] ? data[@"key"] : nil;
        if (!putURL.length || !publicURL.length || !key.length) {
            completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Upload failed at step 1/3 (bad presigned response)"}]);
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
            // Step 3/3: postMomentV2 (mirrors PostMoments + V5 options shape).
            if (progress) progress(@"3/3 posting moment…");
            NSDictionary *mediaInfo = @{@"url": publicURL, @"path": key, @"name": fileName,
                                        @"size": @(fileData.length), @"uploadedAt": [[self class] isoNow], @"type": type};
            NSString *aud = ([audience isKindOfClass:[NSString class]] && audience.length) ? audience : @"all";
            NSDictionary *options = @{@"caption": caption ?: @"", @"overlay_id": @"", @"type": @"",
                                      @"icon": @"", @"text_color": @"", @"color_top": @"", @"color_bottom": @"",
                                      @"audience": aud, @"recipients": @[], @"music": @""};
            dispatch_async(dispatch_get_main_queue(), ^{
                [self POST:@"/postMomentV2" body:@{@"model": @"Version-UploadmediaV3.1", @"mediaInfo": mediaInfo,
                                                   @"options": options, @"contentType": type} completion:completion];
            });
        }];
        [up resume];
    };
    tryNext = ^(NSError *lastErr) {
        if (hi >= hosts.count) {
            finishPre(nil, lastErr);
            return;
        }
        NSString *u = [hosts[hi++] stringByAppendingString:@"/api/presignedV3"];
        [self POSTURL:u body:preBody completion:^(NSDictionary *json, NSInteger status, NSError *error) {
            NSDictionary *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
            BOOL ok = !error && [json[@"status"] isKindOfClass:[NSString class]] &&
                      [json[@"status"] isEqualToString:@"success"] && [data isKindOfClass:[NSDictionary class]];
            if (ok) finishPre(data, nil);
            else {
                NSString *msg = @"";
                if ([json isKindOfClass:[NSDictionary class]]) {
                    id m = json[@"message"];
                    if ([m isKindOfClass:[NSString class]]) msg = m;
                }
                if (!msg.length) msg = error ? error.localizedDescription : [NSString stringWithFormat:@"HTTP %ld", (long)status];
                tryNext([NSError errorWithDomain:@"LocketLegacy" code:-2 userInfo:@{NSLocalizedDescriptionKey: msg}]);
            }
        }];
    };
    tryNext(nil);
}

@end
