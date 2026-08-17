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

## 2026-08-17 Инвентаризация: своё ядро, база ядра, чужие репозитории

Аудит без сборки и без прошивки. Устройство не подключено (`adb devices` пусто на
5037 и на туннеле 15038, `lsusb` без 0e8d/Meizu).

### Что у нас есть по ядру

FACT: from-source ядро m5c существует и собрано: `Linux version 3.18.19
(valakas@n8nagent) (gcc 4.9 20150123) #11 SMP PREEMPT Sun Jun 14 23:16:12 CDT
2026`. Дерево: `/home/valakas/m5c/android_kernel_meizu_m5c`, HEAD
`d2d6975c` (`lcm: lp3101: prevent early boot crash...`).

FACT: артефакты сборки ядра в `/home/valakas/m5c/`: `boot_debug.img`
(sha256 `b6e8df0f45076042a0db67e603769202eb77729000aebab800f77b433774f28b`),
`boot_working_final.img` (`4e66472ee66141499f468f8ce973309f62197d35d407ccc01aa51f19b17be1e2`),
флешабельный `m5c_source_kernel_debug.zip` (boot.img + update-binary).

FACT: собранный ROM `lineage-14.1-20260615-UNOFFICIAL-m5c.zip`
(`/home/n8n/gdrive/`) содержит именно это ядро: его `boot.img`
(sha256 `a166ea14aecad0a45dacfb1a711adb1f2e31e4282b25f692daf506bf96278672`,
9480192 B) распакован — kernel = `#11 ... valakas@n8nagent`, board name
`mt6737`, cmdline `bootopt=64S3,32N2,64N2 androidboot.selinux=permissive
buildvariant=userdebug`.

FACT: в ramdisk этого boot.img лежит `sepolicy` 212408 B, **POLICYDB version
29** (проверено разбором заголовка). То есть подтверждённый блокер загрузки
(v30 xperms против MTK-формата `AVTAB_OP`, см. память
`m5c-boot-blocker-selinux`) в этом артефакте уже закрыт.

FACT: ROM-сборка Build Station `0870fd54-55ec-4bc9-91a3-2cd1cea26912`
(`/home/n8n/forge-work/m5c/rom-0870fd54.../build.log`) завершилась успешно:
`Package Complete: /work/out/target/product/m5c/lineage-14.1-20260615-UNOFFICIAL-m5c.zip`,
`make completed successfully (01:02:48)`.

INFERENCE: единственный неизвестный по этому артефакту — рантайм. Свежего
`last_kmsg`/`ramoops` после 2026-06-15 нет; локальные `last_kmsg.txt` и
`ramoops.txt` от 2026-06-13 (сборка с v30 sepolicy) — СТАРЫЕ, для оценки
текущего образа непригодны.

WARN (in-flight, не мой коммит): в `/home/valakas/m5c/android_kernel_meizu_m5c`
незакоммичены 3 файла — `drivers/misc/mediatek/lcm/lp3101.c`,
`security/selinux/ss/avtab.c`, `security/selinux/ss/policydb.c` (откат 5
SELinux-«заглушек» к сток-поведению `-EINVAL`, обоснован Python-репликой
парсера policydb). Локальный HEAD `d2d6975c` при этом ОТСТАЁТ от origin на
коммит `3204aace5` «Add reverse-engineered component drivers (Ghidra, stock m5c
kernel)» — этот коммит есть только на GitHub, локально объекта нет.

### База ядра: что мы взяли и какие есть альтернативы

FACT: цепочка форков нашего ядра:
`nomorecoolnicknames/android_kernel_meizu_m5c-old` →
`XRedCubeX/android_kernel_meizu_m5c-old` →
`chelghouf/ALPS-MP-M0.MP1-V2.55.6_VZ6737M_65_A_M0_KERNEL`.
То есть база — сырой ALPS M0.MP1 (Android 6) для reference-борда VZ6737M,
kernel 3.18.19; m5c-специфику (dts, LCM, тач) добавил XRedCubeX в 2021 г.
(`947d5e29b` … `5a02b42c4`), остальное реверсили мы.

FACT: наш `arch/arm64/configs/m5c_defconfig`: `CONFIG_ARCH_MT6735M=y`,
`CONFIG_MTK_PLATFORM="mt6735"`, `CONFIG_ARCH_MTK_PROJECT="hq6737m_65_1mz_m0"`,
`CONFIG_CUSTOM_KERNEL_LCM="ili9881c_dsi_vdo_dj_hd720 jd9365_dsi_vdo_holitech_hd720"`,
720x1280 — т.е. проект действительно m5c-овый, а не reference.

FACT: альтернативные базы с уже готовым `m5c_defconfig` и тем же проектом:
- `XRedCubeX/android_kernel_m5c` ветка `nougat` — kernel **3.18.79**,
  `CONFIG_ARCH_MTK_PROJECT="hq6737m_65_1mz_m0"`,
  `CONFIG_CUSTOM_KERNEL_LCM="jd9365_dsi_vdo_holitech_hd720"`,
  `CONFIG_CUSTOM_KERNEL_IMGSENSOR="s5k4h8_mipi_raw s5k5e8_mipi_raw"`
  (т.е. драйверы камер есть в исходниках), плюс `m5c_recovery_defconfig`.
