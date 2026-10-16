#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Meizu M5c (M710H), MediaTek MT6737M.
#

DEVICE_PATH := device/meizu/m5c

# LineageOS kernel/soong plumbing (TARGET_LD_SHIM_LIBS, kernel build,
# BoardConfigSoong export set).
include vendor/lineage/config/BoardConfigLineage.mk

# Architecture
# MT6737M is a quad Cortex-A53 (ARMv8.0-A, no LSE atomics).
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53
TARGET_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53

# The blob set has both 32- and 64-bit libraries.
TARGET_USES_64_BIT_BINDER := true

# Platform
TARGET_BOARD_PLATFORM := mt6737m
TARGET_BOOTLOADER_BOARD_NAME := mt6737m
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

TARGET_OTA_ASSERT_DEVICE := m5c,M710H

# ---------------------------------------------------------------------------
# Kernel
# ---------------------------------------------------------------------------
# m5c_defconfig appends the stock-board device tree (m5c-stock.dts): the
# k37mv1_bsp_k49 reference tree names the eMMC controller "mediatek,msdc",
# which the M5c storage driver does not bind. DRVGEN_FILE_LIST= keeps drvgen
# from regenerating the committed cust.dtsi. Several MediaTek drivers switch
# features on TARGET_BUILD_VARIANT; the tested kernel was built without it.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE := kernel/meizu/m5c
TARGET_KERNEL_CONFIG := m5c_defconfig
TARGET_KERNEL_CLANG_COMPILE := false
TARGET_KERNEL_ADDITIONAL_FLAGS := DRVGEN_FILE_LIST= TARGET_BUILD_VARIANT=
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

# Boot geometry — MUST reproduce the addresses of the proven 14.1/16 image:
#   kernel 0x40080000, ramdisk 0x44000000, tags 0x4e000000.
# The MTK loader jumps exactly where the header says.  A base of 0x40078000
# (taken from the recovery block) put the kernel 0x78000 off and it never ran:
# no pstore, no last_kmsg, no expdb entry, just a boot loop.
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00080000
BOARD_RAMDISK_OFFSET := 0x04000000
BOARD_KERNEL_TAGS_OFFSET := 0x0e000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_MKBOOTIMG_ARGS := \
    --kernel_offset $(BOARD_KERNEL_OFFSET) \
    --ramdisk_offset $(BOARD_RAMDISK_OFFSET) \
    --tags_offset $(BOARD_KERNEL_TAGS_OFFSET) \
    --board mt6737

# androidboot.hardware=mt6735 is what makes init import init.mt6735.rc and
# find fstab.mt6735 — the same lesson as the m681 port.  No androidboot.selinux:
# the runtime is enforcing (SELinux block below).
# buildvariant= is appended by build/make automatically — do not set it here.
# The boot.img of the m5c is repacked from a base image
# cloud-los16/m5c-cloud/repack_boot.py), whose own cmdline must match this one.
# androidboot.boot_devices: under an enforcing boot, without it
# ueventd takes the boot device from the default fstab, that lookup is denied
# under enforcing (ueventd -> metadata_file) and /dev/block/by-name keeps only
# the three first-stage links (custom, metadata, system); with it all 30.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.hardware=mt6735 androidboot.boot_devices=mtk-msdc.0/11230000.msdc0

# Partitions
# boot 16 MiB, recovery 32 MiB, custom (/vendor) 512 MiB, system 2560 MiB.
# The system image is limited to 1936 MiB. /cache is not mounted.
BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2030043136
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12831948800
BOARD_FLASH_BLOCK_SIZE := 131072

TARGET_USERIMAGES_USE_EXT4 := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4

# A-only. fastboot cannot write partitions on this device; install from
# recovery.
AB_OTA_UPDATER := false
BOARD_USES_RECOVERY_AS_BOOT := false

# No system_ext / product partitions, fold them into /system.
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
TARGET_COPY_OUT_PRODUCT := system/product

# Vendor
# The stock `custom` partition (mmcblk0p17, 512 MiB ext4) is used as /vendor.
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912

# Treble
# Set explicitly: PRODUCT_USE_VNDK requires PRODUCT_SHIPPING_API_LEVEL > 27,
# which a Marshmallow launch device does not have.
PRODUCT_FULL_TREBLE_OVERRIDE := true

# VNDK version 30 would require a checked-in vendor snapshot.
BOARD_VNDK_VERSION := current

# Root
# Not system-as-root: the LK always loads the boot.img ramdisk and
# cannot pass skip_initramfs. First stage init mounts /system and /vendor
# from the ramdisk fstab and switches root into /system.
BOARD_ROOT_EXTRA_FOLDERS := nvdata protect_f protect_s

# The fstab mounts /metadata; without the mount point on the system root
# mount_all fails and zygote never starts.
BOARD_USES_METADATA_PARTITION := true

# RIL
# mtk-ril.so has no RIL_Init and is driven through RIL_InitSocket, so
# use the MTK HIDL libril/rild from ril/ instead of hardware/ril.
BOARD_PROVIDES_LIBRIL := true
ENABLE_VENDOR_RIL_SERVICE := true

# The IMS service talks to the Marshmallow-era Flyme librilmtk / mtk-ril.so,
# whose IMS request and URC numbers differ from the Nougat ones.
FORGE_IMS_VENDOR_GEN := m

# SELinux
# Root-level directories need explicit labels, otherwise e2fsdroid fails
# on system.img.
BOARD_VENDOR_SEPOLICY_DIRS += device/meizu/m5c/sepolicy/vendor

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.mt6735
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
TARGET_SCREEN_WIDTH := 720
TARGET_SCREEN_HEIGHT := 1280

# Properties
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP := $(DEVICE_PATH)/vendor.prop

# Wi-Fi
# MT6735 CONSYS combo chip, powered through /dev/wmtWifi.
BOARD_WLAN_DEVICE := MediaTek
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
# Driver private commands (SETSUSPENDMODE, COUNTRY, RXFILTER, ...).
# Without them setSuspendModeEnabled fails and the driver never filters
# broadcast/multicast with the screen off.
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_m5c
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_m5c
WIFI_DRIVER_STATE_CTRL_PARAM := /dev/wmtWifi
WIFI_DRIVER_STATE_ON := 1
WIFI_DRIVER_STATE_OFF := 0

# Bluetooth
BOARD_HAVE_BLUETOOTH := true

# VINTF
# Wi-Fi HalDeviceManager only creates wlan0 if IWifi is declared in the
# device manifest.
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml

# Build workarounds
# The Nougat-era blobs do not resolve against Android 13 libraries by name,
# so the prebuilt ELF checker must not gate the build.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_PREBUILT_ELF_FILES := true
# vendor/meizu/m5c installs some destinations twice.
BUILD_BROKEN_DUP_RULES := true
# The MTK blobs use properties outside the vendor namespaces
# (ro.mtk_*, persist.mtk.*, ril.*, af.*).
BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE := true
