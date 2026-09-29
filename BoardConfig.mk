#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# BoardConfig.mk — Meizu M5c (m5c, M710H), MT6737M, arm64, 2 GB RAM.
# LineageOS 20.0 (Android 13, SDK 33) skeleton.
#
# Every value below is either carried from a tree that demonstrably boots the
# device (the forge LOS 14.1 tree and its LOS 16 successor, both on
# <private-workspace>/m5c/los14.1-m5c-patched/device/meizu/m5c) or derived from
# a recorded measurement.  Where it is a guess it says HYPOTHESIS.

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
BOARD_NAME := m5c
BOARD_USES_MTK_HARDWARE := true
MTK_HARDWARE := true

TARGET_OTA_ASSERT_DEVICE := m5c,M710H

# Use an MT6737M kernel with the matching stock DTB and the required Android BPF/cgroup interfaces.
# Keep kernel version, symbol and checksum validation enabled.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE :=
TARGET_KERNEL_CONFIG :=
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt-kernel/Image.gz-dtb
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

# Freshness gate on the hand-placed prebuilt (carried from the LOS 16 tree).
# The file goes stale silently: on 2026-09-03 a kernel from Aug 28 sat here and
# a clean build would have shipped a ROM without a single fix of that day.
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

# A-only partition geometry from the M5c stock layout. Do not reuse another board partition map.
BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
# ---------------------------------------------------------------------------
# 2026-09-17: ВЕТКА ВАРИАНТА B — требует ПЕРЕРАЗМЕТКИ аппарата
# ---------------------------------------------------------------------------
# Владелец разрешил переразметку 2026-09-17. cache (p24, 400 МиБ) вливается в
# смежный system (p23) -> 1936 МиБ: meizu-fleet/tools/repartition-cache-into-system.sh
# --device m5c (сначала без --confirm: бэкап GPT + проверка смежности).
#
# Пока переразметка НЕ сделана, собранный с этой ветки образ (>1536 МиБ) в
# раздел не влезет — прошивка честно оборвётся на записи. Вариант без
# переразметки — ветка lineage-20-fit1536 (режет 8 optional-пакетов, запас 2 %).
#
# /cache после слияния НЕ СУЩЕСТВУЕТ: BOARD_CACHEIMAGE_* убраны, строка cache
# убрана из rootdir/etc/fstab.mt6735. Android 13 обходится без /cache
# (OTA живёт в /data/ota); TWRP смонтирует его как отсутствующий.
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2030043136
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12831948800
BOARD_FLASH_BLOCK_SIZE := 131072

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USES_MKE2FS := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4

# A successful fastboot transfer does not prove a partition write; installation requires readback verification.
AB_OTA_UPDATER := false
BOARD_USES_RECOVERY_AS_BOOT := false

# No system_ext / product partitions on this GPT — fold them into /system.
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
TARGET_COPY_OUT_PRODUCT := system/product

# The custom partition supplies /vendor. Preserve the stock partition boundaries.
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912

# ---------------------------------------------------------------------------
# Treble + VNDK (2026-09-25, owner's directive "all of the fleet Treble",
# branch lineage-20-treble; design: meizu-fleet/designs/TREBLE_M5C_20260924.md)
# ---------------------------------------------------------------------------
# WAS: VNDK off, PRODUCT_FULL_TREBLE_OVERRIDE := false, on the argument that
# 134 of 403 vendor ELFs link framework-only libraries (M5C_LOS16_TREBLE_PLAN.md
# §6.2).  That count is still right — re-measured on this blob set with
# meizu-fleet/tools/m5c_treble_needed.py: 137 vendor ELFs have a DT_NEEDED the
# vendor namespace cannot reach — but "unreachable" turned out to be wrong:
# m95 runs the same generation of N-era MTK blobs in a VNDK namespace on this
# same platform tree (vendor copies, forwarders and shims, lessons 5-8 of
# designs/FLEET_PORT_FROM_M95_20260924.md).  device.mk carries the m5c half.
#
# FACT (build/make/core/config.mk:721-737): PRODUCT_USE_VNDK (and with it the
# implicit BOARD_VNDK_VERSION := current) needs PRODUCT_SHIPPING_API_LEVEL > 27,
# which a Marshmallow-launched handset does not have, so both switches are set
# explicitly, exactly as m95 does (device/meizu/m95/BoardConfig.mk:236, :267).
PRODUCT_FULL_TREBLE_OVERRIDE := true

# current, NOT 30.  The m95 tree tried 30 first and rejected it with two build
# walls (vendor APEXes of hardware/interfaces take vendor.30 while plain vendor
# modules take vendor.33; any vendor.30 variant then demands a checked-in
# vendor snapshot) — device/meizu/m95/BoardConfig.mk:238-267.  m95 keeps v30
# only as PRODUCT_EXTRA_VNDK_VERSIONS, to boot an OLD 18.1 vendor.img; m5c has
# no such image, so no extra VNDK apex is shipped (com.android.vndk.v30 is
# 109 MiB of /system, measured in out-m95).
BOARD_VNDK_VERSION := current

