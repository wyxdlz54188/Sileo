#import "SLAppDelegate.h"
#import "SLTabBarController.h"
#import "SLPackagesViewController.h"
#import "SLSourcesViewController.h"
#import "SLDownloadsViewController.h"

@interface SLTabBarController ()

@property (nonatomic, strong) SLPackagesViewController *packagesVC;
@property (nonatomic, strong) SLSourcesViewController *sourcesVC;
@property (nonatomic, strong) SLDownloadsViewController *downloadsVC;

@end

@implementation SLTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.packagesVC = [[SLPackagesViewController alloc] init];
    UINavigationController *packagesNav = [[UINavigationController alloc] initWithRootViewController:self.packagesVC];
    packagesNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Packages" image:[UIImage imageNamed:@"package"] tag:0];
    
    self.sourcesVC = [[SLSourcesViewController alloc] init];
    UINavigationController *sourcesNav = [[UINavigationController alloc] initWithRootViewController:self.sourcesVC];
    sourcesNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Sources" image:[UIImage imageNamed:@"source"] tag:1];
    
    self.downloadsVC = [[SLDownloadsViewController alloc] init];
    UINavigationController *downloadsNav = [[UINavigationController alloc] initWithRootViewController:self.downloadsVC];
    downloadsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Downloads" image:[UIImage imageNamed:@"download"] tag:2];
    
    self.viewControllers = @[packagesNav, sourcesNav, downloadsNav];
    self.selectedIndex = 0;
}

@end
