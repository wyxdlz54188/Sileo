#import "Controllers/SLSourcesViewController.h"
#import "Managers/SLRepoManager.h"

@interface SLSourcesViewController ()
@property (nonatomic, strong) NSArray *repos;
@end

@implementation SLSourcesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Sources";
    self.tableView.rowHeight = 60;
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                               target:self
                                                                               action:@selector(addSource:)];
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                    target:self
                                                                                    action:@selector(refreshSources:)];
    self.navigationItem.rightBarButtonItems = @[addButton, refreshButton];
    
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
    self.repos = [SLRepoManager sharedInstance].repos;
    [self.tableView reloadData];
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
            [[SLRepoManager sharedInstance] refreshReposWithCompletion:^(BOOL success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self reloadData];
                });
            }];
        }
    }
}

- (void)refreshSources:(id)sender {
    [[SLRepoManager sharedInstance] refreshReposWithCompletion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadData];
            NSString *msg = success ? @"Sources refreshed successfully." : @"Failed to refresh some sources.";
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Refresh" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [av show];
        });
    }];
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
    cell.textLabel.text = repo.label ?: repo.url;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    cell.detailTextLabel.text = repo.url;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SLRepo *repo = self.repos[indexPath.row];
    NSString *msg = [NSString stringWithFormat:@"URL: %@\nLabel: %@\nOrigin: %@", repo.url, repo.label ?: @"N/A", repo.origin ?: @"N/A"];
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Repository Info" message:msg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Remove", nil];
    av.tag = indexPath.row;
    [av show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView.alertViewStyle == UIAlertViewStyleDefault && buttonIndex == 1) {
        if (alertView.tag < (NSInteger)self.repos.count) {
            SLRepo *repo = self.repos[alertView.tag];
            [[SLRepoManager sharedInstance] removeRepo:repo];
            [self reloadData];
        }
    }
}

@end
