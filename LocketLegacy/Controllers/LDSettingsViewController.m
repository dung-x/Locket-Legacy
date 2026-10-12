// Settings page: backend preset (self-host Docker / original Locket Dio API),
// appearance, notifications, storage, about, logout.
#import "LDSettingsViewController.h"
#import "../API/LDAPIClient.h"
#import "../API/LDDiskCache.h"
#import "../Views/LDServerConfigView.h"
#import "../Config.h"
#import "LDLoginViewController.h"

@interface LDSettingsViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) LDServerConfigView *serverView;
@property (nonatomic, strong) UISegmentedControl *themeControl;
@property (nonatomic, strong) UISwitch *pushSwitch;
@property (nonatomic, strong) UILabel *storageLabel;
@end

@implementation LDSettingsViewController

- (UILabel *)section:(NSString *)text inView:(UIView *)V below:(UIView *)above gap:(CGFloat)gap {
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    l.font = [UIFont boldSystemFontOfSize:13];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:l];
    [NSLayoutConstraint activateConstraints:@[
        [l.topAnchor constraintEqualToAnchor:above.bottomAnchor constant:gap],
        [l.leadingAnchor constraintEqualToAnchor:V.leadingAnchor constant:20],
        [l.trailingAnchor constraintEqualToAnchor:V.trailingAnchor constant:-20],
    ]];
    return l;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.view.backgroundColor = [UIColor blackColor];

    self.scroll = [[UIScrollView alloc] init];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scroll];
    UIView *V = [[UIView alloc] init];
    V.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:V];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [V.topAnchor constraintEqualToAnchor:self.scroll.topAnchor],
        [V.leadingAnchor constraintEqualToAnchor:self.scroll.leadingAnchor],
        [V.trailingAnchor constraintEqualToAnchor:self.scroll.trailingAnchor],
        [V.bottomAnchor constraintEqualToAnchor:self.scroll.bottomAnchor],
        [V.widthAnchor constraintEqualToAnchor:self.scroll.widthAnchor],
    ]];

    // Anchor for the first section.
    UIView *topPad = [[UIView alloc] init];
    topPad.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:topPad];
    [NSLayoutConstraint activateConstraints:@[
        [topPad.topAnchor constraintEqualToAnchor:V.topAnchor],
        [topPad.leadingAnchor constraintEqualToAnchor:V.leadingAnchor],
        [topPad.heightAnchor constraintEqualToConstant:8],
    ]];

    [self section:@"BACKEND" inView:V below:topPad gap:8];
    self.serverView = [[LDServerConfigView alloc] initWithOwner:self];
    [V addSubview:self.serverView];
    [NSLayoutConstraint activateConstraints:@[
        [self.serverView.topAnchor constraintEqualToAnchor:topPad.bottomAnchor constant:30],
        [self.serverView.leadingAnchor constraintEqualToAnchor:V.leadingAnchor constant:20],
        [self.serverView.trailingAnchor constraintEqualToAnchor:V.trailingAnchor constant:-20],
    ]];

    UILabel *appCap = [self section:@"APPEARANCE — 🎨 camera accent theme" inView:V below:self.serverView gap:20];
    (void)appCap;
    self.themeControl = [[UISegmentedControl alloc] initWithItems:@[@"Gold", @"Violet", @"Ocean"]];
    NSString *theme = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyCameraTheme];
    if ([theme isEqualToString:@"violet"]) self.themeControl.selectedSegmentIndex = 1;
    else if ([theme isEqualToString:@"ocean"]) self.themeControl.selectedSegmentIndex = 2;
    else self.themeControl.selectedSegmentIndex = 0;
    [self.themeControl addTarget:self action:@selector(onTheme) forControlEvents:UIControlEventValueChanged];
    self.themeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.themeControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.themeControl.topAnchor constraintEqualToAnchor:self.serverView.bottomAnchor constant:44],
        [self.themeControl.leadingAnchor constraintEqualToAnchor:V.leadingAnchor constant:20],
        [self.themeControl.trailingAnchor constraintEqualToAnchor:V.trailingAnchor constant:-20],
    ]];

    UILabel *pushCap = [self section:@"NOTIFICATIONS — 🔔 push on this device" inView:V below:self.themeControl gap:20];
    (void)pushCap;
    self.pushSwitch = [[UISwitch alloc] init];
    self.pushSwitch.on = [[[NSUserDefaults standardUserDefaults] objectForKey:kLDKeyPushEnabled] boolValue];
    [self.pushSwitch addTarget:self action:@selector(onPush) forControlEvents:UIControlEventValueChanged];
    self.pushSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.pushSwitch];
    [NSLayoutConstraint activateConstraints:@[
        [self.pushSwitch.topAnchor constraintEqualToAnchor:self.themeControl.bottomAnchor constant:44],
        [self.pushSwitch.leadingAnchor constraintEqualToAnchor:V.leadingAnchor constant:20],
    ]];

    UILabel *stCap = [self section:@"STORAGE — offline cache & outbox" inView:V below:self.pushSwitch gap:20];
    (void)stCap;
    self.storageLabel = [[UILabel alloc] init];
    self.storageLabel.textColor = [UIColor lightGrayColor];
    self.storageLabel.font = [UIFont systemFontOfSize:13];
    self.storageLabel.numberOfLines = 0;
    self.storageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.storageLabel];
    UIButton *clearCache = [UIButton buttonWithType:UIButtonTypeSystem];
    [clearCache setTitle:@"Clear cached data" forState:UIControlStateNormal];
    [clearCache addTarget:self action:@selector(onClearCache) forControlEvents:UIControlEventTouchUpInside];
    clearCache.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:clearCache];
    UIButton *clearOutbox = [UIButton buttonWithType:UIButtonTypeSystem];
    [clearOutbox setTitle:@"Clear outbox" forState:UIControlStateNormal];
    [clearOutbox addTarget:self action:@selector(onClearOutbox) forControlEvents:UIControlEventTouchUpInside];
    clearOutbox.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:clearOutbox];
    [NSLayoutConstraint activateConstraints:@[
        [self.storageLabel.topAnchor constraintEqualToAnchor:self.pushSwitch.bottomAnchor constant:44],
        [self.storageLabel.leadingAnchor constraintEqualToAnchor:V.leadingAnchor constant:20],
        [self.storageLabel.trailingAnchor constraintEqualToAnchor:V.trailingAnchor constant:-20],
        [clearCache.topAnchor constraintEqualToAnchor:self.storageLabel.bottomAnchor constant:8],
        [clearCache.leadingAnchor constraintEqualToAnchor:V.leadingAnchor constant:20],
        [clearOutbox.topAnchor constraintEqualToAnchor:self.storageLabel.bottomAnchor constant:8],
        [clearOutbox.leadingAnchor constraintEqualToAnchor:clearCache.trailingAnchor constant:24],
    ]];

    UILabel *abCap = [self section:@"ABOUT" inView:V below:clearCache gap:20];
    (void)abCap;
    UILabel *about = [[UILabel alloc] init];
    NSString *ver = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (![ver isKindOfClass:[NSString class]]) ver = @"?";
    about.text = [NSString stringWithFormat:@"Locket Legacy %@ (Objective-C, iOS 12+)\nPort of Client-Locket-Dio.", ver];
    about.textColor = [UIColor lightGrayColor];
    about.font = [UIFont systemFontOfSize:13];
    about.numberOfLines = 0;
    about.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:about];
    [NSLayoutConstraint activateConstraints:@[
        [about.topAnchor constraintEqualToAnchor:clearCache.bottomAnchor constant:44],
        [about.leadingAnchor constraintEqualToAnchor:V.leadingAnchor constant:20],
        [about.trailingAnchor constraintEqualToAnchor:V.trailingAnchor constant:-20],
    ]];

    UIButton *out = [UIButton buttonWithType:UIButtonTypeSystem];
    [out setTitle:@"Log Out" forState:UIControlStateNormal];
    [out setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [out addTarget:self action:@selector(onLogout) forControlEvents:UIControlEventTouchUpInside];
    out.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:out];
    [NSLayoutConstraint activateConstraints:@[
        [out.topAnchor constraintEqualToAnchor:about.bottomAnchor constant:28],
        [out.centerXAnchor constraintEqualToAnchor:V.centerXAnchor],
        [out.bottomAnchor constraintEqualToAnchor:V.bottomAnchor constant:-32],
    ]];

    [self renderStorage];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.serverView refresh];
    [self renderStorage];
}

