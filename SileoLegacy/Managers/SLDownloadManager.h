#import <Foundation/Foundation.h>
#import "Models/SLPackage.h"

@protocol SLDownloadManagerDelegate <NSObject>
@optional
- (void)downloadProgress:(float)progress forPackage:(SLPackage *)package;
- (void)downloadCompleteForPackage:(SLPackage *)package;
- (void)downloadFailedForPackage:(SLPackage *)package error:(NSError *)error;
@end

@interface SLDownloadManager : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, weak) id<SLDownloadManagerDelegate> delegate;

- (void)installPackage:(SLPackage *)package;
- (void)removePackage:(SLPackage *)package;
- (void)upgradeAll;
- (NSArray *)pendingOperations;
- (BOOL)isOperating;

@end
