#import <Foundation/Foundation.h>

@class SLPackage;

typedef NS_ENUM(NSInteger, SLQueueAction) {
    SLQueueActionInstall,
    SLQueueActionRemove,
    SLQueueActionReinstall,
    SLQueueActionUpgrade
};

typedef NS_ENUM(NSInteger, SLQueueItemState) {
    SLQueueItemStatePending,
    SLQueueItemStateDownloading,
    SLQueueItemStateDownloaded,
    SLQueueItemStateInstalling,
    SLQueueItemStateRemoving,
    SLQueueItemStateComplete,
    SLQueueItemStateFailed
};

@interface SLQueueItem : NSObject
@property (nonatomic, strong) SLPackage *package;
@property (nonatomic, assign) SLQueueAction action;
@property (nonatomic, assign) SLQueueItemState state;
@property (nonatomic, assign) float progress;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, strong) NSArray *dependencies;

+ (instancetype)itemWithPackage:(SLPackage *)package action:(SLQueueAction)action;
@end

@protocol SLQueueManagerDelegate <NSObject>
@optional
- (void)queueManagerDidUpdateItem:(SLQueueItem *)item;
- (void)queueManagerDidCompleteItem:(SLQueueItem *)item;
- (void)queueManagerDidFailItem:(SLQueueItem *)item error:(NSString *)error;
- (void)queueManagerDidCompleteAll;
@end

@interface SLQueueManager : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, weak) id<SLQueueManagerDelegate> delegate;
@property (nonatomic, readonly) NSArray *items;
@property (nonatomic, readonly) BOOL isProcessing;
@property (nonatomic, assign) NSInteger maxConcurrentDownloads;

- (void)addItem:(SLQueueItem *)item;
- (void)removeItem:(SLQueueItem *)item;
- (void)clearQueue;

- (BOOL)containsPackage:(SLPackage *)package;
- (SLQueueItem *)itemForPackage:(SLPackage *)package;

- (void)processQueue;

- (void)installPackage:(SLPackage *)package;
- (void)removePackage:(SLPackage *)package;
- (void)upgradePackage:(SLPackage *)package;
- (void)reinstallPackage:(SLPackage *)package;
- (void)upgradeAll;

@end
