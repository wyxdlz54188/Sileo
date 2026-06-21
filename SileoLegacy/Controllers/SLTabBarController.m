#import "Controllers/SLTabBarController.h"
#import "Controllers/SLHomeViewController.h"
#import "Controllers/SLSourcesViewController.h"
#import "Controllers/SLPackagesViewController.h"
#import "Controllers/SLSearchViewController.h"
#import "Controllers/SLDownloadsViewController.h"

@implementation SLTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    SLHomeViewController *homeVC = [[SLHomeViewController alloc] init];
    UINavigationController *homeNav = [[UINavigationController alloc] initWithRootViewController:homeVC];
    homeNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag:0];

    SLSourcesViewController *sourcesVC = [[SLSourcesViewController alloc] init];
    UINavigationController *sourcesNav = [[UINavigationController alloc] initWithRootViewController:sourcesVC];
    sourcesNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemHistory tag:1];

    SLPackagesViewController *packagesVC = [[SLPackagesViewController alloc] init];
    UINavigationController *packagesNav = [[UINavigationController alloc] initWithRootViewController:packagesVC];
    packagesNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMostViewed tag:2];

    SLSearchViewController *searchVC = [[SLSearchViewController alloc] init];
    UINavigationController *searchNav = [[UINavigationController alloc] initWithRootViewController:searchVC];
    searchNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:3];

    SLDownloadsViewController *downloadsVC = [[SLDownloadsViewController alloc] init];
    UINavigationController *downloadsNav = [[UINavigationController alloc] initWithRootViewController:downloadsVC];
    downloadsNav.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemDownloads tag:4];

    self.viewControllers = @[homeNav, sourcesNav, packagesNav, searchNav, downloadsNav];
    self.selectedIndex = 0;
}

@end
