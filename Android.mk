LOCAL_PATH := $(call my-dir)

# Only scan the subdirectories when building for m5c.
ifeq ($(TARGET_DEVICE),m5c)
include $(call all-makefiles-under,$(LOCAL_PATH))
# vendor/mediatek provides the GUI and ICU compatibility shims; its
# top-level makefile does not select m5c.
MTK_SYMBOLS_GUI_ONLY := true
include vendor/mediatek/symbols/Android.mk
MTK_SYMBOLS_GUI_ONLY :=
include vendor/mediatek/wlan/wifi_hal/Android.mk
include vendor/mediatek/ril/Android.mk
endif
