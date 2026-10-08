










DEVICE_PATH := device/meizu/m5c

include vendor/lineage/config/BoardConfigLineage.mk

# Architecture — arm64 quad Cortex-A53 (MT6737M).
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53

TARGET_2ND_ARCH := arm


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

# Kernel — geometry is the 14.1 board/kernel.mk one (boots the device daily).
# The MTK boot-header board tag is "mt6737" (14.1 BOARD_MKBOOTIMG_ARGS).
# androidboot.hardware=mt6735 matches the rc/fstab suffix the live 14.1
# device uses (init.mt6735.rc, fstab.mt6735) — same lesson as the m681 port,
# where androidboot.hardware was REQUIRED for init to import the platform rc.
# buildvariant= is appended by build/make automatically — do not set it here.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.selinux=permissive androidboot.hardware=mt6735
# Boot geometry MUST reproduce the addresses of the proven 14.1 image:
#   kernel 0x40080000, ramdisk 0x44000000, tags 0x4e000000.
# The earlier base 0x40078000 (taken from the recovery block) plus the
# 0x00080000 kernel offset landed the kernel at 0x400f8000 - 0x78000 off.
# The MTK loader jumps exactly where the header says, so the kernel never ran:
# no pstore, no last_kmsg, no expdb entry from 4.9 at all, just a boot loop.
# ramdisk and tags happened to come out right with the old base; they do not
# with the correct one, hence all four values move together.
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00080000
BOARD_RAMDISK_OFFSET := 0x04000000
BOARD_KERNEL_TAGS_OFFSET := 0x0e000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_MKBOOTIMG_ARGS := --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET) --tags_offset $(BOARD_KERNEL_TAGS_OFFSET) --board mt6737

TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64





























TARGET_KERNEL_SOURCE :=
TARGET_KERNEL_CONFIG :=
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt-kernel/Image.gz-dtb
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb









forge_kernel_check := $(shell $(DEVICE_PATH)/tools/check_prebuilt_kernel.sh \
        $(TARGET_PREBUILT_KERNEL) $(DEVICE_PATH)/prebuilt-kernel/EXPECTED.txt)
ifneq ($(strip $(forge_kernel_check)),)
$(error $(forge_kernel_check))
endif




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

# --- Treble stage A (mirrors m681 BoardConfig.mk vendor block) -------------
# /vendor is a REAL partition: custom = mmcblk0p17, exactly 512 MiB, never
# mounted by LOS 14.1 — the same size as m681's custom(p3) byte for byte.
# TARGET_COPY_OUT_VENDOR=vendor is what makes the difference: it builds a
# vendor.img and removes the ramdisk /vendor -> /system/vendor symlink.
# PRODUCT_FULL_TREBLE_OVERRIDE stays false. Do not invent a launch API or
# enable VNDK until stock ELF dependency closure has been verified for R.
# Having a real vendor partition does not imply a Treble-compliant blob ABI.
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912

# A-only — no slots, no dynamic partitions.  fastboot is DEAD on this device
# (writes no partition); flashing is TWRP/dd over by-name only.
AB_OTA_UPDATER := false
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

# Android R switches root into the system image during first-stage mounting.
# Keep the proven stock GPT (1.5 GiB system + 400 MiB cache + custom/vendor).
# The legacy LK always loads the boot ramdisk; it does not use recovery-as-boot.
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false
BOARD_USES_RECOVERY_AS_BOOT := false
TARGET_COPY_OUT_PRODUCT := system/product
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
BOARD_ROOT_EXTRA_FOLDERS := nvdata protect_f protect_s
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/fstab.mt6735
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
TARGET_SCREEN_WIDTH := 720
TARGET_SCREEN_HEIGHT := 1280

# System props
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/system.prop

# SELinux: runtime stays androidboot.selinux=permissive for bring-up (same
# as 14.1 and the m681/m95 ports).  Pie public-policy neverallows reject
# Oreo-era MTK vendor rules; skip build-time assertions until an enforcing
# build is attempted (same flag the mt6755-common layer uses).
SELINUX_IGNORE_NEVERALLOWS := true

# Seccomp (mediacodec policy carried from 14.1; the MTK omx lesson from m681:
# without the vendor seccomp policy the omx service hits SIGSYS and bootloops).
BOARD_SECCOMP_POLICY := $(DEVICE_PATH)/seccomp

# Wi-Fi — MTK conn_soc (MT6735 CONSYS).  Same control path 14.1 proves live
# (/dev/wmtWifi write 1/0), wired the m681 way for the Pie wifi stack.
BOARD_WLAN_DEVICE := MediaTek
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_mt66xx
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_mt66xx
WIFI_DRIVER_STATE_CTRL_PARAM := /dev/wmtWifi
WIFI_DRIVER_STATE_ON := 1
WIFI_DRIVER_STATE_OFF := 0

# Bluetooth — same CONSYS; the HIDL service arrives with the stage-4 lane.
BOARD_HAVE_BLUETOOTH := true
BOARD_HAVE_BLUETOOTH_MTK := true
BOARD_BLUETOOTH_DOES_NOT_USE_RFKILL := true






FORGE_LIBRILMTK_KEEP_ANCHOR := isEpdgSupport

# Vendor-blob ABI shim. libvcodecdrv.so (Flyme / Android 7.1) imports
# __pthread_gettid, dropped from bionic in Pie; the missing symbol breaks the
# dlopen chain of /vendor/lib/egl/libGLES_mali.so, so the 32-bit zygote aborts
# with couldn't find an OpenGL ES implementation and the boot never finishes.
# The 64-bit path is unaffected, which is why bootanimation ran while the
# framework did not. See shims/pthread_gettid_shim.c.
# Three 32-bit blobs import the symbol (nm -D -u over proprietary/lib):
# libvcodecdrv is the boot blocker, reached through the Mali dlopen chain;
# libMtkOmxVdecEx and libmtkjpeg would trip later on video decode and JPEG.
# All three take the same shim. The 64-bit blobs are clean.
TARGET_LD_SHIM_LIBS += \
    /system/lib/libvcodecdrv.so|/system/vendor/lib/libshim_vcodec.so \
    /system/lib/libMtkOmxVdecEx.so|/system/vendor/lib/libshim_vcodec.so \
    /system/lib/libmtkjpeg.so|/system/vendor/lib/libshim_vcodec.so



















TARGET_LD_SHIM_LIBS += \
    /vendor/bin/mtk_agpsd|/vendor/lib/libmtkshim_icu.so \
    /vendor/bin/mnld|/vendor/lib/libmnld_shim.so













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














BOARD_PROVIDES_LIBRIL := true
TARGET_SPECIFIC_HEADER_PATH := vendor/mediatek/include

# The software keymaster service needs the explicit declaration here.
# R Wi-Fi and supplicant services supply their module-owned fragments.
DEVICE_MANIFEST_FILE := device/meizu/m5c/manifest.xml
