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

# KernelSU-Next manager baked into /product/app (ported from lin23 lmi):
# libksud.so is shipped via PRODUCT_COPY_FILES in device.mk. Force its +x bit
# (the copy rule uses a plain non-preserving cp, and the app execs the file);
# done via a stamp because $(PRODUCT_OUT) is not resolved yet in device.mk.
libksud_chmod_stamp := $(OUT_DIR)/libksud_chmod.stamp
$(libksud_chmod_stamp): $(PRODUCT_OUT)/$(TARGET_COPY_OUT_PRODUCT)/app/KernelSUNext/lib/arm64/libksud.so
	chmod 755 $<
	touch $@
droidcore: $(libksud_chmod_stamp)

# fs_config overrides: the only layer whose mode survives into the image.
# MUST be +=: BoardConfigCommon.mk already sets sm8250-common/config.fs, whose
# AID_VENDOR_* ids the QTI blobs need (:= broke host_init_verifier on lin23).
TARGET_FS_CONFIG_GEN += device/xiaomi/lmi/config.fs
