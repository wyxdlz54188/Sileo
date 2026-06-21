#import "Managers/SLPackageManager.h"
#import "Managers/SLRepoManager.h"
#import "Managers/SLDatabase.h"
#import "Managers/SLDPKGManager.h"

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
    return [[SLDPKGManager sharedInstance] installedPackages];
}

- (NSArray *)availableUpdates {
    return [[SLRepoManager sharedInstance] upgradablePackages];
}

- (NSArray *)packagesWithQuery:(NSString *)query {
    return [[SLRepoManager sharedInstance] packagesMatchingQuery:query];
}

- (SLPackage *)packageWithID:(NSString *)packageID {
    return [[SLDatabase sharedInstance] packageWithID:packageID];
}

- (void)invalidateCache {
}

@end
