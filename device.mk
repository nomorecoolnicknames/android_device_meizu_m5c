#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# device.mk — Meizu M5c (m5c, M710H) on LineageOS 20.0.
#
# Scope discipline: a package only appears below if the module name was
# verified to exist in THIS tree (grep for `name: "<module>"` over Android.bp /

# listed in the "Known gaps" block at the end.

LOCAL_PATH := device/meizu/m5c

# ---------------------------------------------------------------------------
# Soong namespaces (device-tree isolation)
#

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

# Vendor blobs.  The md_ctrl and hwcomposer blobs are DELIBERATELY absent from
# m5c-vendor-blobs.mk: each broke boot in its own way (FORTIFY crash loop ->
# WDT reboot; GameDetector abort -> black screen), and the display runs on
# forge_hwc, built from hwcomposer/.  Do not re-add them when regenerating.
$(call inherit-product-if-exists, vendor/meizu/m5c/m5c-vendor.mk)

# ---------------------------------------------------------------------------
# Full Treble: what the vendor namespace needs that Android 13 keeps on

#

# with every blob on /vendor, 137 vendor ELFs NEED at least one soname the
# vendor namespace cannot reach (27 distinct sonames).  The blocks below
# supply them: vendor builds of AOSP libraries, empty or forwarding stubs
# under the real sonames, and symbol shims the blobs are rewired to
# (treble/Android.bp; wiring: vendor/meizu/m5c treble-elf-wiring.txt).
# ---------------------------------------------------------------------------
# libstdc++ (bionic's small one): 29 blobs, among them the 32-bit Mali closure
# (libGLES_mali -> libvcodec_oal -> libmp4enc_sa/libvc1dec_sa/libvp8dec_sa) and
# akmd09911.  Neither LLNDK nor VNDK; bionic/libc/Android.bp keeps
# vendor_available, so this is the real vendor variant (same as m95).
PRODUCT_PACKAGES += \
    libstdc++.vendor

# Power HAL (power/): touch and launch boosts for the interactive governor.

PRODUCT_PACKAGES += \
    android.hardware.power-service.m5c

# Thermal HAL (thermal/): MTK zones mtktscpu/mtktsbattery/mtktsAP for the
# framework; set 32 had none ("HAL Ready: false").
PRODUCT_PACKAGES += \
    android.hardware.thermal@2.0-service.m5c

# FM radio app (packages/apps/FMRadio, JNI libfmjni over /dev/fm). The node,

# /dev/fm system:media 0660 fm_device, /proc/fm present); only the app was
# missing. Audio routing of the tuner through the Nougat HAL is unchecked.
PRODUCT_PACKAGES += \
    FMRadio

# libgui.so (VNDK-private in A13) -> forwarder onto libgui_vendor; lesson 6.
# libnativehelper.so (ART apex only) -> empty; 35 of its 39 consumers import
# nothing from it.  Both modules and the evidence: treble/Android.bp.
PRODUCT_PACKAGES += \
    libgui_vendor \
    libgui_m5c_fwd \
    libnativehelper_m5c_stub

# Symbol shims the blobs are wired to at build time (DT_NEEDED edits,
# vendor/meizu/m5c/treble-elf-wiring.txt): N-layout android::Region for Mali
# (instead of libui.so, which stays out of sphal), and in libm5cshim_legacy
# MTK xlog, android_memset16, __pthread_gettid, PermissionCache and the six
# RIL symbols (netutils ccmni/txq, cutils jstring).  CallStack comes from the
# VNDK-SP libutilscallstack, nothing to package.  Sources: treble/.
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

# Camera HAL closure: libandroid_runtime.so under its real name (system-only
# on A13), the N-API shims and the operator-new slack the camera blobs are
# rewired to, and LineageOS libsensor_vendor for the N sensor API.  Evidence:
# treble/Android.bp, camera section.
PRODUCT_PACKAGES += \
    libandroid_runtime_m5c_stub \
    libandroid_m5c_stub \
    libjnigraphics_m5c_stub \
    libm5cshim_camera \
    libm5cshim_newpad \
    libsensor_vendor

# libcamera_client.so: 26 camera blobs (camera.mt6737m, libcam.camadapter,
# libacdk, ...).  Lesson 7: frameworks/av branch meizu-legacy-vendor builds a
# vendor copy under the real stem (camera/Android.bp:133-134, 19de1ce65b).
# Unlike m5s/m2note, m5c's libsource.so imports neither of the two symbols

PRODUCT_PACKAGES += \
    libcamera_client_vendor

# vendor: true modules of AOSP that the audio HAL and the RIL chain NEED by
# their plain names (audio.primary.mt6737m: libtinyxml; mtk-ril / librilmtk /
# mtkrild: librilutils).  Without Treble the /system copies were visible; with
# it only a /vendor build is.
#
# libtinycompress (audio.primary.mt6737m NEEDs it too) is deliberately NOT
# here: its vendor variant needs generated_kernel_headers, i.e. a kernel


# file or directory").  The HAL's twelve compress_* calls go to
# libm5cshim_tinycompress (treble/tinycompress.cpp) instead; offload is not
# declared in the audio policy, so nothing real is lost.
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

