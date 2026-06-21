#import "Controllers/SLHomeViewController.h"
#import "Managers/SLRepoManager.h"
#import "Managers/SLQueueManager.h"
#import "Models/SLPackage.h"

@implementation SLHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Sileo";
    self.tableView.rowHeight = 44;

    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                    target:self
                                                                                    action:@selector(refreshTapped:)];
    self.navigationItem.rightBarButtonItem = refreshButton;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadData)
                                                 name:SLRepoManagerDidRefreshNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)reloadData {
    [self.tableView reloadData];
}

- (void)refreshTapped:(id)sender {
    [[SLRepoManager sharedInstance] refreshRepos];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Updates";
        case 1: return @"Repositories";
        case 2: return @"Queue";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return [[SLRepoManager sharedInstance] upgradablePackages].count;
        case 1: return [SLRepoManager sharedInstance].repos.count + 1;
        case 2: {
            NSInteger count = [SLQueueManager sharedInstance].items.count;
            return count > 0 ? count : 1;
        }
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"HomeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (indexPath.section == 0) {
        NSArray *updates = [[SLRepoManager sharedInstance] upgradablePackages];
        SLPackage *pkg = updates[indexPath.row];
        cell.textLabel.text = pkg.name ?: pkg.packageID;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", pkg.version, pkg.sourceRepoURL];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.imageView.image = nil;

    } else if (indexPath.section == 1) {
        NSArray *repos = [SLRepoManager sharedInstance].repos;
        if (indexPath.row < repos.count) {
            SLRepo *repo = repos[indexPath.row];
            cell.textLabel.text = repo.label ?: repo.origin ?: repo.url;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
            cell.detailTextLabel.text = repo.url;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
            cell.detailTextLabel.textColor = [UIColor grayColor];
        } else {
            cell.textLabel.text = @"Add Source...";
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.text = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.imageView.image = nil;

    } else {
        NSArray *items = [SLQueueManager sharedInstance].items;
        if (items.count > 0) {
            SLQueueItem *item = items[indexPath.row];
            cell.textLabel.text = item.description;
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.text = item.errorMessage ?: @"";
            cell.detailTextLabel.textColor = [UIColor grayColor];
        } else {
            cell.textLabel.text = @"No pending operations";
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.text = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.imageView.image = nil;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        NSArray *updates = [[SLRepoManager sharedInstance] upgradablePackages];
        if (indexPath.row < updates.count) {
            SLPackage *pkg = updates[indexPath.row];
            [[SLQueueManager sharedInstance] upgradePackage:pkg];
            [[SLQueueManager sharedInstance] processQueue];
        }
    } else if (indexPath.section == 1) {
        NSArray *repos = [SLRepoManager sharedInstance].repos;
        if (indexPath.row >= repos.count) {
            [self showAddSourceAlert];
        }
    }
}

- (void)showAddSourceAlert {
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

@end
