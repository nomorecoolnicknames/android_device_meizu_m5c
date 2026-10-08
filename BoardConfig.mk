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

# a recorded measurement.  Where it is a guess it says HYPOTHESIS.

DEVICE_PATH := device/meizu/m5c

# LineageOS kernel/soong plumbing (TARGET_LD_SHIM_LIBS, prebuilt-kernel
# handling, BoardConfigSoong export set).
include vendor/lineage/config/BoardConfigLineage.mk

# ---------------------------------------------------------------------------
# Architecture
# ---------------------------------------------------------------------------

# (LDADD/SWP/CAS) trap as SIGILL on this core outside the __aarch64_*
# outline-atomic helpers, so the arch variant must stay armv8-a.
#

#   armv8-a       -> -march=armv8-a          (no +lse, no +atomics)
#   cortex-a53    -> -mcpu=cortex-a53
# and there is no -moutline-atomics anywhere in soong's arm64 config
# (grep over build/soong/cc/config/*.go returns nothing for
# "outline-atomics"/"lse").  So this pair is LSE-free by construction on A13.
#

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

# the 14.1/16 trees both use it for hw_get_module lookups such as
# hwcomposer.mt6737m / audio.primary.mt6737m / camera.mt6737m).
TARGET_BOARD_PLATFORM := mt6737m
TARGET_BOOTLOADER_BOARD_NAME := mt6737m
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

TARGET_OTA_ASSERT_DEVICE := m5c,M710H

# ---------------------------------------------------------------------------
# Kernel — PREBUILT, never rebuilt from this tree
# ---------------------------------------------------------------------------

#

# and that boots the device daily:
#   md5      e35c74fa0ce6beee5b027a06bd28ada6
#   sha256   5dadbb8f10051e664ac27b63678de78265b3eb658f1b1d32b2c1128e9ad91b71

#            Thu Sep  3 21:27:06 MSK 2026
#   size     7 840 291 B

#  prebuilt-kernel/{Image.gz-dtb,EXPECTED.txt}; md5sum re-run on the copy.)
# That file is untouched in the LOS 16 tree — it remains the rollback target.
#

#   md5      10856200094faeafd08060dd6f7ed2e1
#   sha256   0f3c2afddc71fa4d1ee237ee86a56f7d1716dd9a64d68f19f870e9e4d9b1a57f

#            Wed Sep 16 19:45:58 MSK 2026
#   size     7 866 417 B   (+26 126 B = +0,33 % over #22)
#

# ee37bd976 = 3126b4b06 (the kernel above) + d1bdc378c (CIRQ matches the stock
# DTB's "mediatek,mt6735-sys_cirq", no oops if init fails) + 8d7fa28c5 (CIRQ
# ack_all) + 6d1f8ae7d (suspend/dpidle/sodi_pcm -ENODEV instead of oopsing) +
# ee37bd976 (forge_spm_lowpower=0: suspend, dpidle and SODI gated, PCM still

# b614f727 (kernel section byte-identical to this file); battery run without

#   md5      d38af51a61f59f1c26365c1fd2d666d4
#   sha256   1bf4133535b70ee78c3154e85a25969a9381c545d092cd2dc7e69af4f524399a

#            Wed Sep 30 22:41:05 MSK 2026
#   size     7 866 982 B
#

# 273f7f572 = ee37bd976 (the kernel above) + 9985d21f6 (interactive: the
# scheduler update_util hook restored, the governor re-evaluates on arm64) +
# 3efb3b7d2 (CPU_FREQ_STAT=y, time_in_state, as in boot 7ddcc672) + 0bf78ca2c
# (revert of the invented 1352 MHz OPP, top is 1248 MHz) + 273f7f572 (the two


# b614f727 base (ramdisk and cmdline byte-identical).
#   md5      4e5ca0ae9b606adf2ca1d0d3367511f9
#   sha256   c3aa689d5e13842f5d7317a8431fef89457347bb9254f2bc3ee70d7b9d16b794

#            Tue Oct 6 00:20:01 MSK 2026
#   size     7 868 712 B
#

