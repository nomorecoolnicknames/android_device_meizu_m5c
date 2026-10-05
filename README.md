# Meizu M5c · Android 13

Device configuration for **Meizu M5c (m5c, MT6737M)**. Branch: **`lineage-20-treble`**.

**Port status:** Android 13 boots on Linux 4.9, with working display, touch and ADB. Other subsystems are at different stages; see the table below.

Hardware observations are from the development port as of **2026-09-29**, The current source snapshot additionally includes the changes listed below; those source changes have not received a new complete physical acceptance pass. They are not a fresh test of this exact branch tip.

## Components

**Source / integration** describes what this tree provides; **working status** describes tests, not file presence. Unverified does not mean unsupported hardware.

| Subsystem | Implementation / source | Source / integration | Working status |
|---|---|---|---|
| Boot / partitions | [Board configuration](BoardConfig.mk); [Kernel checksum](prebuilt-kernel/EXPECTED.txt) | External `Image.gz-dtb` prebuilt required | Boot observed in the A13 development port |
| Display / composition | [MTK HWC](hwcomposer/forge_hwc.c) | HWC source; vendor gralloc/GPU libraries required | Display and UI working in the development port |
| GPU | [Graphics packages and ABI integration](device.mk) | Vendor Mali userspace; kernel GPU driver lives in the kernel tree | UI rendering observed; performance and stability not qualified |
| Touch / buttons | [Key layouts](configs/keylayout) | Kernel input driver plus Android layouts | Touch working in the development port |
| Wi-Fi | [MTK Wi-Fi integration](rootdir/etc/init/init.m5c.wifi.rc) | MTK transport / firmware and supplicant integration | Partial: scanning works; association and DHCP untested |
| Bluetooth | [HCI / vendor integration](bluetooth/bluetooth_hci.cc) | Custom service or vendor interface | Partial: adapter ON and address loaded; pairing/audio untested |
| Mobile network | [RIL service](ril/libril/ril_service.cpp) | RIL integration; proprietary modem firmware remains required | Partial: LTE registered and data context connected; traffic, calls and SMS untested |
| Camera | [Camera packages / wrapper](device.mk) | Legacy vendor camera HAL; no complete open camera driver stack | Not working: opening the device has not produced a verified usable image |
| Audio output / microphone | [Audio integration](configs/audio) | Vendor primary HAL with compatibility support | Partial: output frames observed; listening test pending. Microphone recording fails (`startInput -22`) |
| Sensors | [Sensor services and permissions](device.mk) | Vendor sensor HAL; declared sensors still need individual tests | Accelerometer events observed; other sensors need complete testing |
| GPS / GNSS | [GNSS integration](device.mk) | Legacy vendor GPS HAL | Provider registered; satellite fix untested |
| Power / charging / suspend | [Power and health integration](device.mk) | Android services plus board-specific kernel drivers | Screen off/on observed; deep suspend, charging and battery life untested |
| SELinux | [Security / boot settings](BoardConfig.mk) | Development configuration | Permissive; enforcing not validated |

## Building

The selected ROM kernel sources are on [m5c-4.9-a13-rom](https://github.com/nomorecoolnicknames/mtk-t-alps-release-q0-kernel-4.9-lc/tree/m5c-4.9-a13-rom), commit `b256a404e931f75e85a5debf9b2693b6a6fcffbf`. This is the ROM baseline; the newer `m5c-4.9-a13` work branch is a separate source selection.

Use a matching LineageOS 20.0 source checkout, with this tree at `device/meizu/m5c`. Required inputs:

- The matching vendor tree, firmware, board configuration files and platform compatibility changes. This repository alone is not a complete ROM checkout.
- A board-specific `prebuilt-kernel/Image.gz-dtb` matching [EXPECTED.txt](prebuilt-kernel/EXPECTED.txt). The kernel binary is not included; [the checksum check](tools/check_prebuilt_kernel.sh) rejects a missing or different input.

With those inputs in place, the product is:

```sh
source build/envsetup.sh
lunch lineage_m5c-userdebug
mka bacon
```

## Next steps

Rebuild the current source selection, complete camera and microphone support, then test Wi-Fi association, Bluetooth pairing, cellular traffic/calls, GPS fix and deep suspend. SELinux enforcing remains a separate milestone.

The [ReMeizu overview](https://github.com/nomorecoolnicknames/remeizu/blob/main/PROJECT_STATUS.md) tracks the whole device family; the [source index](https://github.com/nomorecoolnicknames/remeizu/blob/main/SOURCE_INDEX.md) links related device, common and kernel trees.

## Credits

Based on Android, CyanogenMod / LineageOS and MediaTek device support, with contributors retained in Git history. Keep the original copyright and license notices. Vendor firmware and libraries are separate inputs with their own licenses.

## Current source changes

The tree selects the source-built 4.9.188 kernel with CIRQ initialization fixes and guarded SPM low-power entry. Kernel identity is pinned in `prebuilt-kernel/EXPECTED.txt`; the binary remains an external input. Init uses ondemand with a 1248 MHz cap because interactive frequency scaling is not qualified on this kernel. Firmware loads from `/vendor/firmware`; SPM debug PCM nodes are restricted to root because reading them can panic the kernel. These are source changes, not evidence that suspend, charging, thermals or performance are complete.

The matching vendor tree also supplies restricted MediaTek GPS/RIL inputs and vendor libraries. Files marked confidential/proprietary remain separate; the public RIL and compatibility sources retain their original Android/MediaTek copyright and licensing notices.
