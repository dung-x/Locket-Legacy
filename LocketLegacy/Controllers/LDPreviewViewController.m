// Preview + caption + overlay + music + recipients + upload.
// Mirrors web preview/caption/overlay flow (createRequestPayloadV5 shape).
#import "LDPreviewViewController.h"
#import "../API/LDAPIClient.h"
#import "../API/LDDiskCache.h"
#import "../Config.h"
#import "../Models/LDOverlay.h"
#import "../Models/LDFriend.h"
#import <AVFoundation/AVFoundation.h>

@interface LDPreviewViewController () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) NSURL *videoURL;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *styledCaption;
@property (nonatomic, strong) UITextField *captionField;
@property (nonatomic, strong) UISegmentedControl *audience;
@property (nonatomic, strong) UIScrollView *overlayRow;
@property (nonatomic, strong) NSArray<LDOverlay *> *overlays;
@property (nonatomic, strong) LDOverlay *selectedOverlay;
@property (nonatomic, strong) UITextField *iconField;
@property (nonatomic, strong) UITextField *musicField;
@property (nonatomic, strong) UIButton *musicButton;
@property (nonatomic, strong) AVPlayer *musicPlayer;
@property (nonatomic, strong) UITableView *recipientsTable;
@property (nonatomic, strong) NSArray<LDFriend *> *friends;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedIds;
@property (nonatomic, strong) NSLayoutConstraint *recipientsHeight;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation LDPreviewViewController

- (instancetype)initWithImage:(UIImage *)image videoURL:(NSURL *)videoURL {
    self = [super init];
    if (self) {
        _image = image; _videoURL = videoURL;
        _overlays = @[[LDOverlay standardOverlay]];
        _selectedOverlay = _overlays[0];
        _selectedIds = [NSMutableSet set];
    }
    return self;
}

+ (UIColor *)colorFromHex:(NSString *)hex fallback:(UIColor *)fb {
    NSString *h = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([h hasPrefix:@"#"]) h = [h substringFromIndex:1];
    if (h.length != 6) return fb;
    unsigned v = 0;
    NSScanner *sc = [NSScanner scannerWithString:h];
    if (![sc scanHexInt:&v]) return fb;
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0 blue:(v & 0xFF) / 255.0 alpha:1];
}

- (UITextField *)rowField:(NSString *)placeholder {
    UITextField *f = [[UITextField alloc] init];
    f.placeholder = placeholder;
    f.textColor = [UIColor whiteColor];
    f.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    f.layer.cornerRadius = 10;
    f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,12,1)];
    f.leftViewMode = UITextFieldViewModeAlways;
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.delegate = self;
    f.returnKeyType = UIReturnKeyDone;
    f.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:f];
    return f;
}

