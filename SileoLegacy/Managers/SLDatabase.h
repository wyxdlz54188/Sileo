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
- (NSArray<SLRepo *> *)allRepos;
- (SLRepo *)repoWithURL:(NSString *)url;

- (void)savePackages:(NSArray<SLPackage *> *)packages forRepoURL:(NSString *)repoURL;
- (void)removePackagesForRepoURL:(NSString *)repoURL;
- (void)removeAllPackages;
- (NSArray<SLPackage *> *)packagesForRepoURL:(NSString *)repoURL;
- (NSArray<SLPackage *> *)allPackages;
- (NSArray<SLPackage *> *)packagesMatchingQuery:(NSString *)query;
- (NSArray<SLPackage *> *)packagesInSection:(NSString *)section;
- (NSArray<SLPackage *> *)upgradablePackages;
- (NSArray<NSString *> *)allSections;
- (SLPackage *)packageWithID:(NSString *)packageID;

- (NSInteger)packageCount;

@end
