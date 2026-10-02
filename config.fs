# fs_config overrides for lmi.
#
# libksud.so is bundled inside KernelSUNext.apk but is shipped separately via
# PRODUCT_COPY_FILES in device.mk (see the comment there), because a pre-baked
# /product/app install never gets its native libs extracted. The image-packaging
# step does not mirror the staging directory's host-fs permissions, so the +x
# bit has to be forced here explicitly.
#
# All four of mode/user/group/caps are required by fs_config_generator.py for a
# path section to be recognised -- caps alone being absent is enough for the
# section to be skipped as "Invalid section".
[product/app/KernelSUNext/lib/arm64/libksud.so]
mode: 0755
user: AID_ROOT
group: AID_ROOT
caps: 0
