// LDMediaLoader — image fetch with an authenticated retry.
// Some media hosts reject anonymous fetches; the loader first tries plain,
// then retries with the app's Bearer + Dio headers, and always reports the
// HTTP status so failures are diagnosable on-screen instead of blank cells.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LDMediaCompletion)(UIImage * _Nullable image, NSInteger status, NSError * _Nullable error);

@interface LDMediaLoader : NSObject
+ (void)loadImageWithURLString:(NSString *)urlString completion:(LDMediaCompletion)completion;
@end

NS_ASSUME_NONNULL_END
