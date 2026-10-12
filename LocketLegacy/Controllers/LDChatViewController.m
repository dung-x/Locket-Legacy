// Chat tab: reads getAllMessageV2, sends via sendMessage (self-host).
#import "LDChatViewController.h"
#import "../API/LDAPIClient.h"
#import "../API/LDDiskCache.h"
#import "../Models/LDMessage.h"

@interface LDChatViewController () <UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSArray<LDMessage *> *messages;
@property (nonatomic, strong) UITextField *box;
@property (nonatomic, strong) UIButton *sendButton;
@end

@implementation LDChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Chat";
    self.view.backgroundColor = [UIColor blackColor];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.backgroundColor = [UIColor blackColor];
    self.table.dataSource = self;
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.table];

    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bar];

    self.box = [[UITextField alloc] init];
    self.box.placeholder = @"Message… (tap outside or Done to close keyboard)";
    self.box.textColor = [UIColor whiteColor];
    self.box.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    self.box.layer.cornerRadius = 8;
    self.box.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,8,1)];
    self.box.leftViewMode = UITextFieldViewModeAlways;
    self.box.delegate = self;
    self.box.returnKeyType = UIReturnKeySend;
    self.box.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:self.box];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.sendButton.backgroundColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    self.sendButton.layer.cornerRadius = 8;
    [self.sendButton addTarget:self action:@selector(onSend) forControlEvents:UIControlEventTouchUpInside];
    self.sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:self.sendButton];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapBackground)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [bar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bar.heightAnchor constraintEqualToConstant:56],
        [self.box.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:8],
        [self.box.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [self.box.heightAnchor constraintEqualToConstant:40],
        [self.sendButton.leadingAnchor constraintEqualToAnchor:self.box.trailingAnchor constant:8],
        [self.sendButton.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-8],
        [self.sendButton.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [self.sendButton.widthAnchor constraintEqualToConstant:70],
        [self.sendButton.heightAnchor constraintEqualToConstant:40],
        [self.table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:bar.topAnchor],
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(load)];
    [self load];
}

- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self load]; }
- (void)onTapBackground { [self.view endEditing:YES]; }
- (BOOL)textFieldShouldReturn:(UITextField *)t { [self onSend]; return YES; }

- (void)load {
    id cached = [LDDiskCache loadMessagesJSON];
    if (cached) { self.messages = [LDMessage listFromJSON:cached]; [self.table reloadData]; [self scrollBottom]; }
    [[LDAPIClient shared] getAllMessagesWithCompletion:^(NSDictionary *json, NSError *error) {
        if (error) return;
        [LDDiskCache saveMessagesJSON:json];
        self.messages = [LDMessage listFromJSON:json];
        [self.table reloadData];
        [self scrollBottom];
    }];
}

- (void)scrollBottom {
    if (!self.messages.count) return;
    NSIndexPath *p = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.table scrollToRowAtIndexPath:p atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void)onSend {
    NSString *text = [self.box.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) return;
    [self.view endEditing:YES];
    self.box.text = @"";
    self.sendButton.enabled = NO;
    [[LDAPIClient shared] sendMessageWithText:text completion:^(NSDictionary *json, NSError *error) {
        self.sendButton.enabled = YES;
        if (!error && [json[@"success"] boolValue]) [self load];
    }];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.messages.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    static NSString *rid = @"C";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:rid];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:rid];
        c.backgroundColor = [UIColor blackColor];
        c.textLabel.textColor = [UIColor whiteColor];
        c.textLabel.numberOfLines = 0;
        c.detailTextLabel.textColor = [UIColor lightGrayColor];
        c.detailTextLabel.font = [UIFont systemFontOfSize:11];
    }
    LDMessage *m = self.messages[p.row];
    c.textLabel.text = m.text;
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", m.sender.length ? m.sender : @"?", m.createdAt];
    return c;
}

@end
