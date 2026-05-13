# vibrator.mt6737m: libhardware's vibrator module, which falls back to the
# LED-class device (/sys/class/leds/vibrator) the 4.9 kernel provides. The
# stock vibrator.default.so only supports timed_output. hw_get_module tries
# ro.board.platform before "default", so this module is picked first.
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := vibrator.mt6737m
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_SRC_FILES := ../../../../hardware/libhardware/modules/vibrator/vibrator.c
LOCAL_C_INCLUDES := hardware/libhardware/include
LOCAL_SHARED_LIBRARIES := liblog libcutils
LOCAL_CFLAGS := -Wall -Werror
LOCAL_MULTILIB := both
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)
