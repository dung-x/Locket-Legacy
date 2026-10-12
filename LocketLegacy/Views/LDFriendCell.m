#import "LDFriendCell.h"
#import "../Models/LDFriend.h"

@implementation LDFriendCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:rid];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.textLabel.textColor = [UIColor whiteColor];
        self.detailTextLabel.textColor = [UIColor lightGrayColor];
    }
    return self;
}
- (void)configure:(LDFriend *)f {
    self.textLabel.text = f.displayName.length ? f.displayName : @"(no name)";
    self.detailTextLabel.text = f.uid;
}
@end
