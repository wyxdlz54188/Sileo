#import "Controllers/SLDownloadsViewController.h"
#import "Managers/SLDPKGManager.h"
#import "Managers/SLQueueManager.h"
#import "Models/SLPackage.h"

@interface SLDownloadsViewController ()
@property (nonatomic, strong) NSArray<SLPackage *> *installedPackages;
@property (nonatomic, strong) NSArray<SLQueueItem *> *queueItems;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@end

@implementation SLDownloadsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Downloads";

    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Installed", @"Queue"]];
    self.segmentedControl.selectedSegmentIndex = 0;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.tableView.tableHeaderView = self.segmentedControl;
    self.tableView.rowHeight = 55;

    UIBarButtonItem *processButton = [[UIBarButtonItem alloc] initWithTitle:@"Apply"
                                                                       style:UIBarButtonItemStyleDone
                                                                      target:self
                                                                      action:@selector(applyTapped:)];
    self.navigationItem.rightBarButtonItem = processButton;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)reloadData {
    self.installedPackages = [[SLDPKGManager sharedInstance] installedPackages];
    self.installedPackages = [self.installedPackages sortedArrayUsingComparator:^NSComparisonResult(SLPackage *a, SLPackage *b) {
        return [a.packageID compare:b.packageID options:NSCaseInsensitiveSearch];
    }];
    self.queueItems = [SLQueueManager sharedInstance].items;
    [self.tableView reloadData];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self.tableView reloadData];
}

- (void)applyTapped:(id)sender {
    if (self.queueItems.count > 0) {
        [[SLQueueManager sharedInstance] processQueue];
        [self reloadData];
    }
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        return self.installedPackages.count;
    } else {
        return self.queueItems.count > 0 ? self.queueItems.count : 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"DownloadCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    }

    if (self.segmentedControl.selectedSegmentIndex == 0) {
        SLPackage *pkg = self.installedPackages[indexPath.row];
        cell.textLabel.text = pkg.name ?: pkg.packageID;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%@)", pkg.version, pkg.packageID];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        if (self.queueItems.count > 0) {
            SLQueueItem *item = self.queueItems[indexPath.row];
            cell.textLabel.text = item.description;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
            cell.detailTextLabel.text = item.errorMessage ?: [self stateString:item.state];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
            cell.detailTextLabel.textColor = [UIColor grayColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            cell.textLabel.text = @"No pending operations";
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.text = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }

    return cell;
}

- (NSString *)stateString:(SLQueueItemState)state {
    switch (state) {
        case SLQueueItemStatePending: return @"Pending";
        case SLQueueItemStateDownloading: return @"Downloading...";
        case SLQueueItemStateDownloaded: return @"Downloaded";
        case SLQueueItemStateInstalling: return @"Installing...";
        case SLQueueItemStateRemoving: return @"Removing...";
        case SLQueueItemStateComplete: return @"Complete";
        case SLQueueItemStateFailed: return @"Failed";
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.segmentedControl.selectedSegmentIndex == 0 && indexPath.row < self.installedPackages.count) {
        SLPackage *pkg = self.installedPackages[indexPath.row];
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:pkg.name
                                                      message:[NSString stringWithFormat:@"Version: %@\nSection: %@", pkg.version, pkg.section ?: @"N/A"]
                                                     delegate:self
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:@"Remove", nil];
        av.tag = indexPath.row;
        [av show];
    } else if (self.segmentedControl.selectedSegmentIndex == 1 && indexPath.row < self.queueItems.count) {
        SLQueueItem *item = self.queueItems[indexPath.row];
        [[SLQueueManager sharedInstance] removeItem:item];
        [self reloadData];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1 && alertView.tag < (NSInteger)self.installedPackages.count) {
        SLPackage *pkg = self.installedPackages[alertView.tag];
        [[SLQueueManager sharedInstance] removePackage:pkg];
        [[SLQueueManager sharedInstance] processQueue];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reloadData];
        });
    }
}

@end