# NVRAM service chain (m95 NVRAM lessons, file header), the scripts the vendor
# rc files start, and the SPM firmware loader.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.nvram.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.nvram.rc \
    $(LOCAL_PATH)/rootdir/m5c-bdaddr.sh:$(TARGET_COPY_OUT_VENDOR)/bin/m5c-bdaddr.sh \
    $(LOCAL_PATH)/rootdir/m5c-muxd.sh:$(TARGET_COPY_OUT_VENDOR)/bin/m5c-muxd.sh \
    $(LOCAL_PATH)/rootdir/m5c-spm.sh:$(TARGET_COPY_OUT_VENDOR)/bin/m5c-spm.sh \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.power.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.power.rc

# Hardware rc: mount_all, /data/nvram -> /nvdata, zram, the configfs adb
# gadget, and the ueventd rules.  Headers carry sources.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/hw/init.mt6735.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6735.rc \
    $(LOCAL_PATH)/rootdir/etc/init/hw/init.mt6735.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6735.usb.rc \
    $(LOCAL_PATH)/rootdir/etc/ueventd.mt6735.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc

# ---------------------------------------------------------------------------
# Input — device-verified set from the working 14.1 tree
# ---------------------------------------------------------------------------
# Touch is Goodix GT917D behind mtk-tpd / mtk-tpd-kpd, keys are mtk-kpd,

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
    $(LOCAL_PATH)/configs/audio/audio_param/AudioParamOptions.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_param/AudioParamOptions.xml

# Audio policy.  Android 13 reads only XML; with audio_policy.conf alone the


# is the stock conf (configs/audio/audio_policy.conf, kept as the source, not
# installed: no blob reads it) converted as on m95; the xi:include targets are
# COPIED next to it, not packaged — m95 device.mk explains why (the
# prebuilt_etc modules of the same names are dropped silently).
AUDIO_POLICY_CFG_DIR := frameworks/av/services/audiopolicy/config
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    $(AUDIO_POLICY_CFG_DIR)/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    $(AUDIO_POLICY_CFG_DIR)/surround_sound_configuration_5_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/surround_sound_configuration_5_0.xml

# Audio effects.  Without an audio_effects.xml under /odm/etc, /vendor/etc or

# /system/etc/audio_effects.conf, which a vendor domain may not read

# its libraries are the ones installed in /vendor/lib*/soundfx.
PRODUCT_COPY_FILES += \
    frameworks/av/media/libeffects/data/audio_effects.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.xml

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

# the passthrough registrar: it hw_get_module()s hwcomposer.$(ro.board.platform)
# = hwcomposer.mt6737m and wraps the HWC1.1 module through libhwc2on1adapter.
# hwcomposer.mt6737m itself is forge_hwc (hwcomposer/Android.bp, ported

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

# exists only as ELF32 here, the 64-bit AOSP binary could never load it.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-impl \
    android.hardware.bluetooth@1.1-service.m5c

# Sensors / lights / vibrator / memtrack: generic AOSP passthrough services
# over the legacy hw modules, looked up by ro.board.platform.  On A13 the

# node (census set 21); lights have not been checked beyond the backlight.
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

# mnld is started by init.m5c.gps.rc, and libcurl (NEEDed by mnld) gets its
# SSLv3 methods from libm5cshim_ssl (treble/ssl.cpp).  mtk_agpsd stays off.
PRODUCT_PACKAGES += \
    android.hardware.gnss@1.0-impl \
    android.hardware.gnss@1.0-service \
    gps.mt6737m \
    libm5cshim_ssl

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.gps.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.gps.rc

# Audio: the generic multi-version HIDL audio service.
PRODUCT_PACKAGES += \
    android.hardware.audio@2.0-service


# the loosest one Android 13 carries — lists audio, audio.effect, drm and

# manifest against the platform matrices (system of out-m95, same tree)
# returned rc=65 "HALs incompatible" naming exactly these four.  The same
# check gates OTA packaging, and at runtime Build.isBuildConsistent() fails.
#  * audio / audio.effect 6.0: the in-process impls under the service above,
#    same pair and version as m95 (A13's audio client speaks 4.0..7.1 only,

#    audio.primary.mt6737m is loaded through hardware/interfaces branch
#    meizu-legacy-kernel (a0acaebde, Nougat audio.h); its closure is stubbed
#    (treble/Android.bp, audio section).
#  * gatekeeper: the AOSP software service, as m95 — LockSettingsService
#    cannot live without an IGatekeeper (m95 18.1: system_server restarted
#    every ~2 min with none registered).  Ships its own VINTF fragment.
#  * drm: the clearkey 1.4 service, as m95.  Ships its own VINTF fragment.
PRODUCT_PACKAGES += \
    android.hardware.audio@6.0-impl \
    android.hardware.audio.effect@6.0-impl \
    android.hardware.gatekeeper@1.0-service.software \
    android.hardware.drm@1.4-service.clearkey

# Wi-Fi userspace (the vendor HAL service follows below).
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
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.modem.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.modem.rc \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.sensors.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.sensors.rc

