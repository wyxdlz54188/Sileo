#import "Managers/SLRepoManager.h"
#import "Managers/SLDatabase.h"
#import "Managers/SLDPKGManager.h"
#import "Utils/SLCommandPaths.h"
#import "Models/SLPackage.h"
#import "CContrib/decompression.h"

typedef NS_ENUM(NSInteger, SLRefreshPhase) {
    SLRefreshPhaseInRelease = 0,
    SLRefreshPhaseRelease,
    SLRefreshPhaseReleaseGPG,
    SLRefreshPhasePackages,
    SLRefreshPhaseComplete,
    SLRefreshPhaseFailed
};

static const float kPhaseWeights[] = {0.20f, 0.30f, 0.10f, 0.40f, 0.0f, 0.0f};

NSString * const SLRepoManagerDidRefreshNotification = @"SLRepoManagerDidRefreshNotification";
NSString * const SLRepoManagerRefreshFailedNotification = @"SLRepoManagerRefreshFailedNotification";
NSString * const SLRepoManagerProgressNotification = @"SLRepoManagerProgressNotification";

@interface SLRepoManager ()
@property (nonatomic, strong) NSMutableArray *mutableRepos;
@property (nonatomic, assign) BOOL isRefreshing;
@property (nonatomic, strong) dispatch_queue_t refreshQueue;
@property (nonatomic, assign) NSInteger maxConcurrent;
@end

@implementation SLRepoManager

+ (instancetype)sharedInstance {
    static SLRepoManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLRepoManager alloc] init];
        instance.mutableRepos = [NSMutableArray array];
        instance.refreshQueue = dispatch_queue_create("com.sileolegacy.refresh", DISPATCH_QUEUE_CONCURRENT);
        instance.maxConcurrent = 3;
    });
    return instance;
}

- (NSArray *)repos { return [self.mutableRepos copy]; }
- (NSArray *)allPackages { return [[SLDatabase sharedInstance] allPackages]; }

- (void)loadRepos {
    [self.mutableRepos removeAllObjects];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *sourcesDir = [SLCommandPaths sourcesListD];

    if ([SLCommandPaths isProcursus]) {
        NSArray *files = [fm contentsOfDirectoryAtPath:sourcesDir error:nil];
        for (NSString *file in files) {
            if ([file hasSuffix:@".sources"] && ![file isEqualToString:@"cydia.sources"]) {
                [self parseSourcesFile:[sourcesDir stringByAppendingPathComponent:file]];
            }
        }
    } else {
        NSString *listPath = [sourcesDir stringByAppendingPathComponent:@"cydia.list"];
        if ([fm fileExistsAtPath:listPath]) [self parseListFile:listPath];
        listPath = [sourcesDir stringByAppendingPathComponent:@"sileo.sources"];
        if ([fm fileExistsAtPath:listPath]) [self parseSourcesFile:listPath];
    }

    NSArray *dbRepos = [[SLDatabase sharedInstance] allRepos];
    for (SLRepo *dbRepo in dbRepos) {
        BOOL found = NO;
        for (SLRepo *repo in self.mutableRepos) {
            if ([repo.url isEqualToString:dbRepo.url]) { found = YES; break; }
        }
        if (!found) [self.mutableRepos addObject:dbRepo];
    }
}

- (void)parseListFile:(NSString *)path {
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content) return;
    for (NSString *line in [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length == 0 || [trimmed hasPrefix:@"#"]) continue;
        SLRepo *repo = [SLRepo repoWithSourceLine:trimmed fromFile:path];
        if (repo) [self.mutableRepos addObject:repo];
    }
}

- (void)parseSourcesFile:(NSString *)path {
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content) return;
    for (NSString *paragraph in [content componentsSeparatedByString:@"\n\n"]) {
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
    for (NSString *line in [stanza componentsSeparatedByString:@"\n"]) {
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *key = [[line substringToIndex:colon.location] lowercaseString];
        NSString *val = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        fields[key] = fields[key] ? [NSString stringWithFormat:@"%@\n%@", fields[key], val] : val;
    }
    return fields;
}

- (void)addRepoWithURL:(NSString *)url {
    if ([url hasSuffix:@"/"]) url = [url substringToIndex:url.length - 1];
    for (SLRepo *repo in self.mutableRepos) {
        if ([repo.url isEqualToString:url]) return;
    }
    SLRepo *repo = [SLRepo repoWithURL:url];
    [self.mutableRepos addObject:repo];
    [self writeSourcesToDisk];
}

- (void)removeRepo:(SLRepo *)repo {
    [self.mutableRepos removeObject:repo];
    [[SLDatabase sharedInstance] deleteRepo:repo];
    [self writeSourcesToDisk];
}