- (UILabel *)caption:(NSString *)text {
    UILabel *l = [[UILabel alloc] init];
    l.text = text;
    l.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    l.font = [UIFont boldSystemFontOfSize:12];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:l];
    return l;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Preview";
    self.view.backgroundColor = [UIColor blackColor];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [content.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],
    ]];
    // Reparent helper: add to content instead of self.view.
    UIView *V = content;

    self.imageView = [[UIImageView alloc] init];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.backgroundColor = [UIColor blackColor];
    self.imageView.userInteractionEnabled = YES;
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.imageView];

    if (self.image) self.imageView.image = self.image;
    if (self.videoURL) {
        self.player = [AVPlayer playerWithURL:self.videoURL];
        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [self.imageView.layer addSublayer:self.playerLayer];
        [self.player play];
    }

    // Styled caption overlay rendered over the photo (mirrors overlay theme).
    self.styledCaption = [[UILabel alloc] init];
    self.styledCaption.textAlignment = NSTextAlignmentCenter;
    self.styledCaption.numberOfLines = 2;
    self.styledCaption.font = [UIFont boldSystemFontOfSize:18];
    self.styledCaption.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    self.styledCaption.layer.cornerRadius = 8;
    self.styledCaption.clipsToBounds = YES;
    self.styledCaption.translatesAutoresizingMaskIntoConstraints = NO;
    [self.imageView addSubview:self.styledCaption];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapBackground)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    UILabel *c1 = [self caption:@"Caption"]; [V addSubview:c1];
    self.captionField = [self rowField:@"Add a caption…"]; [V addSubview:self.captionField];
    [self.captionField addTarget:self action:@selector(onCaptionChanged) forControlEvents:UIControlEventEditingChanged];
    self.captionField.inputAccessoryView = [self keyboardToolbar];

    UILabel *c2 = [self caption:@"Overlay style"]; [V addSubview:c2];
    self.overlayRow = [[UIScrollView alloc] init];
    self.overlayRow.showsHorizontalScrollIndicator = NO;
    self.overlayRow.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.overlayRow];

    UILabel *c3 = [self caption:@"Icon emoji (optional)"]; [V addSubview:c3];
    self.iconField = [self rowField:@"❤️"]; [V addSubview:self.iconField];
    [self.iconField addTarget:self action:@selector(onCaptionChanged) forControlEvents:UIControlEventEditingChanged];

    UILabel *c4 = [self caption:@"Music URL (optional, plays in preview)"]; [V addSubview:c4];
    self.musicField = [self rowField:@"https://…/song.mp3"]; [V addSubview:self.musicField];
    self.musicField.keyboardType = UIKeyboardTypeURL;
    self.musicButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.musicButton setTitle:@"▶ Preview music" forState:UIControlStateNormal];
    [self.musicButton addTarget:self action:@selector(onMusicToggle) forControlEvents:UIControlEventTouchUpInside];
    self.musicButton.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.musicButton];

    UILabel *c5 = [self caption:@"Audience"]; [V addSubview:c5];
    self.audience = [[UISegmentedControl alloc] initWithItems:@[@"All friends", @"Selected"]];
    self.audience.selectedSegmentIndex = 0;
    [self.audience addTarget:self action:@selector(onAudienceChanged) forControlEvents:UIControlEventValueChanged];
    self.audience.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.audience];

    self.recipientsTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.recipientsTable.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    self.recipientsTable.dataSource = self; self.recipientsTable.delegate = self;
    self.recipientsTable.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.recipientsTable];
    self.recipientsHeight = [self.recipientsTable.heightAnchor constraintEqualToConstant:0];
    self.recipientsHeight.active = YES;

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sendButton setTitle:@"Send ➤" forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.sendButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.sendButton.backgroundColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    self.sendButton.layer.cornerRadius = 12;
    [self.sendButton addTarget:self action:@selector(onSend) forControlEvents:UIControlEventTouchUpInside];
    self.sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.sendButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [V addSubview:self.statusLabel];

    UIView *iv = self.imageView;
    [NSLayoutConstraint activateConstraints:@[
        [iv.topAnchor constraintEqualToAnchor:V.topAnchor constant:8],
        [iv.leadingAnchor constraintEqualToAnchor:V.leadingAnchor constant:16],
        [iv.trailingAnchor constraintEqualToAnchor:V.trailingAnchor constant:-16],
        [iv.heightAnchor constraintEqualToAnchor:iv.widthAnchor],
        [self.styledCaption.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor constant:12],
        [self.styledCaption.trailingAnchor constraintEqualToAnchor:iv.trailingAnchor constant:-12],
        [self.styledCaption.bottomAnchor constraintEqualToAnchor:iv.bottomAnchor constant:-12],
        [c1.topAnchor constraintEqualToAnchor:iv.bottomAnchor constant:14],
        [c1.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.captionField.topAnchor constraintEqualToAnchor:c1.bottomAnchor constant:6],
        [self.captionField.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.captionField.trailingAnchor constraintEqualToAnchor:iv.trailingAnchor],
        [self.captionField.heightAnchor constraintEqualToConstant:46],
        [c2.topAnchor constraintEqualToAnchor:self.captionField.bottomAnchor constant:12],
        [c2.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.overlayRow.topAnchor constraintEqualToAnchor:c2.bottomAnchor constant:6],
        [self.overlayRow.leadingAnchor constraintEqualToAnchor:V.leadingAnchor constant:16],
        [self.overlayRow.trailingAnchor constraintEqualToAnchor:V.trailingAnchor constant:-16],
        [self.overlayRow.heightAnchor constraintEqualToConstant:40],
        [c3.topAnchor constraintEqualToAnchor:self.overlayRow.bottomAnchor constant:12],
        [c3.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.iconField.topAnchor constraintEqualToAnchor:c3.bottomAnchor constant:6],
        [self.iconField.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.iconField.trailingAnchor constraintEqualToAnchor:iv.trailingAnchor],
        [self.iconField.heightAnchor constraintEqualToConstant:46],
        [c4.topAnchor constraintEqualToAnchor:self.iconField.bottomAnchor constant:12],
        [c4.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.musicField.topAnchor constraintEqualToAnchor:c4.bottomAnchor constant:6],
        [self.musicField.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.musicField.trailingAnchor constraintEqualToAnchor:iv.trailingAnchor],
        [self.musicField.heightAnchor constraintEqualToConstant:46],
        [self.musicButton.topAnchor constraintEqualToAnchor:self.musicField.bottomAnchor constant:4],
        [self.musicButton.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [c5.topAnchor constraintEqualToAnchor:self.musicButton.bottomAnchor constant:12],
        [c5.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.audience.topAnchor constraintEqualToAnchor:c5.bottomAnchor constant:6],
        [self.audience.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.audience.trailingAnchor constraintEqualToAnchor:iv.trailingAnchor],
        [self.recipientsTable.topAnchor constraintEqualToAnchor:self.audience.bottomAnchor constant:8],
        [self.recipientsTable.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.recipientsTable.trailingAnchor constraintEqualToAnchor:iv.trailingAnchor],
        [self.sendButton.topAnchor constraintEqualToAnchor:self.recipientsTable.bottomAnchor constant:16],
        [self.sendButton.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.sendButton.trailingAnchor constraintEqualToAnchor:iv.trailingAnchor],
        [self.sendButton.heightAnchor constraintEqualToConstant:50],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.sendButton.bottomAnchor constant:12],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:iv.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:iv.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:V.bottomAnchor constant:-24],
    ]];

    [self buildOverlayRow];
    [self loadOverlays];
    [self loadFriends];
    [self onCaptionChanged];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.playerLayer.frame = self.imageView.bounds;
}

