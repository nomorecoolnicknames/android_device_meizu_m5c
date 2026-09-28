# rild — MediaTek Oreo RIL daemon for the m5c on Android 13 (companion of
# ../libril/Android.mk, same source and provenance: original-build-host m6rom16
# vendor/mediatek/ril 6dd7c54).  Loads rild.libpath
# (/vendor/lib64/mtk-ril.so, vendor.prop) and calls RIL_InitSocket.
# rild-prop-md1.a: MediaTek's prebuilt property helper object that came with
# the port (mtkInit, signal_treatment, isUserLoad).
# A13 deltas: this header, the TARGET_DEVICE guard, ../include first, and
# librilutils_static -> librilutils (A13 builds it as one cc_library; same as
# hardware/ril/rild/Android.mk).

ifeq ($(TARGET_DEVICE),m5c)
ifeq ($(ENABLE_VENDOR_RIL_SERVICE),true)
LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE = rild-prop-md1
LOCAL_MODULE_CLASS = STATIC_LIBRARIES
LOCAL_MODULE_SUFFIX = .a
LOCAL_PROPRIETARY_MODULE = true
LOCAL_UNINSTALLABLE_MODULE = true
LOCAL_MULTILIB = 64
LOCAL_SRC_FILES_64 = arm64/rild-prop-md1.a
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE = rild-prop-md1
LOCAL_MODULE_CLASS = STATIC_LIBRARIES
LOCAL_MODULE_SUFFIX = .a
LOCAL_PROPRIETARY_MODULE = true
LOCAL_UNINSTALLABLE_MODULE = true
LOCAL_MULTILIB = 32
LOCAL_SRC_FILES_32 = arm/rild-prop-md1.a
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)

LOCAL_SRC_FILES:= \
	rild.c

LOCAL_SHARED_LIBRARIES := \
	liblog \
	libcutils \
	libutils \
	libril \
	libdl

LOCAL_STATIC_LIBRARIES := \
	rild-prop-md1

LOCAL_C_INCLUDES += \
	$(LOCAL_PATH)/../include \
	system/core/libcutils/include

LOCAL_CFLAGS += -DANDROID_MULTI_SIM
LOCAL_CFLAGS += -DANDROID_SIM_COUNT_2

# temporary hack for broken vendor rils
LOCAL_WHOLE_STATIC_LIBRARIES := \
	librilutils

LOCAL_CFLAGS += -DRIL_SHLIB

LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MODULE:= rild

include $(BUILD_EXECUTABLE)
endif
endif
