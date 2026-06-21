#import "SLDPKGManager.h"
#import "SLCommandPaths.h"
#import "SLPackage.h"
#import "C Contrib/dpkgversion.h"

@interface SLDPKGManager ()
@property (nonatomic, copy) NSString *cachedArchitecture;
@property (nonatomic, strong) NSArray *cachedForeignArchitectures;
@end

@implementation SLDPKGManager

+ (instancetype)sharedInstance {
    static SLDPKGManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLDPKGManager alloc] init];
    });
    return instance;
}

- (NSString *)architecture {
    if (self.cachedArchitecture) return self.cachedArchitecture;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [SLCommandPaths dpkg];
    task.arguments = @[@"--print-architecture"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        return @"iphoneos-arm";
    }
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *arch = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    arch = [arch stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.cachedArchitecture = arch;
    return arch ?: @"iphoneos-arm";
}

- (NSArray *)foreignArchitectures {
    if (self.cachedForeignArchitectures) return self.cachedForeignArchitectures;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [SLCommandPaths dpkg];
    task.arguments = @[@"--print-foreign-architectures"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        self.cachedForeignArchitectures = @[];
        return self.cachedForeignArchitectures;
    }
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *foreign = [NSMutableArray array];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length > 0) [foreign addObject:trimmed];
    }
    self.cachedForeignArchitectures = foreign;
    return foreign;
}

- (BOOL)isArchitectureValid:(NSString *)arch {
    if ([arch isEqualToString:@"all"]) return YES;
    if ([arch isEqualToString:[self architecture]]) return YES;
    return [[self foreignArchitectures] containsObject:arch];
}

- (BOOL)dpkgInterrupted {
    NSString *updatesDir = [[SLCommandPaths dpkgDir] stringByAppendingString:@"/updates"];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:updatesDir error:nil];
    return contents.count > 0;
}

- (int)compareVersion:(NSString *)v1 toVersion:(NSString *)v2 {
    if ([v1 isEqualToString:v2]) return 0;
    const char *c1 = [v1 UTF8String];
    const char *c2 = [v2 UTF8String];
    if (!c1 || !c2) return 0;
    return compareVersion(c1, (int)strlen(c1) + 1, c2, (int)strlen(c2) + 1);
}

- (NSArray *)installedPackages {
    NSString *statusPath = [SLCommandPaths statusFile];
    NSString *content = [NSString stringWithContentsOfFile:statusPath encoding:NSUTF8StringEncoding error:nil];
    if (!content) return @[];
    NSArray *paragraphs = [content componentsSeparatedByString:@"\n\n"];
    NSMutableArray *packages = [NSMutableArray array];
    for (NSString *paragraph in paragraphs) {
        if ([paragraph stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) continue;
        NSDictionary *fields = [SLPackage parseControlString:paragraph];
        NSString *pkgID = [fields[@"package"] lowercaseString];
        if (!pkgID || pkgID.length == 0) continue;
        if ([pkgID hasPrefix:@"gsc."] || [pkgID hasPrefix:@"cy+"] || [pkgID isEqualToString:@"firmware"]) continue;
        SLPackage *pkg = [SLPackage packageWithControlFields:fields];
        NSString *wantStatus = fields[@"status"] ?: @"";
        NSArray *statusParts = [wantStatus componentsSeparatedByString:@" "];
        if (statusParts.count >= 3) {
            pkg.wantInfo = statusParts[0];
            pkg.eFlag = statusParts[1];
            pkg.status = statusParts[2];
        }
        if (![self isArchitectureValid:pkg.architecture]) continue;
        if ([pkg.eFlag isEqualToString:@"ok"] &&
            ([pkg.status isEqualToString:@"not-installed"] || [pkg.status isEqualToString:@"config-files"])) {
            continue;
        }
        [packages addObject:pkg];
    }
    return packages;
}

@end