#pragma mark - Keyboard

- (UIToolbar *)keyboardToolbar {
    UIToolbar *bar = [[UIToolbar alloc] init];
    [bar sizeToFit];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onTapBackground)];
    bar.items = @[flex, done];
    return bar;
}

- (void)onTapBackground { [self.view endEditing:YES]; }
- (BOOL)textFieldShouldReturn:(UITextField *)t { [t resignFirstResponder]; return YES; }

#pragma mark - Overlays

- (void)buildOverlayRow {
    for (UIView *v in self.overlayRow.subviews) [v removeFromSuperview];
    CGFloat x = 0;
    for (LDOverlay *o in self.overlays) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        NSString *title = [NSString stringWithFormat:@"%@ %@", o.icon.length ? o.icon : @"◻️", o.title];
        [b setTitle:title forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:14];
        b.backgroundColor = [o.overlayId isEqualToString:self.selectedOverlay.overlayId]
            ? [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1] : [UIColor colorWithWhite:0.2 alpha:1];
        if ([b.backgroundColor isEqual:[UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1]]) {
            [b setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        }
        b.layer.cornerRadius = 8;
        b.tag = [self.overlays indexOfObject:o];
        [b addTarget:self action:@selector(onPickOverlay:) forControlEvents:UIControlEventTouchUpInside];
        [b sizeToFit];
        CGRect f = b.frame;
        f.origin = CGPointMake(x, 0);
        f.size.width += 24; f.size.height = 36;
        b.frame = f;
        [self.overlayRow addSubview:b];
        x += f.size.width + 8;
    }
    self.overlayRow.contentSize = CGSizeMake(x, 40);
}

- (void)loadOverlays {
    id cached = [LDDiskCache loadOverlaysJSON];
    if (cached) { self.overlays = [LDOverlay listFromJSON:cached]; [self buildOverlayRow]; }
    [[LDAPIClient shared] getOverlaysWithCompletion:^(NSDictionary *json, NSError *error) {
        if (error) return;
        NSArray *list = [LDOverlay listFromJSON:json];
        if (list.count > 0) {
            [LDDiskCache saveOverlaysJSON:json];
            NSString *keep = self.selectedOverlay.overlayId;
            self.overlays = list;
            for (LDOverlay *o in list) {
                if ([o.overlayId isEqualToString:keep]) { self.selectedOverlay = o; break; }
            }
            [self buildOverlayRow];
            [self onCaptionChanged];
        }
    }];
}

