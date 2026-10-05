#!/vendor/bin/sh
# Open /dev/spm once: the forge 4.9 kernel loads the SPM PCM code
# (/vendor/firmware/pcm_*_2.bin) on open of this node and cannot suspend
# without it (vendor/meizu/m5c/firmware/spm/README).  The same job as
# stock Flyme's /system/bin/spm_loader, which only opens /dev/spm.
# Runs as a service so that init is not blocked while the kernel's
# firmware fallback waits for ueventd.
exec 3< /dev/spm
