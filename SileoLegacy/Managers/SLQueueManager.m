#import "Managers/SLQueueManager.h"
#import "Managers/SLDPKGManager.h"
#import "Managers/SLRepoManager.h"
#import "Utils/SLCommandPaths.h"
#import "Models/SLPackage.h"
#import "Utils/SLNSTask.h"

@implementation SLQueueItem

+ (instancetype)itemWithPackage:(SLPackage *)package action:(SLQueueAction)action {
    SLQueueItem *item = [[SLQueueItem alloc] init];
    item.package = package;
    item.action = action;
    item.state = SLQueueItemStatePending;
    item.progress = 0.0f;
    return item;
}

- (NSString *)description {
    NSString *actionStr = @"";
    switch (self.action) {
        case SLQueueActionInstall: actionStr = @"Install"; break;
        case SLQueueActionRemove: actionStr = @"Remove"; break;
        case SLQueueActionReinstall: actionStr = @"Reinstall"; break;
        case SLQueueActionUpgrade: actionStr = @"Upgrade"; break;
    }
    return [NSString stringWithFormat:@"%@ %@", actionStr, self.package.name ?: self.package.packageID];
}

@end

@interface SLQueueManager ()
@property (nonatomic, strong) NSMutableArray *mutableItems;
@property (nonatomic, assign) BOOL isProcessing;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@end

@implementation SLQueueManager

+ (instancetype)sharedInstance {
    static SLQueueManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLQueueManager alloc] init];
        instance.mutableItems = [NSMutableArray array];
        instance.workQueue = dispatch_queue_create("com.sileolegacy.queue", DISPATCH_QUEUE_SERIAL);
        instance.maxConcurrentDownloads = 2;
    });
    return instance;
}

- (NSArray *)items { return [self.mutableItems copy]; }

- (void)addItem:(SLQueueItem *)item {
    if ([self containsPackage:item.package]) return;
    [self.mutableItems addObject:item];
    [self notifyDelegateUpdate:item];
}

- (void)removeItem:(SLQueueItem *)item {
    [self.mutableItems removeObject:item];
}

- (void)clearQueue {
    [self.mutableItems removeAllObjects];
}

- (BOOL)containsPackage:(SLPackage *)package {
    for (SLQueueItem *item in self.mutableItems) {
        if ([item.package.packageID isEqualToString:package.packageID]) return YES;
    }
    return NO;
}

- (SLQueueItem *)itemForPackage:(SLPackage *)package {
    for (SLQueueItem *item in self.mutableItems) {
        if ([item.package.packageID isEqualToString:package.packageID]) return item;
    }
    return nil;
}

- (void)installPackage:(SLPackage *)package {
    [self addItem:[SLQueueItem itemWithPackage:package action:SLQueueActionInstall]];
}

- (void)removePackage:(SLPackage *)package {
    [self addItem:[SLQueueItem itemWithPackage:package action:SLQueueActionRemove]];
}

- (void)upgradePackage:(SLPackage *)package {
    [self addItem:[SLQueueItem itemWithPackage:package action:SLQueueActionUpgrade]];
}

- (void)reinstallPackage:(SLPackage *)package {
    [self addItem:[SLQueueItem itemWithPackage:package action:SLQueueActionReinstall]];
}

- (void)upgradeAll {
    NSArray *upgrades = [[SLRepoManager sharedInstance] upgradablePackages];
    for (SLPackage *pkg in upgrades) {
        [self upgradePackage:pkg];
    }
}

- (void)processQueue {
    if (self.isProcessing || self.mutableItems.count == 0) return;
    self.isProcessing = YES;
    dispatch_async(self.workQueue, ^{
        [self processNextItem];
    });
}

- (void)processNextItem {
    SLQueueItem *item = nil;
    @synchronized (self.mutableItems) {
        for (SLQueueItem *i in self.mutableItems) {
            if (i.state == SLQueueItemStatePending) {
                item = i;
                break;
            }
        }
    }

    if (!item) {
        self.isProcessing = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(queueManagerDidCompleteAll)]) {
                [self.delegate queueManagerDidCompleteAll];
            }
        });
        return;
    }

    if (item.action == SLQueueActionRemove) {
        [self processRemove:item];
    } else {
        [self processDownload:item];
    }
}