- (void)onPickOverlay:(UIButton *)b {
    if (b.tag >= 0 && b.tag < (NSInteger)self.overlays.count) {
        self.selectedOverlay = self.overlays[b.tag];
        if (!self.iconField.text.length) self.iconField.text = self.selectedOverlay.icon;
        [self buildOverlayRow];
        [self onCaptionChanged];
    }
}

- (void)onCaptionChanged {
    NSString *cap = self.captionField.text ?: @"";
    NSString *icon = self.iconField.text.length ? self.iconField.text : self.selectedOverlay.icon;
    self.styledCaption.text = [NSString stringWithFormat:@"%@ %@", icon.length ? icon : @"", cap];
    self.styledCaption.textColor = [[self class] colorFromHex:self.selectedOverlay.textColor fallback:[UIColor whiteColor]];
    if (self.selectedOverlay.colorTop.length) {
        self.styledCaption.backgroundColor = [[self class] colorFromHex:self.selectedOverlay.colorTop fallback:[[UIColor blackColor] colorWithAlphaComponent:0.55]];
    } else {
        self.styledCaption.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    }
    self.styledCaption.hidden = (self.styledCaption.text.length <= 1 && !cap.length);
}

#pragma mark - Music

- (void)onMusicToggle {
    [self.view endEditing:YES];
    if (self.musicPlayer) {
        [self.musicPlayer pause];
        self.musicPlayer = nil;
        [self.musicButton setTitle:@"▶ Preview music" forState:UIControlStateNormal];
        return;
    }
    NSString *u = [self.musicField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![u.lowercaseString hasPrefix:@"http"]) { self.statusLabel.text = @"Music needs an http(s) URL."; return; }
    self.musicPlayer = [AVPlayer playerWithURL:[NSURL URLWithString:u]];
    [self.musicPlayer play];
    [self.musicButton setTitle:@"⏸ Stop music" forState:UIControlStateNormal];
}

#pragma mark - Recipients

- (void)onAudienceChanged {
    BOOL sel = (self.audience.selectedSegmentIndex == 1);
    self.recipientsHeight.constant = sel ? 132 : 0;
    [self.view layoutIfNeeded];
}

