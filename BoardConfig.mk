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

# PRODUCT_COPY_FILES of prebuilt ELF files: the native libs of preinstalled
# apps in extra-apps/jni-libs.mk (board-scoped; ignored if set in device.mk).
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
