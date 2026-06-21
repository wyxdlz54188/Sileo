#import <Foundation/Foundation.h>
#import "SLPackage.h"

@interface SLPackageManager : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)installedPackages;
- (NSArray *)availableUpdates;
- (NSArray *)packagesWithQuery:(NSString *)query;
- (SLPackage *)packageWithID:(NSString *)packageID;

@end
