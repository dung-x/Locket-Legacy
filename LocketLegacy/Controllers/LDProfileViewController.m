#import "LDProfileViewController.h"
#import "../API/LDAPIClient.h"
#import "../Models/LDUser.h"
#import "../Config.h"
#import "LDLoginViewController.h"

@interface LDProfileViewController ()
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UITextField *serverField;
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
    srvTitle.text = @"API server (self-host)";
    srvTitle.textColor = [UIColor lightGrayColor];
    srvTitle.font = [UIFont systemFontOfSize:13];
    srvTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:srvTitle];

    self.serverField = [[UITextField alloc] init];
    self.serverField.text = [LDConfig baseAPIURL];
    self.serverField.textColor = [UIColor whiteColor];
    self.serverField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.serverField.layer.cornerRadius = 10;
    self.serverField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
    self.serverField.leftViewMode = UITextFieldViewModeAlways;
    self.serverField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.serverField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.serverField];

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    [save setTitle:@"Save server" forState:UIControlStateNormal];
    [save addTarget:self action:@selector(onSave) forControlEvents:UIControlEventTouchUpInside];
    save.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:save];

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
        [srvTitle.topAnchor constraintEqualToAnchor:self.infoLabel.bottomAnchor constant:24],
        [srvTitle.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.serverField.topAnchor constraintEqualToAnchor:srvTitle.bottomAnchor constant:8],
        [self.serverField.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.serverField.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],
        [self.serverField.heightAnchor constraintEqualToConstant:46],
        [save.topAnchor constraintEqualToAnchor:self.serverField.bottomAnchor constant:8],
        [save.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [out.topAnchor constraintEqualToAnchor:save.bottomAnchor constant:24],
        [out.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];

    [self load];
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