- (void)writeSourcesToDisk {
    NSString *sourcesDir = [SLCommandPaths sourcesListD];
    [[NSFileManager defaultManager] createDirectoryAtPath:sourcesDir withIntermediateDirectories:YES attributes:nil error:nil];

    if ([SLCommandPaths isProcursus]) {
        NSString *path = [sourcesDir stringByAppendingPathComponent:@"sileo.sources"];
        NSMutableString *content = [NSMutableString string];
        for (SLRepo *repo in self.mutableRepos) {
            [content appendFormat:@"Types: deb\nURIs: %@\nSuites: %@\n", repo.url, repo.suite];
            if (repo.components.length > 0)
                [content appendFormat:@"Components: %@\n", repo.components];
            [content appendString:@"\n"];
        }
        [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        NSString *path = [sourcesDir stringByAppendingPathComponent:@"cydia.list"];
        NSMutableString *content = [NSMutableString string];
        for (SLRepo *repo in self.mutableRepos) {
            [content appendFormat:@"deb %@ %@ %@\n", repo.url, repo.suite, repo.components];
        }
        [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (void)clearCache {
    [[SLDatabase sharedInstance] removeAllPackages];
}

#pragma mark - Refresh State Machine

- (void)refreshRepos {
    if (self.isRefreshing) return;
    self.isRefreshing = YES;

    NSArray *reposToRefresh = [self.mutableRepos copy];
    if (reposToRefresh.count == 0) {
        self.isRefreshing = NO;
        [self notifyDelegateComplete];
        return;
    }

    dispatch_semaphore_t sem = dispatch_semaphore_create(self.maxConcurrent);
    dispatch_group_t group = dispatch_group_create();
    __block NSInteger completedCount = 0;
    __block NSInteger successCount = 0;
    NSInteger total = reposToRefresh.count;

    for (SLRepo *repo in reposToRefresh) {
        dispatch_group_enter(group);
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        dispatch_async(self.refreshQueue, ^{
            [self refreshRepo:repo completion:^(BOOL success) {
                @synchronized (self) {
                    completedCount++;
                    if (success) successCount++;
                }
                dispatch_semaphore_signal(sem);
                dispatch_group_leave(group);
            }];
        });
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        self.isRefreshing = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:SLRepoManagerDidRefreshNotification object:nil];
        [self notifyDelegateComplete];
    });
}

- (void)refreshRepo:(SLRepo *)repo {
    [self refreshRepo:repo completion:nil];
}

- (void)refreshRepo:(SLRepo *)repo completion:(void(^)(BOOL))completion {
    [[SLDatabase sharedInstance] removePackagesForRepoURL:repo.url];
    NSString *arch = [[SLDPKGManager sharedInstance] architecture];

    BOOL success = NO;

    // Phase 1: InRelease
    [self notifyDelegateRepo:repo progress:0.0f phase:SLRefreshPhaseInRelease];
    NSString *inReleaseURL = [self releaseURLForRepo:repo signed:YES];
    NSData *inReleaseData = [self downloadURL:inReleaseURL];
    NSDictionary *releaseFields = nil;

    if (inReleaseData) {
        releaseFields = [self parseReleaseData:inReleaseData];
        if (releaseFields) {
            [self notifyDelegateRepo:repo progress:kPhaseWeights[0] phase:SLRefreshPhaseInRelease];
            goto packages_phase;
        }
    }

    // Phase 2: Release
    [self notifyDelegateRepo:repo progress:kPhaseWeights[0] phase:SLRefreshPhaseRelease];
    NSString *releaseURL = [self releaseURLForRepo:repo signed:NO];
    NSData *releaseData = [self downloadURL:releaseURL];
    if (releaseData) {
        releaseFields = [self parseReleaseData:releaseData];
    }

    // Phase 3: Release.gpg
    if (!releaseFields) {
        [self notifyDelegateRepo:repo progress:kPhaseWeights[0] + kPhaseWeights[1] phase:SLRefreshPhaseReleaseGPG];
        NSString *gpgURL = [NSString stringWithFormat:@"%@.gpg", [self releaseURLForRepo:repo signed:NO]];
        NSData *gpgData = [self downloadURL:gpgURL];
        if (gpgData) {
            releaseData = [self downloadURL:releaseURL];
            if (releaseData) {
                releaseFields = [self parseReleaseData:releaseData];
            }
        }
    }

    if (!releaseFields && !inReleaseData) {
        [self notifyDelegateRepo:repo progress:1.0f phase:SLRefreshPhaseFailed];
        if (completion) completion(NO);
        return;
    }

    // Populate repo metadata
    if (releaseFields) {
        repo.label = releaseFields[@"label"];
        repo.origin = releaseFields[@"origin"];
        repo.repoDescription = releaseFields[@"description"];
        repo.version = releaseFields[@"version"];
    }

packages_phase:
    [self notifyDelegateRepo:repo progress:kPhaseWeights[0] + kPhaseWeights[1] + kPhaseWeights[2] phase:SLRefreshPhasePackages];

    NSArray *components = [repo.components componentsSeparatedByString:@" "];
    if (components.count == 0 || [components[0] isEqualToString:@""]) {
        components = @[@"main"];
    }

    float componentWeight = kPhaseWeights[3] / components.count;
    float baseProgress = kPhaseWeights[0] + kPhaseWeights[1] + kPhaseWeights[2];

    for (NSInteger i = 0; i < components.count; i++) {
        NSString *component = components[i];
        NSData *packagesData = nil;

        NSArray *extensions = @[@"zst", @"xz", @"bz2", @"gz", @""];
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

        float compProgress = baseProgress + componentWeight * (i + 1);
        [self notifyDelegateRepo:repo progress:compProgress phase:SLRefreshPhasePackages];
    }

    repo.lastRefreshed = [NSDate date];
    [[SLDatabase sharedInstance] saveRepo:repo];

    SLRefreshPhase finalPhase = success ? SLRefreshPhaseComplete : SLRefreshPhaseFailed;
    [self notifyDelegateRepo:repo progress:1.0f phase:finalPhase];

    if (completion) completion(success);
}

- (NSDictionary *)parseReleaseData:(NSData *)data {
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!str) return nil;
    return [self parseStanzaFields:str];
}

- (NSString *)releaseURLForRepo:(SLRepo *)repo signed:(BOOL)signed {
    NSString *base;
    if (repo.components.length > 0) {
        base = [NSString stringWithFormat:@"%@/dists/%@/%@", repo.url, repo.suite, signed ? @"InRelease" : @"Release"];
    } else {
        base = [NSString stringWithFormat:@"%@/%@", repo.url, signed ? @"InRelease" : @"Release"];
    }
    return base;
}

- (NSString *)packagesURLForRepo:(SLRepo *)repo component:(NSString *)component arch:(NSString *)arch extension:(NSString *)ext {
    NSString *base;
    if (component.length > 0) {
        base = [NSString stringWithFormat:@"%@/dists/%@/%@/binary-%@/Packages", repo.url, repo.suite, component, arch];
    } else {
        base = [NSString stringWithFormat:@"%@/Packages", repo.url];
    }
    if (ext.length > 0) return [base stringByAppendingPathExtension:ext];
    return base;
}

#pragma mark - Network

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
    if (!error && response.statusCode == 200) return data;
    return [self downloadURLViaCurl:urlStr];
}

