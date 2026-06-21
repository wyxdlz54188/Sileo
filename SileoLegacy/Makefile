# SileoLegacy - iOS 6 Compatible Package Manager
# Build system for theos

export TARGET = iphone:6.0:6.0
export ARCHS = armv7 armv7s
export TARGET_IPHONEOS_DEPLOYMENT_VERSION = 6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Sileo
Sileo_FILES = main.m \
	Controllers/SLAppDelegate.m \
	Controllers/SLTabBarController.m \
	Controllers/SLHomeViewController.m \
	Controllers/SLSourcesViewController.m \
	Controllers/SLPackagesViewController.m \
	Controllers/SLPackageDetailViewController.m \
	Controllers/SLDownloadsViewController.m \
	Controllers/SLSearchViewController.m \
	Models/SLPackage.m \
	Models/SLRepo.m \
	Managers/SLRepoManager.m \
	Managers/SLPackageManager.m \
	Managers/SLDownloadManager.m \
	Managers/SLDPKGManager.m \
	Managers/SLDatabase.m \
	Managers/SLQueueManager.m \
	Utils/SLCommandPaths.m \
	CContrib/decompression.c \
	CContrib/dpkgversion.c

Sileo_CFLAGS = -fobjc-arc -I. -D_FORTIFY_SOURCE=0 -fno-builtin-memcpy -fno-builtin-memset -fno-stack-protector
Sileo_FRAMEWORKS = UIKit Foundation CFNetwork CoreFoundation
Sileo_LDFLAGS = -lz -lbz2 -lobjc \
	-Wl,-U,_lzma_stream_decoder \
	-Wl,-U,_lzma_alone_decoder \
	-Wl,-U,_lzma_code \
	-Wl,-U,_lzma_end \
	-Wl,-U,_ZSTD_DStreamInSize \
	-Wl,-U,_ZSTD_DStreamOutSize \
	-Wl,-U,_ZSTD_createDCtx \
	-Wl,-U,_ZSTD_decompressStream \
	-Wl,-U,_ZSTD_isError \
	-Wl,-U,_ZSTD_freeDCtx \
	-Wl,-U,_sqlite3_open \
	-Wl,-U,_sqlite3_close \
	-Wl,-U,_sqlite3_exec \
	-Wl,-U,_sqlite3_prepare_v2 \
	-Wl,-U,_sqlite3_bind_text \
	-Wl,-U,_sqlite3_bind_int \
	-Wl,-U,_sqlite3_bind_double \
	-Wl,-U,_sqlite3_bind_blob \
	-Wl,-U,_sqlite3_bind_null \
	-Wl,-U,_sqlite3_step \
	-Wl,-U,_sqlite3_reset \
	-Wl,-U,_sqlite3_finalize \
	-Wl,-U,_sqlite3_column_text \
	-Wl,-U,_sqlite3_column_int \
	-Wl,-U,_sqlite3_column_double \
	-Wl,-U,_sqlite3_column_blob \
	-Wl,-U,_sqlite3_column_bytes
Sileo_INSTALL_PATH = /Applications
Sileo_INFO_PLIST_PATH = Info.plist

include $(THEOS_MAKE_PATH)/application.mk

after-package::
	@echo "SileoLegacy .deb package built successfully!"
