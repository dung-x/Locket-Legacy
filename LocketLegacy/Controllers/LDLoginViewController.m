#import "LDLoginViewController.h"
#import "../API/LDAPIClient.h"
#import "LDMainTabBarController.h"
#import "../Views/LDServerConfigView.h"
#import "../Config.h"

@interface LDLoginViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *emailField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) LDServerConfigView *serverView;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation LDLoginViewController

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
    f.delegate = self;
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

    // Row 1 — backend (shared component: preset, URL, Scan QR, Test).
    self.serverView = [[LDServerConfigView alloc] initWithOwner:self];
    [self.view addSubview:self.serverView];

    // Row 2 — email
    UILabel *c2 = [self caption:@"② EMAIL — account for POST /locket/login"];
    self.emailField = [self rowField:@"you@example.com" keyboard:UIKeyboardTypeEmailAddress secure:NO];
    self.emailField.returnKeyType = UIReturnKeyNext;

    // Row 3 — password
    UILabel *c3 = [self caption:@"③ PASSWORD — sent with the login request"];
    self.passwordField = [self rowField:@"Your password" keyboard:UIKeyboardTypeDefault secure:YES];
    self.passwordField.returnKeyType = UIReturnKeyDone;

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

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapBackground)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:32],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [title.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [sub.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        [self.serverView.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:20],
        [self.serverView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.serverView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [c2.topAnchor constraintEqualToAnchor:self.serverView.bottomAnchor constant:14],
        [c2.leadingAnchor constraintEqualToAnchor:self.serverView.leadingAnchor],
        [c2.trailingAnchor constraintEqualToAnchor:self.serverView.trailingAnchor],
        [self.emailField.topAnchor constraintEqualToAnchor:c2.bottomAnchor constant:6],
        [self.emailField.leadingAnchor constraintEqualToAnchor:c2.leadingAnchor],
        [self.emailField.trailingAnchor constraintEqualToAnchor:c2.trailingAnchor],
        [self.emailField.heightAnchor constraintEqualToConstant:48],

        [c3.topAnchor constraintEqualToAnchor:self.emailField.bottomAnchor constant:14],
        [c3.leadingAnchor constraintEqualToAnchor:c2.leadingAnchor],
        [c3.trailingAnchor constraintEqualToAnchor:c2.trailingAnchor],
        [self.passwordField.topAnchor constraintEqualToAnchor:c3.bottomAnchor constant:6],
        [self.passwordField.leadingAnchor constraintEqualToAnchor:c2.leadingAnchor],
        [self.passwordField.trailingAnchor constraintEqualToAnchor:c2.trailingAnchor],
        [self.passwordField.heightAnchor constraintEqualToConstant:48],

        [self.loginButton.topAnchor constraintEqualToAnchor:self.passwordField.bottomAnchor constant:20],
        [self.loginButton.leadingAnchor constraintEqualToAnchor:c2.leadingAnchor],
        [self.loginButton.trailingAnchor constraintEqualToAnchor:c2.trailingAnchor],
        [self.loginButton.heightAnchor constraintEqualToConstant:52],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.loginButton.bottomAnchor constant:16],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:c2.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:c2.trailingAnchor],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:12],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.serverView refresh];
}

- (void)onTapBackground { [self.view endEditing:YES]; }

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.emailField) { [self.passwordField becomeFirstResponder]; return NO; }
    [textField resignFirstResponder];
    if (textField == self.passwordField) [self onLogin];
    return YES;
}

- (void)onLogin {
    [self.view endEditing:YES];
    NSString *email = self.emailField.text ?: @"";
    NSString *pw = self.passwordField.text ?: @"";
    if (email.length == 0 || pw.length == 0) { self.statusLabel.text = @"Enter email (row ②) and password (row ③)."; return; }
    self.loginButton.enabled = NO;
    [self.spinner startAnimating];
    self.statusLabel.text = [NSString stringWithFormat:@"Logging in to %@ …", [LDConfig effectiveBaseAPIURL]];
    [[LDAPIClient shared] loginWithEmail:email password:pw completion:^(NSDictionary *json, NSError *error) {
        [self.spinner stopAnimating];
        self.loginButton.enabled = YES;
        if (error) { self.statusLabel.text = error.localizedDescription; return; }
        if (![json[@"success"] boolValue]) {
            NSString *msg = json[@"message"];
            if (![msg isKindOfClass:[NSString class]] || !msg.length) msg = @"Login failed. Check backend (row ①) / credentials.";
            self.statusLabel.text = msg;
            return;
        }
        LDMainTabBarController *tab = [[LDMainTabBarController alloc] init];
        [self.navigationController setViewControllers:@[tab] animated:YES];
    }];
}

@end
