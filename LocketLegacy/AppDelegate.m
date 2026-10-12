#import "AppDelegate.h"
#import "Controllers/LDLoginViewController.h"
#import "Controllers/LDMainTabBarController.h"
#import "Config.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];

    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyIDToken];
    UIViewController *root;
    if (token.length > 0) {
        root = [[LDMainTabBarController alloc] init];
    } else {
        root = [[LDLoginViewController alloc] init];
    }
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    nav.navigationBarHidden = YES;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
