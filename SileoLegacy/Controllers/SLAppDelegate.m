#import "SLAppDelegate.h"
#import "SLTabBarController.h"
#import "SLRepoManager.h"
#import "SLPackageManager.h"
#import "SLDownloadManager.h"

@implementation SLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
    
    [[SLRepoManager sharedInstance] loadRepos];
    
    self.tabBarController = [[SLTabBarController alloc] init];
    self.window.rootViewController = self.tabBarController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[SLRepoManager sharedInstance] refreshReposWithCompletion:nil];
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
