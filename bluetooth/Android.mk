LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := btaddr_mtk.c
LOCAL_MODULE := btaddr_mtk
LOCAL_MODULE_TAGS := optional
LOCAL_INIT_RC := btaddr_mtk.rc
LOCAL_SHARED_LIBRARIES := libcutils liblog
include $(BUILD_EXECUTABLE)
