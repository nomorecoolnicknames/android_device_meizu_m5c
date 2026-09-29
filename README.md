# Meizu M5c · Android 7.1

Device configuration for **Meizu M5c (m5c, MT6737M)**. Branch: **`android-7.1-bringup`**.

Legacy Android 7.1 development sources. Hardware results have not been revalidated for this branch.

## Components

**Source / integration** describes what this tree provides; **working status** describes tests, not file presence. Unverified does not mean unsupported hardware.

| Subsystem | Implementation / source | Source / integration | Working status |
|---|---|---|---|
| Boot / kernel | [Boot layout and kernel input](board/kernel.mk) | `rootdir/kernel` prebuilt required | Not tested on this branch |
| Display / GPU | [Display configuration](board/display.mk); [HWC implementation](hwcomposer/forge_hwc.c) | Board integration; vendor GPU libraries required | Not tested on this branch |
| Touch / keys | [Input and init configuration](rootdir) | Kernel driver and key layout integration | Not tested on this branch |
| Wi-Fi | [Wi-Fi configuration](board/wifi.mk); [MTK combo loader](combo_loader) | Source and board configuration | Not tested on this branch |
| Bluetooth | [MTK Bluetooth support](bluetooth-mtk) | Source present; firmware required | Not tested on this branch |
| Mobile network | [RIL integration](ril); [Telephony configuration](board/telephony.mk) | RIL source plus external modem/vendor components | Not tested on this branch |
| Camera | [Camera configuration](board/camera.mk) | Vendor camera HAL required; no complete open camera stack | Not tested on this branch |
| Audio | [Audio configuration](board/audio.mk); [Audio support](audio) | Mixed source and vendor integration | Not tested on this branch |
| Sensors / lights | [Sensor configuration](board/sensors.mk); [Lights HAL](liblights) | Configuration and lights implementation | Not tested on this branch |
| GPS | [GPS support](gps) | Source present; device firmware/vendor inputs required | Not tested on this branch |
| Power / charging | [Power HAL](power); [Power configuration](board/power.mk) | Userspace source; kernel charging driver is separate | Not tested on this branch |
| FM radio | [FM integration](fmradio) | Source present | Reception untested; no FM transmitter claim |

## Building

Place the tree at `device/meizu/m5c` in the matching Android 7.1 source checkout. Supply the matching vendor tree, kernel prebuilt and required platform changes.

**Build blocker:** [AndroidProducts.mk](AndroidProducts.mk) selects `dot.mk`, which is absent. [lineage.mk](lineage.mk) defines `lineage_m5c`, but is not the selected product. Resolve that product mismatch before attempting a build; this branch is not currently a complete build recipe.

## Next steps

These legacy sources are retained for existing integrations and driver comparison. New Android 9, 11 and 13 work uses separate branches; hardware results do not automatically carry between them.

The [ReMeizu overview](https://github.com/nomorecoolnicknames/remeizu/blob/main/PROJECT_STATUS.md) tracks the whole device family; the [source index](https://github.com/nomorecoolnicknames/remeizu/blob/main/SOURCE_INDEX.md) links related device, common and kernel trees.

## Credits

Based on Android, CyanogenMod / LineageOS and MediaTek device support, with contributors retained in Git history. Keep the original copyright and license notices. Vendor firmware and libraries are separate inputs with their own licenses.

Original device and vendor trees: [dekompilyator](https://github.com/dekompilyator/android_device_meizu_m5c/tree/los-14.1). Thanks to XRed_CubeX, seluce, iodine71, olegsvs, danielhk, Zormax, xcore995, SRTK, nomorecoolnicknames and the other contributors credited in the original project.
