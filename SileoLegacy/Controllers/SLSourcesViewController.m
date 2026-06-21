#import "Controllers/SLSourcesViewController.h"
#import "Managers/SLRepoManager.h"

@interface SLSourcesViewController () <SLRepoManagerDelegate>
@property (nonatomic, strong) NSArray *repos;
@property (nonatomic, strong) NSMutableDictionary *progressDict;
@end

@implementation SLSourcesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Sources";
    self.tableView.rowHeight = 60;
    self.progressDict = [NSMutableDictionary dictionary];

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                target:self
                                                                                action:@selector(addSource:)];
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                     target:self
                                                                                     action:@selector(refreshSources:)];
    self.navigationItem.rightBarButtonItems = @[addButton, refreshButton];

    [SLRepoManager sharedInstance].delegate = self;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadData)
                                                 name:SLRepoManagerDidRefreshNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(progressUpdated:)
                                                 name:SLRepoManagerProgressNotification
                                               object:nil];
    [self reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadData {
    self.repos = [SLRepoManager sharedInstance].repos;
    [self.tableView reloadData];
}

- (void)progressUpdated:(NSNotification *)notification {
    SLRepo *repo = notification.userInfo[@"repo"];
    NSNumber *progress = notification.userInfo[@"progress"];
    if (repo && progress) {
        self.progressDict[repo.url] = progress;
        [self.tableView reloadData];
    }
}

- (void)addSource:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Add Source"
                                                     message:@"Enter repository URL"
                                                    delegate:self
                                           cancelButtonTitle:@"Cancel"
                                           otherButtonTitles:@"Add", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSString *url = [[alertView textFieldAtIndex:0] text];
        if (url.length > 0) {
            [[SLRepoManager sharedInstance] addRepoWithURL:url];
            [self reloadData];
            [[SLRepoManager sharedInstance] refreshRepos];
        }
    }
}

- (void)refreshSources:(id)sender {
    [[SLRepoManager sharedInstance] refreshRepos];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.repos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"SourceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    SLRepo *repo = self.repos[indexPath.row];
    cell.textLabel.text = repo.label ?: repo.origin ?: repo.url;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];

    NSNumber *progress = self.progressDict[repo.url];
    if (progress && [progress floatValue] < 1.0f) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Refreshing... %.0f%%", [progress floatValue] * 100];
        cell.detailTextLabel.textColor = [UIColor orangeColor];
    } else {
        cell.detailTextLabel.text = repo.url;
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SLRepo *repo = self.repos[indexPath.row];
    NSString *msg = [NSString stringWithFormat:@"URL: %@\nLabel: %@\nOrigin: %@\nPackages: %lu",
                     repo.url, repo.label ?: @"N/A", repo.origin ?: @"N/A",
                     (unsigned long)[[SLRepoManager sharedInstance] packagesForRepo:repo].count];
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Repository Info" message:msg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Remove", nil];
    av.tag = indexPath.row;
    [av show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1 && alertView.tag < (NSInteger)self.repos.count) {
        SLRepo *repo = self.repos[alertView.tag];
        [[SLRepoManager sharedInstance] removeRepo:repo];
        [self reloadData];
    }
}

#pragma mark - SLRepoManagerDelegate

- (void)repoManagerDidCompleteAll:(SLRepoManager *)manager {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressDict removeAllObjects];
        [self reloadData];
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Refresh" message:@"Sources refreshed." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [av show];
    });
}

@end
