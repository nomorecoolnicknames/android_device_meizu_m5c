#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# device.mk — Meizu M5c (m5c, M710H) on LineageOS 20.0.
#
# Scope discipline: a package only appears below if the module name was
# verified to exist in THIS tree (grep for `name: "<module>"` over Android.bp /
# `LOCAL_MODULE := <module>` over Android.mk, 2026-09-16).  Everything that
# LOS 16 shipped but Android 13 no longer provides is listed in the
# "NOT WIRED YET" block at the end with the reason, not silently dropped.

LOCAL_PATH := device/meizu/m5c

# ---------------------------------------------------------------------------
# Soong namespaces (device-tree isolation)
#
# FACT (measured 2026-09-16): Soong parses every Android.bp in the workspace
# for every product and has no TARGET_DEVICE guard, so a bp module declared in
# one device tree lands in installs-<product>.mk of ALL products — a plain
# `m nothing` for lineage_m5s carried 51 install-rule lines from
# device/meizu/m95 (27 modules), two of them colliding with real m5s blobs
# (vendor/lib{,64}/libperfservicenative.so, via the `stem:` of
# libm95shim_perfservice).  Modules of a namespace reach Make only for the
# products that list that namespace here
# (build/soong/cmd/soong_build/main.go:99-112 -> android/namespace.go:204 ->
# android/androidmk.go:919).  Each tree carries a root Android.bp with
# `soong_namespace {}`; this line is the other half of the pair.
# ---------------------------------------------------------------------------
PRODUCT_SOONG_NAMESPACES += \
    device/meizu/m5c \
    vendor/meizu/m5c

# Vendor blobs.  m5c-vendor-blobs.mk keeps its protective comments verbatim:
# the md_ctrl and hwcomposer blobs are DELIBERATELY absent there — each used to
# shadow a module this project builds from source (md_ctrl sources / forge_hwc)
# and each broke boot in its own way (FORTIFY crash loop -> WDT reboot;
# GameDetector abort -> black screen).  Do not re-add them when regenerating.
$(call inherit-product-if-exists, vendor/meizu/m5c/m5c-vendor.mk)

# ---------------------------------------------------------------------------
# Full Treble: what the vendor namespace needs that Android 13 keeps on
# /system (2026-09-25, meizu-fleet/designs/TREBLE_M5C_20260924.md §linkage).
#
# FACT (meizu-fleet/tools/m5c_treble_needed.py, VNDK 33 lists of this tree):
# with every blob on /vendor, 137 vendor ELFs NEED at least one soname the
# vendor namespace cannot reach (27 distinct sonames).  Covered here are the
# ones Android 13 already builds for /vendor or that need no symbols; the
# rest (libandroid, libandroid_runtime, libjnigraphics, libmedia,
# libpowermanager, libstagefright, libdrmframework, libicu*, libskia, ...)
# carry real N-era symbol imports and are the shim lane, listed in the design.
# ---------------------------------------------------------------------------
# libstdc++ (bionic's small one): 29 blobs, among them the 32-bit Mali closure
# (libGLES_mali -> libvcodec_oal -> libmp4enc_sa/libvc1dec_sa/libvp8dec_sa) and
# akmd09911.  Neither LLNDK nor VNDK; bionic/libc/Android.bp keeps
# vendor_available, so this is the real vendor variant (same as m95).
PRODUCT_PACKAGES += \
    libstdc++.vendor

# libgui.so (VNDK-private in A13) -> forwarder onto libgui_vendor; lesson 6.
# libnativehelper.so (ART apex only) -> empty; 35 of its 39 consumers import
# nothing from it.  Both modules and the evidence: treble/Android.bp.
PRODUCT_PACKAGES += \
    libgui_vendor \
    libgui_m5c_fwd \
    libnativehelper_m5c_stub

