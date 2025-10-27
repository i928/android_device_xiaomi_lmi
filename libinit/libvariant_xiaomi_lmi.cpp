/*
 * Copyright (C) 2021-2025 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <libvariant.h>

static const variant_info lmi_global_info = {
    .hwc_value = "",
    .sku_value = "std",

    .brand = "POCO",
    .device = "lmi",
    .marketname = "",
    .model = "POCO F2 Pro",
    .build_fingerprint = "POCO/lmi_global/lmi:12/RKQ1.211001.001/V14.0.1.0.SJKMIXM:user/release-keys",

    .nfc = true,
};

static const variant_info lmipro_info = {
    .hwc_value = "",
    .sku_value = "pro",

    .brand = "Redmi",
    .device = "lmipro",
    .marketname = "",
    .model = "Redmi K30 Pro Zoom Edition",
    .build_fingerprint = "Redmi/lmipro/lmipro:12/RKQ1.211001.001/V14.0.1.0.SJKMIXM:user/release-keys",

    .nfc = true,
};

static const variant_info lmi_info = {
    .hwc_value = "",
    .sku_value = "",

    .brand = "Redmi",
    .device = "lmi",
    .marketname = "",
    .model = "Redmi K30 Pro",
    .build_fingerprint = "Redmi/lmi/lmi:12/RKQ1.211001.001/V14.0.1.0.SJKMIXM:user/release-keys",

    .nfc = true,
};

const std::vector<variant_info> variants = {
    lmi_global_info,
    lmipro_info,
    lmi_info,
};
