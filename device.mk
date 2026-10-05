#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/meizu/m5c

PRODUCT_SOONG_NAMESPACES += \
    device/meizu/m5c \
    vendor/meizu/m5c

# Vendor blobs.  The md_ctrl and hwcomposer blobs are DELIBERATELY absent from
# m5c-vendor-blobs.mk: each broke boot in its own way (FORTIFY crash loop ->
# WDT reboot; GameDetector abort -> black screen), and the display runs on
# forge_hwc, built from hwcomposer/.  Do not re-add them when regenerating.
$(call inherit-product-if-exists, vendor/meizu/m5c/m5c-vendor.mk)

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
# that branch adds (designs/FLEET_PORT_FROM_M95_20260924.md §3.7).
PRODUCT_PACKAGES += \
    libcamera_client_vendor

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

AUDIO_POLICY_CFG_DIR := frameworks/av/services/audiopolicy/config
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    $(AUDIO_POLICY_CFG_DIR)/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    $(AUDIO_POLICY_CFG_DIR)/surround_sound_configuration_5_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/surround_sound_configuration_5_0.xml

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

PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-impl \
    android.hardware.bluetooth@1.1-service.m5c

# Sensors / lights / vibrator / memtrack: generic AOSP passthrough services
# over the legacy hw modules, looked up by ro.board.platform.  On A13 the
# sensors report events (FACT, set 14) and the vibrator HAL drives its LED
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

PRODUCT_PACKAGES += \
    android.hardware.wifi@1.0-service


# adb on debuggable builds: persist.sys.usb.config is system_prop.  User
# builds keep the platform default.
ifneq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.usb.config=adb
endif

# TEMPORARY (bring-up): adb without key confirmation, so that the bench can
# reach the phone after /data is formatted.  Only effective in permissive
# mode: ro.adb.secure is build_prop, which vendor_init may not set, so under
# enforcing the platform's ro.adb.secure=1 stays (vprops_check.sh).  Remove
# together with the switch to enforcing, after the bench key is in
# /data/misc/adb/adb_keys.  Same override as m95 ("Bring-up: insecure ADB
# early").
ifneq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.adb.secure=0
endif

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
