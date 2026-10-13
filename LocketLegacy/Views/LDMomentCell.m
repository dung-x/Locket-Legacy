#import "LDMomentCell.h"
#import "../Models/LDMoment.h"

@interface LDMomentCell ()
@property (nonatomic, strong) UIImageView *iv;
@property (nonatomic, strong) UILabel *cap;
@end

@implementation LDMomentCell

- (instancetype)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (self) {
        self.contentView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
        _iv = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iv.contentMode = UIViewContentModeScaleAspectFill;
        _iv.clipsToBounds = YES;
        _iv.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_iv];
        _cap = [[UILabel alloc] init];
        _cap.font = [UIFont systemFontOfSize:10];
        _cap.textColor = [UIColor whiteColor];
        _cap.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
        _cap.numberOfLines = 2;
        _cap.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_cap];
        [NSLayoutConstraint activateConstraints:@[
            [_iv.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_iv.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_iv.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_iv.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [_cap.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:4],
            [_cap.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4],
            [_cap.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],
        ]];
    }
    return self;
}

- (void)configure:(LDMoment *)m {
    self.cap.text = m.isVideo ? [NSString stringWithFormat:@"▶ %@", m.caption] : m.caption;
    self.iv.image = nil;
    // Grid prefers the thumbnail (matches web thumbs); falls back to full media.
    NSString *url = m.thumbnailURL.length ? m.thumbnailURL : (m.isVideo ? m.videoURL : m.imageURL);
    if (!url.length) return;
    NSURL *u = [NSURL URLWithString:url];
    if (!u) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *d = [NSData dataWithContentsOfURL:u];
        UIImage *img = d ? [UIImage imageWithData:d] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ if (img) self.iv.image = img; });
    });
}

@end
