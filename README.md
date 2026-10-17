# Meizu M5c (m5c)

Device tree for the Meizu M5c for LineageOS 20.0.

## Specifications

| | |
| --- | --- |
| SoC | MediaTek MT6737M |
| CPU / GPU | Cortex-A53 (arm64) / Mali |
| Display | 720 x 1280 |
| Kernel | Linux 4.9, `m5c_defconfig` |
| Codenames | m5c, M710H |

## Status

- Display and touch: working
- Cameras: rear and front take photos
- Mobile network: LTE data, SMS sending, USSD and outgoing calls working; SMS receiving and incoming calls untested
- VoLTE: off until the IMS stack starts on its own (with the IMS properties on and IMS not running, the MediaTek RIL blocks every request)
- Wi-Fi: scanning works; association untested. Bluetooth: turns on; pairing and audio untested
- Sensors (20 registered), Power HAL and thermal HAL: working; GPS fix untested
- Audio: output partially working, listening untested; microphone recording not working
- SELinux: enforcing in this tree, not yet validated on the device; deep suspend and battery life: not measured

## Building

```sh
repo init -u https://github.com/LineageOS/android.git -b lineage-20.0 --git-lfs
mkdir -p .repo/local_manifests
curl -L -o .repo/local_manifests/meizu_m5c.xml \
  https://raw.githubusercontent.com/nomorecoolnicknames/android_local_manifests_meizu/lineage-20.0/meizu_m5c.xml
repo sync -c
source build/envsetup.sh
breakfast m5c
brunch m5c
```

Also required:

- Vendor blobs: [android_vendor_meizu_m5c](https://github.com/nomorecoolnicknames/android_vendor_meizu_m5c) `lineage-20.0` at `vendor/meizu/m5c`.
- Kernel: [android_kernel_meizu_m5c](https://github.com/nomorecoolnicknames/android_kernel_meizu_m5c) `lineage-20.0` at `kernel/meizu/m5c`, built with `m5c_defconfig`.
  A boot image with this kernel was tested on the phone.
- Platform patches: `device/meizu/common` (android_device_meizu_common) applies them on `source build/envsetup.sh`.
- The IMS service (MtkImsService) will be provided by device/meizu/common/ims; until it is published the build stops with an error.

Restricted vendor libraries and firmware are separate inputs with their own licenses.

## License

Based on Android, CyanogenMod / LineageOS and MediaTek device support; contributors are retained in Git history.
Original copyright and license notices are kept.
