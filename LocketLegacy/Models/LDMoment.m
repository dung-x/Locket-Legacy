#import "LDMoment.h"
#import "../Config.h"
@implementation LDMoment
+ (NSString *)str:(id)v { return [v isKindOfClass:[NSString class]] ? v : @""; }
+ (NSString *)absURL:(NSString *)url {
    // Older/self-hosted backends may return a bare "/uploads/…" path, which
    // NSURL cannot resolve on its own — prefix the configured API host.
    if (url.length > 0 && [url hasPrefix:@"/"]) {
        NSString *base = [LDConfig baseAPIURL];
        while (base.length > 1 && [base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
        return [base stringByAppendingString:url];
    }
    return url;
}
+ (NSString *)cdnURL:(NSString *)url {
    // Mirror the web client's Jn(): firebasestorage origins don't load
    // everywhere; the CDN mirror does.
    NSString *from = @"https://firebasestorage.googleapis.com";
    if (url.length > from.length && [[url substringToIndex:from.length] isEqualToString:from]) {
        return [@"https://cdn.locketcamera.com" stringByAppendingString:[url substringFromIndex:from.length]];
    }
    return url;
}
+ (instancetype)fromJSON:(NSDictionary *)json {
    LDMoment *m = [[LDMoment alloc] init];
    m.momentId = [self str:json[@"id"]].length ? [self str:json[@"id"]] : [self str:json[@"moment_id"]];
    // Production shape (official Locket): image_url / video_url / thumbnail_url,
    // captions[] with {text,…}, user{}, date. Self-host variants fall back below.
    NSString *img = [self str:json[@"image_url"]];
    if (!img.length) img = [self str:json[@"url"]];
    if (!img.length && [json[@"mediaInfo"] isKindOfClass:[NSDictionary class]]) img = [self str:json[@"mediaInfo"][@"url"]];
    if (!img.length && [json[@"media"] isKindOfClass:[NSDictionary class]]) img = [self str:json[@"media"][@"url"]];
    NSString *vid = [self str:json[@"video_url"]];
    NSString *thumb = [self str:json[@"thumbnail_url"]];
    img = [self cdnURL:[self absURL:img]];
    vid = [self cdnURL:[self absURL:vid]];
    thumb = [self cdnURL:[self absURL:thumb]];
    m.imageURL = img; m.videoURL = vid; m.thumbnailURL = thumb;
    NSString *ct = [self str:json[@"contentType"]];
    if (!ct.length && [json[@"mediaInfo"] isKindOfClass:[NSDictionary class]]) ct = [self str:json[@"mediaInfo"][@"contentType"]];
    m.isVideo = vid.length > 0 || ([img rangeOfString:@".mp4"].location != NSNotFound) || ([ct rangeOfString:@"video"].location != NSNotFound);
    if (m.isVideo && !m.videoURL.length) { m.videoURL = img; m.imageURL = @""; }
    NSString *cap = @"";
    id captions = json[@"captions"];
    if ([captions isKindOfClass:[NSArray class]]) {
        for (id c in captions) {
            if ([c isKindOfClass:[NSDictionary class]]) {
                NSString *t = [self str:c[@"text"]];
                if (t.length) { cap = t; break; }
            }
        }
    }
    if (!cap.length) cap = [self str:json[@"caption"]];
    if (!cap.length && [json[@"options"] isKindOfClass:[NSDictionary class]]) cap = [self str:json[@"options"][@"caption"]];
    m.caption = cap;
    id user = json[@"user"];
    NSString *who = @"";
    if ([user isKindOfClass:[NSDictionary class]]) {
        who = [self str:user[@"displayName"]];
        if (!who.length) who = [self str:user[@"display_name"]];
        if (!who.length) who = [self str:user[@"username"]];
        if (!who.length) who = [self str:user[@"firstName"]];
    }
    if (!who.length) who = [self str:json[@"author"]];
    if (!who.length) who = [self str:json[@"displayName"]];
    m.authorName = who;
    m.createdAt = [self str:json[@"date"]];
    if (!m.createdAt.length) m.createdAt = [self str:json[@"createdAt"]];
    if (!m.createdAt.length) m.createdAt = [self str:json[@"timeCreated"]];
    id rx = json[@"reactions"];
    m.reactions = [rx isKindOfClass:[NSDictionary class]] ? rx : @{};
    return m;
}
+ (NSArray<LDMoment *> *)listFromJSON:(id)json {
    NSArray *arr = nil;
    if ([json isKindOfClass:[NSArray class]]) arr = json;
    else if ([json isKindOfClass:[NSDictionary class]]) {
        id d = json[@"data"];
        if ([d isKindOfClass:[NSArray class]]) arr = d;
        else if ([d isKindOfClass:[NSDictionary class]] && [d[@"moments"] isKindOfClass:[NSArray class]]) arr = d[@"moments"];
    }
    NSMutableArray *out = [NSMutableArray array];
    for (id o in arr ?: @[]) { if ([o isKindOfClass:[NSDictionary class]]) [out addObject:[self fromJSON:o]]; }
    return out;
}
@end
