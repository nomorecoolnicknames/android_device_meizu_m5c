# hwcomposer.mt6737m: HWC 1.1 for the 4.9 kernel. The stock HWC blob was
# built for 3.18 and stalls frames on this kernel.
#
# disp_session_uapi.h must match the kernel's disp_session.h exactly: the
# ioctl numbers encode the struct sizes.

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := hwcomposer.mt6737m
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_MODULE_TAGS := optional
# hw_get_module searches /vendor first; the composer passthrough runs in a
# vendor process.
LOCAL_VENDOR_MODULE := true
LOCAL_MULTILIB := both
LOCAL_SRC_FILES := forge_hwc.c
LOCAL_C_INCLUDES := $(LOCAL_PATH)
LOCAL_SHARED_LIBRARIES := liblog libdl
LOCAL_CFLAGS := -Wall -Wno-unused-parameter -DLOG_TAG=\"forge-hwc\"
include $(BUILD_SHARED_LIBRARY)
