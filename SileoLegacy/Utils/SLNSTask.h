#ifndef SLNSTask_h
#define SLNSTask_h

@interface NSTask : NSObject

@property (copy) NSString *launchPath;
@property (copy) NSArray *arguments;
@property (retain) id standardOutput;
@property (retain) id standardError;
@property (retain) id standardInput;
@property (readonly) int processIdentifier;
@property (readonly) int terminationStatus;
@property (readonly) BOOL isRunning;

- (void)launch;
- (void)waitUntilExit;
- (void)interrupt;
- (void)terminate;

@end

@interface NSPipe : NSObject

+ (id)pipe;
- (id)fileHandleForReading;
- (id)fileHandleForWriting;

@end

@interface NSFileHandle (SLNSTask)

- (NSData *)readDataToEndOfFile;
- (void)closeFile;

@end

#endif
