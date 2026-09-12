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

# Extra user apps sepolicy (see device.mk for the PRODUCT_PACKAGES wiring).
# extra-apps is untracked local content, so a fresh checkout of this branch does
# not have it and a hard include kills board_config.mk before lunch even runs.
# device.mk already wildcards the prebuilts themselves; guard this the same way.
include $(wildcard device/xiaomi/lmi/extra-apps/sepolicy/Android.mk)

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

# libksud.so is shipped via PRODUCT_COPY_FILES in device.mk (see the comment
# there). This flag is what actually permits an ELF binary through that
# mechanism; it is board-scoped and silently ignored if set from a product .mk.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Force the executable bit. PRODUCT_COPY_FILES' copy rule uses plain `cp`
# (no -p), which drops the source's +x regardless, and the app execs this file
# directly. Done via a stamp file because referencing $(PRODUCT_OUT) as a rule
# prerequisite from device.mk hits a "||PRODUCT-PATH-PH||" placeholder bug --
# PRODUCT_OUT is not fully resolved at product-config-parse time, whereas
# BoardConfig.mk runs later.
libksud_chmod_stamp := $(OUT_DIR)/libksud_chmod.stamp
$(libksud_chmod_stamp): $(PRODUCT_OUT)/$(TARGET_COPY_OUT_PRODUCT)/app/KernelSUNext/lib/arm64/libksud.so
	chmod 755 $<
	touch $@
droidcore: $(libksud_chmod_stamp)

# fs_config overrides -- this is the only layer whose permissions survive into
# the packaged image.
#
# MUST be += , not := . BoardConfigCommon.mk (included at the top of this file)
# already sets TARGET_FS_CONFIG_GEN to sm8250-common/config.fs, which defines 42
# sections including [AID_VENDOR_QTI_DIAG] and seven other AID_VENDOR_* ids that
# the QTI vendor blobs reference. Assigning with := discarded all of them and the
# build failed with:
#     host_init_verifier: .../imsdatadaemon.rc: 11: Unable to decode GID for
#     "vendor_qti_diag": getpwnam failed: No such file or directory
TARGET_FS_CONFIG_GEN += device/xiaomi/lmi/config.fs
