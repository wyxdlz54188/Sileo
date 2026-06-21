# SileoLegacy - iOS 6 Compatible Package Manager
# Build system for theos

export TARGET = iphone:latest:6.0
export ARCHS = armv7 armv7s
export TARGET_IPHONEOS_DEPLOYMENT_VERSION = 6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Sileo
Sileo_FILES = main.m \
	Controllers/SLAppDelegate.m \
	Controllers/SLTabBarController.m \
	Controllers/SLSourcesViewController.m \
	Controllers/SLPackagesViewController.m \
	Controllers/SLPackageDetailViewController.m \
	Controllers/SLDownloadsViewController.m \
	Models/SLPackage.m \
	Models/SLRepo.m \
	Managers/SLRepoManager.m \
	Managers/SLPackageManager.m \
	Managers/SLDownloadManager.m \
	Managers/SLDPKGManager.m \
	Utils/SLCommandPaths.m \
	C\ Contrib/decompression.c \
	C\ Contrib/dpkgversion.c

Sileo_CFLAGS = -fobjc-arc -I.
Sileo_FRAMEWORKS = UIKit Foundation
Sileo_LDFLAGS = -lz -lbz2 -L./Deps -llzma -lzstd
Sileo_INSTALL_PATH = /Applications/Sileo.app

include $(THEOS_MAKE_PATH)/application.mk

after-package::
	@echo "SileoLegacy .deb package built successfully!"
