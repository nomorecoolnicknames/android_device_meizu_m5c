# Meizu M5c (m5c)

Device tree for the Meizu M5c for LineageOS 18.1 (Android 11).

## Specifications

| | |
|---|---|
| Codename | m5c (M710H) |
| SoC | MediaTek MT6737M |
| CPU | 4x Cortex-A53 |
| GPU | Mali-T720 |
| RAM | 2 GB |
| Display | 720x1280 |
| Kernel | 4.9 (prebuilt) |

## Status

- Untested: a complete ROM built from this branch has not been tested on the device.
- SELinux: permissive.

## Building

Sync the LineageOS 18.1 sources, then add:

- this tree as `device/meizu/m5c`;
- the vendor trees `vendor/meizu/m5c` and `vendor/mediatek`, with the patches from [patches/](patches/README.md);
- a prebuilt kernel at `prebuilt-kernel/Image.gz-dtb` that matches [EXPECTED.txt](prebuilt-kernel/EXPECTED.txt). The kernel is not included; the build stops if it is missing or different.

Then build:

```sh
source build/envsetup.sh
breakfast m5c
brunch m5c
```

Project overview: https://github.com/nomorecoolnicknames/remeizu
