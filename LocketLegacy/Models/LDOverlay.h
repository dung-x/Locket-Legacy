#import <Foundation/Foundation.h>
// Caption overlay theme (mirrors upstream overlay catalog groups).
@interface LDOverlay : NSObject
@property (nonatomic, copy) NSString *overlayId;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *icon;
@property (nonatomic, copy) NSString *textColor;
@property (nonatomic, copy) NSString *colorTop;
@property (nonatomic, copy) NSString *colorBottom;
+ (instancetype)fromJSON:(NSDictionary *)json;
+ (NSArray<LDOverlay *> *)listFromJSON:(id)json; // grouped dict or flat array
+ (LDOverlay *)standardOverlay;
@end
