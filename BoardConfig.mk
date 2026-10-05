#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/meizu/m5c

# LineageOS kernel/soong plumbing (TARGET_LD_SHIM_LIBS, prebuilt-kernel
# handling, BoardConfigSoong export set).
include vendor/lineage/config/BoardConfigLineage.mk

# ---------------------------------------------------------------------------
# Architecture
# ---------------------------------------------------------------------------
# FACT: MT6737M is a quad Cortex-A53, ARMv8.0-A.  ARMv8.1 LSE atomics
# (LDADD/SWP/CAS) trap as SIGILL on this core outside the __aarch64_*
# outline-atomic helpers, so the arch variant must stay armv8-a.
#
# FACT (build/soong/cc/config/arm64_device.go:29-42, 54-58 in this tree):
#   armv8-a       -> -march=armv8-a          (no +lse, no +atomics)
#   cortex-a53    -> -mcpu=cortex-a53
# and there is no -moutline-atomics anywhere in soong's arm64 config
# (grep over build/soong/cc/config/*.go returns nothing for
# "outline-atomics"/"lse").  So this pair is LSE-free by construction on A13.
#
# FACT (build/soong/android/arch_list.go:21-28): "armv8-a" is still a legal
# arm64 AND arm arch variant in Android 13.
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

# The blob set is 32/64 mixed (449 files under vendor/meizu/m5c/proprietary,
# both lib/ and lib64/), so the 32-bit ABI has to stay.  ro.zygote=zygote64_32
# comes from core_64_bit.mk.
TARGET_USES_64_BIT_BINDER := true

# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------
# FACT: ro.board.platform=mt6737m on the live device (stock system.prop, and
# the 14.1/16 trees both use it for hw_get_module lookups such as
# hwcomposer.mt6737m / audio.primary.mt6737m / camera.mt6737m).
TARGET_BOARD_PLATFORM := mt6737m
TARGET_BOOTLOADER_BOARD_NAME := mt6737m
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

TARGET_OTA_ASSERT_DEVICE := m5c,M710H

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
# find fstab.mt6735 — the same lesson as the m681 port.  selinux=permissive is
# the bring-up setting; see the SELinux block below.
# buildvariant= is appended by build/make automatically — do not set it here.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.selinux=permissive androidboot.hardware=mt6735

BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2030043136
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12831948800
BOARD_FLASH_BLOCK_SIZE := 131072

TARGET_USERIMAGES_USE_EXT4 := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4

AB_OTA_UPDATER := false
BOARD_USES_RECOVERY_AS_BOOT := false

# No system_ext / product partitions on this GPT — fold them into /system.
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
TARGET_COPY_OUT_PRODUCT := system/product

TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912

PRODUCT_FULL_TREBLE_OVERRIDE := true

# current, NOT 30.  The m95 tree tried 30 first and rejected it with two build
# walls (vendor APEXes of hardware/interfaces take vendor.30 while plain vendor
# modules take vendor.33; any vendor.30 variant then demands a checked-in
# vendor snapshot) — device/meizu/m95/BoardConfig.mk:238-267.  m95 keeps v30
# only as PRODUCT_EXTRA_VNDK_VERSIONS, to boot an OLD 18.1 vendor.img; m5c has
# no such image, so no extra VNDK apex is shipped (com.android.vndk.v30 is
# 109 MiB of /system, measured in out-m95).
BOARD_VNDK_VERSION := current

BOARD_ROOT_EXTRA_FOLDERS := nvdata protect_f protect_s

BOARD_USES_METADATA_PARTITION := true

BOARD_PROVIDES_LIBRIL := true
ENABLE_VENDOR_RIL_SERVICE := true

BOARD_VENDOR_SEPOLICY_DIRS += device/meizu/m5c/sepolicy/vendor

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.mt6735
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
TARGET_SCREEN_WIDTH := 720
TARGET_SCREEN_HEIGHT := 1280

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP := $(DEVICE_PATH)/vendor.prop

# ---------------------------------------------------------------------------
# SELinux
# ---------------------------------------------------------------------------
# TEMPORARY: the runtime is permissive through androidboot.selinux in
# BOARD_KERNEL_CMDLINE above.  The vendor policy (sepolicy/vendor) left 0
# system/vendor denials in the permissive census of set 23; the switch to
# enforcing waits for the lead's approval and a live `setenforce 1` run, and
# needs ro.adb.secure handled first (device.mk).
# The build enforces the neverallows (SELINUX_IGNORE_NEVERALLOWS is not set):
# neverallow checks, sepolicy_test and the treble tests pass.

# ---------------------------------------------------------------------------
# Wi-Fi — MTK CONSYS MT6735 combo
# ---------------------------------------------------------------------------
# FACT: the driver is powered through /dev/wmtWifi (write "1"/"0"); this is
# the control path 14.1 and 16 both prove live.
BOARD_WLAN_DEVICE := MediaTek
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
WIFI_DRIVER_STATE_CTRL_PARAM := /dev/wmtWifi
WIFI_DRIVER_STATE_ON := 1
WIFI_DRIVER_STATE_OFF := 0

# ---------------------------------------------------------------------------
# Bluetooth — same CONSYS chip
# ---------------------------------------------------------------------------
BOARD_HAVE_BLUETOOTH := true

DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml

# ---------------------------------------------------------------------------
# Build workarounds
# ---------------------------------------------------------------------------
# The blob set is Nougat/Oreo vintage; its ELF dependency closure does not
# resolve against A13 libraries by name (it is wired at build time, vendor/
# meizu/m5c treble-elf-wiring.txt), so the prebuilt ELF checker must not gate
# the build.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_PREBUILT_ELF_FILES := true
# Make rules defined twice.  Which rule needs it is not recorded; the blob
# list of vendor/meizu/m5c installs several destinations twice, so this is a
# candidate for removal once that list is deduplicated and a build confirms.
BUILD_BROKEN_DUP_RULES := true
# The MTK blobs read and set properties outside the vendor namespaces
# (ro.mtk_*, persist.mtk.*, ril.*, af.*, ...), so sepolicy/vendor/
# property_contexts has to name them.
BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE := true
