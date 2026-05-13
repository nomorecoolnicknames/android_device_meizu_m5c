# Inherit core_64_bit first so core_minimal does not set ro.zygote=zygote32.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)
$(call inherit-product, device/meizu/m5c/device.mk)

DEVICE_PACKAGE_OVERLAYS += device/meizu/m5c/overlay

PRODUCT_NAME := lineage_m5c
PRODUCT_DEVICE := m5c
PRODUCT_BRAND := meizu
PRODUCT_MANUFACTURER := Meizu
PRODUCT_MODEL := m5c
PRODUCT_RELEASE_NAME := m5c
TARGET_OTA_ASSERT_DEVICE := m5c,m710h
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=lineage_m5c \
    PRODUCT_DEVICE=m5c \
    TARGET_DEVICE=m5c

# vendor/lineage does not derive LINEAGE_BUILD from TARGET_DEVICE.
LINEAGE_BUILD := m5c

# Shipped with Android 7.1 blobs. Real vendor partition without VNDK, see
# BoardConfig.mk.
PRODUCT_SHIPPING_API_LEVEL := 25
PRODUCT_FULL_TREBLE_OVERRIDE := false

# profman crashes with SIGBUS when compiling the boot image profile; the
# profile is only an optimisation.
PRODUCT_USE_PROFILE_FOR_BOOT_IMAGE := false

PRODUCT_GMS_CLIENTID_BASE := android-meizu

# ADB
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.secure=0 \
    ro.debuggable=1 \
    ro.adb.secure=0 \
    persist.sys.usb.config=adb \
    persist.service.adb.enable=1
