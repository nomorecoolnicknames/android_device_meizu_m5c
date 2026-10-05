# rild — MediaTek Oreo RIL daemon for the m5c on Android 13 (companion of
# ../libril/Android.mk, same source and provenance: gunwest m6rom16
# vendor/mediatek/ril 6dd7c54).  Loads rild.libpath
# (/vendor/lib64/mtk-ril.so, vendor.prop) and calls RIL_InitSocket.
# rild-prop-md1 (MediaTek's prebuilt property helper: mtkInit,
# signal_treatment, isUserLoad) is defined in vendor/meizu/m5c/Android.mk:
# the object is MediaTek-proprietary and lives with the blobs.
# A13 deltas: this header, the TARGET_DEVICE guard, ../include first, and
# librilutils_static -> librilutils (A13 builds it as one cc_library; same as
# hardware/ril/rild/Android.mk).

ifeq ($(TARGET_DEVICE),m5c)
ifeq ($(ENABLE_VENDOR_RIL_SERVICE),true)
LOCAL_PATH:= $(call my-dir)

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
