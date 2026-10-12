#import "LDDiskCache.h"

@implementation LDDiskCache

+ (NSString *)cachePath:(NSString *)name {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [[dirs firstObject] stringByAppendingPathComponent:name];
}

+ (void)saveJSON:(id)json name:(NSString *)name {
    if (!json) return;
    NSData *d = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    if (d) [d writeToFile:[self cachePath:name] atomically:YES];
}

+ (id)loadJSON:(NSString *)name {
    NSData *d = [NSData dataWithContentsOfFile:[self cachePath:name]];
    if (!d.length) return nil;
    return [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
}

+ (void)saveMomentsJSON:(id)json { [self saveJSON:json name:@"moments.json"]; }
+ (id)loadMomentsJSON { return [self loadJSON:@"moments.json"]; }
+ (void)saveFriendsJSON:(id)json { [self saveJSON:json name:@"friends.json"]; }
+ (id)loadFriendsJSON { return [self loadJSON:@"friends.json"]; }
+ (void)saveMessagesJSON:(id)json { [self saveJSON:json name:@"messages.json"]; }
+ (id)loadMessagesJSON { return [self loadJSON:@"messages.json"]; }
+ (void)saveOverlaysJSON:(id)json { [self saveJSON:json name:@"overlays.json"]; }
+ (id)loadOverlaysJSON { return [self loadJSON:@"overlays.json"]; }

+ (NSString *)outboxDir {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *p = [[dirs firstObject] stringByAppendingPathComponent:@"Outbox"];
    [[NSFileManager defaultManager] createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
    return p;
}

+ (NSString *)isoNow {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    f.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    return [f stringFromDate:[NSDate date]];
}

+ (NSDictionary *)stageOutboxItemWithFileURL:(NSURL *)src isVideo:(BOOL)isVideo caption:(NSString *)caption audience:(NSString *)audience {
    if (!src) return nil;
    NSString *itemId = [[NSUUID UUID] UUIDString];
    NSString *ext = isVideo ? @"mov" : @"jpg";
    NSString *dst = [[[self outboxDir] stringByAppendingPathComponent:itemId] stringByAppendingPathExtension:ext];
    NSError *e = nil;
    [[NSFileManager defaultManager] copyItemAtPath:src.path toPath:dst error:&e];
    if (e) return nil;
    NSDictionary *item = @{@"id": itemId, @"filePath": dst, @"isVideo": @(isVideo),
                           @"caption": caption ?: @"", @"audience": audience ?: @"all",
                           @"createdAt": [self isoNow], @"status": @"queued"};
    NSString *meta = [[[self outboxDir] stringByAppendingPathComponent:itemId] stringByAppendingPathExtension:@"json"];
    NSData *d = [NSJSONSerialization dataWithJSONObject:item options:0 error:nil];
    [d writeToFile:meta atomically:YES];
    return item;
}

+ (NSArray<NSDictionary *> *)pendingOutboxItems {
    NSMutableArray *out = [NSMutableArray array];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self outboxDir] error:nil] ?: @[];
    for (NSString *f in files) {
        if (![[f pathExtension] isEqualToString:@"json"]) continue;
        NSData *d = [NSData dataWithContentsOfFile:[[self outboxDir] stringByAppendingPathComponent:f]];
        NSDictionary *item = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        if ([item isKindOfClass:[NSDictionary class]] && ![item[@"status"] isEqualToString:@"done"]) {
            [out addObject:item];
        }
    }
    return out;
}

+ (void)removeOutboxItem:(NSString *)itemId {
    if (!itemId.length) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [self outboxDir];
    [fm removeItemAtPath:[[dir stringByAppendingPathComponent:itemId] stringByAppendingPathExtension:@"json"] error:nil];
    [fm removeItemAtPath:[[dir stringByAppendingPathComponent:itemId] stringByAppendingPathExtension:@"jpg"] error:nil];
    [fm removeItemAtPath:[[dir stringByAppendingPathComponent:itemId] stringByAppendingPathExtension:@"mov"] error:nil];
}

+ (void)markOutboxSent:(NSString *)itemId error:(NSString *)error {
    if (!itemId.length) return;
    NSString *meta = [[[self outboxDir] stringByAppendingPathComponent:itemId] stringByAppendingPathExtension:@"json"];
    NSData *d = [NSData dataWithContentsOfFile:meta];
    NSMutableDictionary *item = d ? [[NSJSONSerialization JSONObjectWithData:d options:0 error:nil] mutableCopy] : nil;
    if (![item isKindOfClass:[NSMutableDictionary class]]) return;
    if (error) { item[@"status"] = @"failed"; item[@"error"] = error; }
    else { item[@"status"] = @"done"; }
    NSData *out = [NSJSONSerialization dataWithJSONObject:item options:0 error:nil];
    [out writeToFile:meta atomically:YES];
    if (!error) {
        // Drop the bulky media copy a moment later (next load prunes done items).
        [self removeOutboxItem:itemId];
    }
}

@end
