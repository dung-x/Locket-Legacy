#import <Foundation/Foundation.h>
@interface LDMessage : NSObject
@property (nonatomic, copy) NSString *messageId;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *sender;
@property (nonatomic, copy) NSString *createdAt;
+ (instancetype)fromJSON:(NSDictionary *)json;
+ (NSArray<LDMessage *> *)listFromJSON:(id)json;
@end
