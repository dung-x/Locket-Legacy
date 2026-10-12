// Preview + caption + audience + upload (mirrors web preview/caption/overlay flow)
#import "LDPreviewViewController.h"
#import "../API/LDAPIClient.h"
#import <AVFoundation/AVFoundation.h>

@interface LDPreviewViewController ()
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) NSURL *videoURL;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UITextField *captionField;
@property (nonatomic, strong) UISegmentedControl *audience;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation LDPreviewViewController

- (instancetype)initWithImage:(UIImage *)image videoURL:(NSURL *)videoURL {
    self = [super init];
    if (self) { _image = image; _videoURL = videoURL; }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Preview";
    self.view.backgroundColor = [UIColor blackColor];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.backgroundColor = [UIColor blackColor];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.imageView];

    if (self.image) self.imageView.image = self.image;
    if (self.videoURL) {
        self.player = [AVPlayer playerWithURL:self.videoURL];
        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFit;
        [self.imageView.layer addSublayer:self.playerLayer];
        [self.player play];
    }

    self.captionField = [[UITextField alloc] init];
    self.captionField.placeholder = @"Add a caption…";
    self.captionField.textColor = [UIColor whiteColor];
    self.captionField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.captionField.layer.cornerRadius = 10;
    self.captionField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
    self.captionField.leftViewMode = UITextFieldViewModeAlways;
    self.captionField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.captionField];

    self.audience = [[UISegmentedControl alloc] initWithItems:@[@"All friends", @"Selected"]];
    self.audience.selectedSegmentIndex = 0;
    self.audience.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.audience];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sendButton setTitle:@"Send ➤" forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.sendButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.sendButton.backgroundColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    self.sendButton.layer.cornerRadius = 12;
    [self.sendButton addTarget:self action:@selector(onSend) forControlEvents:UIControlEventTouchUpInside];
    self.sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.sendButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.imageView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.imageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.imageView.heightAnchor constraintEqualToAnchor:self.imageView.widthAnchor],
        [self.captionField.topAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:16],
        [self.captionField.leadingAnchor constraintEqualToAnchor:self.imageView.leadingAnchor],
        [self.captionField.trailingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor],
        [self.captionField.heightAnchor constraintEqualToConstant:46],
        [self.audience.topAnchor constraintEqualToAnchor:self.captionField.bottomAnchor constant:12],
        [self.audience.leadingAnchor constraintEqualToAnchor:self.captionField.leadingAnchor],
        [self.audience.trailingAnchor constraintEqualToAnchor:self.captionField.trailingAnchor],
        [self.sendButton.topAnchor constraintEqualToAnchor:self.audience.bottomAnchor constant:16],
        [self.sendButton.leadingAnchor constraintEqualToAnchor:self.captionField.leadingAnchor],
        [self.sendButton.trailingAnchor constraintEqualToAnchor:self.captionField.trailingAnchor],
        [self.sendButton.heightAnchor constraintEqualToConstant:50],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.sendButton.bottomAnchor constant:12],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.captionField.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.captionField.trailingAnchor],
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.playerLayer.frame = self.imageView.bounds;
}

- (NSURL *)stagedFileURL:(BOOL)isVideo {
    NSString *name = isVideo ? @"upload.mov" : @"upload.jpg";
    NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    if (isVideo) {
        if (self.videoURL && ![self.videoURL.path isEqualToString:p]) {
            [[NSFileManager defaultManager] removeItemAtPath:p error:nil];
            [[NSFileManager defaultManager] copyItemAtPath:self.videoURL.path toPath:p error:nil];
        }
    } else {
        NSData *d = UIImageJPEGRepresentation(self.image, 0.85);
        [d writeToFile:p atomically:YES];
    }
    return [NSURL fileURLWithPath:p];
}

- (void)onSend {
    [self.view endEditing:YES];
    BOOL isVideo = (self.videoURL != nil);
    NSURL *file = [self stagedFileURL:isVideo];
    NSString *caption = self.captionField.text ?: @"";
    self.sendButton.enabled = NO;
    self.statusLabel.text = @"Uploading via postMomentV1…";
    [[LDAPIClient shared] postMomentV1WithFileURL:file isVideo:isVideo caption:caption completion:^(NSDictionary *json, NSError *error) {
        self.sendButton.enabled = YES;
        if (error) { self.statusLabel.text = error.localizedDescription; return; }
        if ([json[@"success"] boolValue]) {
            self.statusLabel.text = @"Sent! 🎉";
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Sent" message:@"Your moment was uploaded." preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                [self.navigationController popToRootViewControllerAnimated:YES];
            }]];
            [self presentViewController:a animated:YES completion:nil];
        } else {
            NSString *msg = json[@"message"];
            if (![msg isKindOfClass:[NSString class]] || !msg.length) msg = @"Upload failed.";
            self.statusLabel.text = msg;
        }
    }];
}

@end
