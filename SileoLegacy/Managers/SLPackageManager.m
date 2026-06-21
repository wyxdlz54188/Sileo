#import "Managers/SLPackageManager.h"
#import "Managers/SLRepoManager.h"
#import "Managers/SLDPKGManager.h"

@interface SLPackageManager ()
@property (nonatomic, strong) NSArray *cachedInstalledPackages;
@end

@implementation SLPackageManager

+ (instancetype)sharedInstance {
    static SLPackageManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLPackageManager alloc] init];
    });
    return instance;
}

- (NSArray *)installedPackages {
    if (!self.cachedInstalledPackages) {
        self.cachedInstalledPackages = [[SLDPKGManager sharedInstance] installedPackages];
    }
    return self.cachedInstalledPackages;
}

- (void)invalidateCache {
    self.cachedInstalledPackages = nil;
}

- (NSArray *)availableUpdates {
    [self invalidateCache];
    NSArray *installed = [self installedPackages];
    NSMutableArray *updates = [NSMutableArray array];
    for (SLPackage *installedPkg in installed) {
        if (!installedPkg.packageID) continue;
        SLPackage *repoPkg = [self packageWithID:installedPkg.packageID];
        if (!repoPkg) continue;
        if ([installedPkg compareVersion:repoPkg] == NSOrderedAscending) {
            [updates addObject:repoPkg];
        }
    }
    return updates;
}

- (NSArray *)packagesWithQuery:(NSString *)query {
    NSString *lowerQuery = [query lowercaseString];
    NSMutableArray *results = [NSMutableArray array];
    for (SLPackage *pkg in [SLRepoManager sharedInstance].allPackages) {
        if (pkg.packageID.length == 0) continue;
        if ([pkg.packageID rangeOfString:lowerQuery].location != NSNotFound ||
            [pkg.name.lowercaseString rangeOfString:lowerQuery].location != NSNotFound ||
            [pkg.packageDescription.lowercaseString rangeOfString:lowerQuery].location != NSNotFound) {
            [results addObject:pkg];
        }
    }
    return results;
}

- (SLPackage *)packageWithID:(NSString *)packageID {
    NSString *key = [packageID lowercaseString];
    SLPackage *pkg = [SLRepoManager sharedInstance].allPackagesDict[key];
    if (!pkg) {
        for (NSString *dictKey in [SLRepoManager sharedInstance].allPackagesDict) {
            if ([[dictKey lowercaseString] isEqualToString:key]) {
                pkg = [SLRepoManager sharedInstance].allPackagesDict[dictKey];
                break;
            }
        }
    }
    return pkg;
}

@end