# (forge_m5c_bootguard: BCB boot-recovery in para from late_initcall until


#   md5      8bc44499567c1eaa59cd8f536ab21378
#   sha256   f456359a711d13c064f35b3de5a4f419ba44b77570394102ef83a4724db3d5a8

#            Tue Oct 6 00:35:05 MSK 2026
#   size     7 869 612 B
#

# (front S5K5E8 rail report, behaviour unchanged by default) + d309b7122 (no
# early-suspend OPP pin while the SPM low-power gate is closed: screen-off CPU

# boot 81787eff.
#   md5      1f2f47ee128a1735f02e04b55c91f7f8
#   sha256   d16c21f2e86a15dc46800425f686a396b27caf11267900faaf4f1e99920e09fa

#            Tue Oct 6 01:17:48 MSK 2026
#   size     7870225 B
#

# (forge_rel_defer = 0: layer buffers released at the config latch as in
# stock; the deferral to the next RDMA0 frame-done held Settings at ~50 %
# janky frames, P50 61 ms -> 3.5-5.4 %, 22 ms in the A/B of set 33).

#   md5      e2c70304261a4ff55af59f4a630926be
#   sha256   66013ed2f3e3cb155d44e34c298385469d07002fdf1b6e136a47cd50a7fb7de6

#            Tue Oct 6 11:33:10 MSK 2026
#   size     7870248 B
#

# = kernel E + c2c7849f4 (front S5K5E8 probed at i2c write id 0x30, as every


#   md5      b5f9809dc45b65b0f9f93eb1d22503af
#   sha256   5dec73cca447b4b86a6b9e4f3d051783ede094c61f89adb3817012d7c87e2d6b

#            Tue Oct 6 11:36:22 MSK 2026
#   size     7870253 B
#

# F + G/H/J + 60bd72060 (CMDQ legacy event map, SPM WDT test param, main-pass




#   md5      39d6457a46c823b5ddbd7b85a7311fce
#   sha256   4c7428ae4cb7be5e69ff78e7bf3f8a1925e5fbbe37c6a1e32b9d058b6abfb926

#            Tue Oct 6 18:21:53 MSK 2026
#   size     7871482 B
#



#   base      54bd7024fd0c7752c79a6559e05089df580c14ae  ("cmdq: p51 — runtime
#             race amplifier", branch pie-disp) — the exact commit the #22
#             kernel above was built from, NOT subsys49/HEAD.
#   defconfig arch/arm64/configs/m5c_a13_defconfig (new; savedefconfig of the
#             built .config, round-trip verified byte-for-byte).  NOTE: the old
#             committed m5c_defconfig does NOT reproduce #22 — the shipping
#             config lived only in the piedisp worktree .config (configfs USB
#             gadget, MTK_STK3X1X, I2C_CHARDEV, LMK, PM_AUTOSLEEP).  Building
#             from m5c_defconfig would silently regress adb and sensors.

#             aarch64-linux-android-4.9  (__VERSION__ "4.9 20150123
#             (prerelease)" — matches the #22 banner; the los20 prebuilts copy
#             reports "4.9.x 20150123" and is therefore NOT the one used)
#   recipe    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- \

#             then gzip -n -9 -c Image > Image.gz
#             then cat Image.gz <stock dtb 69 427 B> > Image.gz-dtb
#             (tools/los16_repack_boot_kernel.sh of the 14.1 tree, same steps)

#             (Image, Image.gz-dtb, config, System.map, vmlinux, build logs,
#              SHA256SUMS.txt)

#

# SHIPPED FILE, not on a build directory):
#   CONFIG_CPUSETS=y          CONFIG_BLK_CGROUP=y      CONFIG_BPF_JIT=y
#   CONFIG_PSI=y              # CONFIG_PSI_DEFAULT_DISABLED is not set
#   CONFIG_TMPFS_XATTR=y      CONFIG_TMPFS_POSIX_ACL=y CONFIG_VETH=y
#   CONFIG_UNIX_DIAG=y        CONFIG_NETLINK_DIAG=y    CONFIG_PACKET_DIAG=y
# CPUSETS and BPF_JIT were already =y in #22; the other eight are new.  The
# full diff of the two embedded configs is exactly these lines plus four
# kconfig-derived ones (DEBUG_BLK_CGROUP=n, CGROUP_WRITEBACK=y,
# BLK_DEV_THROTTLING=n, CFQ_GROUP_IOSCHED=n).  No source change, no backport.
#

