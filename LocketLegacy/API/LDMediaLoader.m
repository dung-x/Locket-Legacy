#import "LDMediaLoader.h"
#import "../Config.h"

@implementation LDMediaLoader

+ (void)fetch:(NSURL *)url authed:(BOOL)authed completion:(void(^)(NSData * _Nullable data, NSInteger status, NSError * _Nullable error))completion {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"GET";
    req.timeoutInterval = 30;
    if (authed) {
        for (NSString *k in [LDConfig dioHeaders]) {
            [req setValue:[LDConfig dioHeaders][k] forHTTPHeaderField:k];
        }
        NSString *tok = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyIDToken];
        if ([tok isKindOfClass:[NSString class]] && tok.length > 0) {
            [req setValue:[NSString stringWithFormat:@"Bearer %@", tok] forHTTPHeaderField:@"Authorization"];
        }
        NSString *mt = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyMemberToken];
        if ([mt isKindOfClass:[NSString class]] && mt.length > 0) {
            NSString *mh = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyMemberHeader];
            if (![mh isKindOfClass:[NSString class]] || !mh.length) mh = @"X-LocketDio-Member";
            [req setValue:mt forHTTPHeaderField:mh];
        }
    }
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        NSInteger code = [r isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)r).statusCode : 0;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(d, code, e); });
    }];
    [t resume];
}

+ (void)loadImageWithURLString:(NSString *)urlString completion:(LDMediaCompletion)completion {
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    if (!url) {
        completion(nil, 0, [NSError errorWithDomain:@"LocketLegacy" code:-7 userInfo:@{NSLocalizedDescriptionKey: @"bad media URL"}]);
        return;
    }
    [self fetch:url authed:NO completion:^(NSData *d, NSInteger status, NSError *e) {
        UIImage *img = (d.length && !e && (status == 0 || (status >= 200 && status < 300))) ? [UIImage imageWithData:d] : nil;
        if (img) { completion(img, status, nil); return; }
        // Retry authenticated (private CDN / signed hosts often need it).
        [self fetch:url authed:YES completion:^(NSData *d2, NSInteger status2, NSError *e2) {
            UIImage *img2 = (d2.length && !e2 && (status2 == 0 || (status2 >= 200 && status2 < 300))) ? [UIImage imageWithData:d2] : nil;
            if (img2) { completion(img2, status2, nil); return; }
            NSString *why = e2 ? e2.localizedDescription : (e ? e.localizedDescription : [NSString stringWithFormat:@"HTTP %ld", (long)(status2 ?: status)]);
            NSError *err = [NSError errorWithDomain:@"LocketLegacy" code:-7 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"img %@ (%@)", why, url.host ?: @"?"]}];
            completion(nil, status2 ?: status, err);
        }];
    }];
}

@end
