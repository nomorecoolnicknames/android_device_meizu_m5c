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
FACT: Build Station retry `bdfab955-d9bf-4fb7-a349-66b60a33f681` launched from parent `61ebd5ee-cfc8-44e8-9910-be7b194959e3` after commit `b8da68c` and is using `/home/n8n/forge-work/rom-bdfab955-d9bf-4fb7-a349-66b60a33f681/build.log`.
FACT: Retry `bdfab955-d9bf-4fb7-a349-66b60a33f681` passed the previous early MTK audio-header point and reached at least 19% (`/home/n8n/forge-work/rom-bdfab955-d9bf-4fb7-a349-66b60a33f681/build.log`, 2026-05-17 16:37 UTC); no `audio_mtk.h` or `AudioCustomVolume.h` fatal was present in the live log.
FACT: Retry `bdfab955-d9bf-4fb7-a349-66b60a33f681` failed at 88% in Settings resource generation. First fatal: `res/xml/device_info_settings.xml.orig:0: error: Resource entry device_info_settings is already defined`; original resource was `res/xml/device_info_settings.xml`. This was patch backup residue, not source logic.

PROPER-FIX: preserved the generated Settings `.orig` residues under `/srv/forge/android/los14.1-m5c-patched/m5c_patch_residue_20260517/packages_apps_Settings/` and removed them from scanned `packages/apps/Settings/res` / `src` paths. Build Station classifier returned no issues for this aapt failure, so this should be added to classifier coverage later.

Next action: retry from `bdfab955-d9bf-4fb7-a349-66b60a33f681`; expected result is passing Settings AAPT and reaching package/image stage.

FACT: Build Station retry `757caef9-3f7b-4548-af7a-9df97510d861` passed the previous Settings `.orig` resource blocker and failed at 96% while compiling `packages/apps/Snap` with Jack source level 1.7. Log path: `/home/n8n/forge-work/rom-757caef9-3f7b-4548-af7a-9df97510d861/build.log`.

FACT: First Snap fatal lines were Java 8 lambdas in `ScannerActivity.java` and `ScannerIntentHelper.java`, plus Java 7 captured-local errors for `context` and `enable`. Build Station `/api/builds/757caef9-3f7b-4548-af7a-9df97510d861/classify-log` returned `[]`, so this compiler pattern is not covered by the current rule classifier.

## Patch history

### 2026-05-17 Snap Java 7 compatibility (`packages/apps/Snap` commit `1092d7eacd8b`)

Category: PROPER-FIX

Hypothesis: Snap is built by LOS 14.1 Jack with `jack.java.source.version=1.7`, while this checkout contains Java 8 lambda syntax in QuickReader and one non-final local captured by an anonymous Runnable in PhotoModule. Rewriting those call sites to Java 7 anonymous listener classes should preserve behavior and let Snap compile.

Evidence: Build `757caef9-3f7b-4548-af7a-9df97510d861`, log `/home/n8n/forge-work/rom-757caef9-3f7b-4548-af7a-9df97510d861/build.log`, lines reporting `Lambda expressions are allowed only at source level 1.8 or above` for `ScannerActivity.java` and `ScannerIntentHelper.java`, plus `Cannot refer to the non-final local variable context/enable` for `ScannerIntentHelper.java` and `PhotoModule.java`.

Files changed: `quickReader/src/org/lineageos/quickreader/ScannerActivity.java` converts click/dialog lambdas to anonymous Java 7 listeners; `quickReader/src/org/lineageos/quickreader/ScannerIntentHelper.java` converts dialog lambdas and marks captured `Context` final; `src/com/android/camera/PhotoModule.java` marks the Auto HDR `enable` local final for the existing Runnable.

Why each file changed: each edited file was named by the first failing Snap compile log and each edit removes only the Java 8/source-1.7 incompatibility, without disabling Snap or changing product packages.

Expected next marker: retry build should pass the Snap Jack compile step and continue beyond the previous 96% failure toward package/image creation.

Rollback condition: revert `1092d7eacd8b` if Snap compiles but QuickReader scanner actions or permission dialogs no longer dispatch the same runtime actions.

Verification commands: `git -C /srv/forge/android/los14.1-m5c-patched/packages/apps/Snap diff --check HEAD~1..HEAD`; `grep -n 'ScannerActivity.java\|ScannerIntentHelper.java\|PhotoModule.java\|Lambda expressions\|Cannot refer to the non-final' /home/n8n/forge-work/rom-<retry>/build.log`.

Next action: retry from Build Station build `757caef9-3f7b-4548-af7a-9df97510d861`; if Snap passes, continue with the next first fatal until a ROM artifact exists.
FACT: Build Station retry `7d96d74c-e3d0-4a6b-8f6b-52cfe7c58f07` was queued from parent `757caef9-3f7b-4548-af7a-9df97510d861` after Snap commit `1092d7eacd8b`. Expected log path: `/home/n8n/forge-work/rom-7d96d74c-e3d0-4a6b-8f6b-52cfe7c58f07/build.log`.

