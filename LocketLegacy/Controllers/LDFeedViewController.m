#import "LDFeedViewController.h"
#import "../API/LDAPIClient.h"
#import "../API/LDDiskCache.h"
#import "../Models/LDMoment.h"
#import "../Views/LDMomentCell.h"
#import "LDDetailViewController.h"

@interface LDFeedViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic, strong) NSArray<LDMoment *> *moments;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UILabel *streakLabel;
@property (nonatomic, strong) UIButton *outboxButton;
@end

@implementation LDFeedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Moments";
    self.view.backgroundColor = [UIColor blackColor];

    self.streakLabel = [[UILabel alloc] init];
    self.streakLabel.textAlignment = NSTextAlignmentCenter;
    self.streakLabel.textColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    self.streakLabel.font = [UIFont boldSystemFontOfSize:14];
    self.streakLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.streakLabel];

    self.outboxButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.outboxButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.outboxButton.backgroundColor = [UIColor orangeColor];
    self.outboxButton.layer.cornerRadius = 8;
    self.outboxButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.outboxButton addTarget:self action:@selector(retryOutbox) forControlEvents:UIControlEventTouchUpInside];
    self.outboxButton.hidden = YES;
    self.outboxButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.outboxButton];

    UICollectionViewFlowLayout *lo = [[UICollectionViewFlowLayout alloc] init];
    lo.minimumInteritemSpacing = 2; lo.minimumLineSpacing = 2;
    self.grid = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:lo];
    self.grid.backgroundColor = [UIColor blackColor];
    self.grid.dataSource = self; self.grid.delegate = self;
    [self.grid registerClass:[LDMomentCell class] forCellWithReuseIdentifier:@"M"];
    self.grid.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.grid];

    self.refresh = [[UIRefreshControl alloc] init];
    [self.refresh addTarget:self action:@selector(load) forControlEvents:UIControlEventValueChanged];
    if (@available(iOS 10.0, *)) self.grid.refreshControl = self.refresh;

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"No moments yet.\nCapture your first photo!";
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor lightGrayColor];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.streakLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:6],
        [self.streakLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.streakLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.streakLabel.heightAnchor constraintEqualToConstant:22],
        [self.outboxButton.topAnchor constraintEqualToAnchor:self.streakLabel.bottomAnchor constant:4],
        [self.outboxButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.outboxButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.outboxButton.heightAnchor constraintEqualToConstant:36],
        [self.grid.topAnchor constraintEqualToAnchor:self.outboxButton.bottomAnchor constant:4],
        [self.grid.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.grid.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.grid.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(load)];
    [self load];
    [self updateOutbox];
}

- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self updateOutbox]; }

- (void)updateOutbox {
    NSArray *pending = [LDDiskCache pendingOutboxItems];
    self.outboxButton.hidden = (pending.count == 0);
    [self.outboxButton setTitle:[NSString stringWithFormat:@"⏳ %lu failed upload(s) — tap to retry", (unsigned long)pending.count] forState:UIControlStateNormal];
}

- (void)retryOutbox {
    NSArray *pending = [LDDiskCache pendingOutboxItems];
    if (!pending.count) { [self updateOutbox]; return; }
    [self.outboxButton setTitle:@"Retrying…" forState:UIControlStateNormal];
    [self sendOutboxItem:pending.firstObject rest:[pending subarrayWithRange:NSMakeRange(1, pending.count - 1)]];
}

- (void)sendOutboxItem:(NSDictionary *)item rest:(NSArray *)rest {
    NSString *itemId = item[@"id"];
    NSURL *file = [NSURL fileURLWithPath:item[@"filePath"]];
    NSString *aud = [item[@"audience"] isKindOfClass:[NSString class]] ? item[@"audience"] : @"all";
    [[LDAPIClient shared] sendMomentOriginalFlowWithFileURL:file
                                                    isVideo:[item[@"isVideo"] boolValue]
                                                    caption:item[@"caption"] ?: @""
                                                   audience:aud
                                               extraOptions:nil
                                                   progress:nil
                                                 completion:^(NSDictionary *json, NSError *error) {
        if (!error && [json[@"success"] boolValue]) {
            [LDDiskCache markOutboxSent:itemId error:nil];
        } else {
            [LDDiskCache markOutboxSent:itemId error:error ? error.localizedDescription : @"failed"];
        }
        if (rest.count) [self sendOutboxItem:rest.firstObject rest:[rest subarrayWithRange:NSMakeRange(1, rest.count - 1)]];
        else { [self updateOutbox]; [self load]; }
    }];
}

- (void)load {
    // Offline-first: show cache immediately, then refresh (mirrors IndexedDB hydrate).
    id cached = [LDDiskCache loadMomentsJSON];
    if (cached && !self.moments) {
        self.moments = [LDMoment listFromJSON:cached];
        self.emptyLabel.hidden = (self.moments.count > 0);
        [self.grid reloadData];
    }
    [[LDAPIClient shared] getMomentsWithCompletion:^(NSDictionary *json, NSError *error) {
        [self.refresh endRefreshing];
        if (!error) {
            [LDDiskCache saveMomentsJSON:json];
            self.moments = [LDMoment listFromJSON:json];
            self.emptyLabel.hidden = (self.moments.count > 0);
            NSDictionary *streak = json[@"streak"];
            NSInteger n = [streak isKindOfClass:[NSDictionary class]] ? [streak[@"count"] integerValue] : 0;
            self.streakLabel.text = n > 0 ? [NSString stringWithFormat:@"🔥 %ld day streak", (long)n] : @"";
            [self.grid reloadData];
        } else if (!self.moments) {
            self.emptyLabel.hidden = NO;
            self.emptyLabel.text = [NSString stringWithFormat:@"Offline — showing cache when available.\n%@", error.localizedDescription];
        }
    }];
}

- (NSInteger)collectionView:(UICollectionView *)c numberOfItemsInSection:(NSInteger)s { return self.moments.count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)c cellForItemAtIndexPath:(NSIndexPath *)p {
    LDMomentCell *cell = [c dequeueReusableCellWithReuseIdentifier:@"M" forIndexPath:p];
    [cell configure:self.moments[p.item]];
    return cell;
}
- (void)collectionView:(UICollectionView *)c didSelectItemAtIndexPath:(NSIndexPath *)p {
    [c deselectItemAtIndexPath:p animated:YES];
    LDDetailViewController *d = [[LDDetailViewController alloc] initWithMoment:self.moments[p.item]];
    [self.navigationController pushViewController:d animated:YES];
}
- (CGSize)collectionView:(UICollectionView *)c layout:(UICollectionViewLayout *)l sizeForItemAtIndexPath:(NSIndexPath *)p {
    CGFloat w = (c.bounds.size.width - 4) / 3.0;
    return CGSizeMake(w, w);
}

@end