# VoLTE AP stack (meizu-fleet designs/M5C_VOLTE_LOS20_20260930.md): the
# stock mtkmal and volte_* daemons are installed by vendor/meizu/m5c; the rc
# keeps mal-daemon off until persist.vendor.m5c.volte=1.  libnetd_client.so
# answers volte_stack's setNetworkForSocket (treble/netd_client.c).
# libm5cshim_nparcel serves the boxed Parcel of the 64-bit librilmtk
# (treble/nparcel.cpp).  libm5cshim_jnihelp answers libwfo_jni's one
# libnativehelper call (treble/jnihelp.cpp).
PRODUCT_PACKAGES += \
    libm5cshim_jnihelp \
    libm5cshim_netd_client \
    libm5cshim_nparcel

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.volte.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.volte.rc

# VoLTE Java half (ForgeImsService, inherited in lineage_m5c.mk):
#  - android.hardware.telephony.ims: PhoneGlobals builds the ImsResolver only
#    when the feature is declared;
#  - the privapp allowlist of com.mediatek.ims: lineage-20 enforces it, and

#  - /vendor/etc/public.libraries.txt with libwfo_jni.so, the one vendor
#    library the app loads (the stock m5c vendor ships no such file).
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.ims.xml \
    $(LOCAL_PATH)/configs/permissions/privapp-permissions-com.mediatek.ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/privapp-permissions-com.mediatek.ims.xml \
    $(LOCAL_PATH)/configs/public.libraries-vendor.txt:$(TARGET_COPY_OUT_VENDOR)/etc/public.libraries.txt


# hardware/interfaces/wifi/1.6/default/Android.mk:96 (LineageOS keeps the
# Android.mk; the Android.bp there only has its srcs/defaults).  It links
# LIB_WIFI_HAL = libwifi-hal-mt66xx (frameworks/opt/net/wifi/libwifi_hal/
# Android.mk:123-125, BOARD_WLAN_DEVICE := MediaTek), a Make module that
# device/meizu/m95/wifi_hal/Android.mk already defines for the whole

# would be a duplicate module.  WMT/CONSYS start-up: init.m5c.connectivity.rc.
PRODUCT_PACKAGES += \
    android.hardware.wifi@1.0-service

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------
# sys.usb.configfs / sys.usb.controller / sys.usb.ffs.aio_compat are set by
# rootdir/etc/init/hw/init.mt6735.usb.rc: init.usb.rc resets
# sys.usb.configfs to 0 on init, so build.prop values for them were dead.
#
# Properties whose type vendor_init may not set go to the system build.prop
# (PRODUCT_SYSTEM_PROPERTIES): under enforcing a vendor build.prop line of
# that kind is dropped without a log line (tools/m5c-sepolicy/


# adb on debuggable builds: persist.sys.usb.config is system_prop.  User
# builds keep the platform default.
ifneq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.usb.config=adb
endif

# adb keeps the platform's key authentication (ro.adb.secure=1 on userdebug,
# vendor/lineage/config/common.mk).  The former bring-up override
# ro.adb.secure=0 went with the switch to enforcing: as a build_prop key in
# the vendor build.prop it is dropped under enforcing anyway (vprops_check.sh).
# The bench keeps adb through its key in /data/misc/adb/adb_keys (not in git);
# after a /data wipe the owner confirms the bench key on the screen once.

# Dexopt profile chosen for space, not speed: keep as much as possible out of
# /system, which is 1936 MiB here (BOARD_SYSTEMIMAGE_PARTITION_SIZE,
# BoardConfig.mk).
PRODUCT_SYSTEM_PROPERTIES += \
    pm.dexopt.first-boot=quicken \
    pm.dexopt.boot-after-ota=verify \
    pm.dexopt.install=speed-profile \
    pm.dexopt.bg-dexopt=speed-profile \
    pm.dexopt.ab-ota=speed-profile \
    pm.dexopt.inactive=verify \
    pm.dexopt.shared=speed

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# - SELinux: full vendor policy, 0 system/vendor denials in the permissive

# - Camera: HAL3 opens and delivers two frames, then the 4.9 kernel ISP/MDP
#   path stalls - kernel lane (debug.camera.force_device in vendor.prop).
# - Microphone: startInput failed with -22 up to set 23; the fix is in
#   hardware/interfaces meizu-legacy-kernel 7ea68c4db, not yet checked on the
#   phone.
# - Deep sleep: needs the SPM firmware (vendor/meizu/m5c firmware/spm,
#   init.m5c.power.rc), not yet checked on the phone.
# - VoLTE: ForgeImsService (M numbering, FORGE_IMS_VENDOR_GEN) and the RIL IMS
#   channel (librilmtk boxed, IMS stubs gone) are in; the MAL and volte_*
#   daemons stay off until persist.vendor.m5c.volte=1.  None of it has run on

# - /data is not encrypted (fstab.mt6735).
# - mtk_agpsd (A-GPS) is not started; lib_driver_cmd_mt66xx is not wired
#   (plain nl80211; LOS 16 scanned and connected that way on this device).
# - Wi-Fi association, calls/SMS, FM, tethering, BT pairing and a GPS fix
#   have not been tested yet.
