#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Meizu M5c (M710H), MediaTek MT6737M.
#

DEVICE_PATH := device/meizu/m5c

# LineageOS kernel/soong plumbing (TARGET_LD_SHIM_LIBS, prebuilt-kernel
# handling, BoardConfigSoong export set).
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

# Kernel
# Prebuilt 4.9 kernel with the stock DTB appended. The kernel source tree
# builds a DTB with incompatible eMMC compatible strings, so it must not be
# used. Empty TARGET_KERNEL_SOURCE keeps vendor/lineage on the prebuilt path.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE :=
TARGET_KERNEL_CONFIG :=
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt-kernel/Image.gz-dtb
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

# The MTK LK jumps to the addresses from the boot image header:
# kernel 0x40080000, ramdisk 0x44000000, tags 0x4e000000.
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

# androidboot.hardware=mt6735 makes init import init.mt6735.rc and find
# fstab.mt6735. buildvariant= is appended by the build system.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.hardware=mt6735

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
