#
# Copyright (C) 2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Inherit from lmi device
$(call inherit-product, device/xiaomi/lmi/device.mk)

PRODUCT_NAME := lineage_lmi
PRODUCT_DEVICE := lmi
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_BRAND := POCO
PRODUCT_MODEL := POCO F2 Pro

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="lmi-user 12 RKQ1.211001.001 V14.0.1.0.SJKMIXM release-keys" \
    BuildFingerprint=Redmi/lmi/lmi:12/RKQ1.211001.001/V14.0.1.0.SJKMIXM:user/release-keys

# Boot animation
TARGET_SCREEN_HEIGHT := 2340
TARGET_SCREEN_WIDTH := 1080

# GApps: Evolution X ships its own, pulled in by common_full_phone.mk when
# WITH_GMS is true (the default). There is no vendor/gapps here; the LineageOS
# build inherits MindTheGapps at this point instead.
# Baked into the image either way, so all-EROFS stays safe: nothing is flashed
# into system/product post-install.