# sha256 61e3f822..., the one every A13 set since has been flashed with;

#

#   strings Image.gz-dtb | grep -c mt6735m-mmc  == 2   (stock DTB present)
#   strings Image.gz-dtb | grep -c mediatek,msdc == 0   (tree DTB absent)
# Project rule: the 4.9 kernel runs with the STOCK DTB byte-for-byte.  The
# tree-built DTB spells the eMMC node "mediatek,msdc" while the driver binds
# "mediatek,mt6735m-mmc"; shipping it bricks storage (conn49 lesson,

#
# Empty TARGET_KERNEL_SOURCE keeps vendor/lineage/build/tasks/kernel.mk on its
# prebuilt branch (kernel.mk:127-148: no kernel source + TARGET_PREBUILT_KERNEL
# set -> FULL_KERNEL_BUILD := false).  It prints a "prebuilt kernel is
# DEPRECATED" warning; that is expected and is not an error.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE :=
TARGET_KERNEL_CONFIG :=
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt-kernel/Image.gz-dtb
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

# Freshness gate on the hand-placed prebuilt (carried from the LOS 16 tree).

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
# find fstab.mt6735 — the same lesson as the m681 port.  No androidboot.selinux:
# the runtime is enforcing (SELinux block below).
# buildvariant= is appended by build/make automatically — do not set it here.
# The boot.img of the m5c is repacked from a base image (meizu-fleet
# cloud-los16/m5c-cloud/repack_boot.py), whose own cmdline must match this one.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.hardware=mt6735

# ---------------------------------------------------------------------------
# Partitions — A-only, no slots, no dynamic partitions
# ---------------------------------------------------------------------------


#   p6 para   p7 boot   p8 recovery  p10 expdb  p17 custom (/vendor)
#   p19 nvdata  p22 metadata  p23 system  p24 cache  p25 userdata

# 16 MiB, recovery 32 MiB, custom 512 MiB, system 2560 MiB (0xa0000000),
# cache 400 MiB.
#
# The system image limit is 1936 MiB (the fleet's "variant B" size, the one
# the zip installer checks), which fits the stock 2560 MiB partition with room
# to spare.  cache is not mounted (no fstab line): Android 13 keeps OTA state
# in /data/ota.  The 1.50 GiB of the 14.1 tree was that tree's image size,
# not the partition size.
BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2030043136
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12831948800
BOARD_FLASH_BLOCK_SIZE := 131072

TARGET_USERIMAGES_USE_EXT4 := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4

# A-only.  fastboot writes NOTHING on this device: all three of boot, recovery
# and para answer "format for partition 'X' is not allowed" while the Sending

# TWRP + dd over by-name only.
AB_OTA_UPDATER := false
BOARD_USES_RECOVERY_AS_BOOT := false

# No system_ext / product partitions on this GPT — fold them into /system.
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
TARGET_COPY_OUT_PRODUCT := system/product

# ---------------------------------------------------------------------------
# Vendor partition / VNDK — the one real design decision in this file
# ---------------------------------------------------------------------------
# The brief said "there is no vendor partition, the blobs live in
# /system/vendor".  That was true of LOS 14.1 and is NO LONGER TRUE.
#

# which LineageOS 14.1 never mounts and which holds ~73 MiB of leftover Flyme



# device: "/vendor — реальный раздел (/dev/block/mmcblk0p17 on /vendor type



# 512 MiB with room to spare.
# INFERENCE: moving those 212 MiB off /system is also the single biggest lever
# available for fitting Android 13 into a 1.50 GiB /system — see the report.
# Decision: real /vendor on custom(p17).
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912

# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# WAS: VNDK off, PRODUCT_FULL_TREBLE_OVERRIDE := false, on the argument that
# 134 of 403 vendor ELFs link framework-only libraries (M5C_LOS16_TREBLE_PLAN.md


# vendor namespace cannot reach — but "unreachable" turned out to be wrong:
# m95 runs the same generation of N-era MTK blobs in a VNDK namespace on this
# same platform tree (vendor copies, forwarders and shims, lessons 5-8 of
# designs/FLEET_PORT_FROM_M95_20260924.md).  device.mk carries the m5c half.
#

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
# 2017 Meizu LK does neither: it always loads the boot.img ramdisk, and

# OKAY", the phone stays in fastboot), so the cmdline cannot be changed from
# the host either.  Android 13 init handles this the normal non-A/B way: the
# boot ramdisk carries first-stage init plus fstab.mt6735, DoFirstStageMount()
# mounts /system and /vendor and SwitchRoot()s into /system
# (first_stage_init.cpp:388-401 only uses /first_stage_ramdisk with


# system and vendor.
BOARD_ROOT_EXTRA_FOLDERS := nvdata protect_f protect_s

# /metadata mount point on the system root (system/core/rootdir/Android.mk:116-118).

# (first_stage_mount,formattable), but without this flag the system image has
# no /metadata directory.  First stage switches root to /system BEFORE it
# mounts the other partitions (first_stage_mount.cpp:529-568), so the mount
# fails (formattable -> ignored); in the second stage mount_all fails it again,
# returns FS_MGR_MNTALL_FAIL, ro.crypto.state is never set and zygote-start
# never fires.
BOARD_USES_METADATA_PARTITION := true

# RIL: the MTK Oreo HIDL libril + rild of ril/ (IRadio 1.0, drives mtk-ril.so
# through RIL_InitSocket — the m5c blob has no RIL_Init, so hardware/ril's
# libril/rild cannot host it).  These two switch hardware/ril's modules off
# (hardware/ril/libril/Android.mk:3, hardware/ril/rild/Android.mk:1) and ours

BOARD_PROVIDES_LIBRIL := true
ENABLE_VENDOR_RIL_SERVICE := true

# ForgeImsService (vendor/forge/ims Android.mk) speaks to a Marshmallow vendor
# here: the stock Flyme 6.0.2.4G librilmtk / mtk-ril.so behind rild-ims, whose
# IMS request and URC numbers are not the Nougat ones of the m95, and the M
# libwfo_jni with its own JNI table.  meizu-fleet

FORGE_IMS_VENDOR_GEN := m

# ...and the SELinux labels for exactly those three directories.  Without them
# e2fsdroid aborts while configuring system.img:
#   set_selinux_xattr: No such file or directory searching for label "/nvdata"
# because system/sepolicy/private/file_contexts has no catch-all entry and
# every root-level directory must be labelled explicitly.  Full derivation and
# the rejected alternatives are in sepolicy/vendor/file_contexts itself.



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

# set 35 + kernel S left no denial from a real domain, and a live
# `setenforce 1` over every component scenario (tools/m5c-sepolicy/census.sh)
# left three functionally harmless ones, now dontaudit (kernel.te,
# dontaudit.te); meizu-fleet designs/M5C_A13_COMPONENT_COVERAGE_20261005.md

# its key in /data/misc/adb/adb_keys; after a /data wipe the owner confirms
# the key on the screen once.
# The build enforces the neverallows (SELINUX_IGNORE_NEVERALLOWS is not set):
# neverallow checks, sepolicy_test and the treble tests pass.

# ---------------------------------------------------------------------------
# Wi-Fi — MTK CONSYS MT6735 combo
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# VINTF
# ---------------------------------------------------------------------------
# Wi-Fi is the one HAL that asks the manifest directly: HalDeviceManager
# decides a vendor HAL exists iff getTransport(IWifi) != EMPTY.  With no
# manifest wlan0 is never created at all (measured on the live LOS 16 device

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