- (void)processDownload:(SLQueueItem *)item {
    item.state = SLQueueItemStateDownloading;
    [self notifyDelegateUpdate:item];

    NSString *debURL = [self debURLForPackage:item.package];
    if (!debURL) {
        item.state = SLQueueItemStateFailed;
        item.errorMessage = @"No download URL";
        [self notifyDelegateFail:item error:item.errorMessage];
        [self processNextItem];
        return;
    }

    NSString *destPath = [self downloadPathForPackage:item.package];
    [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];

    NSString *cmd = [NSString stringWithFormat:
        @"/usr/bin/curl -sS -L -A 'Sileo/2.0' --connect-timeout 15 -m 120 -o '%@' '%@' 2>/dev/null",
        destPath, debURL];
    int ret = system([cmd UTF8String]);

    if (ret != 0 || ![[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
        item.state = SLQueueItemStateFailed;
        item.errorMessage = @"Download failed";
        [self notifyDelegateFail:item error:item.errorMessage];
        [self processNextItem];
        return;
    }

    item.state = SLQueueItemStateDownloaded;
    item.progress = 1.0f;
    [self notifyDelegateUpdate:item];

    item.package.debPath = destPath;
    [self processInstall:item];
}

- (void)processInstall:(SLQueueItem *)item {
    item.state = SLQueueItemStateInstalling;
    [self notifyDelegateUpdate:item];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [SLCommandPaths dpkg];
    task.arguments = @[@"-i", item.package.debPath];

    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;

    @try {
        [task launch];
        [task waitUntilExit];
        if (task.terminationStatus == 0) {
            item.state = SLQueueItemStateComplete;
            item.progress = 1.0f;
            [self notifyDelegateComplete:item];
        } else {
            item.state = SLQueueItemStateFailed;
            item.errorMessage = [NSString stringWithFormat:@"dpkg exited with status %d", task.terminationStatus];
            [self notifyDelegateFail:item error:item.errorMessage];
        }
    } @catch (NSException *e) {
        item.state = SLQueueItemStateFailed;
        item.errorMessage = e.reason;
        [self notifyDelegateFail:item error:item.errorMessage];
    }

    [self processNextItem];
}

- (void)processRemove:(SLQueueItem *)item {
    item.state = SLQueueItemStateRemoving;
    [self notifyDelegateUpdate:item];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [SLCommandPaths dpkg];
    task.arguments = @[@"-r", item.package.packageID];

    @try {
        [task launch];
        [task waitUntilExit];
        if (task.terminationStatus == 0) {
            item.state = SLQueueItemStateComplete;
            [self notifyDelegateComplete:item];
        } else {
            item.state = SLQueueItemStateFailed;
            item.errorMessage = [NSString stringWithFormat:@"dpkg exited with status %d", task.terminationStatus];
            [self notifyDelegateFail:item error:item.errorMessage];
        }
    } @catch (NSException *e) {
        item.state = SLQueueItemStateFailed;
        item.errorMessage = e.reason;
        [self notifyDelegateFail:item error:item.errorMessage];
    }

    [self processNextItem];
}

- (NSString *)debURLForPackage:(SLPackage *)package {
    if (package.filename && package.sourceRepoURL) {
        if ([package.filename hasPrefix:@"http"]) return package.filename;
        return [NSString stringWithFormat:@"%@/%@", package.sourceRepoURL, package.filename];
    }
    return nil;
}

- (NSString *)downloadPathForPackage:(SLPackage *)package {
    NSString *archives = [SLCommandPaths archivesDir];
    [[NSFileManager defaultManager] createDirectoryAtPath:archives withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *filename = [package.filename lastPathComponent];
    if (!filename) filename = [NSString stringWithFormat:@"%@_%@.deb", package.packageID, package.version];
    return [archives stringByAppendingPathComponent:filename];
}

#pragma mark - Delegate

- (void)notifyDelegateUpdate:(SLQueueItem *)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(queueManagerDidUpdateItem:)]) {
            [self.delegate queueManagerDidUpdateItem:item];
        }
    });
}

- (void)notifyDelegateComplete:(SLQueueItem *)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(queueManagerDidCompleteItem:)]) {
            [self.delegate queueManagerDidCompleteItem:item];
        }
    });
}

- (void)notifyDelegateFail:(SLQueueItem *)item error:(NSString *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(queueManagerDidFailItem:error:)]) {
            [self.delegate queueManagerDidFailItem:item error:error];
        }
    });
}

@end
