#import "LDProfileViewController.h"
#import "../API/LDAPIClient.h"
#import "../Models/LDUser.h"
#import "../Config.h"
#import "LDLoginViewController.h"
#import "LDQRScannerViewController.h"

@interface LDProfileViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UITextField *serverField;
@property (nonatomic, strong) UILabel *streakLabel;
@property (nonatomic, strong) UISegmentedControl *themeControl;
@property (nonatomic, strong) UISwitch *pushSwitch;
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

    UILabel *srvTitle = [[UILabel alloc] init];
    srvTitle.text = @"① API SERVER — self-host Docker address";
    srvTitle.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    srvTitle.font = [UIFont boldSystemFontOfSize:12];
    srvTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:srvTitle];

    UILabel *srvHint = [[UILabel alloc] init];
    srvHint.text = @"Same as login row ① — e.g. http://192.168.1.5:5001, or Scan QR.";
    srvHint.textColor = [UIColor colorWithWhite:0.5 alpha:1];
    srvHint.font = [UIFont systemFontOfSize:11];
    srvHint.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:srvHint];

    self.serverField = [[UITextField alloc] init];
    self.serverField.placeholder = @"http://<host>:5001";
    self.serverField.text = [LDConfig baseAPIURL];
    self.serverField.textColor = [UIColor whiteColor];
    self.serverField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.serverField.layer.cornerRadius = 10;
    self.serverField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
    self.serverField.leftViewMode = UITextFieldViewModeAlways;
    self.serverField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.serverField.delegate = self;
    self.serverField.returnKeyType = UIReturnKeyDone;
    self.serverField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.serverField];

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    [save setTitle:@"Save server" forState:UIControlStateNormal];
    [save addTarget:self action:@selector(onSave) forControlEvents:UIControlEventTouchUpInside];
    save.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:save];

    UIButton *scan = [UIButton buttonWithType:UIButtonTypeSystem];
    [scan setTitle:@"📷 Scan QR" forState:UIControlStateNormal];
    [scan addTarget:self action:@selector(onScan) forControlEvents:UIControlEventTouchUpInside];
    scan.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scan];

    UIButton *out = [UIButton buttonWithType:UIButtonTypeSystem];
    [out setTitle:@"Log Out" forState:UIControlStateNormal];
    [out setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [out addTarget:self action:@selector(onLogout) forControlEvents:UIControlEventTouchUpInside];
    out.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:out];

    UILabel *streakCap = [[UILabel alloc] init];
    streakCap.text = @"🔥 Posting streak";
    streakCap.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    streakCap.font = [UIFont boldSystemFontOfSize:12];
    streakCap.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:streakCap];

    self.streakLabel = [[UILabel alloc] init];
    self.streakLabel.text = @"—";
    self.streakLabel.textColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    self.streakLabel.font = [UIFont boldSystemFontOfSize:16];
    self.streakLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.streakLabel];

    UILabel *themeCap = [[UILabel alloc] init];
    themeCap.text = @"🎨 Camera accent theme";
    themeCap.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    themeCap.font = [UIFont boldSystemFontOfSize:12];
    themeCap.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:themeCap];

    self.themeControl = [[UISegmentedControl alloc] initWithItems:@[@"Gold", @"Violet", @"Ocean"]];
    NSString *theme = [[NSUserDefaults standardUserDefaults] stringForKey:kLDKeyCameraTheme];
    if ([theme isEqualToString:@"violet"]) self.themeControl.selectedSegmentIndex = 1;
    else if ([theme isEqualToString:@"ocean"]) self.themeControl.selectedSegmentIndex = 2;
    else self.themeControl.selectedSegmentIndex = 0;
    [self.themeControl addTarget:self action:@selector(onTheme) forControlEvents:UIControlEventValueChanged];
    self.themeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.themeControl];

    UILabel *pushCap = [[UILabel alloc] init];
    pushCap.text = @"🔔 Push notifications (registers this device)";
    pushCap.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    pushCap.font = [UIFont boldSystemFontOfSize:12];
    pushCap.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:pushCap];

    self.pushSwitch = [[UISwitch alloc] init];
    self.pushSwitch.on = [[[NSUserDefaults standardUserDefaults] objectForKey:kLDKeyPushEnabled] boolValue];
    [self.pushSwitch addTarget:self action:@selector(onPush) forControlEvents:UIControlEventValueChanged];
    self.pushSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.pushSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [self.infoLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.infoLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.infoLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [srvTitle.topAnchor constraintEqualToAnchor:self.infoLabel.bottomAnchor constant:24],
        [srvTitle.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [srvTitle.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],
        [srvHint.topAnchor constraintEqualToAnchor:srvTitle.bottomAnchor constant:2],
        [srvHint.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [srvHint.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],
        [self.serverField.topAnchor constraintEqualToAnchor:srvHint.bottomAnchor constant:8],
        [self.serverField.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.serverField.trailingAnchor constraintEqualToAnchor:scan.leadingAnchor constant:-8],
        [self.serverField.heightAnchor constraintEqualToConstant:46],
        [scan.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],
        [scan.centerYAnchor constraintEqualToAnchor:self.serverField.centerYAnchor],
        [scan.widthAnchor constraintEqualToConstant:100],
        [save.topAnchor constraintEqualToAnchor:self.serverField.bottomAnchor constant:8],
        [save.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [streakCap.topAnchor constraintEqualToAnchor:save.bottomAnchor constant:20],
        [streakCap.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.streakLabel.topAnchor constraintEqualToAnchor:streakCap.bottomAnchor constant:4],
        [self.streakLabel.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [themeCap.topAnchor constraintEqualToAnchor:self.streakLabel.bottomAnchor constant:16],
        [themeCap.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.themeControl.topAnchor constraintEqualToAnchor:themeCap.bottomAnchor constant:6],
        [self.themeControl.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.themeControl.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],
        [pushCap.topAnchor constraintEqualToAnchor:self.themeControl.bottomAnchor constant:16],
        [pushCap.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.pushSwitch.topAnchor constraintEqualToAnchor:pushCap.bottomAnchor constant:6],
        [self.pushSwitch.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [out.topAnchor constraintEqualToAnchor:self.pushSwitch.bottomAnchor constant:24],
        [out.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapBackground)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [self load];
    [self loadStreak];
}

- (void)onTapBackground { [self.view endEditing:YES]; }

- (void)loadStreak {
    [[LDAPIClient shared] getMomentsWithCompletion:^(NSDictionary *json, NSError *error) {
        if (error) return;
        NSDictionary *streak = json[@"streak"];
        NSInteger n = [streak isKindOfClass:[NSDictionary class]] ? [streak[@"count"] integerValue] : 0;
        self.streakLabel.text = n > 0 ? [NSString stringWithFormat:@"🔥 %ld day(s)", (long)n] : @"No streak yet — post today!";
    }];
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
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

- (void)onScan {
    [self.view endEditing:YES];
    LDQRScannerViewController *vc = [[LDQRScannerViewController alloc] initWithCompletion:^(NSString *value) {
        if (value.length > 0) {
            self.serverField.text = value;
            [LDConfig setBaseAPIURL:value];
            [self load];
        }
    }];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onSave {
    [self.view endEditing:YES];
    [LDConfig setBaseAPIURL:self.serverField.text];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Saved" message:[LDConfig baseAPIURL] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)onLogout {
    [[LDAPIClient shared] logoutWithCompletion:^(NSDictionary *json, NSError *error) {
        LDLoginViewController *l = [[LDLoginViewController alloc] init];
        [self.navigationController setViewControllers:@[l] animated:YES];
        // Also reset tab root if presented modally inside tab controller
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:l];
        nav.navigationBarHidden = YES;
        w.rootViewController = nav;
    }];
}

@end
