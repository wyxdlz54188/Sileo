#import "Managers/SLRepoManager.h"
#import "Managers/SLDPKGManager.h"
#import "Utils/SLCommandPaths.h"
#import "Models/SLPackage.h"
#import "CContrib/decompression.h"

NSString * const SLRepoManagerDidRefreshNotification = @"SLRepoManagerDidRefreshNotification";
NSString * const SLRepoManagerRefreshFailedNotification = @"SLRepoManagerRefreshFailedNotification";

@interface SLRepoManager ()
@property (nonatomic, strong) NSMutableArray *mutableRepos;
@property (nonatomic, strong) NSMutableDictionary *allPackagesDict;
- (void)parseListFile:(NSString *)path;
- (void)parseSourcesFile:(NSString *)path;
- (NSDictionary *)parseStanzaFields:(NSString *)stanza;
- (void)writeReposToDiskIfNeeded;
- (NSData *)downloadURL:(NSString *)url;
- (NSData *)decompressData:(NSData *)data extension:(NSString *)ext;
- (void)parsePackagesData:(NSData *)data repoURL:(NSString *)repoURL;
- (NSString *)releaseURLForRepo:(SLRepo *)repo;
- (NSString *)packagesURLForRepo:(SLRepo *)repo component:(NSString *)component arch:(NSString *)arch extension:(NSString *)ext;
- (void)refreshRepo:(SLRepo *)repo arch:(NSString *)arch completion:(void(^)(BOOL))completion;
@end

@implementation SLRepoManager

+ (instancetype)sharedInstance {
    static SLRepoManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLRepoManager alloc] init];
        instance.mutableRepos = [NSMutableArray array];
        instance.allPackagesDict = [NSMutableDictionary dictionary];
    });
    return instance;
}

- (NSArray *)repos { return [self.mutableRepos copy]; }
- (NSArray *)allPackages { return [self.allPackagesDict allValues]; }

- (void)loadRepos {
    [self.mutableRepos removeAllObjects];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *sourcesDir = [SLCommandPaths sourcesListD];
    if ([SLCommandPaths isProcursus]) {
        NSArray *files = [fm contentsOfDirectoryAtPath:sourcesDir error:nil];
        for (NSString *file in files) {
            if ([file hasSuffix:@".sources"] && ![file isEqualToString:@"cydia.sources"]) {
                NSString *path = [sourcesDir stringByAppendingPathComponent:file];
                [self parseSourcesFile:path];
            }
        }
    } else {
        NSString *listPath = [@"/etc/apt/sources.list.d" stringByAppendingPathComponent:@"cydia.list"];
        if ([fm fileExistsAtPath:listPath]) {
            [self parseListFile:listPath];
        }
        listPath = [@"/etc/apt/sources.list.d" stringByAppendingPathComponent:@"sileo.sources"];
        if ([fm fileExistsAtPath:listPath]) {
            [self parseSourcesFile:listPath];
        }
    }
    [self writeReposToDiskIfNeeded];
}

- (void)writeReposToDiskIfNeeded {
    if (![SLCommandPaths isProcursus]) return;
}

- (void)parseListFile:(NSString *)path {
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content) return;
    NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length == 0 || [trimmed hasPrefix:@"#"]) continue;
        SLRepo *repo = [SLRepo repoWithSourceLine:trimmed fromFile:path];
        if (repo) [self.mutableRepos addObject:repo];
    }
}

- (void)parseSourcesFile:(NSString *)path {
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content) return;
    NSArray *paragraphs = [content componentsSeparatedByString:@"\n\n"];
    for (NSString *paragraph in paragraphs) {
        NSDictionary *fields = [self parseStanzaFields:paragraph];
        if ([fields[@"types"] rangeOfString:@"deb"].location == NSNotFound) continue;
        NSString *uris = fields[@"uris"];
        NSString *suites = fields[@"suites"];
        NSString *comp = fields[@"components"];
        if (!uris) continue;
        for (NSString *uri in [uris componentsSeparatedByString:@"\n"]) {
            NSString *cleanURI = [uri stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (cleanURI.length == 0) continue;
            SLRepo *repo = [SLRepo repoWithURL:cleanURI];
            repo.suite = suites ?: @"./";
            repo.components = comp ?: @"";
            repo.sourceFile = path;
            [self.mutableRepos addObject:repo];
        }
    }
}

