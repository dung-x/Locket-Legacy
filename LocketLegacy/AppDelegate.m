#import "AppDelegate.h"
#import "Controllers/LDLoginViewController.h"
#import "Controllers/LDMainTabBarController.h"
#import "API/LDAPIClient.h"
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

    // Push opt-in (registers only when the user enabled it in Profile).
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:kLDKeyPushEnabled] boolValue]) {
        [application registerForRemoteNotifications];
    }
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    const unsigned char *bytes = (const unsigned char *)deviceToken.bytes;
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger i = 0; i < deviceToken.length; i++) [hex appendFormat:@"%02x", bytes[i]];
    [[LDAPIClient shared] registerPushToken:hex completion:^(NSDictionary *json, NSError *error) {
        if (error) NSLog(@"push register failed: %@", error);
    }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"push register failed (simulator has no APNs): %@", error);
}

@end
