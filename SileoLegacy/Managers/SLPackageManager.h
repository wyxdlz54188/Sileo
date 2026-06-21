#import <Foundation/Foundation.h>
#import "Models/SLPackage.h"

@interface SLPackageManager : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)installedPackages;
- (NSArray *)availableUpdates;
- (NSArray *)packagesWithQuery:(NSString *)query;
- (SLPackage *)packageWithID:(NSString *)packageID;
- (void)invalidateCache;

@end
