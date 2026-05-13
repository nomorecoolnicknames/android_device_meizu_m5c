LOCAL_PATH := $(call my-dir)

# Only scan the subdirectories when building for m5c.
ifeq ($(TARGET_DEVICE),m5c)
include $(call all-makefiles-under,$(LOCAL_PATH))
# The MTK rild and libril. vendor/mediatek/Android.mk does not include ril/
# for this device; its makefiles are gated on BOARD_PROVIDES_LIBRIL and
# ENABLE_VENDOR_RIL_SERVICE.
include vendor/mediatek/ril/Android.mk
endif
