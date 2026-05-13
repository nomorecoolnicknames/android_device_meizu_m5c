#
# Board configuration for the Meizu M5c (m5c, M710H): MT6737M, arm64, 2 GB RAM.
# /vendor is a real partition (custom, mmcblk0p17, 512 MiB); VNDK is not enabled.
#

DEVICE_PATH := device/meizu/m5c

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53

TARGET_2ND_ARCH := arm
# armv8-a, not armv7-a-neon: the combo makefiles warn on armv7-a-neon with an
# armv8-a primary arch.
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53
TARGET_USES_64_BIT_BINDER := true

# Platform
TARGET_BOARD_PLATFORM := mt6737m
TARGET_BOOTLOADER_BOARD_NAME := mt6737m
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true
BOARD_NAME := m5c
BOARD_USES_MTK_HARDWARE := true
MTK_HARDWARE := true

# Kernel
# The MTK boot header board tag is "mt6737". androidboot.hardware=mt6735 is
# required for init to import init.mt6735.rc and fstab.mt6735.
# buildvariant= is appended by the build system; do not set it here.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.selinux=permissive androidboot.hardware=mt6735
# Load addresses: kernel 0x40080000, ramdisk 0x44000000, tags 0x4e000000.
# The MTK loader jumps exactly where the header says, so a wrong base makes the
# kernel never run.
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00080000
BOARD_RAMDISK_OFFSET := 0x04000000
BOARD_KERNEL_TAGS_OFFSET := 0x0e000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_MKBOOTIMG_ARGS := --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET) --tags_offset $(BOARD_KERNEL_TAGS_OFFSET) --board mt6737

TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
# Prebuilt 4.9 kernel: gzip'd Image with the stock DTB appended. The kernel is
# meant to run with the stock DTB, not a tree-built one.
TARGET_KERNEL_SOURCE :=
TARGET_KERNEL_CONFIG :=
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt-kernel/Image.gz-dtb
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

# Fail the build if the prebuilt kernel does not match prebuilt-kernel/EXPECTED.txt,
# so a stale kernel is never packaged. Details go to stderr.
forge_kernel_check := $(shell $(DEVICE_PATH)/tools/check_prebuilt_kernel.sh \
        $(TARGET_PREBUILT_KERNEL) $(DEVICE_PATH)/prebuilt-kernel/EXPECTED.txt)
ifneq ($(strip $(forge_kernel_check)),)
$(error $(forge_kernel_check))
endif

# Partitions
# recovery is 32 MiB (fastboot getvar).
BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 1610612736
BOARD_CACHEIMAGE_PARTITION_SIZE := 419430400
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12831948800
BOARD_FLASH_BLOCK_SIZE := 131072

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USES_MKE2FS := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4

# Vendor
# /vendor lives on the unused "custom" partition (mmcblk0p17, 512 MiB).
# TARGET_COPY_OUT_VENDOR builds a vendor.img and drops the ramdisk
# /vendor -> /system/vendor symlink.
# PRODUCT_FULL_TREBLE_OVERRIDE stays false and the shipping API level stays 25
# (lineage_m5c.mk): many vendor ELFs need framework libs, so VNDK is not
# enabled. A vendor partition does not require it.
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912

# A-only, no dynamic partitions. fastboot cannot write partitions on this
# device; flash from recovery.
AB_OTA_UPDATER := false
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/fstab.mt6735
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
TARGET_SCREEN_WIDTH := 720
TARGET_SCREEN_HEIGHT := 1280

# Properties
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/system.prop

# SELinux
# Runtime is permissive (androidboot.selinux=permissive). Pie neverallows
# reject the Oreo-era MTK vendor rules, so skip the build-time assertions.
SELINUX_IGNORE_NEVERALLOWS := true

# Seccomp
# Without the vendor mediacodec policy the MTK OMX service hits SIGSYS and
# the device bootloops.
BOARD_SECCOMP_POLICY := $(DEVICE_PATH)/seccomp

# Wi-Fi
# MTK CONSYS (conn_soc); the driver is switched through /dev/wmtWifi.
BOARD_WLAN_DEVICE := MediaTek
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_mt66xx
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_mt66xx
WIFI_DRIVER_STATE_CTRL_PARAM := /dev/wmtWifi
WIFI_DRIVER_STATE_ON := 1
WIFI_DRIVER_STATE_OFF := 0

# Bluetooth
BOARD_HAVE_BLUETOOTH := true
BOARD_HAVE_BLUETOOTH_MTK := true
BOARD_BLUETOOTH_DOES_NOT_USE_RFKILL := true

# RIL
# Anchor symbol for hardware/ril/libril/librilmtk_force_needed.c. The stock
# libril has no isMalSupported; isEpdgSupport is one of the symbols
# mtk-ril.so imports.
FORGE_LIBRILMTK_KEEP_ANCHOR := isEpdgSupport

# GPS (32-bit only blobs):
#  - mtk_agpsd links ICU 56 ucnv_* symbols; libmtkshim_icu forwards them.
#  - mnld (libmnl.so) destroys a mutex twice, which FORTIFY turns into SIGABRT;
#    libmnld_shim makes pthread_mutex_destroy a no-op.
# The linker matches realpath()'d consumers, so use the /vendor/... paths.
TARGET_LD_SHIM_LIBS += \
    /vendor/bin/mtk_agpsd|/vendor/lib/libmtkshim_icu.so \
    /vendor/bin/mnld|/vendor/lib/libmnld_shim.so

# Peripherals (see forge-peripherals.mk):
#  - audio.primary: MTK AudioSystem VoiceUnlock symbols -> libshim_audio_m5c.
#  - camera HAL: GraphicBuffer, BufferQueue and BufferItemConsumer symbols ->
#    libmtkshim_gui / libmtkshim_ui.
# Consumers are matched by realpath, so 32- and 64-bit need separate entries.
TARGET_LD_SHIM_LIBS += \
    /vendor/lib/hw/audio.primary.mt6737m.so|/vendor/lib/libshim_audio_m5c.so \
    /vendor/lib64/hw/audio.primary.mt6737m.so|/vendor/lib64/libshim_audio_m5c.so \
    /vendor/lib/libcam_utils.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib64/libcam_utils.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib/libmtk_mmutils.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib64/libmtk_mmutils.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib/libmmsdkservice.feature.so|/vendor/lib/libmtkshim_gui.so \
    /vendor/lib/libmmsdkservice.feature.so|/vendor/lib/libmtkshim_ui.so \
    /vendor/lib64/libmmsdkservice.feature.so|/vendor/lib64/libmtkshim_gui.so \
    /vendor/lib64/libmmsdkservice.feature.so|/vendor/lib64/libmtkshim_ui.so

# Telephony
# The stock mtk-ril.so only has RIL_InitSocket and needs MTK libril entry
# points, so use the MTK HIDL rild/libril from vendor/mediatek/ril, which
# publishes IRadio 1.0. This skips hardware/ril/libril (the anchor above is
# then unused). MTK's telephony/ril.h must come before hardware/ril's.
BOARD_PROVIDES_LIBRIL := true
TARGET_SPECIFIC_HEADER_PATH := vendor/mediatek/include

# VINTF
# Without a device manifest hwservicemanager reports no transport for vendor
# HALs, and the Wi-Fi vendor HAL is never started.
DEVICE_MANIFEST_FILE := device/meizu/m5c/manifest.xml
