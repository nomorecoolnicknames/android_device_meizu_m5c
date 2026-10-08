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
# (FACT: /srv/forge/android/m5c/los14.1-m5c-patched/device/meizu/m5c/
#  M5C_COMPONENT_MATRIX_20260903.md, edition 9).
#
# Launch API level: 23 (product_launched_with_m.mk, as m95 takes
# product_launched_with_n_mr1.mk).  FACT: the last stock firmware, Flyme
# 6.0.2.4G of 2019-04-03, is Android 6.0 (META-INF/build.prop of
# meizu-fleet/captures/m5c-stock-flyme-6.0.2.4G/update.zip:
# ro.build.version.sdk=23), and the vendor blobs are that Marshmallow
# generation.  Up to 2026-10-06 it was left unset (no recorded launch level);
# Android 13's OMXStore then took T and dropped every OMX component with a
# video or audio codec role (frameworks/av/media/libstagefright/omx/
# OMXStore.cpp:104-163): IOmx::listNodes came back empty on the phone ("omx
# common prefix: no nodes") although MtkOmxCore registered 33 components, so
# none of the MTK hardware codecs could be created and all media ran on the
# c2 software codecs.  Treble and VNDK stay switched on explicitly in
# BoardConfig.mk (PRODUCT_FULL_TREBLE_OVERRIDE, BOARD_VNDK_VERSION), so the
# level does not gate them (build/make/core/config.mk:668-737).  Other effects
# of a level below 29/30: base_vendor.mk adds configstore@1.1-service,
# vndservice and vndservicemanager (product_config.mk:484-487), and the common
# /product properties are skipped (sysprop.mk:411-414) - the same as m95.
$(call inherit-product, $(SRC_TARGET_DIR)/product/product_launched_with_m.mk)

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from m5c device
$(call inherit-product, device/meizu/m5c/device.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# VoLTE Java half: ForgeImsService (package com.mediatek.ims), the port of
# MediaTek's ImsService the m95 registers IMS with (repo meizu-fleet
# wt/forge_ims), built for this Marshmallow vendor by FORGE_IMS_VENDOR_GEN in
# BoardConfig.mk.  The wiring around it is in device.mk (feature, privapp
# allowlist, vendor public libraries) and overlay/ (config_ims_mmtel_package,
# APN ims, CarrierConfig).
#
# vendor/forge/ims must be a REAL directory: soong's finder skips symlinked
# directories (build/soong/finder/finder.go:1418), and with
# BUILD_BROKEN_MISSING_REQUIRED_MODULES the package would vanish without a
# word (same guard as lineage_m95.mk).
ifeq ($(wildcard vendor/forge/ims/forge-ims.mk),)
  $(error m5c: vendor/forge/ims is missing; clone meizu-fleet/wt/forge_ims there)
endif
ifneq ($(shell readlink -f vendor/forge/ims),$(shell readlink -f .)/vendor/forge/ims)
  $(error m5c: vendor/forge/ims is or sits under a symlink; soong's finder skips symlinked directories, so ForgeImsService would silently vanish. Use a real clone)
endif
# A forge_ims without the Marshmallow variant ignores FORGE_IMS_VENDOR_GEN and
# builds the Nougat numbering, whose requests are other requests on this
# rild-ims (2127 = SET_STK_UTK_MODE ...).  Refuse it.
ifeq ($(wildcard vendor/forge/ims/forge-src-m/com/mediatek/ims/ForgeVendorGen.java),)
  $(error m5c: vendor/forge/ims has no forge-src-m (Marshmallow vendor); use forge_ims branch m5c-volte, e.g. build-m5c-treble.sh with M5C_FORGE_IMS=meizu-fleet/wt/forge_ims_m5c)
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
