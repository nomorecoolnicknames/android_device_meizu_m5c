#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0

# Launch API level 23 (Marshmallow): with no level set, Android 13 OMXStore
# drops the MTK OMX components with codec roles.
$(call inherit-product, $(SRC_TARGET_DIR)/product/product_launched_with_m.mk)

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from m5c device
$(call inherit-product, device/meizu/m5c/device.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# IMS service (com.mediatek.ims), built for the Marshmallow vendor
# (FORGE_IMS_VENDOR_GEN in BoardConfig.mk). vendor/forge/ims must be a real
# directory: soong's finder skips symlinked directories.
ifeq ($(wildcard vendor/forge/ims/forge-ims.mk),)
  $(error m5c: vendor/forge/ims is missing; check out ForgeImsService (vendor/forge/ims) there)
endif
ifneq ($(shell readlink -f vendor/forge/ims),$(shell readlink -f .)/vendor/forge/ims)
  $(error m5c: vendor/forge/ims is or sits under a symlink; soong's finder skips symlinked directories, so ForgeImsService would silently vanish. Use a real clone)
endif
# Without the Marshmallow variant the IMS requests would be numbered for
# Nougat, which means different requests on this rild-ims.
ifeq ($(wildcard vendor/forge/ims/forge-src-m/com/mediatek/ims/ForgeVendorGen.java),)
  $(error m5c: vendor/forge/ims has no forge-src-m (Marshmallow vendor); use the ForgeImsService branch m5c-volte)
endif
$(call inherit-product, vendor/forge/ims/forge-ims.mk)

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
