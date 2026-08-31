#
# Copyright (C) 2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Fingerprint
TARGET_HAS_UDFPS := true

# Inherit from sm8250-common
$(call inherit-product, device/xiaomi/sm8250-common/kona.mk)

# AAPT
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi

# Audio configs
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/audio/,$(TARGET_COPY_OUT_VENDOR)/etc)

# Boot animation
TARGET_SCREEN_HEIGHT := 2400
TARGET_SCREEN_WIDTH := 1080

# Camera
PRODUCT_PACKAGES += \
    libMegviiFacepp-0.5.2 \
    libmegface \
    libpiex_shim

# Camera motor
PRODUCT_PACKAGES += \
    vendor.xiaomi.hardware.motor@1.0-service.xml

PRODUCT_PACKAGES += \
    vendor.xiaomi.hardware.motor@1.0.vendor

# Init
$(call soong_config_set,xiaomi_kona,variant_lib,//$(LOCAL_PATH):libvariant_xiaomi_lmi)

# Overlays
PRODUCT_PACKAGES += \
    ApertureOverlayDevice \
    FrameworkResOverlayDevice \
    LineageSDKOverlayDevice \
    LineageSystemUIOverlayDevice \
    SystemUIOverlayDevice

# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.sensor.barometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.barometer.xml

# QDCM
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/qdcm/,$(TARGET_COPY_OUT_VENDOR)/etc)

# Shipping API level
PRODUCT_SHIPPING_API_LEVEL := 29

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    hardware/qcom-caf/wlan \
    hardware/qcom-caf/wlan/qcwcn \
    hardware/qcom-caf/sm8250 \
    hardware/qcom-caf/thermal \
    vendor/qcom/opensource/data-ipa-cfg-mgr-legacy-um

# sm8250-common/kona.mk (inherited above) assumes SoC-generic "kona"-suffixed
# vendor blob names, but lmi's own proprietary-files.txt dump uses
# device-specific "lmi"-suffixed names instead (audio.primary.lmi,
# liba2dpoffload_lmi - see vendor/xiaomi/lmi/Android.bp). Swap them.
PRODUCT_PACKAGES := $(filter-out audio.primary.kona liba2dpoffload,$(PRODUCT_PACKAGES))
PRODUCT_PACKAGES += \
    audio.primary.lmi \
    liba2dpoffload_lmi

# Inherit from vendor blobs
$(call inherit-product, vendor/xiaomi/lmi/lmi-vendor.mk)

# Extra user apps (same generator/layout as crosshatch's prebuilts/extra-apps,
# just rooted at device/xiaomi/lmi/extra-apps instead of prebuilts/extra-apps)
USER_APPS_BP := $(wildcard device/xiaomi/lmi/extra-apps/prebuilt/*.apk)
PRODUCT_PACKAGES += $(foreach apk,$(USER_APPS_BP),$(basename $(notdir $(apk))))
# .apks (bundletool APK Set, android_app_set modules) -- split-config apps like Gboard
USER_APP_SETS_BP := $(wildcard device/xiaomi/lmi/extra-apps/prebuilt/*.apks)
PRODUCT_PACKAGES += $(foreach apkset,$(USER_APP_SETS_BP),$(basename $(notdir $(apkset))))
# privapp-permissions-*.xml (prebuilt_etc modules) -- module name is the full
# filename including extension, unlike the .apk/.apks rules above.
USER_APP_PERMS_BP := $(wildcard device/xiaomi/lmi/extra-apps/prebuilt/privapp-permissions-*.xml)
PRODUCT_PACKAGES += $(foreach xml,$(USER_APP_PERMS_BP),$(notdir $(xml)))
