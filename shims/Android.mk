LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE        := libshim_vcodec
LOCAL_MODULE_TAGS   := optional
LOCAL_PROPRIETARY_MODULE := true
LOCAL_SRC_FILES     := pthread_gettid_shim.c
LOCAL_MULTILIB      := both
LOCAL_SHARED_LIBRARIES := libc
include $(BUILD_SHARED_LIBRARY)

# libfs_mgr.so stub. Pie only builds libfs_mgr as a static library, so MTK
# blobs that need libfs_mgr.so (nvram_daemon, mnld) fail to load.
include $(CLEAR_VARS)
LOCAL_MODULE := libfs_mgr_m5c_shim
LOCAL_SRC_FILES := fs_mgr.c
LOCAL_POST_INSTALL_CMD := mkdir -p $(TARGET_OUT_VENDOR)/lib $(TARGET_OUT_VENDOR)/lib64 \
    && ln -sf libfs_mgr_m5c_shim.so $(TARGET_OUT_VENDOR)/lib/libfs_mgr.so \
    && ln -sf libfs_mgr_m5c_shim.so $(TARGET_OUT_VENDOR)/lib64/libfs_mgr.so
LOCAL_MULTILIB := both
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)

# ifc_ipv6_trigger_rs for the MTK RIL blobs.
include $(CLEAR_VARS)
LOCAL_MODULE := libmtkshim_net
LOCAL_SRC_FILES := net.c
LOCAL_MULTILIB := both
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)

# libmnld_shim: no-op pthread_mutex_destroy for mnld (see TARGET_LD_SHIM_LIBS).
# Executable shims load before libc. 32-bit only, like mnld.
include $(CLEAR_VARS)
LOCAL_MODULE := libmnld_shim
LOCAL_SRC_FILES := pthread.c
LOCAL_MULTILIB := 32
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)

# libshim_audio_m5c: no-op MTK voice-unlock AudioSystem symbols for
# audio.primary.mt6737m.so (see TARGET_LD_SHIM_LIBS).
include $(CLEAR_VARS)
LOCAL_MODULE := libshim_audio_m5c
LOCAL_SRC_FILES := audio_voiceunlock.c
LOCAL_MULTILIB := both
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MODULE_TAGS := optional
LOCAL_SHARED_LIBRARIES := libc
include $(BUILD_SHARED_LIBRARY)
