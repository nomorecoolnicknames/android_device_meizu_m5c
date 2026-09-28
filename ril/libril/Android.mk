# libril — MediaTek Oreo HIDL RIL library (IRadio 1.0) for the m5c on
# Android 13.  Lane flash-m5c, 2026-09-28.
#
# Source: the m5c's own LOS 16 tree, original-build-host <private-home>/m6rom16/rom
# vendor/mediatek/ril 6dd7c54 ("forge(m5c): правки бринг-апа LOS 16.0") —
# the RIL with which SIM, calls and mobile data worked on this phone
# (meizu-fleet/FLEET_MATRIX.md §3, rows 6/7/9).  Originally daniel_hk's Oreo
# port of the AOSP libril for MTK: it drives the stock mtk-ril.so through
# RIL_InitSocket/RIL_registerSocket — the m5c blob has no RIL_Init, so
# hardware/ril's libril (m95's route) cannot host it.
#
# A13 deltas vs LOS 16 (nothing else changed):
#  - libhidltransport and libhwbinder folded into libhidlbase (Q);
#  - LOCAL_CLANG dropped;
#  - libm5cshim_legacy linked: it supplies what the stock pair imports from
#    N-era platform libraries — mtk-ril.so: ifc_ccmni_md_cfg,
#    ifc_set_txq_state (MTK libnetutils); librilmtk.so: strdup8to16,
#    strndup16to8, strnlen16to8, strncpy16to8 (libcutils jstring).  rild's
#    whole load graph is RTLD_GLOBAL, so the blobs find them there without a
#    DT_NEEDED edit;
#  - ril.cpp: the unused #include <cutils/jstring.h> removed (the header is
#    gone in A13);
#  - headers: ../include is this port's own copy (telephony/ril.h and
#    mtk_ril.h = original-build-host vendor/mediatek/include 6dd7c54, the rest =
#    that tree's hardware/ril/include) and comes before the ril_headers that
#    librilutils exports.
# Offline check 2026-09-28: all five sources and rild.c pass clang-r450784d
# -fsyntax-only with Soong's -Werror= set, 0 errors.
#
# Guarded by TARGET_DEVICE as well: Make parses this file for every product
# of the workspace, and m95 builds hardware/ril's libril.

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

ril_inc := $(LOCAL_PATH)/../include \
    external/nanopb-c

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
