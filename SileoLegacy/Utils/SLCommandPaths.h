#import <Foundation/Foundation.h>

@interface SLCommandPaths : NSObject

+ (NSString *)prefix;
+ (NSString *)aptGet;
+ (NSString *)dpkg;
+ (NSString *)dpkgDeb;
+ (NSString *)aptKey;
+ (NSString *)aptMark;
+ (NSString *)listsDir;
+ (NSString *)sileoListsDir;
+ (NSString *)dpkgDir;
+ (NSString *)sourcesListD;
+ (NSString *)archivesDir;
+ (NSString *)statusFile;
+ (BOOL)isProcursus;
+ (BOOL)isRootless;

@end