FACT: Build Station retry `7d96d74c-e3d0-4a6b-8f6b-52cfe7c58f07` passed the previous Snap Jack blocker. Log evidence: `Snap_intermediates/with-local/classes.dex`, `Copying: .../Snap_intermediates/classes.dex`, `target Package: Snap`, and `Install: .../system/priv-app/Snap/Snap.apk` in `/home/n8n/forge-work/rom-7d96d74c-e3d0-4a6b-8f6b-52cfe7c58f07/build.log`.

FACT: Same retry failed later at 99% during `Package target files`, inside `./build/tools/releasetools/make_recovery_patch`. First fatal: `UnicodeDecodeError: 'ascii' codec can't decode byte 0x84 in position 32: ordinal not in range(128)`. Build Station classifier returned `[]` before local classifier coverage was added.

### 2026-05-17 recovery patch binary write (`build` commit `092e7e803`)

Category: PROPER-FIX

Hypothesis: `recovery-from-boot.p` is binary patch data. The patched `make_recovery_patch.py` encoded Python 2 `str` bytes as UTF-8 text, forcing an ASCII decode and crashing on non-ASCII bytes. Encoding only Python 2 `unicode` / Python 3 `str`, and writing binary data directly, should preserve the patch bytes and let target-files packaging finish.

Evidence: Build `7d96d74c-e3d0-4a6b-8f6b-52cfe7c58f07`, log `/home/n8n/forge-work/rom-7d96d74c-e3d0-4a6b-8f6b-52cfe7c58f07/build.log`, traceback at `make_recovery_patch` output sink line 60 with `UnicodeDecodeError` while `common.MakeRecoveryPatch` emitted `recovery-from-boot.p`.

Files changed: `build/tools/releasetools/make_recovery_patch.py` fixes the text/binary type guard and writes binary patch data without a second encode.

Why each file changed: `./build/tools/releasetools/make_recovery_patch` is a symlink to `make_recovery_patch.py`, and that was the exact executable in the failed packaging command.

Expected next marker: retry build should pass `Package target files` and continue into OTA zip generation / `Package Complete`.

Rollback condition: revert `092e7e803` if target-files packaging succeeds but `SYSTEM/recovery-from-boot.p` is missing/corrupt or Python 3 execution of the same script regresses.

Verification commands: `python3 -m py_compile /srv/forge/android/los14.1-m5c-patched/build/tools/releasetools/make_recovery_patch.py`; `grep -n 'make_recovery_patch\|UnicodeDecodeError\|Package target files\|Package Complete' /home/n8n/forge-work/rom-<retry>/build.log`.

FACT: Build Station classifier coverage was locally extended for Java source-1.7 app failures and `make_recovery_patch` binary/text encode failures in `/home/n8n/build-station/apps/api/app/services/log_classifier/`; `PYTHONPATH=. pytest tests/test_log_classifier.py -q` passed with 74 tests on 2026-05-17.

Next action: retry from Build Station build `7d96d74c-e3d0-4a6b-8f6b-52cfe7c58f07` after build commit `092e7e803`.
FACT: Build Station retry `4f8b97e2-fd7e-43ec-85da-bcef8776f12f` was queued from parent `7d96d74c-e3d0-4a6b-8f6b-52cfe7c58f07` after build/releasetools commit `092e7e803`. Expected log path: `/home/n8n/forge-work/rom-4f8b97e2-fd7e-43ec-85da-bcef8776f12f/build.log`.

FACT: Retry `4f8b97e2-fd7e-43ec-85da-bcef8776f12f` failed at the same target-files step, but with a new traceback after Build Station commit `159633b65` changed `make_recovery_patch.py`: `NameError: global name '_forge_text_type' is not defined` at line 56. Log path: `/home/n8n/forge-work/rom-4f8b97e2-fd7e-43ec-85da-bcef8776f12f/build.log`.

### 2026-05-17 recovery patch raw bytes follow-up (`build` commit `98c29abe4`)

Category: PROPER-FIX

Hypothesis: commit `159633b65` reintroduced a final write expression that references undefined `_forge_text_type` and would still be wrong for binary patch bytes. Since `make_recovery_patch.py` already encodes true text before the write, the final sink should write the normalized buffer directly.

Evidence: Build `4f8b97e2-fd7e-43ec-85da-bcef8776f12f`, log `/home/n8n/forge-work/rom-4f8b97e2-fd7e-43ec-85da-bcef8776f12f/build.log`, traceback `NameError: global name '_forge_text_type' is not defined` at `make_recovery_patch` line 56.

Files changed: `build/tools/releasetools/make_recovery_patch.py` changes the final sink write to `f.write(data)`.

Why each file changed: `./build/tools/releasetools/make_recovery_patch` is the symlinked script that failed during target-files packaging.