- `XRedCubeX/android_kernel_m5c` ветка `oreo` — kernel **3.18.79**, тот же
  проект и LCM, IMGSENSOR пустой.
- `MTKZU/android_kernel_meizu_m5c` ветки `android-9` / `android-10` — kernel
  **4.9.188**, `CONFIG_ARCH_MTK_PROJECT="m5c"`, но `CUSTOM_KERNEL_LCM=""` и
  в `drivers/misc/mediatek/lcm/` НЕТ `jd9365_dsi_vdo_holitech_hd720`
  (только ili9881c-варианты под nt50358/rt5081) → панель m5c там не заведена.

HYPOTHESIS: 3.18.79 (`nougat`) — лучшая база, чем наша 3.18.19: тот же проект,
живые исходники сенсоров камер, вендор LOS-14.1-эры. Falsify: собрать
`m5c_defconfig` из этой ветки и сравнить набор MTK kernel↔userspace ABI
(ion/m4u/ged/cmdq/imgsensor ioctl, ccci) с тем, что ожидают блобы
`vendor/meizu/m5c` (они из Flyme 6 / Android 6, ALPS M0.MP1). Если ABI
расходится — 3.18.79 даст чёрный экран/камеру/модем при формально
загрузившемся ядре.

REJECTED: «взять ядро с гитхаба автора». `Dekompilyator/kernel_meizu_m5c-old`
— это форк НАШЕГО репозитория (`parent: nomorecoolnicknames/...`), список
коммитов побайтово совпадает с нашим, включая наш `3204aace5` от
2026-06-15T07:48. Брать там нечего: автор взял наше ядро, а не наоборот.

REJECTED (для ядра m5c): репозитории Skyrimus. Они про Wileyfox Porridge
(MT6735, `kernel_porridge_3.18.xx`, `device_kernel_porridge` 2025-01-09,
`lk_porridge_unlocked` alps-7.0) — другой проект и другая панель, m5c_defconfig
там нет. Ценность — донорская: проверенные MT6735/3.18-фиксы под LOS и
разлоченный LK, но не как база.

### Что реально устарело у нас — device tree, не ядро

FACT: наш клон `device/meizu/m5c` стоит на `adcc71a` (2026-05-16). Upstream
`Dekompilyator/android_device_meizu_m5c` (los-14.1) с тех пор ушёл на 30
коммитов до 2026-07-24, включая: `Finalize device tree bringup` (a55206949),
`import new mtk patches` (6765ed408), `m5c: Finalize MTK patches` (e0c0c2445),
`Fix patches path in "apply-patches.sh"` (a5f473bcb), `Update SEPolicy`
(8c44a2cdd), `Update Power HAL` (4241ce5b6), `Update RIL to latest release`
(ae1147d62), `Fix bootloop after Magisk flash` (801bd72a4), `m5c: Update
graphics parameters` (65701933c), `Update include with mt6735 common
configurations` (939881882).

FACT: структура дерева автора изменена: каталог `patches_mtk/` → `patches/`,
proprietary MTK-исходники вынесены в `mtk/`, добавлены `start-build.sh`,
`egl.cfg`, `device.mk` вместо `device_m5c.mk`. Инструкция сборки теперь
`source device/meizu/m5c/patches/apply-patches.sh` + `source
device/meizu/m5c/start-build.sh`. Наши локальные патчи путей
(`TARGET_SPECIFIC_HEADER_PATH`, Settings `.orig`, Snap Java 7,
`make_recovery_patch`) к этой структуре напрямую не приложатся.

FACT: README автора теперь указывает `Touchscreen | Goodix GT917D` и оба LCM
(`ili9881c_dsi_vdo_dj_hd720`, `jd9365_dsi_vdo_holitech_hd720`), а в credits
первым стоит `nomorecoolnicknames` — наши правки у него влиты.

### In-flight состояние рабочего дерева (не тронуто)

FACT: в `/srv/forge/android/m5c/los14.1-m5c-patched/device/meizu/m5c` не
закоммичены: `AndroidProducts.mk`, `board/bluetooth.mk`, `board/kernel.mk`,
`product/prop.mk`, `product/ramdisk.mk`, `rootdir/kernel` (заменён на наше
ядро #11) + untracked `rootdir/kernel.orig-v30` (сток Flyme
`3.18.19+ flyme@Mz-Builder-l10`, Apr 3 2019). Эти файлы сохранены как есть,
коммит этого раздела делается точечным `git add` только `BRINGUP_STATE.md`.

### Следующий шаг (порядок)

1. Прошить и снять факты, а не пересобирать: `lineage-14.1-20260615-UNOFFICIAL-m5c.zip`
   (или `m5c_source_kernel_debug.zip` только на boot) → свежий
   `last_kmsg`/`ramoops` + `dmesg`. Без этого любой выбор базы — гадание:
   у нас есть ядро с v29-политикой, ни разу не проверенное на железе.
2. Подтянуть device/vendor автора до 2026-07-24 и переналожить наши 4 фикса
   на новую структуру `patches/` + `mtk/`; проверить, что в собранном
   `root/sepolicy` версия 29.
3. Только если п.1 упирается в кернельный блокер (не userspace) — пробовать
   базу `XRedCubeX/android_kernel_m5c:nougat` (3.18.79) с проверкой MTK ABI
   против блобов Android 6.
