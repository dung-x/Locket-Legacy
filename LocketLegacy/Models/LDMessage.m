#import "LDMessage.h"
@implementation LDMessage
+ (NSString *)str:(id)v { return [v isKindOfClass:[NSString class]] ? v : @""; }
+ (instancetype)fromJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    LDMessage *m = [[LDMessage alloc] init];
    m.messageId = [self str:json[@"id"]].length ? [self str:json[@"id"]] : [self str:json[@"message_uid"]];
    m.text = [self str:json[@"text"]];
    if (!m.text.length) m.text = [self str:json[@"msg"]];
    m.sender = [self str:json[@"sender"]];
    m.createdAt = [self str:json[@"createdAt"]];
    if (!m.createdAt.length) m.createdAt = [self str:json[@"created_at"]];
    return m;
}
+ (NSArray<LDMessage *> *)listFromJSON:(id)json {
    NSArray *arr = nil;
    if ([json isKindOfClass:[NSArray class]]) arr = json;
    else if ([json isKindOfClass:[NSDictionary class]]) {
        id d = json[@"data"];
        if ([d isKindOfClass:[NSArray class]]) arr = d;
    }
    NSMutableArray *out = [NSMutableArray array];
    for (id o in arr ?: @[]) { LDMessage *m = [self fromJSON:o]; if (m) [out addObject:m]; }
    return out;
}
@end
