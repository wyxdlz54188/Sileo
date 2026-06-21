#import <Foundation/Foundation.h>

@interface SLRepo : NSObject

@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *suite;
@property (nonatomic, copy) NSString *components;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *origin;
@property (nonatomic, copy) NSString *repoDescription;
@property (nonatomic, copy) NSString *architecture;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSDate *lastRefreshed;
@property (nonatomic, strong) NSArray *packages;
@property (nonatomic, copy) NSString *sourceFile;
@property (nonatomic, copy) NSString *releaseGPGURL;
@property (nonatomic, copy) NSString *packagesURL;
@property (nonatomic) BOOL supportsZSTD;

+ (instancetype)repoWithURL:(NSString *)url;
+ (instancetype)repoWithSourceLine:(NSString *)line fromFile:(NSString *)file;

@end
