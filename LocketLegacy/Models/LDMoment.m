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
+ (instancetype)fromJSON:(NSDictionary *)json {
    LDMoment *m = [[LDMoment alloc] init];
    m.momentId = [self str:json[@"id"]].length ? [self str:json[@"id"]] : [self str:json[@"moment_id"]];
    // media may be nested under different keys depending on backend version
    NSString *url = [self str:json[@"image_url"]];
    if (!url.length) url = [self str:json[@"url"]];
    if (!url.length && [json[@"mediaInfo"] isKindOfClass:[NSDictionary class]]) url = [self str:json[@"mediaInfo"][@"url"]];
    if (!url.length && [json[@"media"] isKindOfClass:[NSDictionary class]]) url = [self str:json[@"media"][@"url"]];
    url = [self absURL:url];
    m.imageURL = url; m.videoURL = @"";
    NSString *ct = [self str:json[@"contentType"]];
    if (!ct.length && [json[@"mediaInfo"] isKindOfClass:[NSDictionary class]]) ct = [self str:json[@"mediaInfo"][@"contentType"]];
    m.isVideo = ([url rangeOfString:@".mp4"].location != NSNotFound) || ([ct rangeOfString:@"video"].location != NSNotFound);
    if (m.isVideo) { m.videoURL = url; m.imageURL = @""; }
    m.caption = [self str:json[@"caption"]];
    if (!m.caption.length && [json[@"options"] isKindOfClass:[NSDictionary class]]) m.caption = [self str:json[@"options"][@"caption"]];
    m.authorName = [self str:json[@"author"]];
    if (!m.authorName.length) m.authorName = [self str:json[@"displayName"]];
    m.createdAt = [self str:json[@"createdAt"]];
    if (!m.createdAt.length) m.createdAt = [self str:json[@"timeCreated"]];
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
