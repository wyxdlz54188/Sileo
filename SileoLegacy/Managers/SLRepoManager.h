#import <Foundation/Foundation.h>
#import "Models/SLRepo.h"

@class SLPackage;

extern NSString * const SLRepoManagerDidRefreshNotification;
extern NSString * const SLRepoManagerRefreshFailedNotification;
extern NSString * const SLRepoManagerProgressNotification;

@class SLRepoManager;
@protocol SLRepoManagerDelegate <NSObject>
@optional
- (void)repoManager:(SLRepoManager *)manager didUpdateRepo:(SLRepo *)repo progress:(float)progress;
- (void)repoManager:(SLRepoManager *)manager didCompleteRepo:(SLRepo *)repo;
- (void)repoManager:(SLRepoManager *)manager didFailRepo:(SLRepo *)repo error:(NSString *)error;
- (void)repoManagerDidCompleteAll:(SLRepoManager *)manager;
@end

@interface SLRepoManager : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, weak) id<SLRepoManagerDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray<SLRepo *> *repos;
@property (nonatomic, strong, readonly) NSArray<SLPackage *> *allPackages;
@property (nonatomic, readonly) BOOL isRefreshing;

- (void)loadRepos;
- (void)addRepoWithURL:(NSString *)url;
- (void)removeRepo:(SLRepo *)repo;
- (void)refreshRepos;
- (void)refreshRepo:(SLRepo *)repo;
- (void)clearCache;

- (NSArray<SLPackage *> *)packagesForRepo:(SLRepo *)repo;
- (NSArray<SLPackage *> *)packagesMatchingQuery:(NSString *)query;
- (NSArray<SLPackage *> *)upgradablePackages;
- (NSArray<NSString *> *)allSections;
- (NSArray<SLPackage *> *)packagesInSection:(NSString *)section;

@end
