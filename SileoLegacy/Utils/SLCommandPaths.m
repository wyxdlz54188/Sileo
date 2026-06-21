#import "Utils/SLCommandPaths.h"

@implementation SLCommandPaths

+ (NSString *)prefix {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:@"/var/jb/.procursus_strapped"] ||
        [fm fileExistsAtPath:@"/.procursus_strapped"]) {
        return @"/var/jb";
    }
    if ([fm fileExistsAtPath:@"/.bootstrapped"] ||
        [fm fileExistsAtPath:@"/.installed_unc0ver"] ||
        [fm fileExistsAtPath:@"/.installed_yaluX"] ||
        [fm fileExistsAtPath:@"/.installed_odyssey"] ||
        [fm fileExistsAtPath:@"/.installed_taurine"]) {
        return @"";
    }
    return @"";
}

+ (BOOL)isProcursus {
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm fileExistsAtPath:@"/var/jb/.procursus_strapped"] ||
           [fm fileExistsAtPath:@"/.procursus_strapped"];
}

+ (BOOL)isRootless {
    NSString *prefix = [self prefix];
    return prefix.length > 0 && ![prefix isEqualToString:@""];
}

+ (NSString *)aptGet { return [[self prefix] stringByAppendingString:@"/usr/bin/apt-get"]; }
+ (NSString *)dpkg { return [[self prefix] stringByAppendingString:@"/usr/bin/dpkg"]; }
+ (NSString *)dpkgDeb { return [[self prefix] stringByAppendingString:@"/usr/bin/dpkg-deb"]; }
+ (NSString *)aptKey { return [[self prefix] stringByAppendingString:@"/usr/bin/apt-key"]; }
+ (NSString *)aptMark { return [[self prefix] stringByAppendingString:@"/usr/bin/apt-mark"]; }
+ (NSString *)listsDir { return [[self prefix] stringByAppendingString:@"/var/lib/apt/lists"]; }
+ (NSString *)sileoListsDir { return [[self prefix] stringByAppendingString:@"/var/lib/apt/sileolists"]; }
+ (NSString *)dpkgDir { return [[self prefix] stringByAppendingString:@"/Library/dpkg"]; }
+ (NSString *)sourcesListD { return [[self prefix] stringByAppendingString:@"/etc/apt/sources.list.d"]; }
+ (NSString *)archivesDir { return [[self prefix] stringByAppendingString:@"/var/cache/apt/archives"]; }
+ (NSString *)statusFile { return [[self dpkgDir] stringByAppendingString:@"/status"]; }

@end