# Symbol shims the blobs are wired to at build time (DT_NEEDED edits,
# vendor/meizu/m5c/treble-elf-wiring.txt): N-layout android::Region for Mali
# (instead of libui.so, which stays out of sphal) and MTK xlog /
# android_memset16 / PermissionCache.  CallStack comes from the VNDK-SP
# libutilscallstack, nothing to package.  Sources: treble/.
PRODUCT_PACKAGES += \
    libm5cshim_region \
    libm5cshim_legacy

# Audio HAL closure: libmedia.so / libpowermanager.so under their real names
# (system-only on A13) and the tinycompress calls under a shim name the HAL is
# rewired to.  Evidence and reasons: treble/Android.bp, audio section.
PRODUCT_PACKAGES += \
    libmedia_m5c_stub \
    libpowermanager_m5c_stub \
    libm5cshim_tinycompress

# libcamera_client.so: 26 camera blobs (camera.mt6737m, libcam.camadapter,
# libacdk, ...).  Lesson 7: frameworks/av branch meizu-legacy-vendor builds a
# vendor copy under the real stem (camera/Android.bp:133-134, 19de1ce65b).
# Unlike m5s/m2note, m5c's libsource.so imports neither of the two symbols
# that branch adds (designs/FLEET_PORT_FROM_M95_20260924.md §3.7).
PRODUCT_PACKAGES += \
    libcamera_client_vendor

# vendor: true modules of AOSP that the audio HAL and the RIL chain NEED by
# their plain names (audio.primary.mt6737m: libtinyxml; mtk-ril / librilmtk /
# mtkrild: librilutils).  Without Treble the /system copies were visible; with
# it only a /vendor build is.
#
# libtinycompress (audio.primary.mt6737m NEEDs it too) is deliberately NOT
# here.  FACT (first image build of lineage-20-treble, 2026-09-25 06:45): its
# vendor variant depends on generated_kernel_headers (LineageOS
# extended_compress_format_defaults), whose genrule runs `make -C
# $(TARGET_KERNEL_SOURCE) headers_install` — and this tree ships a prebuilt
# kernel with an empty TARGET_KERNEL_SOURCE, so the build died with
# "make: *** O=.../generated_kernel_includes/gen: No such file or directory".
# It was the ONLY installed module in that position (build.ninja scan).
# Bringing it back needs what m95 did (device/meizu/m95/BoardConfig.mk:
# 94-128): TARGET_KERNEL_SOURCE -> a link to the 4.9 source,
# TARGET_FORCE_PREBUILT_KERNEL := true, and the kbuild fix of m95 kernel commit
# 3522613e, because the m5c 4.9 scripts/Makefile.host:97-98 has the same
# host-csingle rule without $(HOSTLDFLAGS).  Audio lane, together with the
# libmedia/libpowermanager shims audio.primary also needs.
# 2026-09-28: done without the kernel headers — the HAL's twelve compress_*
# calls go to libm5cshim_tinycompress (treble/tinycompress.cpp); offload is
# not declared in the audio policy, so nothing real is lost.
PRODUCT_PACKAGES += \
    libtinyxml \
    librilutils

# ---------------------------------------------------------------------------
# Screen: 720x1280 -> xhdpi
# ---------------------------------------------------------------------------
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xhdpi

PRODUCT_CHARACTERISTICS := nosdcard

DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# ---------------------------------------------------------------------------
# Dalvik / ART heap for a 720p, 2 GB RAM phone
# ---------------------------------------------------------------------------
# Set explicitly rather than via inherit-product-if-exists: on the m95 port a
# wrong inherit path silently left the 16 MB default growth limit and
# system_server OOM'd.
# (There is no phone-*-hwui-memory.mk in Android 13 — the hwui cache sizes moved
# into framework defaults — so only the dalvik-heap profile is inherited.)
$(call inherit-product, frameworks/native/build/phone-xhdpi-2048-dalvik-heap.mk)