- (void)renderStorage {
    self.storageLabel.text = [NSString stringWithFormat:@"Outbox: %lu pending upload(s).\nCache: moments, friends, chat, overlays for offline use.",
        (unsigned long)[LDDiskCache outboxCount]];
}

- (void)onTheme {
    NSArray *vals = @[@"gold", @"violet", @"ocean"];
    NSInteger i = self.themeControl.selectedSegmentIndex;
    if (i >= 0 && i < (NSInteger)vals.count) {
        [[NSUserDefaults standardUserDefaults] setObject:vals[i] forKey:kLDKeyCameraTheme];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)onPush {
    BOOL on = self.pushSwitch.isOn;
    [[NSUserDefaults standardUserDefaults] setObject:@(on) forKey:kLDKeyPushEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (on) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotifications)]) {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        }
    } else {
        [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    }
}

- (void)onClearCache {
    [LDDiskCache clearCaches];
    [self renderStorage];
}

- (void)onClearOutbox {
    [LDDiskCache clearOutbox];
    [self renderStorage];
}

- (void)onLogout {
    [[LDAPIClient shared] logoutWithCompletion:^(NSDictionary *json, NSError *error) {
        LDLoginViewController *l = [[LDLoginViewController alloc] init];
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:l];
        nav.navigationBarHidden = YES;
        w.rootViewController = nav;
    }];
}

@end
