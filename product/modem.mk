# Modem control helper.
#
# The vendor blob bin/md_ctrl is built against an older
# android_fork_execvp_ext signature and dies on FORTIFY under N
# ("write: count > SSIZE_MAX" inside __write_chk), which init turns into a
# crash loop and the watchdog turns into a reboot. The device tree carries the
# MediaTek sources for the same helper, so build them instead; the blob is left
# out of m5c-vendor-blobs.mk.
PRODUCT_PACKAGES += \
    md_ctrl
