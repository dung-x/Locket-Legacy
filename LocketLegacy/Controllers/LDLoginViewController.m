#import "LDLoginViewController.h"
#import "../API/LDAPIClient.h"
#import "LDMainTabBarController.h"
#import "LDQRScannerViewController.h"
#import "../Config.h"

@interface LDLoginViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *emailField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *serverField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation LDLoginViewController

// Small grey caption above each row so every field is self-explanatory.
- (UILabel *)caption:(NSString *)text {
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    l.font = [UIFont boldSystemFontOfSize:12];
    l.numberOfLines = 0;
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:l];
    return l;
}

- (UITextField *)rowField:(NSString *)placeholder keyboard:(UIKeyboardType)kb secure:(BOOL)secure {
    UITextField *f = [[UITextField alloc] init];
    f.placeholder = placeholder;
    f.textColor = [UIColor whiteColor];
    f.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    f.layer.cornerRadius = 10;
    f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
    f.leftViewMode = UITextFieldViewModeAlways;
    f.keyboardType = kb;
    f.secureTextEntry = secure;
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    f.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:f];
    return f;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"📸 Locket Legacy";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:28];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:title];

    UILabel *sub = [[UILabel alloc] init];
    sub.text = @"Share real-time photos with close friends";
    sub.textColor = [UIColor lightGrayColor];
    sub.font = [UIFont systemFontOfSize:14];
    sub.textAlignment = NSTextAlignmentCenter;
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:sub];

    // Row 1 — server
    UILabel *c1 = [self caption:@"① API SERVER — self-host Docker address"];
    UILabel *h1 = [self caption:@"Example: http://192.168.1.5:5001 — or tap Scan QR on the server page."];
    h1.font = [UIFont systemFontOfSize:11];
    h1.textColor = [UIColor colorWithWhite:0.5 alpha:1];

    self.serverField = [self rowField:@"http://<host>:5001" keyboard:UIKeyboardTypeURL secure:NO];
    self.serverField.text = [LDConfig baseAPIURL];

    UIButton *scan = [UIButton buttonWithType:UIButtonTypeSystem];
    [scan setTitle:@"📷 Scan QR" forState:UIControlStateNormal];
    scan.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [scan setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    scan.backgroundColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    scan.layer.cornerRadius = 10;
    [scan addTarget:self action:@selector(onScan) forControlEvents:UIControlEventTouchUpInside];
    scan.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scan];

    // Row 2 — email
    UILabel *c2 = [self caption:@"② EMAIL — account for POST /locket/login"];
    self.emailField = [self rowField:@"you@example.com" keyboard:UIKeyboardTypeEmailAddress secure:NO];

    // Row 3 — password
    UILabel *c3 = [self caption:@"③ PASSWORD — sent with the login request"];
    self.passwordField = [self rowField:@"Your password" keyboard:UIKeyboardTypeDefault secure:YES];

    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.loginButton setTitle:@"Log In" forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.loginButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.loginButton.backgroundColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    self.loginButton.layer.cornerRadius = 12;
    [self.loginButton addTarget:self action:@selector(onLogin) forControlEvents:UIControlEventTouchUpInside];
    self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loginButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.spinner];

    // Keyboard: Done/Next navigation + tap-outside dismissal.
    self.serverField.delegate = self;
    self.serverField.returnKeyType = UIReturnKeyNext;
    self.emailField.delegate = self;
    self.emailField.returnKeyType = UIReturnKeyNext;
    self.passwordField.delegate = self;
    self.passwordField.returnKeyType = UIReturnKeyDone;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapBackground)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    UIView *sv = self.serverField;
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:40],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [title.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [sub.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        [c1.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:28],
        [c1.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [c1.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [h1.topAnchor constraintEqualToAnchor:c1.bottomAnchor constant:2],
        [h1.leadingAnchor constraintEqualToAnchor:c1.leadingAnchor],
        [h1.trailingAnchor constraintEqualToAnchor:c1.trailingAnchor],
        [sv.topAnchor constraintEqualToAnchor:h1.bottomAnchor constant:6],
        [sv.leadingAnchor constraintEqualToAnchor:c1.leadingAnchor],
        [sv.heightAnchor constraintEqualToConstant:48],
        [scan.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [scan.centerYAnchor constraintEqualToAnchor:sv.centerYAnchor],
        [scan.widthAnchor constraintEqualToConstant:110],
        [scan.heightAnchor constraintEqualToConstant:48],
        [sv.trailingAnchor constraintEqualToAnchor:scan.leadingAnchor constant:-8],

        [c2.topAnchor constraintEqualToAnchor:sv.bottomAnchor constant:14],
        [c2.leadingAnchor constraintEqualToAnchor:c1.leadingAnchor],
        [c2.trailingAnchor constraintEqualToAnchor:c1.trailingAnchor],
        [self.emailField.topAnchor constraintEqualToAnchor:c2.bottomAnchor constant:6],
        [self.emailField.leadingAnchor constraintEqualToAnchor:c1.leadingAnchor],
        [self.emailField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.emailField.heightAnchor constraintEqualToConstant:48],

        [c3.topAnchor constraintEqualToAnchor:self.emailField.bottomAnchor constant:14],
        [c3.leadingAnchor constraintEqualToAnchor:c1.leadingAnchor],
        [c3.trailingAnchor constraintEqualToAnchor:c1.trailingAnchor],
        [self.passwordField.topAnchor constraintEqualToAnchor:c3.bottomAnchor constant:6],
        [self.passwordField.leadingAnchor constraintEqualToAnchor:c1.leadingAnchor],
        [self.passwordField.trailingAnchor constraintEqualToAnchor:self.emailField.trailingAnchor],
        [self.passwordField.heightAnchor constraintEqualToConstant:48],

        [self.loginButton.topAnchor constraintEqualToAnchor:self.passwordField.bottomAnchor constant:20],
        [self.loginButton.leadingAnchor constraintEqualToAnchor:c1.leadingAnchor],
        [self.loginButton.trailingAnchor constraintEqualToAnchor:self.emailField.trailingAnchor],
        [self.loginButton.heightAnchor constraintEqualToConstant:52],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.loginButton.bottomAnchor constant:16],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:c1.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.emailField.trailingAnchor],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:12],
    ]];
    // Fix server row: leading is set, trailing derived from scan button.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Refresh in case the QR scanner changed it while we were away.
    if (self.serverField) self.serverField.text = [LDConfig baseAPIURL];
}