# ---------------------------------------------------------------------------
# Kernel — prebuilt only (see BoardConfig.mk for provenance and the gate)
# ---------------------------------------------------------------------------
# target_files / bacon must not emit an empty ":kernel" rule.
M5C_EFFECTIVE_KERNEL_PREBUILT := $(strip $(TARGET_PREBUILT_KERNEL))
ifneq ($(M5C_EFFECTIVE_KERNEL_PREBUILT),)
PRODUCT_COPY_FILES += \
    $(M5C_EFFECTIVE_KERNEL_PREBUILT):kernel
endif

# ---------------------------------------------------------------------------
# Ramdisk / fstab
# ---------------------------------------------------------------------------
# A13 first-stage init reads /fstab.<androidboot.hardware> out of the boot
# ramdisk (it only switches into /first_stage_ramdisk when
# androidboot.force_normal_boot=1, which this bootloader never sets —
# system/core/init/first_stage_init.cpp:388-401).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6735:$(TARGET_COPY_OUT_RAMDISK)/fstab.mt6735 \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6735:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6735

# Init fragment with the m95 NVRAM lessons (see the file header for why it is
# safe to carry ahead of the rc lane — NOT WIRED YET below).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.nvram.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.nvram.rc \
    $(LOCAL_PATH)/rootdir/m5c-bdaddr.sh:$(TARGET_COPY_OUT_VENDOR)/bin/m5c-bdaddr.sh

# Minimum device rc for an observable first boot (item 7 of NOT WIRED YET,
# first part; flash-m5c 2026-09-28): mount_all, /data/nvram -> /nvdata, the
# configfs adb gadget, and the LOS 16 ueventd rules.  Headers carry sources.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/hw/init.mt6735.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6735.rc \
    $(LOCAL_PATH)/rootdir/etc/init/hw/init.mt6735.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6735.usb.rc \
    $(LOCAL_PATH)/rootdir/etc/ueventd.mt6735.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc

# ---------------------------------------------------------------------------
# Input — device-verified set from the working 14.1 tree
# ---------------------------------------------------------------------------
# Touch is Goodix GT917D behind mtk-tpd / mtk-tpd-kpd, keys are mtk-kpd,
# headset detection is ACCDET (FACT: M5C_CHIP_MAP.md, live sysfs).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/keylayout/mtk-kpd.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/mtk-kpd.kl \
    $(LOCAL_PATH)/configs/keylayout/mtk-tpd.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/mtk-tpd.kl \
    $(LOCAL_PATH)/configs/keylayout/mtk-tpd-kpd.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/mtk-tpd-kpd.kl \
    $(LOCAL_PATH)/configs/keylayout/ACCDET.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/ACCDET.kl

# ---------------------------------------------------------------------------
# Media / audio configs (MTK, carried from the working trees)
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(LOCAL_PATH)/configs/media_codecs_mediatek_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_mediatek_audio.xml \
    $(LOCAL_PATH)/configs/media_codecs_mediatek_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_mediatek_video.xml \
    $(LOCAL_PATH)/configs/media_codecs_performance.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_performance.xml \
    $(LOCAL_PATH)/configs/media_profiles.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml \
    $(LOCAL_PATH)/configs/mtk_omx_core.cfg:$(TARGET_COPY_OUT_VENDOR)/etc/mtk_omx_core.cfg \
    $(LOCAL_PATH)/configs/audio/audio_device.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_device.xml \
    $(LOCAL_PATH)/configs/audio/audio_em.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_em.xml \
    $(LOCAL_PATH)/configs/audio/audio_policy.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy.conf \
    $(LOCAL_PATH)/configs/audio/audio_param/AudioParamOptions.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_param/AudioParamOptions.xml

