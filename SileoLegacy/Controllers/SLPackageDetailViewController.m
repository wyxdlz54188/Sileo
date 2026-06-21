#import "SLPackageDetailViewController.h"
#import "SLDownloadManager.h"
#import "SLPackageManager.h"
#import "SLDPKGManager.h"

@interface SLPackageDetailViewController ()
@property (nonatomic, strong) SLPackage *package;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSArray *fieldKeys;
@end

@implementation SLPackageDetailViewController

- (instancetype)initWithPackage:(SLPackage *)package {
    if (self = [super init]) {
        _package = package;
        _fieldKeys = @[@"package", @"version", @"section", @"architecture", @"maintainer", @"author", @"depends", @"conflicts", @"provides", @"replaces", @"size", @"description"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.package.name ?: self.package.packageID;
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 44, self.view.bounds.size.width, 44)];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:toolbar];
    
    SLPackage *installed = nil;
    for (SLPackage *pkg in [[SLPackageManager sharedInstance] installedPackages]) {
        if ([pkg.packageID caseInsensitiveCompare:self.package.packageID] == NSOrderedSame) {
            installed = pkg;
            break;
        }
    }
    
    NSMutableArray *items = [NSMutableArray array];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [items addObject:flex];
    
    if (installed) {
        if ([installed compareVersion:self.package] == NSOrderedAscending) {
            UIBarButtonItem *upgradeBtn = [[UIBarButtonItem alloc] initWithTitle:@"Upgrade"
                                                                           style:UIBarButtonItemStyleDone
                                                                          target:self
                                                                          action:@selector(installPackage)];
            [items addObject:upgradeBtn];
        }
        UIBarButtonItem *removeBtn = [[UIBarButtonItem alloc] initWithTitle:@"Remove"
                                                                      style:UIBarButtonItemStyleBordered
                                                                     target:self
                                                                     action:@selector(removePackage)];
        [items addObject:removeBtn];
    } else {
        UIBarButtonItem *installBtn = [[UIBarButtonItem alloc] initWithTitle:@"Install"
                                                                       style:UIBarButtonItemStyleDone
                                                                      target:self
                                                                      action:@selector(installPackage)];
        [items addObject:installBtn];
    }
    [items addObject:flex];
    toolbar.items = items;
    
    CGFloat y = 10;
    CGFloat width = self.view.bounds.size.width - 20;
    for (NSString *key in self.fieldKeys) {
        NSString *value = self.package.rawControl[key];
        if (!value || value.length == 0) continue;
        if ([key isEqualToString:@"description"]) {
            y = [self addLabel:@"Description" value:value atY:y width:width fullWidth:YES];
        } else {
            y = [self addLabel:[key capitalizedString] value:value atY:y width:width fullWidth:NO];
        }
    }
    
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, y + 60);
}

- (CGFloat)addLabel:(NSString *)title value:(NSString *)value atY:(CGFloat)y width:(CGFloat)width fullWidth:(BOOL)fullWidth {
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, y, 80, 16)];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:12];
    titleLabel.textColor = [UIColor grayColor];
    [self.scrollView addSubview:titleLabel];
    
    CGFloat valueX = fullWidth ? 10 : 95;
    CGFloat valueW = fullWidth ? width : width - 85;
    CGSize size = [value sizeWithFont:[UIFont systemFontOfSize:14]
                    constrainedToSize:CGSizeMake(valueW, CGFLOAT_MAX)
                        lineBreakMode:NSLineBreakByWordWrapping];
    UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(valueX, y, valueW, size.height)];
    valueLabel.text = value;
    valueLabel.font = [UIFont systemFontOfSize:14];
    valueLabel.numberOfLines = 0;
    [self.scrollView addSubview:valueLabel];
    
    return y + size.height + 10;
}

- (void)installPackage {
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Install"
                                                 message:[NSString stringWithFormat:@"Install %@ %@?", self.package.name, self.package.version]
                                                delegate:self
                                       cancelButtonTitle:@"Cancel"
                                       otherButtonTitles:@"Install", nil];
    av.tag = 1;
    [av show];
}

- (void)removePackage {
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Remove"
                                                 message:[NSString stringWithFormat:@"Remove %@?", self.package.name]
                                                delegate:self
                                       cancelButtonTitle:@"Cancel"
                                       otherButtonTitles:@"Remove", nil];
    av.tag = 2;
    [av show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) return;
    if (alertView.tag == 1) {
        [[SLDownloadManager sharedInstance] installPackage:self.package];
        UIAlertView *done = [[UIAlertView alloc] initWithTitle:@"Installing" message:@"The package is being installed." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [done show];
    } else if (alertView.tag == 2) {
        [[SLDownloadManager sharedInstance] removePackage:self.package];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