- (NSDictionary *)parseStanzaFields:(NSString *)stanza {
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    NSArray *lines = [stanza componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *key = [[line substringToIndex:colon.location] lowercaseString];
        NSString *val = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (fields[key]) {
            fields[key] = [NSString stringWithFormat:@"%@\n%@", fields[key], val];
        } else {
            fields[key] = val;
        }
    }
    return fields;
}

- (void)addRepoWithURL:(NSString *)url {
    if ([url hasSuffix:@"/"]) {
        url = [url substringToIndex:url.length - 1];
    }
    for (SLRepo *repo in self.mutableRepos) {
        if ([repo.url isEqualToString:url]) return;
    }
    SLRepo *repo = [SLRepo repoWithURL:url];
    [self.mutableRepos addObject:repo];
    [self writeSourcesToDisk];
}

- (void)removeRepo:(SLRepo *)repo {
    [self.mutableRepos removeObject:repo];
    [self writeSourcesToDisk];
}

- (void)writeSourcesToDisk {
    if ([SLCommandPaths isProcursus]) {
        NSString *path = [[SLCommandPaths sourcesListD] stringByAppendingPathComponent:@"sileo.sources"];
        NSMutableString *content = [NSMutableString string];
        for (SLRepo *repo in self.mutableRepos) {
            [content appendFormat:@"Types: deb\nURIs: %@\nSuites: %@\n", repo.url, repo.suite];
            if (repo.components.length > 0) {
                [content appendFormat:@"Components: %@\n", repo.components];
            }
            [content appendString:@"\n"];
        }
        [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        NSString *path = [[SLCommandPaths sourcesListD] stringByAppendingPathComponent:@"cydia.list"];
        NSMutableString *content = [NSMutableString string];
        for (SLRepo *repo in self.mutableRepos) {
            [content appendFormat:@"deb %@ %@ %@\n", repo.url, repo.suite, repo.components];
        }
        [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (void)clearCache {
    [self.allPackagesDict removeAllObjects];
}

- (NSString *)releaseURLForRepo:(SLRepo *)repo {
    if (repo.components.length > 0) {
        return [NSString stringWithFormat:@"%@/dists/%@/Release", repo.url, repo.suite];
    }
    return [NSString stringWithFormat:@"%@/Release", repo.url];
}

- (NSString *)packagesURLForRepo:(SLRepo *)repo component:(NSString *)component arch:(NSString *)arch extension:(NSString *)ext {
    if (component.length > 0) {
        return [NSString stringWithFormat:@"%@/dists/%@/%@/binary-%@/Packages.%@", repo.url, repo.suite, component, arch, ext];
    }
    return [NSString stringWithFormat:@"%@/Packages.%@", repo.url, ext];
}

- (void)refreshReposWithCompletion:(void(^)(BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSInteger successCount = 0;
        NSString *arch = [[SLDPKGManager sharedInstance] architecture];
        dispatch_group_t group = dispatch_group_create();
        for (SLRepo *repo in self.mutableRepos) {
            dispatch_group_enter(group);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self refreshRepo:repo arch:arch completion:^(BOOL ok) {
                    if (ok) successCount++;
                    dispatch_group_leave(group);
                }];
            });
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(successCount > 0);
            [[NSNotificationCenter defaultCenter] postNotificationName:SLRepoManagerDidRefreshNotification object:nil];
        });
    });
}

