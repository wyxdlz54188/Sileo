#import "Controllers/SLSearchViewController.h"
#import "Managers/SLRepoManager.h"
#import "Managers/SLQueueManager.h"
#import "Models/SLPackage.h"

@interface SLSearchViewController ()
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<SLPackage *> *results;
@property (nonatomic, copy) NSString *currentQuery;
@end

@implementation SLSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Search";
    self.tableView.rowHeight = 60;

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search Packages";
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.tableView.tableHeaderView = self.searchBar;

    self.results = @[];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadIfNeeded)
                                                 name:SLRepoManagerDidRefreshNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadIfNeeded {
    if (self.currentQuery.length > 0) {
        [self performSearch:self.currentQuery];
    }
}

- (void)performSearch:(NSString *)query {
    if (query.length == 0) {
        self.results = @[];
    } else {
        self.results = [[SLRepoManager sharedInstance] packagesMatchingQuery:query];
    }
    [self.tableView reloadData];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.currentQuery = searchText;
    [self performSearch:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"SearchCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    SLPackage *pkg = self.results[indexPath.row];
    cell.textLabel.text = pkg.name ?: pkg.packageID;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@ - %@",
                                 pkg.version, pkg.section ?: @"Uncategorized", pkg.sourceRepoURL];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = [UIColor grayColor];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SLPackage *pkg = self.results[indexPath.row];

    NSString *msg = [NSString stringWithFormat:@"%@\nVersion: %@\nSection: %@\nRepo: %@",
                     pkg.name ?: pkg.packageID, pkg.version, pkg.section ?: @"N/A", pkg.sourceRepoURL];

    UIAlertView *av = [[UIAlertView alloc] initWithTitle:pkg.name ?: pkg.packageID
                                                  message:msg
                                                 delegate:self
                                        cancelButtonTitle:@"Cancel"
                                        otherButtonTitles:@"Install", nil];
    av.tag = indexPath.row;
    [av show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1 && alertView.tag < (NSInteger)self.results.count) {
        SLPackage *pkg = self.results[alertView.tag];
        [[SLQueueManager sharedInstance] installPackage:pkg];
        [[SLQueueManager sharedInstance] processQueue];
    }
}

@end
