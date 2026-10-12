#import <Foundation/Foundation.h>
@interface LDMoment : NSObject
@property (nonatomic, copy) NSString *momentId;
@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, copy) NSString *videoURL;
@property (nonatomic, copy) NSString *caption;
@property (nonatomic, copy) NSString *authorName;
@property (nonatomic, copy) NSString *createdAt;
@property (nonatomic, assign) BOOL isVideo;
+ (instancetype)fromJSON:(NSDictionary *)json;
+ (NSArray<LDMoment *> *)listFromJSON:(id)json;
@end
