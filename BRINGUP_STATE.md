# Meizu M5c LOS 14.1 Build State

## 2026-05-17

FACT: Source device tree is `/srv/forge/android/android_device_meizu_m5c` at upstream `adcc71a` (`los-14.1`). README says build requires cloning device/vendor trees, running `. device/meizu/m5c/patches_mtk/apply-patches.sh`, then `lunch lineage_m5c-userdebug && mka bacon`.

FACT: Active build workspace is `/srv/forge/android/los14.1-m5c-patched`; Build Station build `61ebd5ee-cfc8-44e8-9910-be7b194959e3` failed at `/home/n8n/forge-work/rom-61ebd5ee-cfc8-44e8-9910-be7b194959e3/build.log` while compiling MTK audio patches. First fatal lines:
- `frameworks/av/services/audioflinger/AudioFlinger.cpp:65:10: fatal error: 'audio_mtk.h' file not found`
- `frameworks/av/services/audiopolicy/AudioPolicyInterface.h:26:10: fatal error: 'AudioCustomVolume.h' file not found`

FACT: Those headers exist in `device/meizu/m5c/include/`, but build command showed `-I /include`, proving `TARGET_SPECIFIC_HEADER_PATH := $(LOCAL_PATH)/include` expanded with empty `LOCAL_PATH` in product/board context.

PROPER-FIX: changed `TARGET_SPECIFIC_HEADER_PATH` to `$(DEVICE_PATH)/include` in:
- `device_m5c.mk`
- `board/gps.mk`

FACT: Build Station auto-fix attempt `139` proposed adding nonexistent `vendor/mediatek/proprietary/hardware/audio/common/include` and `hardware/mediatek/audio/common/include` paths. That was not applied because this tree stores these MTK compatibility headers under the device tree, not under a shared Mediatek vendor tree.

INFERENCE: The upstream `patches_mtk` set is not directly clean against the current LOS 14.1 base: `m5c_patch_apply.log` records rejects in `system/core/init/service.cpp`, `system/sepolicy/*.te`, `frameworks/av/camera/cameraserver.rc`, and `frameworks/native/include/ui/GraphicBuffer.h`. Many hunks still applied, so the tree can progress, but the author should know this patch set is not a clean one-command apply on the current base.

Next action: rerun the ROM recipe through Build Station API from parent failed build `61ebd5ee-cfc8-44e8-9910-be7b194959e3`; if audio headers pass, classify the next first fatal from the fresh build log.
