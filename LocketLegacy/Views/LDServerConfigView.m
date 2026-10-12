#import "LDServerConfigView.h"
#import "../Config.h"
#import "../Controllers/LDQRScannerViewController.h"

@interface LDServerConfigView () <UITextFieldDelegate>
@property (nonatomic, weak) UIViewController *owner;
@property (nonatomic, strong) UISegmentedControl *preset;
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation LDServerConfigView

- (instancetype)initWithOwner:(UIViewController *)owner {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _owner = owner;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *cap = [[UILabel alloc] init];
        cap.text = @"① API SERVER — backend preset";
        cap.textColor = [UIColor colorWithWhite:0.65 alpha:1];
        cap.font = [UIFont boldSystemFontOfSize:12];
        cap.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:cap];

        _preset = [[UISegmentedControl alloc] initWithItems:@[@"Self-host Docker", @"Original Locket Dio API"]];
        [_preset addTarget:self action:@selector(onPreset) forControlEvents:UIControlEventValueChanged];
        _preset.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_preset];

        _urlField = [[UITextField alloc] init];
        _urlField.placeholder = @"http://<host>:5001";
        _urlField.textColor = [UIColor whiteColor];
        _urlField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
        _urlField.layer.cornerRadius = 10;
        _urlField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
        _urlField.leftViewMode = UITextFieldViewModeAlways;
        _urlField.keyboardType = UIKeyboardTypeURL;
        _urlField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _urlField.autocorrectionType = UITextAutocorrectionTypeNo;
        _urlField.delegate = self;
        _urlField.returnKeyType = UIReturnKeyDone;
        _urlField.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_urlField];

        UILabel *hint = [[UILabel alloc] init];
        hint.text = @"Self-host: your Docker address (or Scan QR). Original: api/auth/storage.locket-dio.com.";
        hint.textColor = [UIColor colorWithWhite:0.5 alpha:1];
        hint.font = [UIFont systemFontOfSize:11];
        hint.numberOfLines = 0;
        hint.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:hint];

        UIButton *scan = [UIButton buttonWithType:UIButtonTypeSystem];
        [scan setTitle:@"📷 Scan QR" forState:UIControlStateNormal];
        scan.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [scan setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        scan.backgroundColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
        scan.layer.cornerRadius = 10;
        [scan addTarget:self action:@selector(onScan) forControlEvents:UIControlEventTouchUpInside];
        scan.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:scan];

        UIButton *test = [UIButton buttonWithType:UIButtonTypeSystem];
        [test setTitle:@"Test" forState:UIControlStateNormal];
        [test addTarget:self action:@selector(onTest) forControlEvents:UIControlEventTouchUpInside];
        test.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:test];

        _statusLabel = [[UILabel alloc] init];
        _statusLabel.text = @"Not tested yet.";
        _statusLabel.textColor = [UIColor lightGrayColor];
        _statusLabel.font = [UIFont systemFontOfSize:12];
        _statusLabel.numberOfLines = 0;
        _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_statusLabel];

        [NSLayoutConstraint activateConstraints:@[
            [cap.topAnchor constraintEqualToAnchor:self.topAnchor],
            [cap.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [cap.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_preset.topAnchor constraintEqualToAnchor:cap.bottomAnchor constant:6],
            [_preset.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_preset.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_urlField.topAnchor constraintEqualToAnchor:_preset.bottomAnchor constant:8],
            [_urlField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_urlField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_urlField.heightAnchor constraintEqualToConstant:48],
            [hint.topAnchor constraintEqualToAnchor:_urlField.bottomAnchor constant:4],
            [hint.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [hint.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [scan.topAnchor constraintEqualToAnchor:hint.bottomAnchor constant:8],
            [scan.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [scan.widthAnchor constraintEqualToConstant:130],
            [scan.heightAnchor constraintEqualToConstant:44],
            [test.leadingAnchor constraintEqualToAnchor:scan.trailingAnchor constant:12],
            [test.centerYAnchor constraintEqualToAnchor:scan.centerYAnchor],
            [_statusLabel.topAnchor constraintEqualToAnchor:scan.bottomAnchor constant:8],
            [_statusLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_statusLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_statusLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
        [self refresh];
    }
    return self;
}

- (void)refresh {
    BOOL original = [[LDConfig backendMode] isEqualToString:@"original"];
    self.preset.selectedSegmentIndex = original ? 1 : 0;
    self.urlField.text = [LDConfig baseAPIURL];
    self.urlField.enabled = !original;
    self.urlField.alpha = original ? 0.5 : 1.0;
}

- (void)commitURLField {
    if ([[LDConfig backendMode] isEqualToString:@"original"]) return;
    NSString *v = [self.urlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (v.length > 0) [LDConfig setBaseAPIURL:v];
}

- (void)onPreset {
    [LDConfig setBackendMode:(self.preset.selectedSegmentIndex == 1) ? @"original" : @"selfhost"];
    [self refresh];
    [self onTest];
}

- (void)onScan {
    [self commitURLField];
    [self.owner.view endEditing:YES];
    LDQRScannerViewController *vc = [[LDQRScannerViewController alloc] initWithCompletion:^(NSString *value) {
        if (value.length > 0) {
            [LDConfig setBackendMode:@"selfhost"];
            [LDConfig setBaseAPIURL:value];
            [self refresh];
            self.statusLabel.text = [NSString stringWithFormat:@"Server set to %@.", value];
            [self onTest];
        }
    }];
    [self.owner.navigationController pushViewController:vc animated:YES];
}

- (void)onTest {
    [self commitURLField];
    [self.owner.view endEditing:YES];
    NSString *base = [LDConfig effectiveBaseAPIURL];
    self.statusLabel.text = [NSString stringWithFormat:@"Testing %@ …", base];
    // Self-host mock exposes /api/health; the original API answers / with {message}.
    NSString *u = [[LDConfig backendMode] isEqualToString:@"original"]
        ? base : [base stringByAppendingString:@"/api/health"];
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:u] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (e) { self.statusLabel.text = [NSString stringWithFormat:@"❌ Unreachable: %@", e.localizedDescription]; return; }
            NSDictionary *json = d.length ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
            if (![json isKindOfClass:[NSDictionary class]]) { self.statusLabel.text = @"❌ Not a Locket API (bad response)."; return; }
            if (!json[@"serverVersion"] && [json[@"message"] isKindOfClass:[NSString class]]) {
                // Original production root answers {message} with no version endpoint.
                self.statusLabel.text = @"✅ Reachable (Original API). Log in to verify credentials.";
                return;
            }
            NSString *ver = [json[@"serverVersion"] isKindOfClass:[NSString class]] ? json[@"serverVersion"] : @"(old server — pull + rebuild for uploads!)";
            NSArray *feat = [json[@"features"] isKindOfClass:[NSArray class]] ? json[@"features"] : @[];
            BOOL canSend = [feat containsObject:@"presignedV3"];
            self.statusLabel.text = [NSString stringWithFormat:@"%@ %@ • moments: %@ • sending: %@",
                [@"ok" isEqualToString:json[@"status"]] ? @"✅ Reachable" : @"⚠️ Odd response",
                ver, json[@"moments"] ?: @"?", canSend ? @"supported ✅" : @"NOT supported ❌ (update server)"];
        });
    }];
    [t resume];
}

- (BOOL)textFieldShouldReturn:(UITextField *)t {
    [t resignFirstResponder];
    [self commitURLField];
    return YES;
}

@end
