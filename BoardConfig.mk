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

# This device tree never included the canonical vendor/lineage BoardConfig
# fragment that almost every other LineageOS device gets automatically -
# it's what sets TARGET_KERNEL_VERSION (BoardConfigKernel.mk, needed by
# vendor/lineage/build/tasks/kernel.mk's GKI_SUFFIX logic - its absence was
# a hard "Argument missing" kati error), exports KERNEL_*/TARGET_KERNEL_*
# to Soong's lineageVarsPlugin namespace (BoardConfigSoong.mk), and
# auto-adds hardware/qcom-caf/$(QCOM_HARDWARE_VARIANT)+bootctrl to
# PRODUCT_SOONG_NAMESPACES (BoardConfigQcom.mk, gated on
# BOARD_USES_QCOM_HARDWARE which sm8250-common already sets true). See
# lin23-lmi-lineage23-build-blockers memory for the full diagnosis.
include vendor/lineage/config/BoardConfigLineage.mk
