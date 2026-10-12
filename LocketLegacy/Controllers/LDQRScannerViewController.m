// LDQRScannerViewController — scan the server dashboard QR to fill the API URL.
// AVFoundation only (no extra frameworks), iOS 12 compatible.
#import "LDQRScannerViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface LDQRScannerViewController () <AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, copy) LDQRScanCompletion completion;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preview;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, assign) BOOL handled;
@end

@implementation LDQRScannerViewController

- (instancetype)initWithCompletion:(LDQRScanCompletion)completion {
    self = [super init];
    if (self) { _completion = [completion copy]; }
    return self;
}

+ (nullable NSString *)apiURLFromScannedString:(nullable NSString *)raw {
    if (![raw isKindOfClass:[NSString class]]) return nil;
    NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return nil;
    // 1) locketlegacy://connect?api=<urlencoded>
    NSString *low = s.lowercaseString;
    if ([low hasPrefix:@"locketlegacy://"]) {
        NSURLComponents *c = [NSURLComponents componentsWithString:s];
        for (NSURLQueryItem *it in c.queryItems) {
            if ([it.name isEqualToString:@"api"] && it.value.length > 0) {
                return [self normalizeURL:it.value];
            }
        }
        return nil;
    }
    // 2) JSON {"api":"http://..."} (some generators wrap the payload)
    if ([s hasPrefix:@"{"]) {
        NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
        id o = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        if ([o isKindOfClass:[NSDictionary class]]) {
            for (NSString *k in @[@"api", @"baseUrl", @"baseURL", @"url", @"server"]) {
                id v = o[k];
                if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length > 0) {
                    NSString *n = [self normalizeURL:v];
                    if (n) return n;
                }
            }
        }
        return nil;
    }
    // 3) raw http(s) URL
    return [self normalizeURL:s];
}

+ (nullable NSString *)normalizeURL:(nullable NSString *)s {
    if (![s isKindOfClass:[NSString class]]) return nil;
    NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // strip trailing slashes (client appends "/locket/..." itself)
    while (t.length > 1 && [t hasSuffix:@"/"]) t = [t substringToIndex:t.length - 1];
    NSString *low = t.lowercaseString;
    if ([low hasPrefix:@"http://"] || [low hasPrefix:@"https://"]) return t;
    return nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Scan server QR";
    self.view.backgroundColor = [UIColor blackColor];

    AVAuthorizationStatus st = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (st == AVAuthorizationStatusDenied || st == AVAuthorizationStatusRestricted) {
        [self showDenied];
        return;
    }
    if (st == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) [self startSession];
                else [self showDenied];
            });
        }];
    } else {
        [self startSession];
    }

    // Frame overlay
    UIView *frame = [[UIView alloc] init];
    frame.layer.borderColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1].CGColor;
    frame.layer.borderWidth = 2;
    frame.layer.cornerRadius = 12;
    frame.userInteractionEnabled = NO;
    frame.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:frame];

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.text = @"Point at the QR on the server page\n(http://<host>:5001)";
    self.hintLabel.numberOfLines = 0;
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    self.hintLabel.textColor = [UIColor whiteColor];
    self.hintLabel.font = [UIFont systemFontOfSize:14];
    self.hintLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.hintLabel.layer.cornerRadius = 8;
    self.hintLabel.clipsToBounds = YES;
    self.hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hintLabel];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [cancel addTarget:self action:@selector(onCancel) forControlEvents:UIControlEventTouchUpInside];
    cancel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:cancel];

    [NSLayoutConstraint activateConstraints:@[
        [frame.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [frame.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30],
        [frame.widthAnchor constraintEqualToConstant:240],
        [frame.heightAnchor constraintEqualToConstant:240],
        [self.hintLabel.topAnchor constraintEqualToAnchor:frame.bottomAnchor constant:20],
        [self.hintLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.hintLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [cancel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [cancel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];
}

- (void)startSession {
    AVCaptureDevice *dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *err = nil;
    AVCaptureDeviceInput *in = [AVCaptureDeviceInput deviceInputWithDevice:dev error:&err];
    if (!in) { [self showError:err.localizedDescription ?: @"No camera"]; return; }
    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canAddInput:in]) [self.session addInput:in];
    AVCaptureMetadataOutput *out = [[AVCaptureMetadataOutput alloc] init];
    if ([self.session canAddOutput:out]) {
        [self.session addOutput:out];
        [out setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        out.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
    } else {
        [self showError:@"QR output unsupported"]; return;
    }
    self.preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.preview.frame = self.view.bounds;
    [self.view.layer insertSublayer:self.preview atIndex:0];
    [self.session startRunning];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.preview.frame = self.view.bounds;
}

- (void)showDenied {
    [self showError:@"Camera denied. Enable it in Settings → Locket Legacy."];
}

- (void)showError:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Scanner" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Back" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)onCancel {
    [self.session stopRunning];
    if (self.completion) { LDQRScanCompletion cb = self.completion; self.completion = nil; cb(nil); }
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output
didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)objects
       fromConnection:(AVCaptureConnection *)connection {
    if (self.handled) return;
    for (AVMetadataObject *o in objects) {
        if (![o isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) continue;
        NSString *v = [(AVMetadataMachineReadableCodeObject *)o stringValue];
        NSString *api = [[self class] apiURLFromScannedString:v];
        if (api) {
            self.handled = YES;
            [self.session stopRunning];
            if (self.completion) { LDQRScanCompletion cb = self.completion; self.completion = nil; cb(api); }
            [self.navigationController popViewControllerAnimated:YES];
            return;
        } else if (v.length > 0) {
            self.hintLabel.text = [NSString stringWithFormat:@"Not a server QR:\n%@\n\nShow the dashboard QR (http://<host>:5001)", v];
        }
    }
}

@end
