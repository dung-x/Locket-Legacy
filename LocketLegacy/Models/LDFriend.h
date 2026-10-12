#import <Foundation/Foundation.h>
@interface LDFriend : NSObject
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *profilePicture;
+ (instancetype)fromJSON:(NSDictionary *)json;
+ (NSArray<LDFriend *> *)listFromJSON:(id)json;
@end
