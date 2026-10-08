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

# KeyMint
# Software KeyMint, there is no usable TEE.
PRODUCT_PACKAGES += \
    android.hardware.security.keymint-service

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
