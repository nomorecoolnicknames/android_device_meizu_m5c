#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# lineage_m5c.mk — product definition for the Meizu M5c (m5c, model M710H).
#
# SoC MT6737M, quad Cortex-A53 arm64, 2 GB RAM, 720x1280 (xhdpi), 16 GB eMMC.
# Runtime is the forge 4.9.188-m5c+ kernel (prebuilt, see BoardConfig.mk);
# LineageOS 16.0 boots to the shell on that kernel with 31/40 tracks live
# (FACT: <private-workspace>/m5c/los14.1-m5c-patched/device/meizu/m5c/
#  M5C_COMPONENT_MATRIX_20260903.md, edition 9).
#
# Deliberately NOT set here:
#   PRODUCT_SHIPPING_API_LEVEL.  Up to lineage-20-fleet it was left undefined
#   to keep PRODUCT_USE_VNDK false (build/make/core/config.mk:729-737).  On
#   lineage-20-treble (2026-09-25) Treble and VNDK are switched on explicitly
#   in BoardConfig.mk (PRODUCT_FULL_TREBLE_OVERRIDE, BOARD_VNDK_VERSION), so
#   the shipping level no longer gates them.  It stays unset because the
#   handset's launch API level is not recorded anywhere on disk (m95 sets 25
#   from its own 18.1 tree; there is no such source for m5c) — a guessed
#   ro.product.first_api_level would be worse than none.

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

# Stock fingerprint of the Flyme build these blobs came from.  Kept so that
# blob-side checks that sniff the fingerprint keep seeing what they expect.
# FACT: taken from the stock system.prop carried in the working 14.1 tree
# (device/meizu/m5c/system.prop: ro.mediatek.version.release=
# ZAL856_999A_V0_0_5_BSP_20170605, ro.product.flyme.model=m1710).
PRODUCT_BUILD_PROP_OVERRIDES += \
    TARGET_DEVICE=m5c \
    PRODUCT_NAME=m5c
