#import "LDLoginViewController.h"
#import "../API/LDAPIClient.h"
#import "LDMainTabBarController.h"
#import "../Config.h"

@interface LDLoginViewController ()
@property (nonatomic, strong) UITextField *emailField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *serverField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation LDLoginViewController

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

    self.serverField = [[UITextField alloc] init];
    self.serverField.placeholder = @"API URL (http://localhost:5001)";
    self.serverField.text = [LDConfig baseAPIURL];
    self.serverField.textColor = [UIColor whiteColor];
    self.serverField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.serverField.layer.cornerRadius = 10;
    self.serverField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
    self.serverField.leftViewMode = UITextFieldViewModeAlways;
    self.serverField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.serverField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.serverField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.serverField];

    self.emailField = [[UITextField alloc] init];
    self.emailField.placeholder = @"Email";
    self.emailField.textColor = [UIColor whiteColor];
    self.emailField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.emailField.layer.cornerRadius = 10;
    self.emailField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
    self.emailField.leftViewMode = UITextFieldViewModeAlways;
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emailField];

    self.passwordField = [[UITextField alloc] init];
    self.passwordField.placeholder = @"Password";
    self.passwordField.secureTextEntry = YES;
    self.passwordField.textColor = [UIColor whiteColor];
    self.passwordField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.passwordField.layer.cornerRadius = 10;
    self.passwordField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
    self.passwordField.leftViewMode = UITextFieldViewModeAlways;
    self.passwordField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.passwordField];

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

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:60],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [title.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [sub.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [self.serverField.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:32],
        [self.serverField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.serverField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.serverField.heightAnchor constraintEqualToConstant:48],
        [self.emailField.topAnchor constraintEqualToAnchor:self.serverField.bottomAnchor constant:12],
        [self.emailField.leadingAnchor constraintEqualToAnchor:self.serverField.leadingAnchor],
        [self.emailField.trailingAnchor constraintEqualToAnchor:self.serverField.trailingAnchor],
        [self.emailField.heightAnchor constraintEqualToConstant:48],
        [self.passwordField.topAnchor constraintEqualToAnchor:self.emailField.bottomAnchor constant:12],
        [self.passwordField.leadingAnchor constraintEqualToAnchor:self.serverField.leadingAnchor],
        [self.passwordField.trailingAnchor constraintEqualToAnchor:self.serverField.trailingAnchor],
        [self.passwordField.heightAnchor constraintEqualToConstant:48],
        [self.loginButton.topAnchor constraintEqualToAnchor:self.passwordField.bottomAnchor constant:20],
        [self.loginButton.leadingAnchor constraintEqualToAnchor:self.serverField.leadingAnchor],
        [self.loginButton.trailingAnchor constraintEqualToAnchor:self.serverField.trailingAnchor],
        [self.loginButton.heightAnchor constraintEqualToConstant:52],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.loginButton.bottomAnchor constant:16],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.serverField.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.serverField.trailingAnchor],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:12],
    ]];
}

- (void)onLogin {
    [self.view endEditing:YES];
    NSString *email = self.emailField.text ?: @"";
    NSString *pw = self.passwordField.text ?: @"";
    NSString *srv = [self.serverField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (srv.length > 0) [LDConfig setBaseAPIURL:srv];
    if (email.length == 0 || pw.length == 0) { self.statusLabel.text = @"Enter email and password."; return; }
    self.loginButton.enabled = NO;
    [self.spinner startAnimating];
    self.statusLabel.text = [NSString stringWithFormat:@"Logging in to %@ …", [LDConfig baseAPIURL]];
    [[LDAPIClient shared] loginWithEmail:email password:pw completion:^(NSDictionary *json, NSError *error) {
        [self.spinner stopAnimating];
        self.loginButton.enabled = YES;
        if (error) { self.statusLabel.text = error.localizedDescription; return; }
        if (![json[@"success"] boolValue]) {
            NSString *msg = json[@"message"];
            if (![msg isKindOfClass:[NSString class]] || !msg.length) msg = @"Login failed. Check server / credentials.";
            self.statusLabel.text = msg;
            return;
        }
        LDMainTabBarController *tab = [[LDMainTabBarController alloc] init];
        [self.navigationController setViewControllers:@[tab] animated:YES];
    }];
}

@end