# Audio policy.  Android 13 reads only XML; with audio_policy.conf alone the
# policy fell back to setDefault() and had no output device (FACT, A13 boot
# 2026-09-28: "AudioSystem::listAudioPorts error -19" every 100 ms).  The file
# is the stock conf converted as on m95; the six xi:include targets are
# COPIED next to it, not packaged — m95 device.mk explains why (the
# prebuilt_etc modules of the same names are dropped silently).
AUDIO_POLICY_CFG_DIR := frameworks/av/services/audiopolicy/config
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/a2dp_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/a2dp_audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    $(AUDIO_POLICY_CFG_DIR)/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    $(AUDIO_POLICY_CFG_DIR)/surround_sound_configuration_5_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/surround_sound_configuration_5_0.xml

# Operator names by MCC/MNC for the status bar.  Read by the framework from
# /system/etc, not from vendor.  Without it the shade shows the raw PLMN.
# (Restored on LOS 16 from the 14.1 tree, md5 481b9ce7148a9b62d2fc0cbad8f6db03,
# byte-identical to what runs on the device.)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/spn-conf.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/spn-conf.xml

# MTK omx vendor seccomp policy.  m681 evidence: without it the omx service
# hits SIGSYS, crash_dump storms and the device OOM-bootloops.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/seccomp/mediacodec.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediacodec.policy

# ---------------------------------------------------------------------------
# Permissions — only hardware that exists AND works on this unit
# ---------------------------------------------------------------------------
# No fingerprint / NFC / gyroscope: the hardware is physically absent
# (component matrix 2026-09-03).
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/handheld_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.camera.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.xml \
    frameworks/native/data/etc/android.hardware.camera.autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml

# ---------------------------------------------------------------------------
# HIDL / HAL backbone
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    hwservicemanager \
    vndservicemanager

# Graphics.  surfaceflinger aborts with "failed to get hwcomposer service"
# without a composer (tombstone 2026-08-29 on LOS 16).  composer@2.1-service is
# the passthrough registrar: it hw_get_module()s hwcomposer.$(ro.board.platform)
# = hwcomposer.mt6737m and wraps the HWC1.1 module through libhwc2on1adapter.
# hwcomposer.mt6737m itself is forge_hwc (hwcomposer/Android.bp, ported
# 2026-09-28 from the 14.1 tree without source changes).
PRODUCT_PACKAGES += \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.mapper@2.0-impl \
    libhwc2on1adapter \
    hwcomposer.mt6737m

# Keystore.  Android 13 keystore2 needs a KeyMint (AIDL) instance or it aborts
# with "no viable keymaster device found".  The AOSP default at
# hardware/interfaces/security/keymint/aidl/default is a pure-SOFTWARE
# implementation (libpuresoftkeymasterdevice) — no TEE required, which matters
# because nothing on this device provides a trustlet we can talk to.
PRODUCT_PACKAGES += \
    android.hardware.security.keymint-service

# Bluetooth.  com.android.bluetooth aborts in hci_layer_android.cc
# (Check failed: btHci != nullptr) with no IBluetoothHci registered.  The AOSP
# 1.1 default service wraps the vendor libbt-vendor.so.
# 2026-09-28: the service is the 32-bit copy in bluetooth/ — libbt-vendor.so
# exists only as ELF32 here, the 64-bit AOSP binary could never load it.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-impl \
    android.hardware.bluetooth@1.1-service.m5c

# Sensors / lights / vibrator / memtrack / power: generic AOSP passthrough
# services over the legacy hw modules, looked up by ro.board.platform.
# Static measurement on the Pie image (blobsym.py, both ABIs) showed
# sensors.mt6737m, lights.mt6737m and vibrator.default have ZERO unresolved
# symbols, so the generic wrappers were enough there.  That measurement has NOT
# been repeated against A13 libraries — see the risk list in the report.
PRODUCT_PACKAGES += \
    android.hardware.sensors@1.0-impl \
    android.hardware.sensors@1.0-service \
    android.hardware.light@2.0-impl \
    android.hardware.light@2.0-service \
    android.hardware.vibrator@1.0-impl \
    android.hardware.vibrator@1.0-service \
    android.hardware.memtrack@1.0-impl \
    android.hardware.memtrack@1.0-service

