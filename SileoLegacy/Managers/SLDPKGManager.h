#import <Foundation/Foundation.h>
#import "SLPackage.h"

@interface SLDPKGManager : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)installedPackages;
- (NSString *)architecture;
- (NSArray *)foreignArchitectures;
- (BOOL)dpkgInterrupted;
- (BOOL)isArchitectureValid:(NSString *)arch;
- (int)compareVersion:(NSString *)v1 toVersion:(NSString *)v2;

@end
