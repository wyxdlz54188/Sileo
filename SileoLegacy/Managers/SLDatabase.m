#import "Managers/SLDatabase.h"
#import "Managers/SLDPKGManager.h"
#import <sqlite3.h>

@interface SLDatabase () {
    sqlite3 *_db;
}
@end

@implementation SLDatabase

+ (instancetype)sharedInstance {
    static SLDatabase *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SLDatabase alloc] init];
    });
    return instance;
}

- (NSString *)dbPath {
    NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [caches stringByAppendingPathComponent:@"sileolegacy.db"];
}

- (void)open {
    if (_db) return;
    const char *path = [[self dbPath] UTF8String];
    if (sqlite3_open(path, &_db) != SQLITE_OK) {
        _db = NULL;
        return;
    }
    sqlite3_exec(_db, "PRAGMA journal_mode=WAL", NULL, NULL, NULL);
    sqlite3_exec(_db, "PRAGMA synchronous=NORMAL", NULL, NULL, NULL);
    [self createTables];
}

- (void)close {
    if (_db) {
        sqlite3_close(_db);
        _db = NULL;
    }
}

- (void)vacuum {
    sqlite3_exec(_db, "VACUUM", NULL, NULL, NULL);
}

- (void)createTables {
    const char *reposSQL =
        "CREATE TABLE IF NOT EXISTS repos ("
        "  url TEXT PRIMARY KEY,"
        "  suite TEXT,"
        "  components TEXT,"
        "  label TEXT,"
        "  origin TEXT,"
        "  description TEXT,"
        "  version TEXT,"
        "  architecture TEXT,"
        "  source_file TEXT,"
        "  supports_zstd INTEGER DEFAULT 0,"
        "  last_refreshed REAL DEFAULT 0"
        ")";
    sqlite3_exec(_db, reposSQL, NULL, NULL, NULL);

    const char *packagesSQL =
        "CREATE TABLE IF NOT EXISTS packages ("
        "  package_id TEXT NOT NULL,"
        "  name TEXT,"
        "  version TEXT,"
        "  description TEXT,"
        "  section TEXT,"
        "  architecture TEXT,"
        "  maintainer TEXT,"
        "  author TEXT,"
        "  depiction TEXT,"
        "  homepage TEXT,"
        "  filename TEXT,"
        "  size TEXT,"
        "  icon TEXT,"
        "  depends TEXT,"
        "  conflicts TEXT,"
        "  provides TEXT,"
        "  replaces TEXT,"
        "  essential TEXT,"
        "  tag TEXT,"
        "  source_repo_url TEXT NOT NULL,"
        "  raw_control BLOB,"
        "  PRIMARY KEY (package_id, source_repo_url)"
        ")";
    sqlite3_exec(_db, packagesSQL, NULL, NULL, NULL);

    const char *indexSQL =
        "CREATE INDEX IF NOT EXISTS idx_packages_section ON packages(section);"
        "CREATE INDEX IF NOT EXISTS idx_packages_name ON packages(name COLLATE NOCASE);"
        "CREATE INDEX IF NOT EXISTS idx_packages_source ON packages(source_repo_url);";
    sqlite3_exec(_db, indexSQL, NULL, NULL, NULL);
}

- (NSData *)archivedControl:(NSDictionary *)dict {
    if (!dict) return nil;
    return [NSKeyedArchiver archivedDataWithRootObject:dict];
}

- (NSDictionary *)unarchivedControl:(NSData *)data {
    if (!data) return nil;
    @try {
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    } @catch (NSException *e) {
        return nil;
    }
}

#pragma mark - Repos

- (void)saveRepo:(SLRepo *)repo {
    if (!_db) return;
    const char *sql =
        "INSERT OR REPLACE INTO repos (url, suite, components, label, origin, description, "
        "version, architecture, source_file, supports_zstd, last_refreshed) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) return;
    sqlite3_bind_text(stmt, 1, [repo.url UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, [repo.suite UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 3, [repo.components UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 4, [repo.label UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 5, [repo.origin UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 6, [repo.repoDescription UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 7, [repo.version UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 8, [repo.architecture UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 9, [repo.sourceFile UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 10, repo.supportsZSTD ? 1 : 0);
    sqlite3_bind_double(stmt, 11, [repo.lastRefreshed timeIntervalSince1970]);
    sqlite3_step(stmt);
    sqlite3_finalize(stmt);
}

- (void)deleteRepo:(SLRepo *)repo {
    if (!_db) return;
    const char *sql = "DELETE FROM repos WHERE url = ?";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) return;
    sqlite3_bind_text(stmt, 1, [repo.url UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    [self removePackagesForRepoURL:repo.url];
}

- (SLRepo *)repoFromStmt:(sqlite3_stmt *)stmt {
    SLRepo *repo = [[SLRepo alloc] init];
    repo.url = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 0)] ?: @"";
    repo.suite = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 1)];
    repo.components = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 2)];
    repo.label = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 3)];
    repo.origin = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 4)];
    repo.repoDescription = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 5)];
    repo.version = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 6)];
    repo.architecture = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 7)];
    repo.sourceFile = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 8)];
    repo.supportsZSTD = sqlite3_column_int(stmt, 9) != 0;
    double t = sqlite3_column_double(stmt, 10);
    if (t > 0) repo.lastRefreshed = [NSDate dateWithTimeIntervalSince1970:t];
    return repo;
}