- (NSData *)downloadURLViaCurl:(NSString *)urlStr {
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sileo_dl_tmp"];
    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
    NSString *cmd = [NSString stringWithFormat:
        @"/usr/bin/curl -sS -L -A 'Sileo/2.0' --connect-timeout 15 -m 30 -o '%@' '%@' 2>/dev/null",
        tmpPath, urlStr];
    int ret = system([cmd UTF8String]);
    if (ret != 0) return nil;
    NSData *data = [NSData dataWithContentsOfFile:tmpPath];
    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
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
        result = decompressXz(in, out, [ext isEqualToString:@"lzma"] ? 1 : 0);
    } else if ([ext isEqualToString:@"bz2"]) {
        result = decompressBzip(in, out);
    } else if ([ext isEqualToString:@"zst"]) {
        result = decompressZst(in, out);
    }
    fclose(in); fclose(out);
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
    NSMutableArray *packages = [NSMutableArray array];
    for (NSString *paragraph in paragraphs) {
        if ([paragraph stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) continue;
        NSDictionary *fields = [SLPackage parseControlString:paragraph];
        if (!fields[@"package"]) continue;
        SLPackage *pkg = [SLPackage packageWithControlFields:fields];
        pkg.sourceRepoURL = repoURL;
        [packages addObject:pkg];
    }
    [[SLDatabase sharedInstance] savePackages:packages forRepoURL:repoURL];
}

#pragma mark - Queries

- (NSArray *)packagesForRepo:(SLRepo *)repo {
    return [[SLDatabase sharedInstance] packagesForRepoURL:repo.url];
}

- (NSArray *)packagesMatchingQuery:(NSString *)query {
    return [[SLDatabase sharedInstance] packagesMatchingQuery:query];
}

- (NSArray *)upgradablePackages {
    return [[SLDatabase sharedInstance] upgradablePackages];
}

- (NSArray *)allSections {
    return [[SLDatabase sharedInstance] allSections];
}

- (NSArray *)packagesInSection:(NSString *)section {
    return [[SLDatabase sharedInstance] packagesInSection:section];
}

#pragma mark - Delegate

- (void)notifyDelegateRepo:(SLRepo *)repo progress:(float)progress phase:(SLRefreshPhase)phase {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(repoManager:didUpdateRepo:progress:)]) {
            [self.delegate repoManager:self didUpdateRepo:repo progress:progress];
        }
        NSDictionary *info = @{@"repo": repo, @"progress": @(progress), @"phase": @(phase)};
        [[NSNotificationCenter defaultCenter] postNotificationName:SLRepoManagerProgressNotification object:self userInfo:info];
    });
}

- (void)notifyDelegateComplete {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(repoManagerDidCompleteAll:)]) {
            [self.delegate repoManagerDidCompleteAll:self];
        }
    });
}

@end
