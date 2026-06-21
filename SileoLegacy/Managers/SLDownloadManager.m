#import "SLDownloadManager.h"
#import "SLCommandPaths.h"
#import "SLDPKGManager.h"
#import "SLPackageManager.h"

@interface SLDownloadManager ()
@property (nonatomic, strong) NSMutableArray *operationQueue;
@property (nonatomic) BOOL operating;
@end

@implementation SLDownloadManager

+ (instancetype)sharedInstance {
    static SLDownloadManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLDownloadManager alloc] init];
        instance.operationQueue = [NSMutableArray array];
    });
    return instance;
}

- (NSArray *)pendingOperations { return [self.operationQueue copy]; }
- (BOOL)isOperating { return self.operating; }

- (void)installPackage:(SLPackage *)package {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (package.debPath) {
            [self installLocalPackage:package];
        } else {
            [self installRemotePackage:package];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[SLPackageManager sharedInstance] invalidateCache];
        });
    });
}

- (void)installLocalPackage:(SLPackage *)package {
    NSString *archivesDir = [SLCommandPaths archivesDir];
    [[NSFileManager defaultManager] createDirectoryAtPath:archivesDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *debName = [NSString stringWithFormat:@"%@_%@_%@.deb", package.packageID, package.version, package.architecture ?: @"iphoneos-arm"];
    NSString *destPath = [archivesDir stringByAppendingPathComponent:debName];
    [[NSFileManager defaultManager] copyItemAtPath:package.debPath toPath:destPath error:nil];
    [self runAPTInstall:@[destPath]];
}

- (void)installRemotePackage:(SLPackage *)package {
    NSString *baseURL = package.sourceRepoURL;
    NSString *filename = package.filename;
    if (!baseURL || !filename) return;
    NSString *fullURL;
    if ([filename hasPrefix:@"/"]) {
        fullURL = [NSString stringWithFormat:@"%@%@", baseURL, filename];
    } else if ([filename hasPrefix:@"http"]) {
        fullURL = filename;
    } else {
        fullURL = [NSString stringWithFormat:@"%@/%@", baseURL, filename];
    }
    NSURL *url = [NSURL URLWithString:fullURL];
    NSData *debData = [NSData dataWithContentsOfURL:url];
    if (!debData) return;
    NSString *archivesDir = [SLCommandPaths archivesDir];
    [[NSFileManager defaultManager] createDirectoryAtPath:archivesDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *debName = [NSString stringWithFormat:@"%@_%@_%@.deb", package.packageID, package.version, package.architecture ?: @"iphoneos-arm"];
    NSString *destPath = [archivesDir stringByAppendingPathComponent:debName];
    [debData writeToFile:destPath atomically:YES];
    [self runAPTInstall:@[destPath]];
}

- (void)runAPTInstall:(NSArray *)debPaths {
    self.operating = YES;
    NSMutableArray *args = [NSMutableArray arrayWithArray:@[
        @"install", @"--reinstall", @"--allow-unauthenticated",
        @"--allow-downgrades", @"--no-download", @"-y",
        @"-o", @"Dpkg::Options::=--force-confdef",
        @"-o", @"Dpkg::Options::=--force-confnew"
    ]];
    [args addObjectsFromArray:debPaths];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [SLCommandPaths aptGet];
    task.arguments = args;
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        self.operating = NO;
        return;
    }
    self.operating = NO;
    [self cleanArchives];
}

- (void)removePackage:(SLPackage *)package {
    self.operating = YES;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [SLCommandPaths aptGet];
    task.arguments = @[
        @"remove", @"-y",
        @"--allow-remove-essential", @"--allow-change-held-packages",
        @"-o", @"Dpkg::Options::=--force-confdef",
        @"-o", @"Dpkg::Options::=--force-confnew",
        [package.packageID stringByAppendingString:@"-"]
    ];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {}
    self.operating = NO;
    [[SLPackageManager sharedInstance] invalidateCache];
}

- (void)upgradeAll {
    self.operating = YES;
    NSArray *updates = [[SLPackageManager sharedInstance] availableUpdates];
    if (updates.count == 0) {
        self.operating = NO;
        return;
    }
    NSMutableArray *packageSpecs = [NSMutableArray array];
    for (SLPackage *pkg in updates) {
        [packageSpecs addObject:[NSString stringWithFormat:@"%@=%@", pkg.packageID, pkg.version]];
    }
    NSMutableArray *args = [NSMutableArray arrayWithArray:@[
        @"install", @"--reinstall", @"--allow-unauthenticated",
        @"--allow-downgrades", @"-y",
        @"-o", @"Dpkg::Options::=--force-confdef",
        @"-o", @"Dpkg::Options::=--force-confnew"
    ]];
    [args addObjectsFromArray:packageSpecs];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [SLCommandPaths aptGet];
    task.arguments = args;
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {}
    self.operating = NO;
    [[SLPackageManager sharedInstance] invalidateCache];
    [self cleanArchives];
}

- (void)cleanArchives {
    NSString *archivesDir = [SLCommandPaths archivesDir];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:archivesDir error:nil];
    for (NSString *file in files) {
        if ([file hasSuffix:@".deb"]) {
            [[NSFileManager defaultManager] removeItemAtPath:[archivesDir stringByAppendingPathComponent:file] error:nil];
        }
    }
}

@end
