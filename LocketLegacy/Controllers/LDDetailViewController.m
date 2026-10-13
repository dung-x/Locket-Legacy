// Moment detail: full media, meta, emoji reactions (❤️ 🔥 😂 + more).
#import "LDDetailViewController.h"
#import "../API/LDAPIClient.h"
#import "../API/LDMediaLoader.h"
#import "../Config.h"
#import "../Models/LDMoment.h"

@interface LDDetailViewController ()
@property (nonatomic, strong) LDMoment *moment;
@property (nonatomic, strong) UIImageView *iv;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UILabel *reactLabel;
@end

@implementation LDDetailViewController

- (instancetype)initWithMoment:(LDMoment *)moment {
    self = [super init];
    if (self) _moment = moment;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Moment";
    self.view.backgroundColor = [UIColor blackColor];

    self.iv = [[UIImageView alloc] init];
    self.iv.contentMode = UIViewContentModeScaleAspectFit;
    self.iv.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.iv];

    self.metaLabel = [[UILabel alloc] init];
    self.metaLabel.numberOfLines = 0;
    self.metaLabel.textColor = [UIColor whiteColor];
    self.metaLabel.font = [UIFont systemFontOfSize:14];
    self.metaLabel.textAlignment = NSTextAlignmentCenter;
    self.metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.metaLabel];

    self.reactLabel = [[UILabel alloc] init];
    self.reactLabel.textColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    self.reactLabel.font = [UIFont systemFontOfSize:16];
    self.reactLabel.textAlignment = NSTextAlignmentCenter;
    self.reactLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.reactLabel];

    NSArray *quick = @[@"❤️", @"🔥", @"😂"];
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:row];
    UIButton *prev = nil;
    for (NSString *e in quick) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        [b setTitle:e forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:30];
        [b addTarget:self action:@selector(onReact:) forControlEvents:UIControlEventTouchUpInside];
        b.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:b];
        [NSLayoutConstraint activateConstraints:@[
            [b.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [b.widthAnchor constraintEqualToConstant:60],
        ]];
        if (prev) [NSLayoutConstraint activateConstraints:@[[b.leadingAnchor constraintEqualToAnchor:prev.trailingAnchor constant:16]]];
        else [NSLayoutConstraint activateConstraints:@[[b.leadingAnchor constraintEqualToAnchor:row.leadingAnchor]]];
        prev = b;
    }
    UIButton *more = [UIButton buttonWithType:UIButtonTypeSystem];
    [more setTitle:@"＋" forState:UIControlStateNormal];
    more.titleLabel.font = [UIFont systemFontOfSize:24];
    [more setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    [more addTarget:self action:@selector(onMoreReact) forControlEvents:UIControlEventTouchUpInside];
    more.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:more];
    [NSLayoutConstraint activateConstraints:@[
        [more.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [more.leadingAnchor constraintEqualToAnchor:prev.trailingAnchor constant:16],
        [more.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [self.iv.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.iv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.iv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.iv.heightAnchor constraintEqualToAnchor:self.iv.widthAnchor],
        [self.metaLabel.topAnchor constraintEqualToAnchor:self.iv.bottomAnchor constant:12],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.iv.leadingAnchor],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.iv.trailingAnchor],
        [self.reactLabel.topAnchor constraintEqualToAnchor:self.metaLabel.bottomAnchor constant:8],
        [self.reactLabel.leadingAnchor constraintEqualToAnchor:self.iv.leadingAnchor],
        [self.reactLabel.trailingAnchor constraintEqualToAnchor:self.iv.trailingAnchor],
        [row.topAnchor constraintEqualToAnchor:self.reactLabel.bottomAnchor constant:12],
        [row.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [row.heightAnchor constraintEqualToConstant:60],
    ]];

    [self renderMeta];
    [self loadImage];
    [self refreshReactions];
}

- (void)renderMeta {
    NSString *cap = self.moment.caption.length ? self.moment.caption : @"(no caption)";
    NSString *who = self.moment.authorName.length ? self.moment.authorName : @"friend";
    NSString *when = self.moment.createdAt.length ? self.moment.createdAt : @"";
    self.metaLabel.text = [NSString stringWithFormat:@"%@\n👤 %@  •  %@%@", cap, who, self.moment.isVideo ? @"🎬 video" : @"📷 photo", when.length ? [@"  •  " stringByAppendingString:when] : @""];
}

