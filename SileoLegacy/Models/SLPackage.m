#import "Models/SLPackage.h"
#import "C Contrib/dpkgversion.h"
#import "Utils/SLNSTask.h"

@implementation SLPackage

+ (instancetype)packageWithControlFields:(NSDictionary *)fields {
    SLPackage *pkg = [[SLPackage alloc] init];
    pkg.rawControl = fields;
    pkg.packageID = [fields[@"package"] lowercaseString];
    pkg.name = fields[@"name"] ?: pkg.packageID;
    pkg.version = fields[@"version"] ?: @"";
    pkg.packageDescription = fields[@"description"] ?: @"";
    pkg.section = fields[@"section"] ?: @"";
    pkg.architecture = fields[@"architecture"] ?: @"";
    pkg.maintainer = fields[@"maintainer"] ?: @"";
    pkg.author = fields[@"author"] ?: @"";
    pkg.depiction = fields[@"depiction"] ?: @"";
    pkg.homepage = fields[@"homepage"] ?: @"";
    pkg.filename = fields[@"filename"] ?: @"";
    pkg.size = fields[@"size"] ?: @"";
    pkg.icon = fields[@"icon"] ?: @"";
    pkg.depends = fields[@"depends"] ?: @"";
    pkg.conflicts = fields[@"conflicts"] ?: @"";
    pkg.provides = fields[@"provides"] ?: @"";
    pkg.replaces = fields[@"replaces"] ?: @"";
    pkg.essential = fields[@"essential"] ?: @"";
    pkg.tag = fields[@"tag"] ?: @"";
    return pkg;
}

+ (instancetype)packageWithDebPath:(NSString *)debPath {
    NSDictionary *fields = [self controlFieldsFromDeb:debPath];
    if (!fields) return nil;
    SLPackage *pkg = [self packageWithControlFields:fields];
    pkg.debPath = debPath;
    return pkg;
}

+ (NSDictionary *)controlFieldsFromDeb:(NSString *)debPath {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/dpkg-deb";
    task.arguments = @[@"--field", debPath];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = [NSPipe pipe];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        return nil;
    }
    if (task.terminationStatus != 0) return nil;
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!output) return nil;
    return [self parseControlString:output];
}

+ (NSDictionary *)parseControlString:(NSString *)control {
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    NSArray *lines = [control componentsSeparatedByString:@"\n"];
    NSString *currentKey = nil;
    NSMutableString *currentValue = [NSMutableString string];
    for (NSString *line in lines) {
        if ([line hasPrefix:@" "] || [line hasPrefix:@"\t"]) {
            if (currentKey) {
                [currentValue appendString:@"\n"];
                [currentValue appendString:[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
            }
        } else {
            if (currentKey) {
                fields[[currentKey lowercaseString]] = [currentValue copy];
            }
            NSRange colonRange = [line rangeOfString:@":"];
            if (colonRange.location != NSNotFound) {
                currentKey = [[line substringToIndex:colonRange.location] lowercaseString];
                currentValue = [[[line substringFromIndex:colonRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] mutableCopy];
            }
        }
    }
    if (currentKey) {
        fields[[currentKey lowercaseString]] = [currentValue copy];
    }
    return fields;
}

- (BOOL)isInstalled {
    return [self.status isEqualToString:@"installed"];
}

- (BOOL)isHalfInstalled {
    return [self.status isEqualToString:@"unpacked"] || [self.status isEqualToString:@"halfconfigured"];
}

- (NSComparisonResult)compareVersion:(SLPackage *)other {
    const char *v1 = [self.version UTF8String];
    const char *v2 = [other.version UTF8String];
    if (!v1 || !v2) return NSOrderedSame;
    int result = compareVersion(v1, (int)strlen(v1) + 1, v2, (int)strlen(v2) + 1);
    if (result > 0) return NSOrderedDescending;
    if (result < 0) return NSOrderedAscending;
    return NSOrderedSame;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[SLPackage class]]) return NO;
    SLPackage *other = object;
    return [self.packageID isEqualToString:other.packageID] && [self.version isEqualToString:other.version];
}

- (NSUInteger)hash {
    return [self.packageID hash] ^ [self.version hash];
}

- (id)copyWithZone:(NSZone *)zone {
    SLPackage *copy = [[SLPackage alloc] init];
    copy.packageID = self.packageID;
    copy.name = self.name;
    copy.version = self.version;
    copy.packageDescription = self.packageDescription;
    copy.section = self.section;
    copy.architecture = self.architecture;
    copy.maintainer = self.maintainer;
    copy.author = self.author;
    copy.depiction = self.depiction;
    copy.homepage = self.homepage;
    copy.filename = self.filename;
    copy.size = self.size;
    copy.icon = self.icon;
    copy.depends = self.depends;
    copy.conflicts = self.conflicts;
    copy.provides = self.provides;
    copy.replaces = self.replaces;
    copy.essential = self.essential;
    copy.rawControl = self.rawControl;
    copy.sourceRepoURL = self.sourceRepoURL;
    copy.debPath = self.debPath;
    copy.wantInfo = self.wantInfo;
    copy.eFlag = self.eFlag;
    copy.status = self.status;
    copy.installDate = self.installDate;
    return copy;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@ v%@ (%@)>", NSStringFromClass([self class]), self.packageID, self.version, self.status ?: @"repo"];
}

@end
