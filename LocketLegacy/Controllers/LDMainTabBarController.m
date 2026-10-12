#import "LDMainTabBarController.h"
#import "LDCameraViewController.h"
#import "LDFeedViewController.h"
#import "LDFriendsViewController.h"
#import "LDProfileViewController.h"

@implementation LDMainTabBarController
- (void)viewDidLoad {
    [super viewDidLoad];
    LDCameraViewController *cam = [[LDCameraViewController alloc] init];
    cam.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Camera" image:nil tag:0];
    LDFeedViewController *feed = [[LDFeedViewController alloc] init];
    feed.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Moments" image:nil tag:1];
    LDFriendsViewController *fr = [[LDFriendsViewController alloc] init];
    fr.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Friends" image:nil tag:2];
    LDProfileViewController *me = [[LDProfileViewController alloc] init];
    me.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Profile" image:nil tag:3];
    self.viewControllers = @[
        [[UINavigationController alloc] initWithRootViewController:cam],
        [[UINavigationController alloc] initWithRootViewController:feed],
        [[UINavigationController alloc] initWithRootViewController:fr],
        [[UINavigationController alloc] initWithRootViewController:me],
    ];
    self.tabBar.barStyle = UIBarStyleBlack;
    self.tabBar.tintColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
}
@end