# Health.  Android 13 system_server cannot start without an IHealth:
# HealthServiceWrapper.create() tries AIDL, then HIDL instance "default", and
# throws NoSuchElementException when neither exists (frameworks/base/services/
# core/java/com/android/server/health/HealthServiceWrapper.java:110-116,
# HealthServiceWrapperHidl.java:205-209); BatteryService dies with it.  The
# service ships its own VINTF fragment (hardware/interfaces/health/2.1/
# default/Android.bp:83).  The previous build of this tree installed no
# health service at all (out-m5c/.../vendor/bin/hw, 2026-09-17).  Same pair as
# m95 (device/meizu/m95/device.mk).
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-service

# Camera: camera.mt6737m.so is a HAL1 module; provider@2.4's default impl
# wraps it.  Both -impl and -service are required — the service binary is only
# the passthrough registrar (m681 lesson: provider crashloops on "Could not get
# passthrough implementation").  The torch path also runs through the provider.
PRODUCT_PACKAGES += \
    android.hardware.camera.provider@2.4-impl \
    android.hardware.camera.provider@2.4-service

# GNSS: the legacy gps.h HAL behind the AOSP gnss@1.0 passthrough service.
# Without it the daemons (mnld, mtk_agpsd) run but the framework has no IGnss.
# gps.mt6737m itself is built from the 14.1 sources and is NOT ported yet.
PRODUCT_PACKAGES += \
    android.hardware.gnss@1.0-impl \
    android.hardware.gnss@1.0-service

# Audio: the generic multi-version HIDL audio service.
PRODUCT_PACKAGES += \
    android.hardware.audio@2.0-service

# Treble / VINTF (2026-09-25).  The framework compatibility matrix at FCM 3 —
# the loosest one Android 13 carries — lists audio, audio.effect, drm and
# gatekeeper as REQUIRED.  FACT: checkvintf --check-compat of this tree's
# manifest against the platform matrices (system of out-m95, same tree)
# returned rc=65 "HALs incompatible" naming exactly these four.  The same
# check gates OTA packaging, and at runtime Build.isBuildConsistent() fails.
#  * audio / audio.effect 6.0: the in-process impls under the service above,
#    same pair and version as m95 (A13's audio client speaks 4.0..7.1 only,
#    frameworks/av/media/libaudiohal/FactoryHalHidl.cpp).  The legacy
#    audio.primary.mt6737m is loaded through hardware/interfaces branch
#    meizu-legacy-kernel (a0acaebde, Nougat audio.h).  NOTE: its closure is
#    not complete under Treble yet (libmedia, libpowermanager — shim lane);
#    the factory registers regardless, primary fails at openDevice.
#    2026-09-28: closure stubbed (treble/Android.bp, audio section).
#  * gatekeeper: the AOSP software service, as m95 — LockSettingsService
#    cannot live without an IGatekeeper (m95 18.1: system_server restarted
#    every ~2 min with none registered).  Ships its own VINTF fragment.
#  * drm: the clearkey 1.4 service, as m95.  Ships its own VINTF fragment.
PRODUCT_PACKAGES += \
    android.hardware.audio@6.0-impl \
    android.hardware.audio.effect@6.0-impl \
    android.hardware.gatekeeper@1.0-service.software \
    android.hardware.drm@1.4-service.clearkey

# Wi-Fi userspace.  NOTE: the vendor HAL SERVICE binary is missing, see below.
PRODUCT_PACKAGES += \
    wificond \
    wpa_supplicant \
    hostapd

# wpa_supplicant service with the AIDL interface name the A13 framework asks
# for (m95 lesson 161682f; nothing else in this image defines the service —
# see the header of that rc).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.wifi.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.wifi.rc \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.connectivity.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.connectivity.rc \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.modem.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.modem.rc