- (NSArray<SLRepo *> *)allRepos {
    if (!_db) return @[];
    NSMutableArray *repos = [NSMutableArray array];
    const char *sql = "SELECT url, suite, components, label, origin, description, version, "
                       "architecture, source_file, supports_zstd, last_refreshed FROM repos ORDER BY label, url";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            [repos addObject:[self repoFromStmt:stmt]];
        }
        sqlite3_finalize(stmt);
    }
    return repos;
}

- (SLRepo *)repoWithURL:(NSString *)url {
    if (!_db) return nil;
    const char *sql = "SELECT url, suite, components, label, origin, description, version, "
                       "architecture, source_file, supports_zstd, last_refreshed FROM repos WHERE url = ?";
    sqlite3_stmt *stmt;
    SLRepo *repo = nil;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [url UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            repo = [self repoFromStmt:stmt];
        }
        sqlite3_finalize(stmt);
    }
    return repo;
}

#pragma mark - Packages

- (SLPackage *)packageFromStmt:(sqlite3_stmt *)stmt {
    SLPackage *pkg = [[SLPackage alloc] init];
    pkg.packageID = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 0)] ?: @"";
    pkg.name = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 1)];
    pkg.version = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 2)];
    pkg.packageDescription = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 3)];
    pkg.section = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 4)];
    pkg.architecture = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 5)];
    pkg.maintainer = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 6)];
    pkg.author = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 7)];
    pkg.depiction = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 8)];
    pkg.homepage = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 9)];
    pkg.filename = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 10)];
    pkg.size = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 11)];
    pkg.icon = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 12)];
    pkg.depends = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 13)];
    pkg.conflicts = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 14)];
    pkg.provides = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 15)];
    pkg.replaces = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 16)];
    pkg.essential = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 17)];
    pkg.tag = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 18)];
    pkg.sourceRepoURL = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 19)] ?: @"";
    const void *blob = sqlite3_column_blob(stmt, 20);
    int blobSize = sqlite3_column_bytes(stmt, 20);
    if (blob && blobSize > 0) {
        NSData *data = [NSData dataWithBytes:blob length:blobSize];
        pkg.rawControl = [self unarchivedControl:data];
    }
    return pkg;
}

