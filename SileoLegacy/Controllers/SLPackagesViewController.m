#import "Controllers/SLPackagesViewController.h"
#import "Controllers/SLPackageDetailViewController.h"
#import "Managers/SLRepoManager.h"
#import "Managers/SLQueueManager.h"
#import "Managers/SLDPKGManager.h"
#import "Models/SLPackage.h"
#import <QuartzCore/QuartzCore.h>

@interface SLPackagesViewController () <UISearchBarDelegate>
@property (nonatomic, strong) NSArray *packages;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic) BOOL isSearching;
@property (nonatomic, strong) NSArray *installedIDs;
@end

@implementation SLPackagesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Packages";

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search packages";
    self.tableView.tableHeaderView = self.searchBar;
    self.tableView.rowHeight = 70;
    self.tableView.sectionIndexColor = [UIColor colorWithRed:0.12 green:0.51 blue:0.86 alpha:1.0];

    UIBarButtonItem *updatesButton = [[UIBarButtonItem alloc] initWithTitle:@"Updates"
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(showUpdates:)];
    self.navigationItem.rightBarButtonItem = updatesButton;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadData)
                                                 name:SLRepoManagerDidRefreshNotification
                                               object:nil];
    [self reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadInstalledIDs];
    [self.tableView reloadData];
}

- (void)reloadInstalledIDs {
    NSArray *installed = [[SLDPKGManager sharedInstance] installedPackages];
    NSMutableArray *ids = [NSMutableArray array];
    for (SLPackage *p in installed) {
        [ids addObject:[p.packageID lowercaseString]];
    }
    self.installedIDs = ids;
}

- (void)reloadData {
    if (self.isSearching) return;
    [self reloadInstalledIDs];
    self.packages = [[SLRepoManager sharedInstance] allPackages];
    [self buildSections];
    [self.tableView reloadData];
}

- (void)buildSections {
    if (self.packages.count == 0) {
        self.sections = @[];
        self.sectionTitles = @[];
        return;
    }
    NSMutableArray *sectionList = [NSMutableArray array];
    NSMutableArray *titleList = [NSMutableArray array];
    unichar currentChar = 0;
    NSMutableArray *currentSection = nil;
    for (SLPackage *pkg in self.packages) {
        NSString *sortKey = pkg.name ?: pkg.packageID;
        if (sortKey.length == 0) continue;
        unichar upperChar = (unichar)toupper([sortKey characterAtIndex:0]);
        if (upperChar != currentChar) {
            if (currentSection) [sectionList addObject:currentSection];
            currentSection = [NSMutableArray array];
            currentChar = upperChar;
            [titleList addObject:[NSString stringWithCharacters:&currentChar length:1]];
        }
        [currentSection addObject:pkg];
    }
    if (currentSection) [sectionList addObject:currentSection];
    self.sections = sectionList;
    self.sectionTitles = titleList;
}

- (void)showUpdates:(id)sender {
    NSArray *updates = [[SLRepoManager sharedInstance] upgradablePackages];
    if (updates.count > 0) {
        [[SLQueueManager sharedInstance] upgradeAll];
        [[SLQueueManager sharedInstance] processQueue];
        NSString *msg = [NSString stringWithFormat:@"Upgrading %lu packages...", (unsigned long)updates.count];
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Upgrading" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reloadData];
        });
    } else {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Up to Date" message:@"All packages are up to date." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
    }
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.isSearching = NO;
        [self reloadData];
        return;
    }
    self.isSearching = YES;
    self.packages = [[SLRepoManager sharedInstance] packagesMatchingQuery:searchText];
    [self buildSections];
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.searchBar resignFirstResponder];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.sectionTitles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return index;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"PackageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    SLPackage *pkg = self.sections[indexPath.section][indexPath.row];
    cell.textLabel.text = pkg.name ?: pkg.packageID;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];

    BOOL installed = [self.installedIDs containsObject:[pkg.packageID lowercaseString]];
    BOOL queued = [[SLQueueManager sharedInstance] containsPackage:pkg];

    NSString *status = installed ? @"Installed" : @"";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@%@",
                                 pkg.version, status, queued ? @" [Queued]" : @""];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];

    if (installed) {
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0];
        cell.textLabel.textColor = [UIColor blackColor];
    } else if (queued) {
        cell.detailTextLabel.textColor = [UIColor orangeColor];
    } else {
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.searchBar resignFirstResponder];
    SLPackage *pkg = self.sections[indexPath.section][indexPath.row];
    SLPackageDetailViewController *detailVC = [[SLPackageDetailViewController alloc] initWithPackage:pkg];
    [self.navigationController pushViewController:detailVC animated:YES];
}

@end
