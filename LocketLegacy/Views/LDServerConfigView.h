// Shared backend picker used by Login (logged out) and Settings (logged in):
// preset Self-host / Original API, custom URL row, Scan QR, Test connection.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LDServerConfigView : UIView
- (instancetype)initWithOwner:(UIViewController *)owner;
- (void)refresh;
@property (nonatomic, strong, readonly) UILabel *statusLabel;
@end

NS_ASSUME_NONNULL_END
