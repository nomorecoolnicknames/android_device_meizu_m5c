LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := btaddr_mtk.c
LOCAL_MODULE := btaddr_mtk
LOCAL_MODULE_TAGS := optional
LOCAL_INIT_RC := btaddr_mtk.rc
LOCAL_SHARED_LIBRARIES := libcutils liblog
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := btaddr_settings.sh
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)
LOCAL_SRC_FILES := btaddr_settings.sh
include $(BUILD_PREBUILT)