# ---------------------------------------------------------------------------
# Boot / root layout
# ---------------------------------------------------------------------------
# NOT system-as-root in the BOARD_BUILD_SYSTEM_ROOT_IMAGE sense.  That mode
# needs the bootloader to pass skip_initramfs / force_normal_boot, and this
# 2017 Meizu LK does neither (it always loads the boot.img ramdisk; it also
# refuses `fastboot boot` with "unknown command", so the cmdline cannot be
# changed from the host either).  Android 13 init handles this the normal
# non-A/B way instead: the boot ramdisk carries first-stage init plus
# fstab.mt6735, DoFirstStageMount() mounts /system and SwitchRoot()s into it,
# which produces the same "/ is the system partition" result at runtime.
# (first_stage_init.cpp:388-401 only switches into /first_stage_ramdisk when
# ForceNormalBoot() is true, which needs androidboot.force_normal_boot=1.)
# HYPOTHESIS to verify on the first boot attempt: that A13 first-stage init
# finds /fstab.mt6735 in the ramdisk root on this device.  The LOS 16 port ran
# WITHOUT first-stage mount at all (device.mk comment: "on this
# no-first-stage-mount device the ONLY prop file early init actually loads is
# /system/build.prop"), and that mode no longer exists in A13 — this is the
# single largest untested change in the port.
BOARD_ROOT_EXTRA_FOLDERS := nvdata protect_f protect_s

# /metadata mount point on the system root (system/core/rootdir/Android.mk:116-118).
# FACT (flash-m5c, first A13 boots 2026-09-28): the fstab mounts /metadata
# (first_stage_mount,formattable), but without this flag the system image has
# no /metadata directory.  First stage switches root to /system BEFORE it
# mounts the other partitions (first_stage_mount.cpp:529-568), so the mount
# fails (formattable -> ignored); in the second stage mount_all fails it again,
# returns FS_MGR_MNTALL_FAIL, ro.crypto.state is never set and zygote-start
# never fires.  The HYPOTHESIS above ("fstab.mt6735 found in the ramdisk
# root") is CONFIRMED by the same boots: system and vendor were mounted by
# the first stage.
BOARD_USES_METADATA_PARTITION := true

# RIL: the MTK Oreo HIDL libril + rild of ril/ (IRadio 1.0, drives mtk-ril.so
# through RIL_InitSocket — the m5c blob has no RIL_Init, so hardware/ril's
# libril/rild cannot host it).  These two switch hardware/ril's modules off
# (hardware/ril/libril/Android.mk:3, hardware/ril/rild/Android.mk:1) and ours
# on (ril/libril/Android.mk, ril/rild/Android.mk).  flash-m5c, 2026-09-28.
BOARD_PROVIDES_LIBRIL := true
ENABLE_VENDOR_RIL_SERVICE := true

# ...and the SELinux labels for exactly those three directories.  Without them
# e2fsdroid aborts while configuring system.img:
#   set_selinux_xattr: No such file or directory searching for label "/nvdata"
# because system/sepolicy/private/file_contexts has no catch-all entry and
# every root-level directory must be labelled explicitly.  Full derivation and
# the rejected alternatives are in sepolicy/vendor/file_contexts itself.
# This is the tree's ONLY sepolicy input; the "NOT WIRED YET" note in device.mk
# (nothing carried over, runtime is permissive) still stands.
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
# Runtime stays permissive via the kernel cmdline for bring-up, exactly as on
# 14.1 and 16.  Build-time neverallow assertions are skipped because the
# Oreo-era MTK vendor rules this port inherits violate A13 public policy.
SELINUX_IGNORE_NEVERALLOWS := true

# ---------------------------------------------------------------------------
# Seccomp
# ---------------------------------------------------------------------------
# m681 evidence: without the vendor mediacodec seccomp policy the MTK omx
# service takes SIGSYS, crash_dump storms, and the device OOM-bootloops.
BOARD_SECCOMP_POLICY := $(DEVICE_PATH)/seccomp

# ---------------------------------------------------------------------------
# Graphics
# ---------------------------------------------------------------------------
BOARD_EGL_CFG := $(DEVICE_PATH)/configs/egl.cfg
USE_OPENGL_RENDERER := true

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
BOARD_HAVE_BLUETOOTH_MTK := true
BOARD_BLUETOOTH_DOES_NOT_USE_RFKILL := true

# ---------------------------------------------------------------------------
# VINTF
# ---------------------------------------------------------------------------
# Wi-Fi is the one HAL that asks the manifest directly: HalDeviceManager
# decides a vendor HAL exists iff getTransport(IWifi) != EMPTY.  With no
# manifest wlan0 is never created at all (measured on the live LOS 16 device
# 2026-09-03, M5C_LOS16_PERIPHERALS_MEASURE_20260903.md).
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml

# ---------------------------------------------------------------------------
# Build workarounds
# ---------------------------------------------------------------------------
# The blob set is Nougat/Oreo vintage; its ELF dependency closure does not
# resolve against A13 libraries, so the prebuilt ELF checker must not gate the
# build.  This is a statement of fact about the blobs, not a wish.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_PREBUILT_ELF_FILES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE := true
