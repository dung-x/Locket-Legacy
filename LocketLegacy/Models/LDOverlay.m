#import "LDOverlay.h"
@implementation LDOverlay
+ (NSString *)str:(id)v { return [v isKindOfClass:[NSString class]] ? v : @""; }
+ (instancetype)fromJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    LDOverlay *o = [[LDOverlay alloc] init];
    o.overlayId = [self str:json[@"overlay_id"]];
    if (!o.overlayId.length) o.overlayId = [self str:json[@"id"]];
    o.type = [self str:json[@"type"]];
    o.title = [self str:json[@"title"]];
    if (!o.title.length) o.title = o.overlayId;
    o.icon = [self str:json[@"icon"]];
    o.textColor = [self str:json[@"text_color"]];
    if (!o.textColor.length) o.textColor = @"#FFFFFF";
    o.colorTop = [self str:json[@"color_top"]];
    o.colorBottom = [self str:json[@"color_bottom"]];
    return o;
}
+ (NSArray<LDOverlay *> *)listFromJSON:(id)json {
    id d = json;
    if ([json isKindOfClass:[NSDictionary class]] && json[@"data"]) d = json[@"data"];
    NSMutableArray *out = [NSMutableArray array];
    void (^add)(id) = ^(id arr) {
        if (![arr isKindOfClass:[NSArray class]]) return;
        for (id o in arr) { LDOverlay *t = [self fromJSON:o]; if (t) [out addObject:t]; }
    };
    if ([d isKindOfClass:[NSArray class]]) add(d);
    else if ([d isKindOfClass:[NSDictionary class]]) {
        for (id k in d) add(d[k]);
    }
    if (!out.count) [out addObject:[self standardOverlay]];
    return out;
}
+ (LDOverlay *)standardOverlay {
    LDOverlay *o = [[LDOverlay alloc] init];
    o.overlayId = @"standard"; o.type = @"default"; o.title = @"Standard";
    o.icon = @""; o.textColor = @"#FFFFFF"; o.colorTop = @""; o.colorBottom = @"";
    return o;
}
@end
