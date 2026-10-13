#import "LDProfileViewController.h"
#import "../API/LDAPIClient.h"
#import "../Models/LDUser.h"
#import "../Config.h"
#import "LDLoginViewController.h"
#import "LDSettingsViewController.h"

@interface LDProfileViewController ()
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UILabel *streakLabel;
@property (nonatomic, strong) UILabel *backendLabel;
@end

@implementation LDProfileViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Profile";
    self.view.backgroundColor = [UIColor blackColor];

    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.textColor = [UIColor whiteColor];
    self.infoLabel.font = [UIFont systemFontOfSize:14];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.infoLabel];

    self.streakLabel = [[UILabel alloc] init];
    self.streakLabel.text = @"—";
    self.streakLabel.textColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    self.streakLabel.font = [UIFont boldSystemFontOfSize:16];
    self.streakLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.streakLabel];

    self.backendLabel = [[UILabel alloc] init];
    self.backendLabel.numberOfLines = 0;
    self.backendLabel.textColor = [UIColor lightGrayColor];
    self.backendLabel.font = [UIFont systemFontOfSize:13];
    self.backendLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.backendLabel];

    UIButton *settings = [UIButton buttonWithType:UIButtonTypeSystem];
    [settings setTitle:@"⚙️ Open Settings" forState:UIControlStateNormal];
    settings.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [settings addTarget:self action:@selector(onSettings) forControlEvents:UIControlEventTouchUpInside];
    settings.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:settings];

    UIButton *out = [UIButton buttonWithType:UIButtonTypeSystem];
    [out setTitle:@"Log Out" forState:UIControlStateNormal];
    [out setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [out addTarget:self action:@selector(onLogout) forControlEvents:UIControlEventTouchUpInside];
    out.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:out];

    [NSLayoutConstraint activateConstraints:@[
        [self.infoLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.infoLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.infoLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.streakLabel.topAnchor constraintEqualToAnchor:self.infoLabel.bottomAnchor constant:16],
        [self.streakLabel.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.backendLabel.topAnchor constraintEqualToAnchor:self.streakLabel.bottomAnchor constant:16],
        [self.backendLabel.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.backendLabel.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],
        [settings.topAnchor constraintEqualToAnchor:self.backendLabel.bottomAnchor constant:20],
        [settings.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [out.topAnchor constraintEqualToAnchor:settings.bottomAnchor constant:16],
        [out.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"⚙️" style:UIBarButtonItemStylePlain target:self action:@selector(onSettings)];
    [self load];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self renderBackend];
    [self loadStreak];
}

- (void)renderBackend {
    if ([[LDConfig backendMode] isEqualToString:@"original"]) {
        NSString *mt = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyMemberToken];
        NSString *member = ([mt isKindOfClass:[NSString class]] && mt.length) ? @"member session ✅" : @"member session ❌ (log in again)";
        self.backendLabel.text = [NSString stringWithFormat:@"Backend: Original Locket Dio API\nhttps://api.locket-dio.com\n%@",
            member];
    } else {
        self.backendLabel.text = [NSString stringWithFormat:@"Backend: Self-host Docker\n%@", [LDConfig baseAPIURL]];
    }
}

- (void)onSettings {
    LDSettingsViewController *s = [[LDSettingsViewController alloc] init];
    [self.navigationController pushViewController:s animated:YES];
}

- (void)load {
    self.infoLabel.text = @"Loading…";
    [[LDAPIClient shared] getInfoUserWithCompletion:^(NSDictionary *json, NSError *error) {
        if (error) { self.infoLabel.text = error.localizedDescription; return; }
        NSDictionary *d = json[@"data"];
        if (![d isKindOfClass:[NSDictionary class]]) d = json;
        LDUser *u = [LDUser fromJSON:d];
        self.infoLabel.text = [NSString stringWithFormat:@"👤 %@\n📧 %@\n🆔 %@\n@%@",
            u.displayName.length ? u.displayName : @"(no name)",
            u.email, u.uid, u.username];
    }];
}

- (void)loadStreak {
    [[LDAPIClient shared] getMomentsWithCompletion:^(NSDictionary *json, NSError *error) {
        if (error) return;
        NSDictionary *streak = json[@"streak"];
        NSInteger n = [streak isKindOfClass:[NSDictionary class]] ? [streak[@"count"] integerValue] : 0;
        self.streakLabel.text = n > 0 ? [NSString stringWithFormat:@"🔥 %ld day(s)", (long)n] : @"No streak yet — post today!";
    }];
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
