#!/vendor/bin/sh
# Open /dev/spm once: the kernel loads the SPM PCM code
# (/vendor/firmware/pcm_*_2.bin) on open of this node and cannot suspend
# without it. Same as the stock spm_loader.
exec 3< /dev/spm
