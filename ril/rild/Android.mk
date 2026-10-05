# MediaTek RIL daemon; vendor property helper is a separate restricted input.

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
