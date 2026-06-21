#import "Controllers/SLDownloadsViewController.h"
#import "Managers/SLPackageManager.h"
#import "Managers/SLDownloadManager.h"
#import "Managers/SLRepoManager.h"
#import "Models/SLPackage.h"

@interface SLDownloadsViewController ()
@property (nonatomic, strong) NSArray *installedPackages;
@end

@implementation SLDownloadsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Downloads";
    self.tableView.rowHeight = 60;
    [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)reloadData {
    self.installedPackages = [[SLPackageManager sharedInstance] installedPackages];
    self.installedPackages = [self.installedPackages sortedArrayUsingComparator:^NSComparisonResult(SLPackage *a, SLPackage *b) {
        return [a.packageID compare:b.packageID options:NSCaseInsensitiveSearch];
    }];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.installedPackages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"DownloadCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    }
    SLPackage *pkg = self.installedPackages[indexPath.row];
    cell.textLabel.text = pkg.name;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%@)", pkg.version, pkg.packageID];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SLPackage *pkg = self.installedPackages[indexPath.row];
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:pkg.name
                                                 message:[NSString stringWithFormat:@"Version: %@\nSection: %@", pkg.version, pkg.section ?: @"N/A"]
                                                delegate:self
                                       cancelButtonTitle:@"OK"
                                       otherButtonTitles:@"Remove", nil];
    av.tag = indexPath.row;
    [av show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1 && alertView.tag < (NSInteger)self.installedPackages.count) {
        SLPackage *pkg = self.installedPackages[alertView.tag];
        [[SLDownloadManager sharedInstance] removePackage:pkg];
        [self reloadData];
    }
}

@end
