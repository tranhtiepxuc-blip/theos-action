TARGET := iphone:clang:latest:15.0

ARCHS = arm64 arm64e

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FakeMedia

FakeMedia_FILES = tweak.x
FakeMedia_CFLAGS = -fobjc-arc

FakeMedia_FRAMEWORKS = UIKit Photos PhotosUI AVFoundation

include $(THEOS_MAKE_PATH)/tweak.mk