Expected next marker: retry build should pass `make_recovery_patch`, package target files, and continue to OTA zip generation.

Rollback condition: revert `98c29abe4` if target-files packaging succeeds but `SYSTEM/recovery-from-boot.p` is missing/corrupt.

Verification commands: `python3 -m py_compile /srv/forge/android/los14.1-m5c-patched/build/tools/releasetools/make_recovery_patch.py`; `grep -n 'NameError: global name _forge_text_type\|UnicodeDecodeError\|Package Complete' /home/n8n/forge-work/rom-<retry>/build.log`.

Next action: retry from Build Station build `4f8b97e2-fd7e-43ec-85da-bcef8776f12f` after build commit `98c29abe4`.
FACT: Build Station retry `ecb7a919-a5af-46de-b312-f4858f42c408` was queued from parent `4f8b97e2-fd7e-43ec-85da-bcef8776f12f` after build commit `98c29abe4` and Build Station auto-patcher correction/restart. Expected log path: `/home/n8n/forge-work/rom-ecb7a919-a5af-46de-b312-f4858f42c408/build.log`.

FACT: Build Station retry `ecb7a919-a5af-46de-b312-f4858f42c408` completed successfully at `2026-05-17T18:44:23Z` in 1171 seconds. Build log evidence: `/home/n8n/forge-work/rom-ecb7a919-a5af-46de-b312-f4858f42c408/build.log` contains `Package Complete: /workspace/out/target/product/m5c/lineage-14.1-20260517-UNOFFICIAL-m5c.zip` and `make completed successfully (18:27 (mm:ss))`.

FACT: Produced ROM artifact:
- path: `/home/n8n/forge-work/rom-workspaces/lineage-los-14.1-m5c-813fc01280/out/target/product/m5c/lineage-14.1-20260517-UNOFFICIAL-m5c.zip`
- size: `519359742` bytes
- SHA256: `ff4043581a7379a81707acb555beffc2453739138aae60e090a242498ce352a8`

FACT: Related image hashes from the same output directory:
- `boot.img` SHA256: `3f5eecca00f0fe29137d0cb5d3cfe31fdf5e9cc6ce65dcc8d3e8fe1121ce6599`
- `recovery.img` SHA256: `aad32478d81709fb7296d8ba86da43c30f37abe20fcb1d2fe79edde96173a5d0`
- `system.img` SHA256: `b4174cb778a419a670591586eb5d7579fe456ebb591379a3dff9d69ceb7762a6`

## Author-facing notes on `patches_mtk`

FACT: README build instructions require applying `. device/meizu/m5c/patches_mtk/apply-patches.sh` before `lunch lineage_m5c-userdebug && mka bacon`.

FACT: `patches_mtk/apply-patches.sh` modifies `system/core`, `bionic`, `system/sepolicy`, `system/netd`, `frameworks/av`, `frameworks/native`, `frameworks/base`, `frameworks/opt/telephony`, `packages/apps/Snap`, `packages/apps/FMRadio`, `external/wpa_supplicant_8`, and `packages/apps/Settings`. The script explicitly comments out `system/bt` as `DO NOT USE SYSTEM BLUETOOTH PATCH`.

FACT: Patch content is a broad legacy MTK Android 7 compatibility stack: libion/netutils/init/fs_config/logging/healthd/ueventd/fingerprint in `system/core`; bionic symbol compatibility; SELinux relaxations; netd hotspot/tethering changes; MTK camera/media/audio/dpframework/stagefright additions; GraphicBuffer/Fence/Sensor/BatteryService MTK hooks; telephony SIM TLV handling; FMRadio JNI; fake NVRAM Wi-Fi ignore; Settings/Snap UI tweaks; and EngineerMode audio APIs.

FACT: The upstream patch set is stale against this LOS 14.1 base. Initial apply produced rejects in `system/core/init/service.cpp`, `system/sepolicy/*.te`, `frameworks/av/camera/cameraserver.rc`, and `frameworks/native/include/ui/GraphicBuffer.h`. Settings `.orig` residue also entered resource scan and was preserved under `/srv/forge/android/los14.1-m5c-patched/m5c_patch_residue_20260517/` after causing one build failure.

INFERENCE: For this exact M5c tree the MTK patch stack is required: without the applied MTK audio/media/framework changes and device headers, the build failed before packaging. After the header path, Settings residue, Snap Java 7, and recovery-patch binary write fixes, the same patched tree produced a full LOS 14.1 zip.

INFERENCE: These patches should not be copied wholesale to existing Meizu/MTK devices. They are useful as a donor catalogue for proven blockers on matching legacy MTK Android 7 vendor stacks, but blind application would mix unrelated audio, camera, graphics, SELinux, init, netd, telephony, and app changes and can regress already-working devices. Port only narrow pieces after a build/runtime log proves the same ABI or framework gap.

Next action: provide the author the artifact hash and this state file. Runtime status is not verified; the current FACT only proves the patched source tree builds and packages successfully.
