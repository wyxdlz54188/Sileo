# SileoLegacy - iOS 6 Compatible Package Manager

SileoLegacy is an iOS 6-compatible rewrite of the Sileo package manager, combining concepts from the Zebra and Cydia package managers. Built entirely in Objective-C for maximum backwards compatibility.

## Requirements

- iOS 6.0+
- Jailbroken device
- dpkg and APT installed
- armv7 or arm64 architecture

## Features

- Browse packages from multiple repositories
- Search packages by name, description, or package ID
- Install, remove, and upgrade packages
- Add and manage APT sources
- View installed packages
- dpkg-style version comparison for accurate update detection

## Architecture

```
SileoLegacy/
├── main.m                          # Entry point
├── Info.plist                      # Application manifest
├── Models/
│   ├── SLPackage.h/m               # Package data model with dpkg control parsing
│   └── SLRepo.h/m                  # Repository data model
├── Managers/
│   ├── SLRepoManager.h/m           # Repository listing, refresh, caching
│   ├── SLPackageManager.h/m        # Package queries, update detection
│   ├── SLDownloadManager.h/m       # Package install/remove via APT
│   └── SLDPKGManager.h/m           # dpkg status parsing, architecture detection
├── Controllers/
│   ├── SLAppDelegate.h/m           # Application delegate
│   ├── SLTabBarController.h/m       # Main tab bar
│   ├── SLPackagesViewController.h/m # Package browser with search
│   ├── SLPackageDetailViewController.h/m # Package detail view
│   ├── SLSourcesViewController.h/m  # Repository management
│   └── SLDownloadsViewController.h/m # Installed packages
├── Utils/
│   └── SLCommandPaths.h/m          # Bootstrap-aware command resolution
├── C Contrib/
│   ├── decompression.c/h           # Gzip/XZ/Bzip2/Zstd decompression
│   └── dpkgversion.c/h             # dpkg version comparison
└── layout/DEBIAN/
    ├── control                     # DEB package metadata
    └── postinst                    # Post-install script
```

## Key Design Decisions for iOS 6 Compatibility

1. **Objective-C only** - No Swift runtime dependency (Swift requires iOS 7+)
2. **UITableView-based UI** - No UICollectionView dependency
3. **NSURLConnection** - No NSURLSession (iOS 7+)
4. **UIAlertView** - No UIAlertController (iOS 8+)
5. **Manual layout** - No Auto Layout constraints (minimal support in iOS 6)
6. **32-bit compatible** - Supports armv7 architecture
7. **NSTask process spawning** - Available on jailbroken iOS for APT/dpkg interaction

## Building

The project can be built with Theos:

```bash
make package
```

Or directly with xcodebuild (requires Xcode with iOS 6 SDK):

```bash
xcodebuild -project SileoLegacy.xcodeproj -scheme SileoLegacy -sdk iphoneos -configuration Release
```

## Upstream Credits

- Sileo (https://github.com/Sileo/Sileo) - Modern APT package manager frontend
- Zebra (https://github.com/zbrateam/Zebra) - Clean package manager UI
- Cydia (by saurik) - Original iOS package manager, dpkg/APT integration patterns
