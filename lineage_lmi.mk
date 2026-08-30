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

# MindTheGapps (Android 16 / baklava) — baked in so all-EROFS is safe:
# nothing is flashed into system/product post-install.
$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)
