#import <Foundation/Foundation.h>
#import "Models/SLPackage.h"
#import "Models/SLRepo.h"

@interface SLDatabase : NSObject

+ (instancetype)sharedInstance;

- (void)open;
- (void)close;
- (void)vacuum;

- (void)saveRepo:(SLRepo *)repo;
- (void)deleteRepo:(SLRepo *)repo;
- (NSArray *)allRepos;
- (SLRepo *)repoWithURL:(NSString *)url;

- (void)savePackages:(NSArray *)packages forRepoURL:(NSString *)repoURL;
- (void)removePackagesForRepoURL:(NSString *)repoURL;
- (void)removeAllPackages;
- (NSArray *)packagesForRepoURL:(NSString *)repoURL;
- (NSArray *)allPackages;
- (NSArray *)packagesMatchingQuery:(NSString *)query;
- (NSArray *)packagesInSection:(NSString *)section;
- (NSArray *)upgradablePackages;
- (NSArray *)allSections;
- (SLPackage *)packageWithID:(NSString *)packageID;

- (NSInteger)packageCount;

@end
