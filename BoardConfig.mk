#
# Copyright (C) 2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from sm8250-common
include device/xiaomi/sm8250-common/BoardConfigCommon.mk

DEVICE_PATH := device/xiaomi/lmi

# Display
TARGET_SCREEN_DENSITY := 440

# Kernel
TARGET_KERNEL_CONFIG += vendor/xiaomi/lmi.config

# OTA assert
TARGET_OTA_ASSERT_DEVICE := lmi

# Properties
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# Inherit from the proprietary version
include vendor/xiaomi/lmi/BoardConfigVendor.mk

# Extra user apps sepolicy (see device.mk for the PRODUCT_PACKAGES wiring)
include device/xiaomi/lmi/extra-apps/sepolicy/Android.mk

# Export TARGET_KERNEL_SOURCE/KERNEL_ARCH/etc to Soong's lineageVarsPlugin
# namespace -- without this, vendor/lineage/build/soong/Android.bp's
# generated_kernel_includes/prebuilt_kernel_includes genrules fail Soong
# analysis entirely with "unknown variable" for every $(KERNEL_*)/
# $(TARGET_KERNEL_*) reference, even though nothing in this device's own
# build graph currently depends on those genrules.
-include vendor/lineage/config/BoardConfigSoong.mk