- (void)savePackages:(NSArray<SLPackage *> *)packages forRepoURL:(NSString *)repoURL {
    if (!_db || !repoURL) return;
    const char *sql =
        "INSERT OR REPLACE INTO packages (package_id, name, version, description, section, "
        "architecture, maintainer, author, depiction, homepage, filename, size, icon, "
        "depends, conflicts, provides, replaces, essential, tag, source_repo_url, raw_control) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) != SQLITE_OK) return;

    sqlite3_exec(_db, "BEGIN TRANSACTION", NULL, NULL, NULL);
    for (SLPackage *pkg in packages) {
        sqlite3_bind_text(stmt, 1, [pkg.packageID UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, [pkg.name UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 3, [pkg.version UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 4, [pkg.packageDescription UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 5, [pkg.section UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 6, [pkg.architecture UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 7, [pkg.maintainer UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 8, [pkg.author UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 9, [pkg.depiction UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 10, [pkg.homepage UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 11, [pkg.filename UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 12, [pkg.size UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 13, [pkg.icon UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 14, [pkg.depends UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 15, [pkg.conflicts UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 16, [pkg.provides UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 17, [pkg.replaces UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 18, [pkg.essential UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 19, [pkg.tag UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 20, [repoURL UTF8String], -1, SQLITE_TRANSIENT);
        NSData *archived = [self archivedControl:pkg.rawControl];
        if (archived) {
            sqlite3_bind_blob(stmt, 21, [archived bytes], (int)[archived length], SQLITE_TRANSIENT);
        } else {
            sqlite3_bind_null(stmt, 21);
        }
        sqlite3_step(stmt);
        sqlite3_reset(stmt);
    }
    sqlite3_exec(_db, "COMMIT", NULL, NULL, NULL);
    sqlite3_finalize(stmt);
}

- (void)removePackagesForRepoURL:(NSString *)repoURL {
    if (!_db || !repoURL) return;
    const char *sql = "DELETE FROM packages WHERE source_repo_url = ?";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [repoURL UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
}

- (void)removeAllPackages {
    if (!_db) return;
    sqlite3_exec(_db, "DELETE FROM packages", NULL, NULL, NULL);
}

#define PKG_COLUMNS "package_id, name, version, description, section, architecture, maintainer, author, depiction, homepage, filename, size, icon, depends, conflicts, provides, replaces, essential, tag, source_repo_url, raw_control"

- (NSArray<SLPackage *> *)allPackages {
    return [self packagesMatchingQuery:nil];
}

- (NSArray<SLPackage *> *)packagesForRepoURL:(NSString *)repoURL {
    if (!_db) return @[];
    NSMutableArray *packages = [NSMutableArray array];
    const char *sql = "SELECT " PKG_COLUMNS " FROM packages WHERE source_repo_url = ? ORDER BY name COLLATE NOCASE";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [repoURL UTF8String], -1, SQLITE_TRANSIENT);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            [packages addObject:[self packageFromStmt:stmt]];
        }
        sqlite3_finalize(stmt);
    }
    return packages;
}

- (NSArray<SLPackage *> *)packagesMatchingQuery:(NSString *)query {
    if (!_db) return @[];
    NSMutableArray *packages = [NSMutableArray array];
    const char *sql;
    if (query && query.length > 0) {
        sql = "SELECT " PKG_COLUMNS " FROM packages WHERE package_id LIKE ?1 OR name LIKE ?1 "
              "OR description LIKE ?1 ORDER BY name COLLATE NOCASE";
    } else {
        sql = "SELECT " PKG_COLUMNS " FROM packages ORDER BY name COLLATE NOCASE";
    }
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        if (query && query.length > 0) {
            NSString *pattern = [NSString stringWithFormat:@"%%%@%%", query];
            sqlite3_bind_text(stmt, 1, [pattern UTF8String], -1, SQLITE_TRANSIENT);
        }
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            [packages addObject:[self packageFromStmt:stmt]];
        }
        sqlite3_finalize(stmt);
    }
    return packages;
}

- (NSArray<SLPackage *> *)packagesInSection:(NSString *)section {
    if (!_db || !section) return @[];
    NSMutableArray *packages = [NSMutableArray array];
    const char *sql = "SELECT " PKG_COLUMNS " FROM packages WHERE section = ? ORDER BY name COLLATE NOCASE";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [section UTF8String], -1, SQLITE_TRANSIENT);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            [packages addObject:[self packageFromStmt:stmt]];
        }
        sqlite3_finalize(stmt);
    }
    return packages;
}

- (NSArray<SLPackage *> *)upgradablePackages {
    NSArray *installed = [[SLDPKGManager sharedInstance] installedPackages];
    NSMutableArray *upgradable = [NSMutableArray array];
    for (SLPackage *installedPkg in installed) {
        SLPackage *repoPkg = [self packageWithID:installedPkg.packageID];
        if (repoPkg && [installedPkg compareVersion:repoPkg] == NSOrderedAscending) {
            repoPkg.wantInfo = installedPkg.wantInfo;
            repoPkg.eFlag = installedPkg.eFlag;
            repoPkg.status = installedPkg.status;
            repoPkg.installDate = installedPkg.installDate;
            [upgradable addObject:repoPkg];
        }
    }
    return upgradable;
}

- (NSArray<NSString *> *)allSections {
    if (!_db) return @[];
    NSMutableArray *sections = [NSMutableArray array];
    const char *sql = "SELECT DISTINCT section FROM packages WHERE section IS NOT NULL AND section != '' ORDER BY section";
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NSString *s = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 0)];
            if (s) [sections addObject:s];
        }
        sqlite3_finalize(stmt);
    }
    return sections;
}

- (SLPackage *)packageWithID:(NSString *)packageID {
    if (!_db || !packageID) return nil;
    const char *sql = "SELECT " PKG_COLUMNS " FROM packages WHERE package_id = ? LIMIT 1";
    sqlite3_stmt *stmt;
    SLPackage *pkg = nil;
    if (sqlite3_prepare_v2(_db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [packageID UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            pkg = [self packageFromStmt:stmt];
        }
        sqlite3_finalize(stmt);
    }
    return pkg;
}

- (NSInteger)packageCount {
    if (!_db) return 0;
    sqlite3_stmt *stmt;
    NSInteger count = 0;
    if (sqlite3_prepare_v2(_db, "SELECT COUNT(*) FROM packages", -1, &stmt, NULL) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            count = sqlite3_column_int(stmt, 0);
        }
        sqlite3_finalize(stmt);
    }
    return count;
}

@end
