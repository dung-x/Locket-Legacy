#import "LDFriendsViewController.h"
#import "../API/LDAPIClient.h"
#import "../Models/LDFriend.h"
#import "../Views/LDFriendCell.h"

@interface LDFriendsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<LDFriend *> *friends;
@end

@implementation LDFriendsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Friends";
    self.view.backgroundColor = [UIColor blackColor];
    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.backgroundColor = [UIColor blackColor];
    self.table.dataSource = self; self.table.delegate = self;
    [self.table registerClass:[LDFriendCell class] forCellReuseIdentifier:@"F"];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];
    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(load)];
    [self load];
}

- (void)load {
    [[LDAPIClient shared] getAllFriendsWithCompletion:^(NSDictionary *json, NSError *error) {
        if (!error) {
            self.friends = [LDFriend listFromJSON:json];
            [self.table reloadData];
        }
    }];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.friends.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    LDFriendCell *c = [t dequeueReusableCellWithIdentifier:@"F" forIndexPath:p];
    [c configure:self.friends[p.row]];
    return c;
}

@end
