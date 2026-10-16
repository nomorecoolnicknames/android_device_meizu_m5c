#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/meizu/m5c

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    device/meizu/m5c \
    vendor/meizu/m5c

# Vendor blobs
# The md_ctrl and hwcomposer blobs must stay out of m5c-vendor-blobs.mk:
# both break boot. The display runs on hwcomposer/.
$(call inherit-product-if-exists, vendor/meizu/m5c/m5c-vendor.mk)

# Treble
# Vendor variants, stubs and shims for libraries the blobs need that
# Android 13 keeps on /system (see treble/Android.bp).

# libstdc++ for the Mali closure and akmd09911.
PRODUCT_PACKAGES += \
    libstdc++.vendor

# Power
PRODUCT_PACKAGES += \
    android.hardware.power-service.meizu
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/power/fleet_power.json:$(TARGET_COPY_OUT_VENDOR)/etc/power/fleet_power.json

# Thermal
PRODUCT_PACKAGES += \
    android.hardware.thermal@2.0-service.m5c

# libgui.so is VNDK-private: forward it to libgui_vendor.
# libnativehelper.so is provided as an empty stub.
PRODUCT_PACKAGES += \
    libgui_vendor \
    libgui_m5c_fwd \
    libnativehelper_m5c_stub

# Symbol shims the blobs are rewired to: N-layout android::Region for Mali,
# MTK xlog, android_memset16, __pthread_gettid, PermissionCache and RIL
# helpers.
PRODUCT_PACKAGES += \
    libm5cshim_region \
    libm5cshim_legacy

# Audio HAL dependencies
PRODUCT_PACKAGES += \
    libmedia_m5c_stub \
    libpowermanager_m5c_stub \
    libm5cshim_tinycompress

# AOSP vendor libraries the audio HAL and RIL need by their plain names.
# libtinycompress is not built: its vendor variant needs kernel headers.
# libm5cshim_tinycompress provides the compress_* calls instead.
PRODUCT_PACKAGES += \
    libtinyxml \
    librilutils

# Screen density
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xhdpi

PRODUCT_CHARACTERISTICS := nosdcard

DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# Dalvik heap
$(call inherit-product, frameworks/native/build/phone-xhdpi-2048-dalvik-heap.mk)

# Kernel
M5C_EFFECTIVE_KERNEL_PREBUILT := $(strip $(TARGET_PREBUILT_KERNEL))
ifneq ($(M5C_EFFECTIVE_KERNEL_PREBUILT),)
PRODUCT_COPY_FILES += \
    $(M5C_EFFECTIVE_KERNEL_PREBUILT):kernel
endif

# Ramdisk
# First stage init reads /fstab.<androidboot.hardware> from the boot ramdisk.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6735:$(TARGET_COPY_OUT_RAMDISK)/fstab.mt6735 \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6735:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6735

# NVRAM, helper scripts and SPM firmware loader
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.nvram.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.nvram.rc \
    $(LOCAL_PATH)/rootdir/m5c-bdaddr.sh:$(TARGET_COPY_OUT_VENDOR)/bin/m5c-bdaddr.sh \
    $(LOCAL_PATH)/rootdir/m5c-muxd.sh:$(TARGET_COPY_OUT_VENDOR)/bin/m5c-muxd.sh \
    $(LOCAL_PATH)/rootdir/m5c-spm.sh:$(TARGET_COPY_OUT_VENDOR)/bin/m5c-spm.sh \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.power.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.power.rc

# Init
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/hw/init.mt6735.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6735.rc \
    $(LOCAL_PATH)/rootdir/etc/init/hw/init.mt6735.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.mt6735.usb.rc \
    $(LOCAL_PATH)/rootdir/etc/ueventd.mt6735.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc

# Input
# Goodix GT917D touchscreen (mtk-tpd), mtk-kpd keys, ACCDET headset.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/keylayout/mtk-kpd.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/mtk-kpd.kl \
    $(LOCAL_PATH)/configs/keylayout/mtk-tpd.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/mtk-tpd.kl \
    $(LOCAL_PATH)/configs/keylayout/mtk-tpd-kpd.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/mtk-tpd-kpd.kl \
    $(LOCAL_PATH)/configs/keylayout/ACCDET.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/ACCDET.kl

# Media
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

# Audio policy
# Android 13 reads only the XML policy. The xi:include targets are copied,
# not packaged: their prebuilt_etc modules are dropped silently.
AUDIO_POLICY_CFG_DIR := frameworks/av/services/audiopolicy/config
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    $(AUDIO_POLICY_CFG_DIR)/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    $(AUDIO_POLICY_CFG_DIR)/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    $(AUDIO_POLICY_CFG_DIR)/surround_sound_configuration_5_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/surround_sound_configuration_5_0.xml

