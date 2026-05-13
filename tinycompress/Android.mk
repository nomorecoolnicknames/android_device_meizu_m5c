# libtinycompress for audio.primary.mt6737m.so. external/tinycompress needs
# generated_kernel_headers, which cannot be built with a prebuilt kernel, so
# build the same sources against bionic's uapi headers under a unique name
# and install a libtinycompress.so symlink.
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := libtinycompress_m5c
LOCAL_SRC_FILES := \
    ../../../../external/tinycompress/compress.c \
    ../../../../external/tinycompress/utils.c
LOCAL_C_INCLUDES := external/tinycompress/include
LOCAL_CFLAGS := -Wall -Wno-macro-redefined -Wno-unused-function
LOCAL_LDFLAGS := -Wl,-soname,libtinycompress.so
LOCAL_SHARED_LIBRARIES := libcutils libutils
LOCAL_POST_INSTALL_CMD := mkdir -p $(TARGET_OUT_VENDOR)/lib $(TARGET_OUT_VENDOR)/lib64 \
    && ln -sf libtinycompress_m5c.so $(TARGET_OUT_VENDOR)/lib/libtinycompress.so \
    && ln -sf libtinycompress_m5c.so $(TARGET_OUT_VENDOR)/lib64/libtinycompress.so
LOCAL_MULTILIB := both
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)
