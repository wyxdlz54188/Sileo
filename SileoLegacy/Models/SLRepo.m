#import "SLRepo.h"

@implementation SLRepo

+ (instancetype)repoWithURL:(NSString *)url {
    SLRepo *repo = [[SLRepo alloc] init];
    repo.url = url;
    if ([url hasSuffix:@"/"]) {
        repo.url = [url substringToIndex:url.length - 1];
    }
    repo.suite = @"./";
    repo.components = @"";
    repo.supportsZSTD = YES;
    return repo;
}

+ (instancetype)repoWithSourceLine:(NSString *)line fromFile:(NSString *)file {
    NSArray *parts = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSString *part in parts) {
        if (part.length > 0) [filtered addObject:part];
    }
    if (filtered.count < 2) return nil;
    if (![filtered[0] isEqualToString:@"deb"]) return nil;
    SLRepo *repo = [[SLRepo alloc] init];
    repo.url = filtered[1];
    repo.suite = filtered.count > 2 ? filtered[2] : @"./";
    NSMutableArray *comps = [NSMutableArray array];
    for (NSUInteger i = 3; i < filtered.count; i++) {
        [comps addObject:filtered[i]];
    }
    repo.components = [comps componentsJoinedByString:@" "];
    repo.sourceFile = file;
    repo.supportsZSTD = YES;
    return repo;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[SLRepo class]]) return NO;
    SLRepo *other = object;
    return [self.url isEqualToString:other.url] && [self.suite isEqualToString:other.suite];
}

- (NSUInteger)hash {
    return [self.url hash] ^ [self.suite hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@ %@>", NSStringFromClass([self class]), self.url, self.suite];
}

@end