# Audio effects
# Without audio_effects.xml the effects factory falls back to
# /system/etc/audio_effects.conf, which a vendor domain may not read.
PRODUCT_COPY_FILES += \
    frameworks/av/media/libeffects/data/audio_effects.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.xml

# Operator names by MCC/MNC, read by the framework from /system/etc.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/spn-conf.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/spn-conf.xml

# MTK OMX seccomp policy, without it the OMX service crashes with SIGSYS.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/seccomp/mediacodec.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediacodec.policy

# Permissions
# No fingerprint, NFC or gyroscope hardware.
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

# HIDL
PRODUCT_PACKAGES += \
    hwservicemanager \
    vndservicemanager

# Graphics
# composer@2.1 wraps the HWC 1.1 hwcomposer.mt6737m (hwcomposer/) through
# libhwc2on1adapter.
PRODUCT_PACKAGES += \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.mapper@2.0-impl \
    libhwc2on1adapter \
    hwcomposer.mt6737m

# KeyMint
# Software KeyMint, there is no usable TEE.
PRODUCT_PACKAGES += \
    android.hardware.security.keymint-service

# Bluetooth
# 32-bit service: libbt-vendor.so exists only as ELF32.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-impl \
    android.hardware.bluetooth@1.1-service.m5c

# Sensors, lights, vibrator, memtrack
PRODUCT_PACKAGES += \
    android.hardware.sensors@1.0-impl \
    android.hardware.sensors@1.0-service \
    android.hardware.light@2.0-impl \
    android.hardware.light@2.0-service \
    android.hardware.vibrator@1.0-impl \
    android.hardware.vibrator@1.0-service \
    android.hardware.memtrack@1.0-impl \
    android.hardware.memtrack@1.0-service

# Health
# system_server cannot start without an IHealth service.
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-service

# Audio
PRODUCT_PACKAGES += \
    android.hardware.audio@2.0-service

# HALs required by the FCM level 3 compatibility matrix: audio, audio.effect,
# gatekeeper and drm. The legacy audio.primary.mt6737m is loaded through the
# 6.0 impl. LockSettingsService needs an IGatekeeper.
PRODUCT_PACKAGES += \
    android.hardware.audio@6.0-impl \
    android.hardware.audio.effect@6.0-impl \
    android.hardware.gatekeeper@1.0-service.software \
    android.hardware.drm@1.4-service.clearkey

# Wi-Fi
PRODUCT_PACKAGES += \
    wificond \
    wpa_supplicant \
    hostapd

# Wi-Fi, connectivity, modem and sensors init scripts
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.wifi.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.wifi.rc \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.connectivity.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.connectivity.rc \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.modem.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.modem.rc \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.sensors.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.sensors.rc

# VoLTE
# Stock mtkmal and volte_* daemons from vendor/meizu/m5c, plus shims for
# setNetworkForSocket, the 64-bit librilmtk Parcel and libwfo_jni.
PRODUCT_PACKAGES += \
    libm5cshim_jnihelp \
    libm5cshim_netd_client \
    libm5cshim_nparcel

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/init.m5c.volte.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m5c.volte.rc

# IMS
# The telephony.ims feature enables the ImsResolver, the privapp allowlist is
# enforced, and libwfo_jni.so must be a public vendor library.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.ims.xml \
    $(LOCAL_PATH)/configs/permissions/privapp-permissions-com.mediatek.ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/privapp-permissions-com.mediatek.ims.xml \
    $(LOCAL_PATH)/configs/public.libraries-vendor.txt:$(TARGET_COPY_OUT_VENDOR)/etc/public.libraries.txt

# Wi-Fi HAL (links libwifi-hal-mt66xx)
PRODUCT_PACKAGES += \
    android.hardware.wifi@1.0-service

# Properties
# Properties that vendor_init may not set go to the system build.prop.

# adb on debuggable builds
ifneq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.usb.config=adb
endif

# Dexopt profile chosen for space, not speed.
PRODUCT_SYSTEM_PROPERTIES += \
    pm.dexopt.first-boot=quicken \
    pm.dexopt.boot-after-ota=verify \
    pm.dexopt.install=speed-profile \
    pm.dexopt.bg-dexopt=speed-profile \
    pm.dexopt.ab-ota=speed-profile \
    pm.dexopt.inactive=verify \
    pm.dexopt.shared=speed
