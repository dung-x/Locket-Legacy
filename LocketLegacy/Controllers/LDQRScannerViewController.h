#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LDQRScanCompletion)(NSString * _Nullable value);

/* QR scanner (AVFoundation metadata output, iOS 7+ safe).
 * Accepts: raw http(s) URL, locketlegacy://connect?api=<urlencoded>, or JSON {"api":"..."}.
 */
@interface LDQRScannerViewController : UIViewController
- (instancetype)initWithCompletion:(LDQRScanCompletion)completion;
+ (nullable NSString *)apiURLFromScannedString:(nullable NSString *)raw;
@end

NS_ASSUME_NONNULL_END
