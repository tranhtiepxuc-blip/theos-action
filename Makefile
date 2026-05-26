TARGET := iphone:clang:latest:15.0

ARCHS = arm64 arm64e

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FakePicker

FakePicker_FILES = tweak.x
FakePicker_CFLAGS = -fobjc-arc

FakePicker_FRAMEWORKS = UIKit PhotosUI

include $(THEOS_MAKE_PATH)/tweak.mk