- (void)renderReactions {
    NSMutableArray *parts = [NSMutableArray array];
    NSArray *keys = [[self.moment.reactions allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *e in keys) {
        [parts addObject:[NSString stringWithFormat:@"%@ %@", e, self.moment.reactions[e]]];
    }
    self.reactLabel.text = parts.count ? [parts componentsJoinedByString:@"   "] : @"Be the first to react!";
}

- (void)loadImage {
    // Video shows its thumbnail poster; photos load full media (thumbnail fallback).
    NSString *url = self.moment.isVideo
        ? (self.moment.thumbnailURL.length ? self.moment.thumbnailURL : self.moment.videoURL)
        : (self.moment.imageURL.length ? self.moment.imageURL : self.moment.thumbnailURL);
    if (!url.length) {
        self.metaLabel.text = [self.metaLabel.text stringByAppendingString:@"\n⚠️ no media URL in this moment"];
        return;
    }
    if (self.moment.isVideo) { self.iv.image = nil; self.metaLabel.text = [self.metaLabel.text stringByAppendingString:[NSString stringWithFormat:@"\n▶ %@", self.moment.videoURL]]; }
    self.metaLabel.text = [self.metaLabel.text stringByAppendingString:[NSString stringWithFormat:@"\n🔗 %@", url]];
    [LDMediaLoader loadImageWithURLString:url completion:^(UIImage *img, NSInteger status, NSError *error) {
        if (img) {
            self.iv.image = img;
        } else {
            NSString *why = error ? error.localizedDescription : @"load failed";
            self.metaLabel.text = [self.metaLabel.text stringByAppendingString:[NSString stringWithFormat:@"\n⚠️ %@", why]];
        }
    }];
}

- (void)refreshReactions {
    // Production shape: getMomentReactions -> data (array of {emoji,…} or counts).
    if ([[LDConfig backendMode] isEqualToString:@"original"]) {
        [[LDAPIClient shared] getMomentReactions:self.moment.momentId completion:^(NSDictionary *json, NSError *error) {
            if (error) return;
            id d = json[@"data"];
            NSMutableDictionary *counts = [NSMutableDictionary dictionary];
            if ([d isKindOfClass:[NSArray class]]) {
                for (id o in d) {
                    NSString *e = [o isKindOfClass:[NSDictionary class]] ? o[@"emoji"] : nil;
                    if (![e isKindOfClass:[NSString class]] || !e.length) continue;
                    counts[e] = @([counts[e] integerValue] + 1);
                }
            } else if ([d isKindOfClass:[NSDictionary class]]) {
                for (id k in d) { if ([d[k] isKindOfClass:[NSNumber class]]) counts[k] = d[k]; }
            }
            if (counts.count) { self.moment.reactions = counts; [self renderReactions]; }
        }];
        return;
    }
    [[LDAPIClient shared] getInfoMoment:self.moment.momentId completion:^(NSDictionary *json, NSError *error) {
        if (error) return;
        NSArray *list = [LDMoment listFromJSON:json];
        if (list.count > 0) {
            LDMoment *m = list[0];
            self.moment.reactions = m.reactions;
            [self renderReactions];
        }
    }];
}

- (void)onReact:(UIButton *)b {
    NSString *emoji = b.titleLabel.text ?: @"❤️";
    [[LDAPIClient shared] reactToMoment:self.moment.momentId emoji:emoji completion:^(NSDictionary *json, NSError *error) {
        if (!error && [json[@"success"] boolValue]) {
            NSDictionary *r = json[@"data"][@"reactions"];
            if ([r isKindOfClass:[NSDictionary class]]) self.moment.reactions = r;
            [self renderReactions];
        }
    }];
}

- (void)onMoreReact {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"React" message:@"Pick an emoji" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *f) { f.placeholder = @"😍"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Send" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        NSString *e = a.textFields.firstObject.text;
        if (!e.length) return;
        [[LDAPIClient shared] reactToMoment:self.moment.momentId emoji:e completion:^(NSDictionary *json, NSError *error) {
            if (!error && [json[@"success"] boolValue]) {
                NSDictionary *r = json[@"data"][@"reactions"];
                if ([r isKindOfClass:[NSDictionary class]]) self.moment.reactions = r;
                [self renderReactions];
            }
        }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
