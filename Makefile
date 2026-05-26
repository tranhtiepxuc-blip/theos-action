ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

TWEAK_NAME = CamFakeLite
CamFakeLite_FILES = Tweak.x
CamFakeLite_FRAMEWORKS = UIKit PhotosUI Photos AVFoundation CoreGraphics
CamFakeLite_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
