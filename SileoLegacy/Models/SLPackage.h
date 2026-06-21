#import <Foundation/Foundation.h>

@interface SLPackage : NSObject <NSCopying>

@property (nonatomic, copy) NSString *packageID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *packageDescription;
@property (nonatomic, copy) NSString *section;
@property (nonatomic, copy) NSString *architecture;
@property (nonatomic, copy) NSString *maintainer;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *depiction;
@property (nonatomic, copy) NSString *homepage;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *size;
@property (nonatomic, copy) NSString *icon;
@property (nonatomic, copy) NSString *depends;
@property (nonatomic, copy) NSString *conflicts;
@property (nonatomic, copy) NSString *provides;
@property (nonatomic, copy) NSString *replaces;
@property (nonatomic, copy) NSString *essential;
@property (nonatomic, copy) NSString *tag;

@property (nonatomic, strong) NSDictionary *rawControl;
@property (nonatomic, copy) NSString *sourceRepoURL;
@property (nonatomic, copy) NSString *debPath;

@property (nonatomic, copy) NSString *wantInfo;
@property (nonatomic, copy) NSString *eFlag;
@property (nonatomic, copy) NSString *status;

@property (nonatomic, strong) NSDate *installDate;

+ (instancetype)packageWithControlFields:(NSDictionary *)fields;
+ (instancetype)packageWithDebPath:(NSString *)debPath;
+ (NSDictionary *)parseControlString:(NSString *)control;
- (BOOL)isInstalled;
- (BOOL)isHalfInstalled;
- (NSComparisonResult)compareVersion:(SLPackage *)other;

@end
