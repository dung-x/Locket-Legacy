#import "LDOtaUpdate.h"

static NSString * const kLDOtaOwner = @"dung-x";
static NSString * const kLDOtaRepo  = @"Locket-Legacy";
static NSString * const kLDKeyLastOtaCheck = @"LDOtaLastCheck";

@implementation LDOtaUpdate

+ (NSString *)currentVersion {
    NSString *v = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (![v isKindOfClass:[NSString class]] || !v.length) v = @"0";
    return v;
}

+ (NSInteger)compareVersion:(NSString *)a toVersion:(NSString *)b {
    NSArray *pa = [[a stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"."];
    NSArray *pb = [[b stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"."];
    NSUInteger n = MAX(pa.count, pb.count);
    for (NSUInteger i = 0; i < n; i++) {
        NSInteger va = i < pa.count ? [pa[i] integerValue] : 0;
        NSInteger vb = i < pb.count ? [pb[i] integerValue] : 0;
        if (va > vb) return 1;
        if (va < vb) return -1;
    }
    return 0;
}

+ (void)checkForUpdatesWithCompletion:(LDOtaCheckCompletion)completion {
    NSString *u = [NSString stringWithFormat:@"https://api.github.com/repos/%@/%@/releases/latest", kLDOtaOwner, kLDOtaRepo];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:u]];
    [req setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (e) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, e); }); return; }
        NSDictionary *json = d.length ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) {
            NSError *err = [NSError errorWithDomain:@"LocketLegacy" code:-6 userInfo:@{NSLocalizedDescriptionKey: @"Update check got a bad response"}];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, err); });
            return;
        }
        NSString *tag = [json[@"tag_name"] isKindOfClass:[NSString class]] ? json[@"tag_name"] : @"";
        if ([tag hasPrefix:@"v"] || [tag hasPrefix:@"V"]) tag = [tag substringFromIndex:1];
        NSString *notes = [json[@"body"] isKindOfClass:[NSString class]] ? json[@"body"] : @"";
        NSString *html = [json[@"html_url"] isKindOfClass:[NSString class]] ? json[@"html_url"] : @"";
        NSString *ipaURL = nil;
        id assets = json[@"assets"];
        if ([assets isKindOfClass:[NSArray class]]) {
            for (id a in (NSArray *)assets) {
                if (![a isKindOfClass:[NSDictionary class]]) continue;
                NSString *dl = a[@"browser_download_url"];
                NSString *nm = a[@"name"];
                if ([dl isKindOfClass:[NSString class]] &&
                    ([dl.lowercaseString hasSuffix:@".ipa"] ||
                     ([nm isKindOfClass:[NSString class]] && [((NSString *)nm).lowercaseString hasSuffix:@".ipa"]))) {
                    ipaURL = dl;
                    break;
                }
            }
        }
        NSString *current = [self currentVersion];
        NSDictionary *info = nil;
        if (tag.length > 0 && [self compareVersion:tag toVersion:current] > 0) {
            NSMutableDictionary *m = [@{@"current": current, @"latest": tag, @"notes": notes, @"htmlURL": html} mutableCopy];
            if (ipaURL) m[@"ipaURL"] = ipaURL;
            info = m;
        }
        [[NSUserDefaults standardUserDefaults] setObject:[[NSDate date] description] forKey:kLDKeyLastOtaCheck];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSDictionary *inf = info;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(inf, nil); });
    }];
    [t resume];
}

+ (void)downloadIPAFromURL:(NSString *)urlString
                  progress:(LDOtaProgressBlock)progress
                completion:(LDOtaDownloadCompletion)completion {
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"LocketLegacy" code:-6 userInfo:@{NSLocalizedDescriptionKey: @"No download URL in this release"}]);
        return;
    }
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate:nil
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionDownloadTask *t = [session downloadTaskWithURL:url completionHandler:^(NSURL *loc, NSURLResponse *r, NSError *e) {
        if (e || !loc) {
            completion(nil, e ?: [NSError errorWithDomain:@"LocketLegacy" code:-6 userInfo:@{NSLocalizedDescriptionKey: @"Download failed"}]);
            return;
        }
        NSString *dst = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LocketLegacy-update.ipa"];
        [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
        NSError *moveErr = nil;
        [[NSFileManager defaultManager] moveItemAtURL:loc toURL:[NSURL fileURLWithPath:dst] error:&moveErr];
        if (moveErr) { completion(nil, moveErr); return; }
        completion([NSURL fileURLWithPath:dst], nil);
    }];
    [t resume];
    if (progress) {
        // Lightweight progress pump (download task without delegate).
        __weak NSURLSessionDownloadTask *weak = t;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (weak && weak.state == NSURLSessionTaskStateRunning) {
                int64_t got = weak.countOfBytesReceived;
                int64_t total = weak.countOfBytesExpectedToReceive;
                double f = (total > 0) ? (double)got / (double)total : -1;
                dispatch_async(dispatch_get_main_queue(), ^{ progress(f); });
                [NSThread sleepForTimeInterval:0.25];
            }
        });
    }
}

@end
