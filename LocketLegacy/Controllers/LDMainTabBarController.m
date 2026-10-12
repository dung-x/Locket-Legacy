#import "LDMainTabBarController.h"
#import "LDCameraViewController.h"
#import "LDFeedViewController.h"
#import "LDFriendsViewController.h"
#import "LDChatViewController.h"
#import "LDProfileViewController.h"
#import "../Config.h"

@implementation LDMainTabBarController
- (void)viewDidLoad {
    [super viewDidLoad];
    LDCameraViewController *cam = [[LDCameraViewController alloc] init];
    cam.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Camera" image:nil tag:0];
    LDFeedViewController *feed = [[LDFeedViewController alloc] init];
    feed.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Moments" image:nil tag:1];
    LDFriendsViewController *fr = [[LDFriendsViewController alloc] init];
    fr.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Friends" image:nil tag:2];
    LDChatViewController *chat = [[LDChatViewController alloc] init];
    chat.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Chat" image:nil tag:3];
    LDProfileViewController *me = [[LDProfileViewController alloc] init];
    me.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Profile" image:nil tag:4];
    self.viewControllers = @[
        [[UINavigationController alloc] initWithRootViewController:cam],
        [[UINavigationController alloc] initWithRootViewController:feed],
        [[UINavigationController alloc] initWithRootViewController:fr],
        [[UINavigationController alloc] initWithRootViewController:chat],
        [[UINavigationController alloc] initWithRootViewController:me],
    ];
    self.tabBar.barStyle = UIBarStyleBlack;
    self.tabBar.tintColor = [LDConfig themeAccentColor];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tabBar.tintColor = [LDConfig themeAccentColor];
}
@end
