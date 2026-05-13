LOCAL_PATH := device/meizu/m5c

# Vendor blobs
# The md_ctrl and hwcomposer blobs are intentionally not shipped: they would
# shadow the modules built from source here and break boot.
$(call inherit-product-if-exists, vendor/meizu/m5c/m5c-vendor.mk)

PRODUCT_DEVICE := m5c

# Screen density
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xhdpi

# Dalvik heap (phone-xhdpi-2048 values)
PRODUCT_PROPERTY_OVERRIDES += \
    dalvik.vm.heapstartsize=8m \
    dalvik.vm.heapgrowthlimit=192m \
    dalvik.vm.heapsize=512m \
    dalvik.vm.heaptargetutilization=0.75 \
    dalvik.vm.heapminfree=512k \
    dalvik.vm.heapmaxfree=8m

# Kernel
# Copy the prebuilt kernel into the target-files "kernel" slot; avoid an empty
# ":kernel" rule when no prebuilt is set.
M5C_EFFECTIVE_KERNEL_PREBUILT := $(strip $(TARGET_PREBUILT_KERNEL))
ifneq ($(M5C_EFFECTIVE_KERNEL_PREBUILT),)
PRODUCT_COPY_FILES += \
    $(M5C_EFFECTIVE_KERNEL_PREBUILT):kernel
endif

# Ramdisk
# Nougat-era MTK init scripts; fstab mounts /vendor from the custom partition.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/fstab.mt6735:root/fstab.mt6735 \
    $(LOCAL_PATH)/rootdir/init.mt6735.rc:root/init.mt6735.rc \
    $(LOCAL_PATH)/rootdir/init.mt6735.usb.rc:root/init.mt6735.usb.rc \
    $(LOCAL_PATH)/rootdir/init.modem.rc:root/init.modem.rc \
    $(LOCAL_PATH)/rootdir/init.project.rc:root/init.project.rc \
    $(LOCAL_PATH)/rootdir/init.recovery.mt6735.rc:root/init.recovery.mt6735.rc \
    $(LOCAL_PATH)/rootdir/ueventd.mt6735.rc:root/ueventd.mt6735.rc \
    $(LOCAL_PATH)/rootdir/enableswap.sh:root/enableswap.sh

# Recovery also needs the fstab at its own path.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/fstab.mt6735:recovery/root/fstab.mt6735

# Keylayouts
# Touchscreen GT917D (mtk-tpd, mtk-tpd-kpd), keys (mtk-kpd), headset (ACCDET).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/keylayout/mtk-kpd.kl:system/usr/keylayout/mtk-kpd.kl \
    $(LOCAL_PATH)/keylayout/mtk-tpd.kl:system/usr/keylayout/mtk-tpd.kl \
    $(LOCAL_PATH)/keylayout/mtk-tpd-kpd.kl:system/usr/keylayout/mtk-tpd-kpd.kl \
    $(LOCAL_PATH)/keylayout/ACCDET.kl:system/usr/keylayout/ACCDET.kl

# Seccomp
# Required by the MTK OMX blobs; without it they die with SIGSYS.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/seccomp/mediacodec.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediacodec.policy

# Permissions
# The device has no fingerprint sensor, NFC or gyroscope.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/handheld_core_hardware.xml:system/etc/permissions/handheld_core_hardware.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:system/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:system/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:system/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:system/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.camera.xml:system/etc/permissions/android.hardware.camera.xml \
    frameworks/native/data/etc/android.hardware.camera.autofocus.xml:system/etc/permissions/android.hardware.camera.autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:system/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:system/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:system/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:system/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:system/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:system/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:system/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:system/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:system/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:system/etc/permissions/android.hardware.wifi.direct.xml

# HIDL
PRODUCT_PACKAGES += \
    hwservicemanager \
    vndservicemanager \
    servicemanager

# Graphics
# hwcomposer.mt6737m (HWC 1.1, see hwcomposer/) is loaded by the composer@2.1
# passthrough and wrapped by libhwc2on1adapter. Allocator and mapper wrap the
# gralloc.mt6737m blob.
PRODUCT_PACKAGES += \
    hwcomposer.mt6737m \
    android.hardware.graphics.composer@2.1-impl \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.mapper@2.0-impl \
    libhwc2on1adapter

# Keymaster
# Software keymaster; keystore aborts at boot without a keymaster HAL.
PRODUCT_PACKAGES += \
    android.hardware.keymaster@3.0-impl \
    android.hardware.keymaster@3.0-service

# Properties
# USB configfs props must be set from the start: the "on boot && property:"
# triggers fire only once. Without first-stage mount only /system/build.prop
# is loaded early, so these go into PRODUCT_PROPERTY_OVERRIDES. The zygote
# services themselves are declared in rootdir/forge-zygote.rc.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.zygote=zygote64_32 \
    sys.usb.configfs=1 \
    sys.usb.controller=musb-hdrc \
    persist.sys.usb.config=adb \
    sys.usb.ffs.aio_compat=1 \
    pm.dexopt.first-boot=quicken \
    pm.dexopt.boot=verify \
    pm.dexopt.install=speed-profile \
    pm.dexopt.bg-dexopt=speed-profile \
    pm.dexopt.ab-ota=speed-profile \
    pm.dexopt.inactive=verify \
    pm.dexopt.shared=speed

# Init
PRODUCT_COPY_FILES += \
    device/meizu/m5c/rootdir/forge-usb-gadget.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/forge-usb-gadget.rc \
    device/meizu/m5c/rootdir/forge-zygote.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/forge-zygote.rc \
    device/meizu/m5c/rootdir/forge-cpuset.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/forge-cpuset.rc

# Bluetooth
# The default HAL wraps the vendor libbt-vendor.so.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-impl

# libfs_mgr.so stub for nvram_daemon and mnld, and a net symbol for the MTK RIL.
PRODUCT_PACKAGES += \
    libfs_mgr_m5c_shim \
    libmtkshim_net

# GPS shims for mtk_agpsd and mnld. The TARGET_LD_SHIM_LIBS entries do
# nothing unless these are built.
PRODUCT_PACKAGES += \
    libmtkshim_icu \
    libmnld_shim

# Modem
PRODUCT_COPY_FILES += \
    device/meizu/m5c/rootdir/forge-modem.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/forge-modem.rc

# Operator names by MCC/MNC. The framework reads this from /system/etc.
# The other configs/ files are installed by forge-peripherals.mk.
PRODUCT_COPY_FILES += \
    device/meizu/m5c/configs/spn-conf.xml:system/etc/spn-conf.xml

# GNSS
# Legacy gps.h HAL behind the gnss@1.0 passthrough service.
PRODUCT_PACKAGES += \
    gps.mt6737m \
    android.hardware.gnss@1.0-impl \
    android.hardware.gnss@1.0-service

# Peripherals (Wi-Fi, sensors, lights, vibrator, camera, audio)
$(call inherit-product, device/meizu/m5c/forge-peripherals.mk)

# RIL
# Use the MTK rild and libril from vendor/mediatek/ril instead of the AOSP
# rild (see BoardConfig.mk). The stock librilmtk and mtk-ril blobs are
# modules in the vendor tree because the MTK libril links them by name.
ENABLE_VENDOR_RIL_SERVICE := true
PRODUCT_PACKAGES += \
    rild \
    librilmtk \
    mtk-ril

# Firmware
# /vendor/firmware -> etc/firmware symlink for the modem firmware.
PRODUCT_PACKAGES += \
    forge_vendor_firmware_link
