#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from m5c device
$(call inherit-product, device/meizu/m5c/device.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_m5c
PRODUCT_DEVICE := m5c
PRODUCT_BRAND := Meizu
PRODUCT_MANUFACTURER := Meizu
PRODUCT_MODEL := M5c

PRODUCT_GMS_CLIENTID_BASE := android-meizu

# 720x1280 panel -> 720p boot animation.
TARGET_BOOT_ANIMATION_RES := 720

# Device and product names in the generated build properties (the stock
# identity strings the blobs read, ro.mediatek.* / ro.product.flyme.model,
# are in vendor.prop).
PRODUCT_BUILD_PROP_OVERRIDES += \
    TARGET_DEVICE=m5c \
    PRODUCT_NAME=m5c
