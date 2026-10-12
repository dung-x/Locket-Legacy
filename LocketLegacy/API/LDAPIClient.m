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

@end
