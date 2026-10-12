#import "LDFeedViewController.h"
#import "../API/LDAPIClient.h"
#import "../Models/LDMoment.h"
#import "../Views/LDMomentCell.h"

@interface LDFeedViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic, strong) NSArray<LDMoment *> *moments;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation LDFeedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Moments";
    self.view.backgroundColor = [UIColor blackColor];

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
        [self.grid.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.grid.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.grid.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.grid.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(load)];
    [self load];
}

- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self load]; }

- (void)load {
    [[LDAPIClient shared] getMomentsWithCompletion:^(NSDictionary *json, NSError *error) {
        [self.refresh endRefreshing];
        if (!error) {
            self.moments = [LDMoment listFromJSON:json];
            self.emptyLabel.hidden = (self.moments.count > 0);
            [self.grid reloadData];
        } else {
            self.emptyLabel.hidden = NO;
            self.emptyLabel.text = [NSString stringWithFormat:@"Load failed:\n%@", error.localizedDescription];
        }
    }];
}

- (NSInteger)collectionView:(UICollectionView *)c numberOfItemsInSection:(NSInteger)s { return self.moments.count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)c cellForItemAtIndexPath:(NSIndexPath *)p {
    LDMomentCell *cell = [c dequeueReusableCellWithReuseIdentifier:@"M" forIndexPath:p];
    [cell configure:self.moments[p.item]];
    return cell;
}
- (CGSize)collectionView:(UICollectionView *)c layout:(UICollectionViewLayout *)l sizeForItemAtIndexPath:(NSIndexPath *)p {
    CGFloat w = (c.bounds.size.width - 4) / 3.0;
    return CGSizeMake(w, w);
}

@end
