
ifeq ($(TARGET_DEVICE),m5c)
ifeq ($(BOARD_PROVIDES_LIBRIL),true)
LOCAL_PATH:= $(call my-dir)

ril_src_files := \
    ril.cpp \
    ril_event.cpp\
    RilSapSocket.cpp \
    ril_service.cpp \
    sap_service.cpp

ril_shared_libs := \
    liblog \
    libutils \
    libcutils \
    libhardware_legacy \
    libbinder \
    librilmtk \
    librilutils \
    mtk-ril \
    android.hardware.radio@1.0 \
    android.hardware.radio.deprecated@1.0 \
    libhidlbase \
    libm5cshim_legacy

# vendor/meizu/m5c/ril/libril: mtk_ril_unsol_commands.h, included by ril.cpp
# (MediaTek-proprietary, kept with the blobs).
ril_inc := $(LOCAL_PATH)/../include \
    external/nanopb-c \
    vendor/meizu/m5c/ril/libril

# RIL_InitialAttachApn of the m5c blob has no roamingProtocol (objdump,
# LOS 16 forge commit cc9b313; ril_service.cpp).
ril_cflags := -Wno-unused-parameter -DANDROID_SIM_COUNT_2 -DANDROID_MULTI_SIM -DMTK_HARDWARE \
    -DMTK_RIL_IAA_NO_ROAMING_PROTOCOL

include $(CLEAR_VARS)
LOCAL_VENDOR_MODULE := true
LOCAL_SRC_FILES := $(ril_src_files)
LOCAL_SHARED_LIBRARIES := $(ril_shared_libs)
LOCAL_STATIC_LIBRARIES := \
    libprotobuf-c-nano-enable_malloc
LOCAL_CFLAGS := $(ril_cflags)
LOCAL_C_INCLUDES += $(ril_inc)
LOCAL_EXPORT_C_INCLUDE_DIRS := $(LOCAL_PATH)/../include
LOCAL_MODULE:= libril
LOCAL_SANITIZE := integer
include $(BUILD_SHARED_LIBRARY)

endif
endif