# Wi-Fi vendor HAL (2026-09-28).  The module IS in this tree:
# hardware/interfaces/wifi/1.6/default/Android.mk:96 (LineageOS keeps the
# Android.mk; the Android.bp there only has its srcs/defaults).  It links
# LIB_WIFI_HAL = libwifi-hal-mt66xx (frameworks/opt/net/wifi/libwifi_hal/
# Android.mk:123-125, BOARD_WLAN_DEVICE := MediaTek), a Make module that
# device/meizu/m95/wifi_hal/Android.mk already defines for the whole
# workspace (FACT: 79 references in build-lineage_m5c.ninja) — copying it here
# would be a duplicate module.  WMT/CONSYS start-up: init.m5c.connectivity.rc.
PRODUCT_PACKAGES += \
    android.hardware.wifi@1.0-service

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------
# HARD-WON FACT from the LOS 16 bring-up (2026-08-29) that still applies:
# on this device property_load_boot_defaults() runs before /vendor and /system
# are mounted, so /vendor/default.prop and /system/etc/prop.default are never
# read.  Anything that must exist at zygote-start time has to be in
# PRODUCT_PROPERTY_OVERRIDES (-> build.prop), not in the *DEFAULT* variants.
# ro.zygote in particular cannot come from ANY prop file: the import of
# init.${ro.zygote}.rc resolves while init.rc is being parsed.
PRODUCT_PROPERTY_OVERRIDES += \
    sys.usb.configfs=1 \
    sys.usb.controller=musb-hdrc \
    persist.sys.usb.config=adb \
    sys.usb.ffs.aio_compat=1

# Bring-up: adb without key confirmation (the screen is not wired yet, and a
# failed /data mount would also hide /data/misc/adb/adb_keys).  vendor
# build.prop is loaded after system's ro.adb.secure=1 and wins — the same
# override m95 boots with (device/meizu/m95/device.mk "Bring-up: insecure
# ADB early").  Remove once the display works.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.adb.secure=0

# Dexopt profile for a 2 GB / 1.5 GiB-system device: keep as much as possible
# out of /system.  See the partition-size section of the report — this is not
# a performance choice, it is a space choice.
PRODUCT_PROPERTY_OVERRIDES += \
    pm.dexopt.first-boot=quicken \
    pm.dexopt.boot-after-ota=verify \
    pm.dexopt.install=speed-profile \
    pm.dexopt.bg-dexopt=speed-profile \
    pm.dexopt.ab-ota=speed-profile \
    pm.dexopt.inactive=verify \
    pm.dexopt.shared=speed