- (void)onTapBackground { [self.view endEditing:YES]; }

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.serverField) { [self.emailField becomeFirstResponder]; return NO; }
    if (textField == self.emailField) { [self.passwordField becomeFirstResponder]; return NO; }
    [textField resignFirstResponder];
    if (textField == self.passwordField) [self onLogin];
    return YES;
}

- (void)onScan {
    [self.view endEditing:YES];
    LDQRScannerViewController *vc = [[LDQRScannerViewController alloc] initWithCompletion:^(NSString *value) {
        if (value.length > 0) {
            [LDConfig setBaseAPIURL:value];
            self.serverField.text = value;
            self.statusLabel.text = [NSString stringWithFormat:@"Server set to %@ — now log in.", value];
        }
    }];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onLogin {
    [self.view endEditing:YES];
    NSString *email = self.emailField.text ?: @"";
    NSString *pw = self.passwordField.text ?: @"";
    NSString *srv = [self.serverField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (srv.length > 0) [LDConfig setBaseAPIURL:srv];
    if (email.length == 0 || pw.length == 0) { self.statusLabel.text = @"Enter email (row ②) and password (row ③)."; return; }
    self.loginButton.enabled = NO;
    [self.spinner startAnimating];
    self.statusLabel.text = [NSString stringWithFormat:@"Logging in to %@ …", [LDConfig baseAPIURL]];
    [[LDAPIClient shared] loginWithEmail:email password:pw completion:^(NSDictionary *json, NSError *error) {
        [self.spinner stopAnimating];
        self.loginButton.enabled = YES;
        if (error) { self.statusLabel.text = error.localizedDescription; return; }
        if (![json[@"success"] boolValue]) {
            NSString *msg = json[@"message"];
            if (![msg isKindOfClass:[NSString class]] || !msg.length) msg = @"Login failed. Check server (row ①) / credentials.";
            self.statusLabel.text = msg;
            return;
        }
        LDMainTabBarController *tab = [[LDMainTabBarController alloc] init];
        [self.navigationController setViewControllers:@[tab] animated:YES];
    }];
}

@end
