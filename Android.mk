LOCAL_PATH := $(call my-dir)

# Guarded so sibling products in this shared tree (m681, m95, ...) never
# scan m5c subdir makefiles.
ifeq ($(TARGET_DEVICE),m5c)
include $(call all-makefiles-under,$(LOCAL_PATH))
# Pinned private vendor/mediatek supplies real GUI/ICU compatibility code.
# Its top-level product guard does not otherwise select m5c.
MTK_SYMBOLS_GUI_ONLY := true
include vendor/mediatek/symbols/Android.mk
MTK_SYMBOLS_GUI_ONLY :=
include vendor/mediatek/wlan/wifi_hal/Android.mk





include vendor/mediatek/ril/Android.mk
endif
