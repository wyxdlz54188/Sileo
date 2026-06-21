#import "Controllers/SLAppDelegate.h"
#import "Controllers/SLTabBarController.h"
#import "Managers/SLRepoManager.h"
#import "Managers/SLPackageManager.h"
#import "Managers/SLDownloadManager.h"
#import "Managers/SLDatabase.h"

@implementation SLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[SLDatabase sharedInstance] open];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
    
    [[SLRepoManager sharedInstance] loadRepos];
    
    self.tabBarController = [[SLTabBarController alloc] init];
    self.window.rootViewController = self.tabBarController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[SLRepoManager sharedInstance] refreshRepos];
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if ([url.scheme isEqualToString:@"sileo"]) {
        if ([url.host isEqualToString:@"source"] && url.query) {
            NSString *sourceURL = [url.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            if (sourceURL) {
                [[SLRepoManager sharedInstance] addRepoWithURL:sourceURL];
            }
        }
        return YES;
    }
    return NO;
}

@end