# ---------------------------------------------------------------------------
# NOT WIRED YET — every item here is a known gap, with the reason
# ---------------------------------------------------------------------------
# 1. hwcomposer.mt6737m (forge_hwc).  1360 lines of HWC1.1 facade over the
#    native 4.9 mtk_disp_mgr ABI, living in the 14.1 tree at
#    device/meizu/m5c/hwcomposer/forge_hwc.c.  It is THE display path on this
#    device (the stock vendor hwcomposer blob hangs on 4.9).
#    DONE 2026-09-28 (flash-m5c): hwcomposer/Android.bp.  CORRECTION to the
#    earlier note here: forge_hwc is plain C and links only liblog/libdl
#    (14.1 Android.mk; NEEDED of the standalone build: libc, liblog, libdl,
#    libm) plus dlopen("libgralloc_extra.so") — no libui/libgui.
# 2. DONE 2026-09-28 (flash-m5c) — CORRECTION: the service module exists,
#    in hardware/interfaces/wifi/1.6/default/Android.mk:96 (the text below
#    only looked at Android.bp).  Kept for the record:
#    The Wi-Fi vendor HAL service.  In Android 13 there is NO standalone
#    `android.hardware.wifi@1.0-service` module any more: the srcs/defaults
#    exist in hardware/interfaces/wifi/1.6/default/Android.bp (lines 20, 25,
#    54, 77) but the only cc_binary using them is the cuttlefish apex
#    (device/google/cuttlefish/apex/com.google.cf.wifi_hwsim/Android.bp:33).
#    The device tree has to define its own binary.  Until then wlan0 cannot
#    come up — manifest.xml already declares IWifi, and a HAL declared but not
#    served hangs its client (the m681 light@2.0 lesson), so this is a real
#    blocker, not a cosmetic one.
# 3. libwifi-hal-mt66xx: DONE 2026-09-28 — device/meizu/m95/wifi_hal (global
#    Make module, see the Wi-Fi HAL block above).  lib_driver_cmd_mt66xx
#    (device/meizu/m95/wpa_supplicant_8_lib) is not wired: plain nl80211 is
#    enough to scan and connect (LOS 16 on this device did so).
#    Original note: lib_driver_cmd_mt66xx / libwifi-hal-mt66xx — come from vendor/mediatek,
#    which is not in this tree.  libwpa_client does not exist in A13 at all.
# 4. Telephony: WIRED 2026-09-28 (flash-m5c) the LOS 16 way — the MTK Oreo
#    HIDL libril + rild are now in this tree (ril/, BoardConfig
#    BOARD_PROVIDES_LIBRIL / ENABLE_VENDOR_RIL_SERVICE), the modem chain in
#    rootdir/etc/init/init.m5c.modem.rc, IRadio/ISap/IOemHook in manifest.xml.
#    Original note:
#    Telephony.  LOS 16 ran the MTK Oreo HIDL rild out of vendor/mediatek/ril
#    (BOARD_PROVIDES_LIBRIL + ENABLE_VENDOR_RIL_SERVICE).  That vendor/mediatek
#    tree is not present here, and A13 telephony expects IRadio 1.6 / AIDL.
#    FACT that still constrains any solution: the stock mtk-ril.so has no
#    RIL_Init (only RIL_InitSocket), so the AOSP rild can never host it.
# 5. The LD shim set (libshim_vcodec, libmtkshim_icu, libmnld_shim,
#    libshim_audio_m5c, libmtkshim_gui/ui, libfs_mgr_m5c_shim, libmtkshim_net).
#    TARGET_LD_SHIM_LIBS IS still supported on LOS 20
#    (vendor/lineage/config/BoardConfigSoong.mk:45,109 ->
#    vendor/lineage/build/soong/Android.bp:143-153 -> bionic linker_main.cpp:451),
#    so the mechanism survives; the shims themselves must be re-measured against
#    A13 bionic/libui/libgui before being declared, because the symbol sets they
#    patch are Pie symbol sets.
# 6. sepolicy.  Nothing is carried over.  The runtime is permissive via the
#    kernel cmdline, so this does not block a first boot, but it does block
#    anything beyond bring-up.
# 7. rootdir rc files (init.mt6735.rc, forge-usb-gadget.rc, forge-zygote.rc,
#    forge-cpuset.rc, forge-modem.rc, forge-connectivity.rc, ueventd).  The
#    LOS 16 set is Nougat-era init syntax with Pie patches; A13 init rejects
#    several of those constructs outright.  Porting them is its own lane.
#    Partly done 2026-09-28 (flash-m5c): hw/init.mt6735.rc (mount_all,
#    /data/nvram -> /nvdata), hw/init.mt6735.usb.rc (configfs adb gadget),
#    vendor ueventd.rc (LOS 16 rules).  Still open: modem, connectivity,
#    cpuset, bluetooth; forge-zygote.rc is NOT needed any more (with
#    first_stage_mount the stock init.${ro.zygote}.rc import works).
#    Carried ahead of that lane: rootdir/etc/init/init.m5c.wifi.rc
#    (wpa_supplicant with the AIDL interface; do not port a second
#    `service wpa_supplicant`) and rootdir/etc/init/init.m5c.nvram.rc (m95
#    NVRAM lessons, 2026-09-24).  When porting init.mt6735.rc, keep the
#    creation of /data/nvram (the 14.1/16 rc symlinks it to /nvdata) in hw/,
#    so it runs before that fragment, and start nvram_daemon no earlier than
#    class main.