- (void)refreshRepo:(SLRepo *)repo arch:(NSString *)arch completion:(void(^)(BOOL))completion {
    BOOL success = NO;
    @try {
        NSData *releaseData = [self downloadURL:[self releaseURLForRepo:repo]];
        if (!releaseData) { completion(NO); return; }
        NSString *releaseStr = [[NSString alloc] initWithData:releaseData encoding:NSUTF8StringEncoding];
        NSDictionary *releaseFields = [self parseStanzaFields:releaseStr];
        repo.label = releaseFields[@"label"];
        repo.origin = releaseFields[@"origin"];
        repo.repoDescription = releaseFields[@"description"];
        repo.version = releaseFields[@"version"];
        NSArray *components = [repo.components componentsSeparatedByString:@" "];
        if (components.count == 0 || [components[0] isEqualToString:@""]) {
            components = @[@"main"];
        }
        [self.allPackagesDict removeObjectForKey:repo.url];
        for (NSString *component in components) {
            NSData *packagesData = nil;
            NSArray *extensions;
            if (repo.supportsZSTD) {
                extensions = @[@"zst", @"xz", @"bz2", @"gz", @""];
            } else {
                extensions = @[@"xz", @"bz2", @"gz", @""];
            }
            for (NSString *ext in extensions) {
                NSString *url = [self packagesURLForRepo:repo component:component arch:arch extension:ext];
                packagesData = [self downloadURL:url];
                if (packagesData) {
                    packagesData = [self decompressData:packagesData extension:ext];
                    if (packagesData) break;
                }
            }
            if (packagesData) {
                [self parsePackagesData:packagesData repoURL:repo.url];
                success = YES;
            }
        }
        repo.lastRefreshed = [NSDate date];
    } @catch (NSException *e) {
        success = NO;
    }
    completion(success);
}

- (NSData *)downloadURL:(NSString *)urlStr {
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:30.0];
    [request setValue:@"Sileo/2.0 CFNetwork/1.5" forHTTPHeaderField:@"User-Agent"];
    NSHTTPURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error || response.statusCode != 200) return nil;
    return data;
}

- (NSData *)decompressData:(NSData *)data extension:(NSString *)ext {
    if (ext.length == 0) return data;
    NSString *tmpInput = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sileo_decomp_in"];
    NSString *tmpOutput = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sileo_decomp_out"];
    [data writeToFile:tmpInput atomically:YES];
    FILE *in = fopen([tmpInput UTF8String], "rb");
    FILE *out = fopen([tmpOutput UTF8String], "wb");
    if (!in || !out) {
        if (in) fclose(in);
        if (out) fclose(out);
        return nil;
    }
    uint8_t result = 1;
    if ([ext isEqualToString:@"gz"]) {
        result = decompressGzip(in, out);
    } else if ([ext isEqualToString:@"xz"] || [ext isEqualToString:@"lzma"]) {
        uint8_t type = [ext isEqualToString:@"lzma"] ? 1 : 0;
        result = decompressXz(in, out, type);
    } else if ([ext isEqualToString:@"bz2"]) {
        result = decompressBzip(in, out);
    } else if ([ext isEqualToString:@"zst"]) {
        result = decompressZst(in, out);
    }
    fclose(in);
    fclose(out);
    [[NSFileManager defaultManager] removeItemAtPath:tmpInput error:nil];
    if (result != 0) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpOutput error:nil];
        return nil;
    }
    NSData *decompressed = [NSData dataWithContentsOfFile:tmpOutput];
    [[NSFileManager defaultManager] removeItemAtPath:tmpOutput error:nil];
    return decompressed;
}

- (void)parsePackagesData:(NSData *)data repoURL:(NSString *)repoURL {
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!content) return;
    NSArray *paragraphs = [content componentsSeparatedByString:@"\n\n"];
    for (NSString *paragraph in paragraphs) {
        if ([paragraph stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) continue;
        NSDictionary *fields = [SLPackage parseControlString:paragraph];
        if (!fields[@"package"]) continue;
        SLPackage *pkg = [SLPackage packageWithControlFields:fields];
        pkg.sourceRepoURL = repoURL;
        NSString *existingKey = [pkg.packageID lowercaseString];
        SLPackage *existing = self.allPackagesDict[existingKey];
        if (!existing || [existing compareVersion:pkg] == NSOrderedAscending) {
            self.allPackagesDict[existingKey] = pkg;
        }
    }
}

@end
