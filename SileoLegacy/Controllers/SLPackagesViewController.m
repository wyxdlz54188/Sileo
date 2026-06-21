#import "Controllers/SLPackagesViewController.h"
#import "Controllers/SLPackageDetailViewController.h"
#import "Managers/SLPackageManager.h"
#import "Managers/SLDownloadManager.h"
#import "Managers/SLRepoManager.h"
#import "Models/SLPackage.h"
#import <QuartzCore/QuartzCore.h>

@interface SLPackagesViewController () <UISearchBarDelegate>
@property (nonatomic, strong) NSArray *packages;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic) BOOL isSearching;
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

- (void)reloadData {
    if (self.isSearching) return;
    NSArray *allPkgs = [SLRepoManager sharedInstance].allPackages;
    self.packages = [allPkgs sortedArrayUsingComparator:^NSComparisonResult(SLPackage *a, SLPackage *b) {
        return [a.packageID compare:b.packageID options:NSCaseInsensitiveSearch];
    }];
    [self buildSections];
    [self.tableView reloadData];
}

- (void)buildSections {
    NSMutableArray *sectionList = [NSMutableArray array];
    NSMutableArray *titleList = [NSMutableArray array];
    if (self.packages.count == 0) return;
    unichar currentChar = 0;
    NSMutableArray *currentSection = nil;
    for (SLPackage *pkg in self.packages) {
        unichar firstChar = [pkg.packageID characterAtIndex:0];
        unichar upperChar = (unichar)toupper(firstChar);
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
    self.isSearching = NO;
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    NSArray *updates = [[SLPackageManager sharedInstance] availableUpdates];
    if (updates.count > 0) {
        [[SLDownloadManager sharedInstance] upgradeAll];
        NSString *msg = [NSString stringWithFormat:@"Updating %lu packages...", (unsigned long)updates.count];
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Upgrading" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reloadData];
        });
    } else {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Up to Date" message:@"All packages are up to date." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.isSearching = NO;
        [self reloadData];
        return;
    }
    self.isSearching = YES;
    self.packages = [[SLPackageManager sharedInstance] packagesWithQuery:searchText];
    [self buildSections];
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.searchBar resignFirstResponder];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [(NSArray *)self.sections[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.sectionTitles;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"PackageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        UIView *iconView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        iconView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        iconView.layer.cornerRadius = 8;
        iconView.tag = 100;
        cell.imageView.image = nil;
        [cell.contentView addSubview:iconView];
    }
    
    SLPackage *pkg = self.sections[indexPath.section][indexPath.row];
    cell.textLabel.text = pkg.name;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", pkg.version, pkg.packageID];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.imageView.image = [self iconForPackage:pkg];
    
    return cell;
}

- (UIImage *)iconForPackage:(SLPackage *)pkg {
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.searchBar resignFirstResponder];
    SLPackage *pkg = self.sections[indexPath.section][indexPath.row];
    SLPackageDetailViewController *detailVC = [[SLPackageDetailViewController alloc] initWithPackage:pkg];
    [self.navigationController pushViewController:detailVC animated:YES];
}

@end
