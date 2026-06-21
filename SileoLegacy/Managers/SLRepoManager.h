#import <Foundation/Foundation.h>
#import "SLRepo.h"

extern NSString * const SLRepoManagerDidRefreshNotification;
extern NSString * const SLRepoManagerRefreshFailedNotification;

@interface SLRepoManager : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, strong, readonly) NSArray *repos;
@property (nonatomic, strong, readonly) NSMutableDictionary *allPackagesDict;
@property (nonatomic, strong, readonly) NSArray *allPackages;

- (void)loadRepos;
- (void)addRepoWithURL:(NSString *)url;
- (void)removeRepo:(SLRepo *)repo;
- (void)refreshReposWithCompletion:(void(^)(BOOL success))completion;
- (void)clearCache;

@end