- (void)loadFriends {
    id cached = [LDDiskCache loadFriendsJSON];
    if (cached) self.friends = [LDFriend listFromJSON:cached];
    [[LDAPIClient shared] getAllFriendsWithCompletion:^(NSDictionary *json, NSError *error) {
        if (error) { [self.recipientsTable reloadData]; return; }
        [LDDiskCache saveFriendsJSON:json];
        self.friends = [LDFriend listFromJSON:json];
        [self.recipientsTable reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.friends.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    static NSString *rid = @"R";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:rid];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:rid];
        c.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
        c.textLabel.textColor = [UIColor whiteColor];
        c.detailTextLabel.textColor = [UIColor lightGrayColor];
    }
    LDFriend *f = self.friends[p.row];
    c.textLabel.text = f.displayName.length ? f.displayName : @"(no name)";
    c.detailTextLabel.text = f.uid;
    c.accessoryType = [self.selectedIds containsObject:f.uid] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    [t deselectRowAtIndexPath:p animated:YES];
    LDFriend *f = self.friends[p.row];
    if ([self.selectedIds containsObject:f.uid]) [self.selectedIds removeObject:f.uid];
    else if (f.uid.length) [self.selectedIds addObject:f.uid];
    [t reloadRowsAtIndexPaths:@[p] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Media staging + send

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

// Video poster for the server thumbnail (official video posts require one).
- (NSURL *)stagedThumbnailURLForVideo:(NSURL *)videoURL {
    if (!videoURL) return nil;
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    AVAssetImageGenerator *gen = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    gen.maximumSize = CGSizeMake(512, 512);
    CGImageRef cg = [gen copyCGImageAtTime:kCMTimeZero actualTime:NULL error:nil];
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    if (!img) return nil;
    NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:@"thumb.jpg"];
    NSData *d = UIImageJPEGRepresentation(img, 0.8);
    if (![d writeToFile:p atomically:YES]) return nil;
    return [NSURL fileURLWithPath:p];
}

- (void)onSend {
    [self.view endEditing:YES];
    [self.musicPlayer pause];
    BOOL isVideo = (self.videoURL != nil);
    NSURL *file = [self stagedFileURL:isVideo];
    NSString *caption = self.captionField.text ?: @"";
    NSString *audience = (self.audience.selectedSegmentIndex == 1) ? @"selected" : @"all";
    if ([audience isEqualToString:@"selected"] && self.selectedIds.count == 0) {
        self.statusLabel.text = @"Pick at least one friend below for “Selected”, or switch to “All friends”.";
        self.sendButton.enabled = YES;
        return;
    }
    NSString *icon = self.iconField.text.length ? self.iconField.text : self.selectedOverlay.icon;
    NSDictionary *extra = @{@"overlay_id": self.selectedOverlay.overlayId ?: @"standard",
                            @"type": self.selectedOverlay.type ?: @"default",
                            @"icon": icon ?: @"",
                            @"text_color": self.selectedOverlay.textColor ?: @"#FFFFFF",
                            @"color_top": self.selectedOverlay.colorTop ?: @"",
                            @"color_bottom": self.selectedOverlay.colorBottom ?: @"",
                            @"music": [self.musicField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"",
                            @"recipients": [self.selectedIds allObjects]};
    self.sendButton.enabled = NO;
    if ([[LDConfig backendMode] isEqualToString:@"original"]) {
        // Original production chain: presigned PUT -> createMomentPayloadV2 -> official post.
        self.statusLabel.text = @"Sending (original method)…";
        [[LDAPIClient shared] sendMomentOriginalFlowWithFileURL:file
                                                        isVideo:isVideo
                                                        caption:caption
                                                       audience:audience
                                                   extraOptions:extra
                                                       progress:^(NSString *stage) {
                                                           self.statusLabel.text = stage;
                                                       }
                                                     completion:^(NSDictionary *json, NSError *error) {
            [self finishSendWithJSON:json error:error file:file isVideo:isVideo caption:caption audience:audience];
        }];
        return;
    }
    // Self-host bridge: direct multipart upload (file + thumbnail + optionsData);
    // the server runs the official Firebase/payload chain itself.
    self.statusLabel.text = @"Uploading to self-host…";
    NSURL *thumb = isVideo ? [self stagedThumbnailURLForVideo:file] : nil;
    [[LDAPIClient shared] postMomentV1WithFileURL:file
                                          isVideo:isVideo
                                     thumbnailURL:thumb
                                          caption:caption
                                         audience:audience
                                     extraOptions:extra
                                       completion:^(NSDictionary *json, NSError *error) {
        [self finishSendWithJSON:json error:error file:file isVideo:isVideo caption:caption audience:audience];
    }];
}

- (void)finishSendWithJSON:(NSDictionary *)json error:(NSError *)error file:(NSURL *)file isVideo:(BOOL)isVideo caption:(NSString *)caption audience:(NSString *)audience {
        if (error) {
            // Offline/failed → stage to outbox for retry (mirrors upload queue).
            NSDictionary *item = [LDDiskCache stageOutboxItemWithFileURL:file isVideo:isVideo caption:caption audience:audience];
            self.sendButton.enabled = YES;
            self.statusLabel.text = item
                ? [NSString stringWithFormat:@"Send failed (%@). Saved to outbox — retry from Moments.", error.localizedDescription]
                : error.localizedDescription;
            return;
        }
        self.sendButton.enabled = YES;
        if ([json[@"success"] boolValue]) {
            self.statusLabel.text = @"Sent! 🎉";
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Sent" message:@"Your moment was uploaded." preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                [self.navigationController popToRootViewControllerAnimated:YES];
            }]];
            [self presentViewController:a animated:YES completion:nil];
        } else {
            // Surface the server's own reason (code + message), not just "failed".
            NSString *msg = nil;
            id m = json[@"message"];
            if ([m isKindOfClass:[NSString class]] && ((NSString *)m).length) msg = m;
            id errObj = json[@"error"];
            if ([errObj isKindOfClass:[NSDictionary class]]) {
                NSString *code = errObj[@"code"];
                NSString *em = errObj[@"message"];
                if ([code isKindOfClass:[NSString class]] && [em isKindOfClass:[NSString class]]) {
                    msg = [NSString stringWithFormat:@"%@: %@", code, em];
                } else if ([em isKindOfClass:[NSString class]] && em.length) {
                    msg = em;
                }
            }
            if (![msg isKindOfClass:[NSString class]] || !msg.length) msg = @"Upload failed.";
            self.statusLabel.text = msg;
        }
}

@end
