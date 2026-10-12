#import <Foundation/Foundation.h>
@interface LDUser : NSObject
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *profilePicture;
@property (nonatomic, copy) NSString *username;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end
