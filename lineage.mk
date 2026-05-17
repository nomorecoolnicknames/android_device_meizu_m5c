#
# Copyright (C) 2015-2016 The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Inherit some common dotOS stuff.
$(call inherit-product, vendor/cm/config/common_full_phone.mk)

# Inherit device configuration
$(call inherit-product, $(LOCAL_PATH)/device_m5c.mk)

# Device display
TARGET_SCREEN_HEIGHT := 1280
TARGET_SCREEN_WIDTH := 720

# Device identifier
PRODUCT_BRAND := meizu
PRODUCT_DEVICE := m5c
PRODUCT_MANUFACTURER := Meizu
PRODUCT_MODEL := Meizu M5c
PRODUCT_NAME := lineage_m5c
PRODUCT_RELEASE_NAME := m5c
PRODUCT_RESTRICT_VENDOR_FILES := false

# Build Station: target device identity override
PRODUCT_NAME := lineage_m5c
PRODUCT_DEVICE := m5c
PRODUCT_BRAND := meizu
PRODUCT_MANUFACTURER := Meizu
PRODUCT_MODEL := m5c
PRODUCT_RELEASE_NAME := m5c
TARGET_OTA_ASSERT_DEVICE := m5c
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=lineage_m5c \
    PRODUCT_DEVICE=m5c \
    TARGET_DEVICE=m5c
