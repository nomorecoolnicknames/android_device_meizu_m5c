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

## 2026-08-17 Первая прошивка LOS 14.1 с нашим ядром на живое железо

Устройство `710HVBR923RYK` через девбокс (`pc-00007533-1`, контейнер, USB 1-3).
Владелец подтвердил: данных на телефоне нет, полный дамп снят им отдельно,
эксперименты разрешены.

### Что сделано

FACT: сняты бэкапы 23 разделов в `/tmp/m5c-backup-20260817/` на девбоксе
(proinfo, nvram, nvdata, protect1/2, lk, para, boot, recovery, logo, expdb,
devinfo, seccfg, secro, tee1/2, frp, keystore, oemkeystore, metadata, rstinfo,
flashinfo, custom). Стоковый `boot.img` = sha256
`69d272f9b42766da9f14940f60dfbfa00e8f0be1dbea2a4c22269aa64386bd29`.

FACT: до прошивки на устройстве стоял сток **Flyme 6.0.2.3G** (Android 6.0,
`ro.build.date=Sat Nov 11 00:25:12 CST 2017`), /data не шифрован.

FACT: `/data` отформатирован, установлен `lineage-14.1-20260615-UNOFFICIAL-m5c.zip`
(md5 `6a868271de4d61591e44839469bf5441`). Установка прошла штатно:
`Target: meizu/lineage_m5c/m5c:7.1.2/NJH47F/1e12cbe1dc:userdebug/test-keys`.
`/system/recovery-from-boot.p` удалён, чтобы LOS не перезаписал TWRP.

FACT: в boot-разделе подтверждено наше ядро: `Linux version 3.18.19
(valakas@n8nagent) #11 SMP PREEMPT Sun Jun 14 23:16:12 CDT 2026`, board `mt6737`,
cmdline `bootopt=64S3,32N2,64N2 androidboot.selinux=permissive buildvariant=userdebug`.

FACT: собран и прошит `boot_forge.img` (md5 `847243efad6af251768e32b24f31f6ac`) —
то же ядро #11, ramdisk дополнен диагностикой: `/init.forge.rc` + `/init.forge.sh`
(импорт добавлен в `init.rc` после `init.cm.rc`). Скрипт по `post-fs-data`
пишет в `/data/forge/`: `dmesg`, `logcat`, `heartbeat` (состояние USB и
init.svc.*), `ps`, `getprop`, `/proc/last_kmsg`, и принудительно поднимает
`android_usb`. Это единственный способ получить лог с устройства без adb —
pstore/ramoops на этом железе пустой, expdb нечитаемый.

### Результат загрузки (наблюдение владельца + логи)

FACT: LOS грузится до экрана «Welcome to LineageOS» — **дисплей работает**
(панель, подсветка, композиция). Тач, USB мёртвые; кнопки и звук на второй
загрузке работали.

FACT: система доходит очень далеко: `/data/system/packages.xml` 376 KB,
`dalvik-cache` с `boot.art`, `/data/property/persist.sys.usb.config=adb`,
`system_server` живой (`DisplayPowerController.updatePowerState` работает,
единственный WTF — безобидный `neither /proc/wakelocks nor /d/wakeup_sources exists`).

FACT: `/data/tombstones/` — 10 падений, все `/system/bin/mtk_agpsd`, SIGABRT в
динамическом линкере (`__linker_init_post_relocation` → `__libc_fatal` → abort).
Это userspace/blob-дефект (не хватает библиотеки или символа), не блокер загрузки.

### Root cause: USB/adb — PMIC EINT не зарегистрирован

FACT: `android_usb` в нашем ядре есть и настроен: `functions=adb`, `enable=1`,
но `state=DISCONNECTED` (`captures/20260817-los-first-boot/forge.log`).

FACT: в ядерном логе `usb_cable_connected 592: type(0)` на каждой попытке —
MTK-детект типа зарядника всегда возвращает 0 (кабель «не подключён»), поэтому
mt_usb не поднимает periferal-режим.

FACT: причина видна на 0.28 с загрузки:
```
[0.283544] [PWRAP] clear EINT flag mt_pmic_wrap_eint_status=0x0
[0.284606] WARNING: CPU: 0 PID: 54 at kernel/irq/manage.c:454 enable_irq+0x8c/0xd4()
[0.284616] Unbalanced enable for IRQ 494
```
`pmic_thread` вызывает `enable_irq()` на IRQ 494, не запросив/не отключив его.

FACT (ground truth со стока в тот же момент, тот же кабель): в
`/proc/interrupts` стока `494: 1 mt-eint 206 pmic-eint` — прерывание
зарегистрировано и сработало; `/sys/class/power_supply/usb/online=1`,
`battery/status=Charging`.

INFERENCE: цепочка блокера — сломанная регистрация PMIC EINT (IRQ 494 /
`mt-eint 206`) → CHRDET не доставляется → `g_chr_type=0` → `usb_cable_connected
type(0)` → гаджет не подключается → нет adb и нет индикации зарядки.
Это ядерный дефект нашей сборки, не adb-secure и не ramdisk: prop'ы уже
`ro.secure=0`, `ro.adb.secure=0`, `persist.service.adb.enable=1`.

REJECTED: «adb не работает из-за отсутствия FunctionFS». `f_fs.c` включён
в `android.c` (`#include "f_fs.c"`, строка 43) и линкуется в `android.o`;
ramdisk нигде не монтирует `/dev/usb-ffs`, adbd идёт по legacy-пути
`/dev/android_adb`, а сам `android_usb` присутствует. Дело в детекте кабеля.

### Root cause: тач — драйвер Goodix вообще не собран

FACT: реальный чип — Goodix (сток биндит `gt9xx` на `1-005d`, см.
`M5C_CHIP_MAP.md`).

FACT: в нашем `m5c_defconfig` стоят `CONFIG_TOUCHSCREEN_MTK_GT9XX=y`,
`CONFIG_TOUCHSCREEN_MTK_FOCALTECH_TS=y`,
`CONFIG_TOUCHSCREEN_MTK_FTS_DIRECTORY="focaltech_touch"`, но в
`drivers/input/touchscreen/mediatek/Makefile` **нет правил** ни для
`CONFIG_TOUCHSCREEN_MTK_GT9XX`, ни для `CONFIG_TOUCHSCREEN_MTK_FOCALTECH_TS`,
и каталогов `GT9XX/` и `focaltech_touch/` в дереве нет. Собирается только
`ft5x46/` (`CONFIG_TOUCHSCREEN_MTK_FT5x46=y`).

FACT: следствие видно в логе — ни одной строки `GTP` за всю загрузку, зато
`ft5x46_ts 1-005d: Create proc entry success!` и `tpd_probe OK`: FocalTech-драйвер
занял адрес Goodix-чипа. Плюс `mtk-tpd bus:touch@: fwq Cannot find touch pinctrl
default -19!`.

INFERENCE: тач мёртв потому, что Goodix-драйвера в ядре нет, а его адрес забрал
неподходящий ft5x46.

FACT: каталоги, дающие драйвер с именем `gt9xx`, в дереве уже есть: `GT910`,
`GT911`, `GT928`, `GT9XXTB_hotknot`, `GT9XX_hotknot_scp` (`GT1151` — вариант
gt1x с `tpd_device_name=gt9xx`). Плоского `GT9XX_hotknot`, который есть у
`XRedCubeX/android_kernel_m5c` (ветки `nougat`/`oreo`), у нас нет.

### Что это меняет в приоритетах

REJECTED (для текущей ветки работ): смена базы ядра на 3.18.79/4.9.188.
Наши блокеры — не «плохая база»: DTB стоковый, дисплей работает, система
доходит до Welcome. Два оставшихся блокера локальны и адресны (PMIC EINT,
Goodix-драйвер). Смена базы сейчас только обнулит этот прогресс.

Next action (по приоритету):
1. Тач: собрать Goodix. Порт `GT9XX_hotknot` из `XRedCubeX/android_kernel_m5c:nougat`
   (у стока есть `/sys/class/misc/hotknot` → hotknot-вариант) + правила в
   `Makefile`/`Kconfig`; выключить `CONFIG_TOUCHSCREEN_MTK_FT5x46`, чтобы он не
   занимал `1-005d`.
2. USB: разобрать путь регистрации PMIC EINT (IRQ 494 / `mt-eint 206`), найти
   `enable_irq()` без парного `request_irq()`/`disable_irq()` в pmic-драйвере;
   цель — CHRDET → `chr_type != 0` → `android_usb state=CONFIGURED`.
3. Логгер `init.forge.*` оставить в ramdisk до появления adb; добавить в него
   `/proc/interrupts` и `/sys/class/power_supply/*` для следующей итерации.
4. `mtk_agpsd` — отдельная userspace-задача, не блокер (лечится после adb по
   `linker` сообщению из logcat).

Захват: `captures/20260817-los-first-boot/` (dmesg/logcat/heartbeat/ps/props/
last_kmsg + оба DTB). Карта железа: `M5C_CHIP_MAP.md`.

## 2026-08-17 (позже) Уточнение: LOS грузится полностью; настоящие причины найдены

### Коррекция предыдущей записи

REJECTED: гипотеза «USB мёртв из-за сломанной регистрации PMIC EINT
(`Unbalanced enable for IRQ 494`)». Две независимые проверки её убили:
1. Код `drivers/misc/mediatek/power/mt6735/pmic.c`: `request_irq()` на строке
   3315 (IRQ включён по умолчанию), обработчик `mt_pmic_eint_irq` делает
   `disable_irq_nosync()` (стр. 3199), а `pmic_thread_kthread` в конце каждого
   прохода вызывает `enable_irq()` (стр. 3435). Первый проход поток делает по
   `wake_up_process()` при создании — без предшествующего disable, отсюда
   разовый WARNING. Это штатное поведение стока, не дефект.
2. Замер на устройстве: в нашем ядре `/proc/interrupts` показывает
   `494: 8 mt-eint 206 pmic-eint` — прерывания PMIC приходят и обрабатываются.

### FACT: LOS 14.1 на нашем ядре загружается ДО КОНЦА

Захват `captures/20260817-los-first-boot/` (второй прогон, `heartbeat.txt`):
на 57 с `boot_completed=1`, `bootanim=stopped`, `adbd=running`,
`surfaceflinger=running`, `zygote=running`. Дисплей работает (владелец видит
экран Welcome). Неработоспособны только USB и тач.

### FACT: причина мёртвого USB — драйвер зарядника не биндится (compatible)

Замер `i2c.txt` в нашем ядре против стока:
- `1-006a swithing_charger` → **driver пусто** (в стоке `fan5405`)
- `2-0048 alsps` → **driver пусто** (в стоке `stk3x1x`)
- `1-005d cap_touch` → `ft5x46_ts` (в стоке `gt9xx`)
- `3-006b ext_buck` → `mt6311` (в стоке НЕ биндится — расхождение, пока не трогаем)

Причина найдена в match-таблицах против стокового DTB (`dtc -I dtb` от
`captures/.../dtb_stock.dtb`):
- DTB: `swithing_charger@6a { compatible = "mediatek,swithing_charger"; }`,
  а `drivers/misc/mediatek/power/mt6735/fan5405.c`:
  `fan5405_of_match[] = {{.compatible = "fan5405"},{}}` → **не совпадает**.
- DTB: `alsps@48 { compatible = "mediatek,alsps"; }`,
  а `drivers/misc/mediatek/alsps/stk3x1x/stk3x1x.c`:
  `alsps_of_match[] = {{.compatible = "mediatek,alsps2"},{}}` → **не совпадает**.

INFERENCE (цепочка USB): нет биндинга `fan5405` → нет BC1.2-детекта типа
зарядника → `g_chr_type` остаётся 0 → `usb_cable_connected 592: type(0)` →
`mt_usb` не поднимает peripheral → `android_usb state=DISCONNECTED` при
`functions=adb, enable=1` → adbd работает, но шины нет. Подтверждающие замеры:
`musb-hdrc` IRQ = **0** за всю загрузку (в стоке 1785),
`power_supply usb/online=0`, `ac/online=0`, `battery status=Not charging`,
`capacity=50` (фолбэк вместо реальных 93% со стока).

### FACT: причина мёртвого тача

Реальный чип — Goodix (сток биндит `gt9xx`, см. `M5C_CHIP_MAP.md`). Из
gt9xx-каталогов в нашем дереве стоковым строкам лога соответствуют ровно два:
`GT9XXTB_hotknot` и `GT9XX_hotknot_scp` — только в них есть весь набор
`pre_touch:`, `[Esd]`, `Init external watchdog`, `GTP wakeup sleep`,
`buffer not ready`, `guitar_update` (в `GT928`/`GT911`/`GT910` нет `[Esd]`).
`GT1151` — это gt1x, другое семейство. У всех of_match = `mediatek,cap_touch`,
как и у ft5x46, поэтому адрес забирал тот, кто собран.

### Патч-набор ядра (kernel #12), собирается

Category: PROPER-FIX

1. `drivers/misc/mediatek/power/mt6735/fan5405.c` — в `fan5405_of_match`
   добавлен `{.compatible = "mediatek,swithing_charger",}`.
2. `drivers/misc/mediatek/alsps/stk3x1x/stk3x1x.c` — в `alsps_of_match`
   добавлен `{.compatible = "mediatek,alsps"}`.
3. `arch/arm64/configs/m5c_defconfig`:
   `CONFIG_TOUCHSCREEN_MTK_GT9XXTB_HOTKNOT=y` (было not set),
   `CONFIG_TOUCHSCREEN_MTK_FT5x46` выключен (чтобы не занимал `1-005d`),
   `CONFIG_GTP_DRIVER_SEND_CFG` выключен — намеренно: конфиг-массив в
   каталоге рассчитан на другую панель, пусть GT917D работает на своём
   заводском конфиге. Заодно зафиксировано, что `CONFIG_TOUCHSCREEN_MTK_GT9XX`
   в defconfig — мёртвая опция (в Kconfig такого символа нет, `make
   m5c_defconfig` её выбрасывает).

Ожидаемые маркеры на следующей загрузке:
- `i2c.txt`: `1-006a ... driver=fan5405`, `1-005d ... driver=gt9xx`,
  `2-0048 ... driver=stk3x1x`;
- dmesg: строки `<<-GTP-INFO->>`/`<<-GTP-DEBUG->>` вместо `ft5x46_ts`,
  `usb_cable_connected` с type != 0;
- `/proc/interrupts`: ненулевой счётчик `musb-hdrc.0.auto`;
- `android_usb state=CONFIGURED` и живой `adb devices` через девбокс;
- `power_supply usb/online=1`, `battery status=Charging` с реальной ёмкостью.

Rollback condition: если тач не поднимается — пробовать
`GT9XX_hotknot_scp`, затем портировать плоский `GT9XX_hotknot` из
`XRedCubeX/android_kernel_m5c:nougat`; если USB поднялся, а зарядка ведёт себя
неверно — проверять `ext_buck`/`mt6311` (у нас биндится, в стоке нет).

### Диагностический ramdisk

FACT: `init.forge.sh` в ramdisk расширен: `/proc/interrupts`, таблица
`/sys/bus/i2c/devices/*` с драйверами, `/sys/class/input/*`, все
`/sys/class/power_supply/*`. Замечено ограничение: сервис умирает примерно на
6-й итерации (~57 с, вероятно LMK на 2 ГБ во время dexopt), поэтому
добавленный `reboot recovery` в конце цикла не срабатывает — возврат в TWRP
пока руками.

## 2026-08-17 (итог сессии) adb, тач, зарядка — работают; экран после resume

Все проверки — на живом `710HVBR923RYK` через девбокс.

### Проверено работающим (FACT, замеры на устройстве)

- `1-006a swithing_charger -> fan5405` (было пусто);
  `android_usb state=CONFIGURED`, `functions=adb`; `adb devices` видит телефон
  из Android; `musb-hdrc` в `/proc/interrupts` набирает счётчики (было 0);
  `power_supply/usb/online=1`, `battery status=Charging`, `capacity=98`
  (раньше был фолбэк 50 и `Not charging`).
- `1-005d cap_touch -> gt9xx` (было `ft5x46_ts`); `350: … TOUCH_PANEL-eint`
  набирает счётчики; `mtk-tpd` = `event5`; `getevent` даёт настоящий
  multitouch (`ABS_MT_POSITION_X/Y`, `BTN_TOUCH`, tracking id).
- Ориентация тача исправлена: тап в левый верхний угол даёт X=136, Y=43
  (до правки координаты были точечно-симметричны — панель повёрнута на 180°).
- `sys.boot_completed=1`, LOS 14.1 доходит до UI.

Коммиты в ядре (`/home/valakas/m5c/android_kernel_meizu_m5c`):
`2f918464` (USB/зарядка/тач), `b83303d7` (обвязка stk3x1x, выключен),
`4137458e` (таблица инициализации панели и тайминги bias из стока).

### Экран после блокировки: причина найдена, правка залита, визуал уточняется

FACT: на загрузке таблица инициализации панели из ядра **не используется** —
панель поднимает LK, и `disp_lcm_probe` ставит `is_inited=true`. Наша таблица
исполняется только на resume — ровно там и был мусор.

FACT: сравнение реверс-таблицы с эталоном из стокового `vmlinux.elf`
(VA `0xffffffc00101c5e8`, 192 записи по 72 байта, сток пушит
`push_table(tbl, 0xc0, 1)`) показало расхождения во многих регистрах страницы 1
ILI9881C: `0x04`, `0x05`, `0x07`–`0x0b`, `0x0f`, `0x10`, `0x1e`, `0x1f` и др.
(например `0x0a` было `0x00` вместо `0x19`). Таблица перегенерирована
байт-в-байт из стока; старая сохранена как
`ili9881c_dsi_vdo_dj_hd720.c.bak-handreversed`.

FACT: тайминги `lcm_init_power` тоже выровнены по стоку (5/5/2/5/10 мс вместо
2 мс везде) — по декомпиляции `decompiled_src/lcm_ili9881c.c`.

FACT: после правок resume проходит без ошибок:
`lcm_suspend` → `lcm_init_power` (`add VSP ret=2`, `add VSN ret=2`) →
`lcm_resume`. Промежуточная итерация (только тайминги, до замены таблицы) дала
«другой мусор» — что и указало на саму таблицу.

REJECTED: `[DISP][disp_lcm_probe #831]ERROR:FATAL ERROR: can't found lcm
driver:...` — сообщение косметическое. В `disp_lcm.c` (строки 817–831) цикл
поиска делает `break` при совпадении, но `DISPERR` печатается после цикла
безусловно; `isLCMFound` при этом true и берётся правильный драйвер (индекс 1).
Не тратить время на это сообщение.

REJECTED: «мусор из-за короткой задержки после сброса в `lcm_resume`
(MDELAY(20) против MDELAY(120) в `lcm_init`)». Стоковый
`ili9881c_lcm_resume` (декомпиляция, `0xffffffc0004e529c`) делает ровно то же:
reset 1/2мс, 0/10мс, 1/`0x14`=20мс, затем push_table. Наш код совпадает.

### Ещё не сделано

1. Визуальное подтверждение экрана после блокировки на текущей сборке.
2. Если мусор останется: следующий шаг — таблица `jd9365` тем же методом
   (вторая ревизия панели, на этом экземпляре не используется) и сверка
   `lp3101` bias-драйвера с `decompiled_src/driver_lp3101.c`; далее — сверка
   `lcm_get_params` (DSI timing: porches, PLL, lane count) с
   `decompiled_src/lcm_ili9881c.c`, потому что параметры DSI на первой загрузке
   тоже приходят от LK.
3. `stk3x1x` (свет/приближение) — обвязка готова, драйвер не компилируется
   (legacy `BOOL/TRUE/FALSE` без `mt_typedefs`).
4. `mtk_agpsd` падает по кругу (linker abort) — userspace, теперь диагностируется
   через живой adb (`logcat` покажет, какой символ/библиотеку не находит).
5. `3-006b ext_buck` у нас биндится драйвером `mt6311`, в стоке — нет. Проверить,
   не мешает ли (питание CPU).
6. Диагностический ramdisk (`init.forge.rc`/`init.forge.sh`) можно убрать —
   adb теперь живой сам по себе; сервис всё равно умирает на ~6-й итерации
   (вероятно LMK).

### План перехода на 4.9

`M5C_KERNEL_49_PORT_PLAN.md` — исследование баз 4.9 для MT6737/6735 и фазовый
план переноса компонентов. Его предпосылка «сначала добить два блокера 3.18»
на момент записи уже выполнена: adb и тач работают.

## 2026-08-17 Коррекция записи о базах: MTKZU android-9 — это 3.18.119, а не 4.9

CORRECTION к разделу «2026-08-17 Инвентаризация»: там сказано, что
`MTKZU/android_kernel_meizu_m5c` в обеих ветках — kernel 4.9.188. Это верно
только для `android-10`.

FACT (проверено запросом к GitHub API/raw):
`MTKZU/android_kernel_meizu_m5c:android-9` — **kernel 3.18.119**, arm64,
`CONFIG_ARCH_MT6735M=y`, `CONFIG_MTK_PLATFORM="mt6735"`,
`CONFIG_ARCH_MTK_PROJECT="m5c"` (собственный проект, не `hq6737m_65_1mz_m0`),
есть `m5c_defconfig` и `m5c_debug_defconfig` (3794 строки), а в
`drivers/misc/mediatek/lcm/` присутствует `jd9365_dsi_vdo_holitech_hd720`.
То есть это настоящий m5c-порт на 3.18.119 — на 100 стабильных версий новее
нашей 3.18.19, и он arm64 (в отличие от официальной линии 4.9-lc, которая
arm32-only).

FACT: но по железу он настроен под **другой экземпляр m5c**, не наш:
- `CONFIG_CUSTOM_KERNEL_LCM="jd9365_dsi_vdo_holitech_hd720"` — только jd9365;
  нашей панели `ili9881c_dsi_vdo_dj_hd720` там нет;
- тач: `CONFIG_TOUCHSCREEN_MTK_FOCALTECH_TS=y`, все Goodix-варианты выключены —
  у них FocalTech, у нас Goodix GT917D (см. `M5C_CHIP_MAP.md`);
- `# CONFIG_MTK_FAN5405_SUPPORT is not set` — зарядник не настроен;
- `# CONFIG_MTK_IMGSENSOR is not set`, `CUSTOM_KERNEL_IMGSENSOR=""` — камеры не
  настроены;
- USB — тот же legacy `CONFIG_USB_G_ANDROID=y`, configfs выключен.

INFERENCE: как база для uplift 3.18.19 → 3.18.119 это дерево полезно
(свежее ядро, arm64, m5c-проект и DTS), но не drop-in: панель ili9881c,
Goodix-тач, fan5405 и сенсоры придётся переносить туда так же, как сейчас
сделано у нас. Ровно та же ловушка, что была на m6: панель и тач различаются
между экземплярами одной модели, поэтому настройка чужого дерева не описывает
наше железо — эталон только `M5C_CHIP_MAP.md` со стока этого экземпляра.

INFERENCE: это даёт третий путь помимо «остаться на 3.18.19» и «прыгнуть на
4.9»: uplift на 3.18.119 arm64 с переносом наших уже-исправленных драйверов.
Дешевле 4.9 (нет arm32-развилки и смены vendor ABI), но и выигрыш меньше.
Решать после визуального подтверждения экрана.

FACT (из `M5C_KERNEL_49_PORT_PLAN.md`, детали для будущей фазы): в линии
4.9-lc `charging_hw_fan5405.c` присутствует, но номер i2c-шины зашит как 3 —
для нашего железа нужен 1 (`1-006a`).

## 2026-08-17 Решения по треку новых Android (от владельца)

Решения приняты владельцем и являются ограничениями, а не вариантами:

1. **Цель — Android 13**, и 4.9 нужен именно как средство к ней (не A9/A10).
2. **Только arm64** — потому что Treble/GSI строится под arm64. Значит
   arm32-фолбэк из плана выпадает, а arm64-графт 4.9-lc становится обязательным
   и самым рискованным элементом (официальная линия 4.9-lc для mt6735m —
   arm32-only, а arm64-defconfig у `MTKZU:android-10` рукописный, причём
   `MACH_MT6735M` в arm64-Kconfig не заведён).
3. **Vendor-раздел размещаем на `custom`.**

FACT про `custom` (замеры этого экземпляра):
- есть в стоковой GPT: `by-name/custom -> mmcblk0p17`, размер ровно
  `536870912` B = 512 MiB;
- это **ext4** (магия `0x53ef` по смещению `0x438`), block size 4096,
  131072 блоков, свободно 112720 блоков (~440 MiB), занято ~73 MiB,
  32768 inode (свободно 32737), метка тома пустая;
- в LOS 14.1 раздел **не монтируется вообще**: в `/proc/mounts` его нет,
  каталог `/custom` пустой;
- дамп снят: `/tmp/m5c-backup-20260817/custom.img` на девбоксе, sha256
  `ad8f6a88aed0d8f1cf6e244e35ac133233aa0b14dbb3862ce4d95e34f98b9174`.

INFERENCE: 512 MiB ext4, никем не смонтированный и уже сдампленный, —
пригодная площадка под `/vendor` для Treble. Прежде чем перезаписывать, надо
посмотреть содержимое дампа (что там держит Meizu, ~73 MiB) и научить
fstab/TWRP этому разделу. Прецедент в том же хозяйстве:
`/srv/forge/android/meizu_mx6_m95/TREBLE_VENDOR_PARTITION_PLAN.md` (MT6797, тот
же приём).

Субагенту `k49-plan` отправлено задание переработать
`M5C_KERNEL_49_PORT_PLAN.md` под эти три ограничения, с решающим вопросом:
существует ли вообще arm64-4.9 дерево/defconfig для MT6735M/MT6737M (искать
`k37mv1_64_bsp_k49_defconfig` и любые arm64-конфиги 4.9 с k37mv1/k37tv1/
mt6735m/mt6737). Если существует — риск графта исчезает; если нет — план должен
явно перечислить, что именно графтить (arm64 Kconfig/Makefile/mach-обвязка,
arm32-only части: spm, lowlevel asm, ATF-handoff, mrdump) и каким минимальным
тестом «boot до init» это проверяется.

## 2026-08-17 (вечер) Дисплей закрыт, тач выровнен, камера опознана

### Дисплей после resume — РЕШЕНО

FACT: владелец прошёл экран первичной настройки на сборке с исправленными
параметрами DSI — мусора после блокировки нет.

FACT: причина была в `lcm_get_params`. Стоковые значения вынуты из
`ili9881c_lcm_get_params` (`0xffffffc0004e5014`) и расшифрованы по именам полей
хостовым `offsetof`-пробником против `lcm_drv.h` этого дерева:
`type=2`, 720x1280, `dsi.mode=1` (SYNC_PULSE_VDO), `LANE_NUM=4`, `PS=2`,
`format=2`, `vsa=4 vbp=16 vfp=20 vact=1280`, `hsa=20 hbp=70 hfp=70 hact=720`,
`PLL_CLOCK=212`, `ssc_disable=1`, `HS_TRAIL=6`, esd table `{0x0a,1,{0x9c}}`,
физический размер 62x110 мм.

FACT: у нас было `LANE_NUM=LCM_THREE_LANE` и `PLL_CLOCK=285`, плюс `hsa=60`,
`hbp=80`, `vbp=18`, `vfp=10` — то есть неверная битовая скорость DSI и неверные
порчи. На первой загрузке это не проявлялось (DSI-хост программирует LK), а на
resume ядро перепрограммировало его этими значениями → шум на матрице.

INFERENCE (метод на будущее): всё, что реверсили руками, надо сверять со стоком
байт-в-байт. Таблица инициализации панели и параметры DSI — обе оказались
неверны, и обе проявляются ТОЛЬКО на resume. Заметка: в стоковом заголовке
`LCM_PARAMS` на 8 байт длиннее нашего в хвосте (`physical_width` у стока по
`0x36c`, у нас по `0x364`), поэтому хвост структуры проверять отдельно.

### Самопроизвольный ребут в TWRP — объяснён, не дефект

FACT: `/sys/fs/pstore/console-ramoops` заработал (65 КБ) и показал на 203-й
секунде `reboot: Restarting system with command 'recovery'` от `init`,
`arch_reset: cmd = recovery`, без паники. Это наш собственный диагностический
`init.forge.sh`: он дожил до конца цикла и выполнил `reboot recovery`.
Логгер убран, boot собирается со штатным ramdisk LOS.

### Тач — выровнен, поворот не нужен вовсе

FACT: `/sys/module/tpd_setting/parameters/tpd_calmat` показал
`-4096,0,3276800,0,-4096,5242880,0,0`. `tpd_calibrate()` считает
`x=(m0*x+m1*y+m2)>>12`, т.е. это `x→800-x`, `y→1280-y` — поворот 180°,
рассчитанный на панель 800x1280. Матрица приходит из
`GT9XXTB_hotknot/include/config_default/gt9xx_config.h`
(`TPD_CALIBRATION_MATRIX_ROTATION_NORMAL/FACTORY`).

Три измерения на железе:
1. с исходной матрицей (800) тач был повёрнут на 180°;
2. с добавленной зеркалкой `TPD_WARP_X/Y` (719-x) повороты сократились, остался
   постоянный сдвиг `800-719 = 81` px вправо (владелец видел ~85 px);
3. с матрицей, исправленной на 719/1279, и без зеркалки — снова инверсия: тап в
   левый верхний угол дал X=683 Y=1267 (подтверждено владельцем).

FACT: значит «сырые» координаты контроллера уже совпадают с экраном. Итог —
единичная матрица `{4096,0,0,0,4096,0,0,0}`, `TPD_WARP_X/Y` выключены. Владелец
подтвердил: тач в норме. Коммит `59330781`.

INFERENCE: это же должно вернуть ряд ёмкостных кнопок (mBack). DT кладёт три
tpd-кнопки на `y=1400`, вне 1280-строчной панели; поворачивающая матрица
переводила это в отрицательное значение, и нажатие всплывало как тап по экрану.
Требует подтверждения на устройстве.

### Камера — сенсор опознан, HAL подключается

FACT: причина «камеры нет» — неверные i2c-адреса в драйверах. `S5K4H8` имел
`i2c_addr_table = {0x5A, 0xff}`, тогда как сток биндит `camera_main` на i2c0
`reg=0x10` → 8-битный write id `0x20`; у `S5K5E8YX` в таблице не было `0x78`
(для `camera_sub` `reg=0x3c`). Симптом в логе: `Read sensor id fail, write id:
0x5a, sensor id = 0x0` и `MtkCam enumDeviceLocked i4DeviceNum=0`.

FACT после правки (коммит `d9c41e0e`): `S5K4H8 get_imgsensor_id i2c write id:
0x20, sensor id: 0x4088`, `[open]` из `initCamdevice`,
`CameraService::connect ... camera ID 0`, и **фонарик зарегистрировался**
(`onTorchStatusChangedLocked cameraId=0 newStatus=1`). Также включён
`CONFIG_MTK_LENS_DW9714AF_SUPPORT` — сток ведёт `camera_main_af@0x18` через
DW9714, а собран был только DUMMYLENS.

FACT: осталась ошибка OTP-калибровки: HAL просит `/dev/S5K5E8_ST_OTP`, получает
`ERR_NO_SHADING`. В `drivers/misc/mediatek/cam_cal/src/` есть только
`mt6735/imx135_otp` и `mt6735/imx219_eeprom` — драйверов OTP для S5K4H8/S5K5E8
нет вообще, а в стоке они есть в вариантах holitech/ofilm/st/sunwin (и есть
декомпиляции в `/home/valakas/m5c/decompiled_src/`). Это следующая задача по
камере. Отдельно: HAL спрашивает `SENSOR_DRVNAME_S5K5E8_ST_MIPI_RAW`, т.е. ждёт
ST-вариант — при портировании OTP надо согласовать имена драйверов с тем, что
ждут блобы.

Прочее замеченное: в `frameworks` этой ROM-сборки сидит наш же m681-шим
(`CameraService: M681 legacy shim metadata left lazy`) — дерево общее с m681,
на m5c безвредно, но знать полезно.

## 2026-08-17 (поздний вечер) Камера снимает, но цвет сломан; фонарик не доходит до железа

### Камера: снимок получен и изучен

FACT: камера открывается и делает снимок. Снятый кадр
(`/sdcard/DCIM/Camera/IMG_20260817_151905.jpg`, 1193774 B, JPEG 1920x2560)
изучен визуально. В нём **геометрия и резкость нормальные** — читаемы кабели,
панель с кнопками, клавиатура, стойка; сломан **только цвет**: крупные плавные
радужные пятна (зелёный/маджента/циан) поверх правильной яркости.

INFERENCE: это подпись неверной таблицы lens shading / цветовой калибровки, а не
дефекта захвата: при поломке порядка Байера или шага строки ломалась бы
геометрия. Совпадает с уже зафиксированной ошибкой
`CamCal: can't open CAM_CAL /dev/S5K5E8_ST_OTP` → `ERR_NO_SHADING`: HAL берёт
таблицу шейдинга из OTP, не может её прочитать и применяет мусорные
пер-блочные коэффициенты.

FACT: владелец отмечает, что изображение повёрнуто на 180° и в видоискателе
тоже. Это ориентация сенсора на стороне HAL/конфига камеры (не та же проблема,
что была у тача — тач уже исправлен в ядре).

Задачи по камере, по приоритету:
1. Портировать cam_cal OTP для S5K4H8 и S5K5E8 (в стоке варианты
   holitech/ofilm/st/sunwin; декомпиляции — `/home/valakas/m5c/decompiled_src/
   sensor_s5k4h8.c`, `sensor_s5k5e8.c`). HAL ждёт узел `/dev/S5K5E8_ST_OTP` и
   имя драйвера `SENSOR_DRVNAME_S5K5E8_ST_MIPI_RAW`, т.е. ST-вариант — имена
   надо согласовать с блобами. Быстрый промежуточный вариант: заставить путь
   «OTP нет» отдавать нейтральный (единичный) шейдинг вместо мусора — кадр
   станет плоским по цвету, но без радуги.
2. Ориентация 180°: найти, где задаётся `sensor orientation` для main/sub
   (userspace-конфиг камеры / блоб `libcameracustom`), и выставить 180.

### Фонарик: userspace включает, ядро молчит

FACT: userspace честно включает фонарь — в логкате
`flash_custom.cpp: cust_getFlashHalTorchDuty devid main id1` и
`onTorchStatusChangedLocked cameraId=0 newStatus=2` (torch ON), затем обратно 1.

FACT: в ядре в этот момент **ни одной строки**. При загрузке есть только
`flashlight_init` и `LM3642_init` (последний — просто `i2c_add_driver`,
71 мкс). i2c-клиент привязан: `1-0063 strobe_main -> leds-LM3642`.

FACT: собран вариант `flashlight/src/mt6735/constant_flashlight/leds_strobe.c`
(12 КБ, 65 упоминаний LM3642 — то есть это LM3642-вариант, а не GPIO-only), но
определения `#define FLASH_GPIO_ENF GPIO12` / `ENT GPIO13` в нём **закомментированы**,
а вся отладка идёт через `PK_DBG` (pr_debug), поэтому в dmesg тишина
независимо от результата.

HYPOTHESIS: `FL_Enable()` вызывается, но либо i2c-запись в LM3642 не проходит,
либо не поднят EN-пин (в стоке он может управляться GPIO, а у нас определения
закомментированы). Falsify: включить dynamic debug для `leds_strobe.c`
(`echo 'file leds_strobe.c +p' > /sys/kernel/debug/dynamic_debug/control`) и
повторить нажатие — увидим, доходит ли до `FL_Enable` и что возвращает i2c;
плюс сверить `leds_strobe.c` со стоковой декомпиляцией по последовательности
включения.

REJECTED: «фонарик не работает, потому что осталось донорское userspace». Логкат
показывает, что userspace как раз доходит до HAL и меняет статус; молчит именно
ядро.

## 2026-08-17 (ночь) mBack, фонарик, иконка камеры — закрыты на железе

Работа шла четырьмя параллельными агентами, каждому — свой `git worktree` ядра
(`/srv/forge/android/m5c/k-worktrees/{mback,camotp,torch}`), прошивку делала
только родительская сессия. Их подробные ленты: `M5C_TOUCHKEY_LANE.md`,
`M5C_FLASHLIGHT_LANE.md`, `M5C_CAMERA_ORIENTATION_LANE.md`,
`M5C_CAMERA_OTP_LANE.md`, `M5C_KERNEL_49_BUILD_LOG.md`.

### mBack — РАБОТАЕТ (подтверждено владельцем)

FACT: причина — драйвер синтезировал тап по захардкоженным координатам вместо
key-события: `GTP_KEY_MAP_ARRAY` в
`GT9XXTB_hotknot/include/tpd_gt9xx_common.h:39` = `{{60,850},{180,850},{300,850}}`
(референсный дизайн 480x800), и `gt9xx_driver.c` брал `input_x = maping[i].x` →
`tpd_down()`. На 720x1280 точка `(60,850)` попадает внутрь экрана.

FACT (замер на устройстве до правки, три ловушки `getevent -c N` одновременно):
нажатие давало на `event5` ровно `ABS_MT_TOUCH_MAJOR=100`, `BTN_TOUCH=1`,
`X=60`, `Y=850`, **без** `ABS_MT_TRACKING_ID`; на `event6` (mtk-tpd-kpd) и
`event1` (mtk-kpd) — ноль событий; счётчик `mtk-kpd` (irq 196) не двигался, а
`TOUCH_PANEL-eint` (irq 350) рос. То есть кнопка ёмкостная, на панели, и
firmware поднимает бит 0 в `key_value`.

FACT: `TPD_KEYS_DIM`, `GTP_KEY_TAB` и `TPD_HAVE_BUTTON` в этом драйвере —
мёртвый код (их читают GT928/GT910/GT9XX_hotknot_scp/ft5x46, но не наш);
живой путь гейтится только на `tpd_dts_data.use_tpd_button`, который равен 1 из
DT. `ABS_MT_TOUCH_MAJOR=100` тоже не от ширины кнопки: это хардкод в `tpd_down()`
для случая `size==0 && id==0`, там же пропускается tracking id.

Исправление (ядро, коммит `55c14fdc`, слит в master как `e56d6726`): отдавать
настоящий `EV_KEY` на `tpd->kpd`, код и геометрию брать из
`tpd_dts_data.tpd_key_local/tpd_key_dim_local` (бит 0 → `0x9e` = `KEY_BACK`),
`GTP_KEY_MAP_ARRAY` удалён. Заодно исправлен `tpd_button.c`: там
`j += sprintf(buf, "%s...", buf, ...)` складывал частичные длины, из-за чего
`/sys/board_properties/virtualkeys.mtk-tpd` отдавал 150 байт вместо 75.

FACT: userspace-половина маршрута уже была готова —
`/system/usr/keylayout/mtk-tpd-kpd.kl` содержит `key 158 BACK VIRTUAL`, менять в
ROM ничего не потребовалось.

Проверка после прошивки: `virtualkeys.mtk-tpd` = ровно **75 байт**; владелец
подтвердил, что кнопка работает как «Назад».

### Фонарик — РАБОТАЕТ (подтверждено владельцем)

FACT: два независимых дефекта.
1. Узел `flashlight { compatible = "mediatek,mt6737-flashlight" }` в стоковом DTB
   **ни к какому драйверу не привязывался**: строка `mt6737-flashlight`
   встречается только в DTS, потребителя не было. Замер до правки:
   в `/sys/devices/bus/bus:flashlight/` не было symlink'а `driver`. Поэтому
   pinctrl-состояния (`hwen_low/high`, `torch_*`, `flash_*`; GPIO9 HWEN,
   GPIO78 TORCH, GPIO80 FLASH) никогда не выбирались и HWEN оставался как его
   бросил LK. Тот же класс дефекта, что зарядник/alsps/lp3101, но здесь
   отсутствовал сам потребитель, а не совпадало имя.
2. Чип — **не LM3642**. Сток сохраняет имя драйвера `leds-LM3642`, но живой код
   у него `SY7806_*`: регистры 0x01 (enable/mode), 0x03/0x04 (flash),
   0x05/0x06 (torch), 0x08 (тайминги). У стокового `FL_Enable` от LM3642
   (пишущего 0x09/0x0A — на SY7806 это Temperature и read-only Flag1)
   **ноль вызывающих** во всём образе.

REJECTED: «включить dynamic debug на `leds_strobe.c` и посмотреть». `PK_DBG`
там разворачивается в **пустой** макрос (`DEBUG_LEDS_STROBE` закомментирован),
это не `pr_debug`, поэтому dynamic debug не напечатал бы ничего. Молчание ядра
объяснялось конфигом сборки и не было уликой о пути исполнения.

Исправление (ядро, коммит `ba5b9145`, слит как `80fd92ed`): привязать DT-узел
(`FLASHLIGHT_of_match` + `flashlight_gpio_init/set`), программировать реальный
SY7806, продублировать путь strobe id 2 (сток программирует чип именно оттуда),
логи поднять до `pr_info`.

Маркеры после прошивки, все сошлись: `flashlight_gpio_init done, ret = 0`;
`/sys/devices/bus/bus:flashlight/driver -> kd_camera_flashlight`;
на нажатии `FL_Enable: torch on, duty = 0, level = 0x23`,
`pin(0) state(1) ret(0)`, `strobe_main_sid2_part1: forwarding to the constant
flashlight strobe`; на отпускании `FL_Disable: off` + `pin(0) state(0)`.

FACT (новое, с железа): `FL_Enable: readback enable = 0x0b flag1 = 0x00
devid = 0x18` — регистр enable читается обратно тем же значением, что записали,
а **device id (рег 0x0C) = 0x18**. Идентификация чипа теперь замер, а не
вывод из стокового кода.

### Иконка камеры в лончере — восстановлена

FACT: приложение `org.cyanogenmod.snap` было установлено, включено и
запускалось (я поднимал его интентом, активность в фокусе, HAL отдавал полный
список параметров вплоть до 2560x1920), но в лончере иконки не было.
Причина: в `disabledComponents` пакета лежали
`com.android.camera.CameraLauncher` **и** `com.android.camera.DisableCameraReceiver`.

INFERENCE: это штатный механизм LOS — `DisableCameraReceiver` на первой загрузке
видит «камер в системе нет», убирает иконку и отключает сам себя. Он отработал
до того, как мы исправили i2c-адреса сенсоров, и его решение осталось
залипшим. Лечится одной командой:
`pm enable org.cyanogenmod.snap/com.android.camera.CameraLauncher`
(проверено, владелец подтвердил появление иконки). Стоит помнить как класс:
userspace-решения, принятые при сломанном железе, переживают починку железа.

### Поворот камеры — обе гипотезы опровергнуты на железе

REJECTED: таблица `SensorOrientation_T` в `libcameracustom.so`. Патч (main=270,
затем и main2=270) применён, `mediaserver` его действительно грузит
(проверено по `/proc/<pid>/maps`, отдельного `cameraserver` в этой сборке нет),
`dumpsys media.camera` всё равно отдаёт `Orientation: 90`. Причина промаха
агента: оба вызова `getSensorOrientation()` в `libcam.halsensor.so` лежат внутри
`ImgSensorDrv::sendCommand(SENSOR_DEV_ENUM,…)` — значение идёт ВНИЗ в ядро, а не
в `camera_info`.

REJECTED: 4-байтовая правка fallback'а в
`MetadataProvider::getDeviceWantedOrientation` (`libcam.metadataprovider.so`,
смещение `0x00015E06`). Патч загружен тем же процессом (md5 сверен на
устройстве), `Orientation` остался 90.

FACT (важнее самого поворота): в этих блобах **нет таблиц метаданных для наших
сенсоров вообще**. `strings | grep -oE 'SENSOR_DRVNAME_[A-Z0-9_]+' | sort -u`
по `libcam.halsensor.so`, `libcam.metadataprovider.so`, `libcameracustom.so`,
`camera.mt6737m.so` даёт ровно пять имён: GC0310, GC2145, GC2355, IMX135,
IMX219. Ни одного `S5K4H8`/`S5K5E8`. Поиск идёт через
`impConstructStaticMetadata_by_SymbolName`, поэтому для наших сенсоров
характеристики берутся из generic-заглушки MTK — не только ориентация.

INFERENCE: правильная цель — не гнуть fallback, а добавить таблицу метаданных
для `S5K4H8`/`S5K5E8`; тогда чинится и ориентация, и остальные статические
характеристики. Оба стоковых блоба восстановлены, устройство чистое.

### Цвет камеры — причина уточнена (лента продолжается)

FACT: калибровка главной камеры лежит **не в сенсоре**, а в отдельной EEPROM
**GT24C64A** на камерной i2c0, 8-битный write id `0xA0`: сток читает 1868 байт
таблицы шейдинга (`LscSize = 0x074C` в `Data[21..22]`) со смещения `0x51`,
раскладка как у MTK imx135 cam_cal. У нас `CONFIG_MTK_CAM_CAL` не включён вовсе,
драйвера нет → `ERR_NO_SHADING` и мусорная таблица.

FACT: сток выбирает вариант модуля по байту `0x0001` в EEPROM
(ofilm 5 / st 8 / holitech 9 / sunwin 0x0A) и затем сообщает sensor id
`0x4088 + offset`, чтобы `kd_sensorlist` отдал HAL соответствующее имя драйвера.
Фронтальный S5K5E8 использует OTP-страницу 4 сенсора (id `0x5E80..0x5E83`,
модули 3/7/9/0x0A) и несёт **только AWB, без шейдинга**.

REJECTED: «быстрый нейтральный шейдинг». Синтезировать единичную таблицу на
1868 байт без знания кодировки MTK — выдумывание; правильный драйвер — тот же
объём работы.

## 2026-08-17 (ночь, позже) TWRP на нашем ядре — новый инструмент отладки

Идея владельца, и она сняла главное ограничение диагностики.

FACT: стоковое ядро TWRP собрано **без** `CONFIG_DEVMEM` — попытка прочитать
физическую память в recovery даёт `ENXIO` даже после `mknod /dev/mem c 1 1`.
Наше 3.18 наоборот: `CONFIG_DEVMEM=y`, `CONFIG_DEVKMEM=y`,
`# CONFIG_STRICT_DEVMEM is not set`, `CONFIG_PROC_KCORE` не нужен.

Сделано: ramdisk TWRP взят из бэкапа раздела recovery
(`/tmp/m5c-backup-20260817/recovery.img` на девбоксе; ramdisk 10757538 B,
заголовок: kernel@0x40080000, ramdisk@0x44000000, page 2048, cmdline
`bootopt=64S3,32N2,64N2 androidboot.selinux=permissive`), к нему подставлено наше
ядро, образ собран заново и записан в раздел `recovery` (18606080 B из 33554432
доступных).

FACT (проверено на устройстве): recovery поднимается, `cat /proc/version` в нём
показывает `3.18.19 (root@n8nagent) #27`, присутствуют все 7 input-устройств,
монтирования работают, и `dd if=/dev/mem` **успешно читает физическую память**.

Зачем: маркеры ранней загрузки чужого ядра (например 4.9) теперь читаются
**прямо из recovery**, без загрузки Android. Путь: бутлуп → кнопками в recovery →
`dd if=/dev/mem`. Раньше читать умел только Android, а его загрузка сама
затирала исследуемые области памяти.

Ограничения recovery-окружения, о которые уже спотыкались: это busybox, поэтому
`od` понимает только флаги вида `-x`/`-c` (без `-t`), `dd` требует `bs=1` и
десятичный `skip`, `awk` отсутствует, `strings` есть.

FACT (контрольный опыт, отрицательный результат): адрес `0x43ff0800`
(= 1140787200), выбранный для маркеров 4.9 внутри окна minirdump
`reg=<0x43ff0000 0x10000>`, **перезагрузку не переживает**: строка
`FORGETEST01`, записанная из Android через `/dev/mem`, читается в той же
загрузке и обнуляется после ребута. Кроме того всё окно 64 КБ не является
свободным — дамп показывает живой Thumb-код. Значит нулевое чтение маркера
4.9 не доказывает, что ядро не дошло до `stext`: путь считывания был непригоден
изначально. Адрес нужно выбирать заново и **валидировать тем же опытом до**
того, как на него опираться.

Артефакты (вне эфемерного скретчпада), `artifacts/` в git игнорируется:
- `artifacts/recovery_ourkernel.img` sha256
  `d998ffaea68fb8ac4dc69e30d3bc6cd8207167f5f578ebb6cc0b0d4ff2b1151c`
- `artifacts/boot_mb_torch.img` sha256
  `1543e75feddc4b9b765d6f3b5649e49da2747cbac287fcfc99ad1d5fc008abd8`
  (рабочее 3.18: дисплей, тач, USB/зарядка, mBack, фонарик, опознанная камера)
- стоковый recovery сохранён на девбоксе, откат — прошивка его же в раздел.

INFERENCE: дальше стоит собрать TWRP полностью из дерева
(`Dekompilyator/twrp_meizu_m5c`, `OrangeFox_meizu_m5c`) уже на нашем ядре —
тогда в recovery будут и наши исправления тача/дисплея, и можно добавить
инструменты (xxd, полноценный od, python) для разбора маркеров на месте.
Текущая подмена ядра — быстрый вариант, который уже работает.

## 2026-08-17 (ночь, ещё позже) Камера: поворот исправлен, cam_cal читает EEPROM, цвет и фронталка открыты

### Поворот на 180° — ИСПРАВЛЕН (подтверждено владельцем)

FACT: значение, которое видит фреймворк, приходит по цепочке
`CameraService::getCameraInfo` → `camera.mt6737m.so:CamDeviceManagerBase::getDeviceInfo`
(`camera_info.orientation` ← `EnumInfo+20`) →
`CamDeviceManagerImp::enumDeviceLocked` (`EnumInfo+20` ← `IMetadataProvider` vtable+40)
→ `libcam.metadataprovider.so`.

FACT: решающая улика — собственная отладочная строка HAL в `camera.mt6737m.so`,
её видно в живом логе без всяких патчей:
`MtkCam/devicemgr: [enumDeviceLocked] [0x00] DeviceVersion:0x100 metadata:0x… facing:0 orientation(wanted/setup)=(90/90)`.
Она сразу показывает и `wanted`, и `setup`, и потому это самый дешёвый способ
проверки в этой ленте — дешевле и информативнее `dumpsys`.

FACT: `HalSensorList::buildStaticInfo` (`libcam.halsensor.so` @0xf524) делает
**двухуровневый** `dlsym`: сначала имя таблицы под конкретный сенсор, при
промахе — default-имя. Для наших сенсоров таблиц первого уровня нет (в блобах
присутствуют только GC0310, GC2145, GC2355, IMX135, IMX219), поэтому всегда
берётся `constructCustStaticMetadata_DEVICE_CAMERA_COMMON`
(`libcam.metadataprovider.so` @0x7bf4), где по `facing==0` стоит
`mov.w sl, #90` (@0x7cd0), и этот же регистр пишется в оба тега —
`MTK_SENSOR_INFO_ORIENTATION (0x000F000B)` и
`MTK_SENSOR_INFO_WANTED_ORIENTATION (0x000F0012)`.

Правка: 4 байта по файловому смещению `0x00006CD0`,
`4f f0 5a 0a` (`mov.w sl,#90`) → `4f f4 87 7a` (`mov.w sl,#270`). Ветка
`facing==1` (фронталка) уже давала 270 и не тронута. Проверено на устройстве:
`dumpsys media.camera` → `Orientation: 270`, лог HAL → `(270/270)`, владелец
подтвердил, что превью и снимок больше не перевёрнуты.

REJECTED (две предыдущие версии, обе проверены прошивкой на железе):
1. таблица `SensorOrientation_T` в `libcameracustom.so` — оба вызова
   `getSensorOrientation()` лежат внутри
   `ImgSensorDrv::sendCommand(SENSOR_DEV_ENUM,…)`, т.е. значение идёт ВНИЗ в
   ядро, а не в `camera_info`;
2. NOP'ирование хардкода `90` в fallback'е
   `MetadataProvider::getDeviceWantedOrientation` — лог `(90/90)` при
   загруженном патче доказал, что теги выставлены и fallback не исполняется.

Ловушка на будущее: константы `#90` (@0x7ec6) и `#66` (@0x7d0a) в том же файле —
это **номера строк для логов**, не градусы. Слепой grep по `#90` уводит в сторону.

Минус выбранного решения записан: правка живёт в прибилде и умрёт при следующем
прогоне `extract-files.sh`; страховка — скрипт `patch_camera_orientation.py`
(`--check/--apply/--revert`) и эта запись. Альтернатива «добавить нормальную
таблицу метаданных под наши сенсоры» отвергнута не по лени: поиск идёт по имени
символа, и наша библиотека действительно перебила бы default, но таблица первого
уровня **заменяет всю категорию**, а не дополняет — пришлось бы воспроизвести
все теги COMMON-таблицы против реверс-инженерного ABI, и любой пропущенный тег
стал бы молча потерянной характеристикой камеры.

### cam_cal / OTP — драйвер читает EEPROM, но HAL стучится в чужой узел

FACT: калибровка главной камеры лежит в EEPROM **GT24C64A** на камерной i2c0,
8-битный write id `0xA0`; 1868 байт LSC по смещению `0x51`, `LscSize = 0x074C`
в `Data[21..22]`. Вариант модуля сток определяет по байту `0x0001`
(ofilm 5 / st 8 / holitech 9 / sunwin 0x0A). Фронтальный S5K5E8 использует
OTP-страницу 4 самого сенсора и несёт только AWB, шейдинга там нет.

Сделано (ветка `forge/camotp`, слита как `07e2a164`): портированы cam_cal-драйверы
для восьми вариантов модулей, к ним добавлены права в ramdisk —
`chmod 0660` + `chown system camera` на восемь узлов после строк
`/dev/CAM_CAL_DRV` в `init.mt6735.rc` (без этого узлы создаются как
`root:root 0600` и HAL получает `EACCES`).

FACT (на железе, работает): все восемь узлов есть с правами
`system:camera 0660`; EEPROM реально читается —
`[S5K4H8_OTP] S5K4H8_ST_OTP LSC 1868 bytes read, first=0xff 0x00 0x02 last=0x58`;
вариант разрешается — `camera module id 8 -> variant 1, sensor id 0x4089`;
и HAL впервые запускает обработку шейдинга (`ShadingTrans_RA: [LscRaSwMain]`,
`isp_tuning_custom: [evaluate_Shading_CCT_index] … i4CCT = 6500`) вместо
прежнего `ERR_NO_SHADING`.

FACT (остающийся дефект): HAL открывает **не тот** узел —
`S5K4H8_SUNWIN_OTP`, при том что модуль ST:
ядро пишет `S5K4H8_SUNWIN_OTP opened but no calibration was read`, HAL —
`s5k4h8_sunwinErr: LayoutType= 0x5`, `result= 0x8fffffff`,
`Return ERROR ERR_NO_3A_GAIN`. То есть sensor id, который мы сообщаем для
модуля 8 (`0x4089`), HAL сопоставляет с sunwin-именем, а не с st.

FACT: цвет после этой прошивки стал **хуже**, а не лучше: пятна крупнее и
насыщеннее (кадры сохранены:
`captures/20260817-camera/01_before_camcal_rainbow.jpg` и
`02_after_camcal_worse.jpg` с хешами). Геометрия, резкость и ориентация при этом
правильные.

INFERENCE: судить о цвете пока нельзя — HAL получает данные из узла, в который
ничего не прочитано, и, видимо, откатывается на что-то ещё худшее. Сначала
нужно согласовать соответствие «вариант → имя драйвера», и только потом
измерять цвет.

Открыто также: `[Read_CamOtpInfo_CheckSum] read otp module flag fail!!!` →
`[Otp_Calibration] read otp fail` → `[open] otp apply fail` — это путь OTP
внутри самого сенсора (не EEPROM); безвреден он или что-то блокирует, пока не
установлено.

### Фронтальная камера отсутствует — её не ищут вовсе

FACT: `dumpsys media.camera` → `Number of camera devices: 1`.
FACT: за всю загрузку в ядре **ни одной** попытки опроса sub-сенсора: нет строк
`s5k5e8yx`, нет обращений `i2c write id: 0x78`, нет `GetSensorID` на слоте SUB.
Единственная строка про эту шину — `i2c-bus2 speed is 100Khz`. Для сравнения,
главный сенсор опрашивается и отвечает (`i2c write id: 0x20, sensor id: 0x4088`).
FACT: при этом cam_cal-узлы фронталки регистрируются нормально
(`/dev/S5K5E8_ST_OTP registered (major 235)` и три остальных).

INFERENCE: молчание на слоте SUB — это не отказ i2c, а отсутствие запроса:
HAL просит `SENSOR_DRVNAME_S5K5E8_ST_MIPI_RAW`, и если ядро объявляет драйвер
под другим именем, HAL просто не поручает ядру опрашивать слот SUB.
Проверяется сверкой имени, которое реально объявляет наш sub-драйвер, с тем,
что запрашивает HAL.

## 2026-08-17 (ночь) 4.9 arm64: ядро доходит до включения MMU

Три попытки прошивки, все три с бутлупом, но третья дала точную точку смерти.

### Инструмент: валидация адресов маркеров

FACT: маркеры ранней загрузки бессмысленны без доказательства, что выбранный
адрес переживает сброс И загрузку читателя. Метод (делается из recovery на нашем
ядре, без участия владельца): записать по каждому кандидату свою ASCII-метку
через `/dev/mem`, убедиться что читается в той же загрузке, `adb reboot recovery`,
прочитать снова.

Результаты проверки (десятичные смещения для `dd bs=1 skip=`):
- `0x43ff0800` (1140787200) — **затирается** (первая попытка, окно minirdump);
- `0x44800000` (1149239296) — **затирается**;
- `0x4e100000` (1309671424) — **затирается**;
- `0x5f000000` (1593835520) — **выживает**;
- `0x7f000000` (2130706432) — **выживает**;
- `0xb0000000` (2952790016) — **выживает**.

INFERENCE, почему первые погибли: `0x44800000` выбирался «за концом ramdisk», и
для загрузочного ramdisk LOS (1.6 МБ по 0x44000000) это верно — но читателем
выступает **recovery**, а ramdisk TWRP весит 10757538 B и занимает примерно
`0x44000000…0x44A40000`, проглатывая `0x44800000`. `0x4e100000` лежит сразу за
областью tags/DTB (`0x4e000000`). То есть оба погибли не от умирающего ядра, а
от самого читателя — ровно тот класс ошибки, который контрольный опыт и ловит.

### Результат P3 (boot_49_p3.img, sha256 caa57b3c…)

Образ: Image.gz #9 ядра `4.9.188-m5c+`, `code0 = 0x142c8000` (EFI-stub выключен —
у P0 был EFI-«MZ» 0x91005a4d), стоковый DTB внутри (md5 `e17a0910…`, 69427 B),
ramdisk LOS. Маркеры пишутся в оба валидированных адреса.

FACT (прочитано из recovery сразу после бутлупа, по обоим адресам независимо):
```
0000000  4f46 4752 3445 0039 ...        F O R G E 4 9
0000020  4101 4152 ...  4102 4152 ...   веха 1, веха 2
0000040  4103 4152 ...  4104 4152 ...   веха 3, веха 4
```
То есть присутствуют магия и **все четыре вехи**: вход в `stext`,
пройден `el2_setup`, построены таблицы страниц, пройден `cpu_setup`.

FACT: ни `/proc/last_kmsg` (65570 B), ни `/sys/fs/pstore/console-ramoops` не
содержат вывода 4.9 — в обоих только предыдущая 3.18-сессия (заголовок
`hw_status: 5`, строки про `agpsd` и `charging_hw_fan5405`).

INFERENCE: смерть наступает на **включении MMU / релокации / раннем C-коде** до
`console_initcall`. Это качественный сдвиг относительно P0/P1, где не было вообще
ничего: загрузчик передаёт управление, формат образа принят, CPU поднимается,
ассемблерная инициализация проходит целиком. Значит сама идея arm64-ядра 4.9 на
этом железе не упирается ни в LK, ни в заголовок Image, ни в bring-up CPU.

Замечено к проверке: восемь байт сразу после магии различаются между адресами
(`0000 7200 0000 7200` против `e07c 000f 0000 0000`) — если поле должно быть
одинаковым, там ещё что-то.

Следующий шаг (передан агенту): вехи ЗА переключением MMU — сразу после
`__enable_mmu`, после релокации/`__primary_switch`, на входе в `start_kernel`,
после `setup_arch` и `paging_init`; плюс отметка из C с включённым MMU, чтобы
проверить линейную карту (при включённом MMU запись по физическому адресу
требует корректного отображения, поэтому нужна запись по виртуальному адресу в ту
же физическую страницу). Оба валидированных адреса сохранить: доверие к чтению
дало именно совпадение двух независимых копий.

REJECTED (обосновано агентом, зафиксировано): дублировать маркер в область
ram console `0x43f00000`, чтобы он всплыл в `last_kmsg`. Чтобы вывод был
читаемым, пришлось бы воспроизвести структуру `ram_console_buffer`
(`off_*`/`log_start`/`log_size` + `ram_console_check_header`), иначе получится
«header may be corrupted», а сырая запись в эту область рискует затереть то, что
умирающее ядро могло бы записать само.

## 2026-08-17 (глубокая ночь) 4.9 arm64: дошли до конца console_init

Восемь прошивок за сессию, каждая читалась маркерами из recovery на нашем ядре.
Подробности по каждой — в `M5C_KERNEL_49_BUILD_LOG.md`; здесь итог и то, что
стоит помнить как метод.

### Пройденные точки (FACT, по маркерам на двух независимых адресах)

Ассемблерная инициализация (вход в `stext`, `el2_setup`, таблицы страниц,
`cpu_setup`) → включение MMU → `early_ioremap` → разбор стокового DTB
(`setup_machine_fdt`) → `arm64_memblock_init` → `paging_init` → возврат из
`setup_arch` → `start_kernel` → `mm_init` → `sched_init` → **`init_IRQ`** →
**`time_init`** → **`console_init` целиком** (веха 20 встала).

### Два дефекта, найденные дифом с нашим рабочим 3.18 — без прошивок

FACT (init_IRQ): наше 3.18 arm64 управляет этим GIC драйвером
`CONFIG_MTK_GIC=y` → `drivers/irqchip/irq-mt-gic.c`, причём `CONFIG_MTK_IRQ`
у него выключен. В дереве 4.9-lc файла `irq-mt-gic.c` нет вовсе, и был включён
единственный имевшийся `misc/mediatek/irq/mt6735/irq.c` — но mt6735 в 4.9-lc
существовал только как arm32, и этот драйвер на arm64 не работал никогда.
То есть умирал не «GIC вообще», а чужой arm32-драйвер. Лечение: портирован
проверенный на железе 3.18-й `irq-mt-gic.c` с правками API-дрейфа.
Подтверждено прошивкой: веха `init_IRQ пройден` встала.

FACT (console_init): `ram_console_early_init` версии Q0 требует от загрузчика
контракт `chosen/ram_console` + `memory_info` и на любое отклонение зовёт
`ram_console_fatal()` → `BUG()`, то есть тихая паника до появления консоли и
WDT-бутлуп. Стоковый LK 2017 года такого контракта не даёт. Наше рабочее 3.18
этот контракт вообще не читает: фиксированные `0x43F00000/0x10000` и pstore
`0x43F10000/0xE0000` — ровно окна `reserved-memory` стокового DTB, все ошибки
мягкие. Лечение: `BUG()` убран, при отсутствии контракта — падение назад на
3.18-раскладку. Подтверждено: `console_init` прошёл.

INFERENCE (метод, сработавший дважды): когда чужое ядро умирает в подсистеме,
которой наше рабочее 3.18 управляет на том же железе из того же DTB, дешевле
сравнить два драйвера в исходниках, чем ставить ещё маркеры. Оба этих дефекта
закрылись без единой прошивки на диагностику.

### Инструментальные выводы (пригодятся в любой похожей работе)

FACT: маркеры ранней загрузки бессмысленны без доказательства, что адрес
переживает и сброс, и загрузку читателя. Из шести кандидатов три оказались
непригодны (`0x43ff0800`, `0x44800000`, `0x4e100000`), три выжили
(`0x5f000000` = 1593835520, `0x7f000000` = 2130706432, `0xb0000000` =
2952790016). Причина провала: ramdisk TWRP весит 10.7 МБ и занимает
`0x44000000…0x44A40000`, то есть проглатывает «свободный» адрес за концом
загрузочного ramdisk; а `0x4e100000` лежит сразу за областью tags/DTB.

FACT: читатель может затирать улику. Область ram console `0x43f00000` к моменту
чтения уже переиспользована нашим же recovery-ядром (в начале лежит магия
`DBGC` работающего ядра), а `/proc/last_kmsg` показывает предыдущую 3.18-сессию.
Поэтому текст 4.9 из штатного окна получить нельзя.

Открыто: первый настоящий лог 4.9. Предложено направить его ram console на
`0x5f000000` — адрес, проверенный на выживание и не занятый ни маркерами, ни
`reserved-memory` стокового DTB. Тогда отсутствие текста там будет чистым
доказательством проблемы в пути записи, а наличие — переводом отладки с маркеров
на настоящий лог.

## 4.9 arm64: P10 — ядро исполняется и висит по watchdog, путь записи лога всё ещё мёртв (2026-08-17)

Прошит `boot_49_p10.img` (sha256 `721dcd2645e3445955426b17df0b5356cbb1f93052f695c3e280c4aee344cbf7`,
9459712 Б), в котором `register_console(&ram_console)` сделан безусловным.

FACT (идентичность артефакта): обратное чтение раздела `mmcblk0p7` совпало с
образом бит-в-бит, md5 `4177d97086698435d1169f6e35362dc1` — но только при
сравнении **файлов**. Первые две попытки посчитать md5 диапазона раздела через
пайп (`dd | md5sum` и `dd | dd bs=1 count=N | md5sum`) дали два РАЗНЫХ и оба
неверных ответа: toybox `dd` делает короткие чтения через пайп. Инструментальный
вывод: сверку хэшей раздела всегда вести через `dd` в файл, затем `md5sum` от
файлов.

FACT (свежесть, ядро действительно исполнялось): в окне `0x5f000000` появилось
поле, которого в P9 не было — по смещению `0x208` значение `1e ab 15 0d`, по
`0x210` указатель `0xffffff8008da0fe8`. Это диапазон ядерного маппинга arm64
**4.9**; у нашего 3.18 указатели вида `0xffffffc0…`. То есть запись сделана
ядром-под-тестом, а не осталась от предыдущей сессии. Заголовок тот же:
`DBGC`, `off_console=0x5c0`, `sz_console=0xfa40`.

FACT (характер смерти): `/proc/cmdline` последующей загрузки recovery содержит
`androidboot.bootreason=wdt_by_pass_pwk` и `boot_reason=4` — предыдущая загрузка
завершилась сбросом по watchdog. Значит ядро **висло**, а не паниковало.

REJECTED: «бутлуп удлинился с ~50 до ~90 с, значит ядро прошло дальше». При
смерти по watchdog время до сброса задаётся таймаутом WDT от последнего kick, а
не глубиной загрузки. Прежняя INFERENCE снята как неподтверждённая.

FACT (root cause остаточной тишины, вторая развилка того же `#ifdef`): в
`drivers/misc/mediatek/ram_console/mtk_ram_console.c` у `sram_log_save()` ДВЕ
реализации. Под `#ifdef CONFIG_PSTORE` (стр. 289) собирается стр. 295:
`sram_log_save() { pstore_bconsole_write(NULL, msg, count); }`. Настоящий
писатель в DRAM лежит в ветке `#else` (стр. 333–373) и при `PSTORE=y` не
компилируется вовсе. А `fs/pstore/platform.c:612 pstore_bconsole_write()`
начинается с `if (psinfo)`, то есть является тихим no-op, пока ramoops не
зарегистрировался на device-initcall. Итог: `register_console` из P10 честно
вызывает `ram_console_write` → `sram_log_save` → в пустоту. Заголовок пишет
инициализация, тело не пишет никто — ровно наблюдаемая картина (23 ненулевых
байта на 64 КБ).

Рецепт (передан в лоту 4.9 для P11): вынести DRAM-писателя из `#else` под
отдельным именем, компилировать всегда, вызывать из `ram_console_write()`;
форвард в pstore можно оставить рядом, конфликта нет (у pstore своя консоль
`pstore_console`). Обязательно вернуть в сборку `ram_console_size()` и проверку
границ в `aee_sram_fiq_log()` — они спрятаны под тем же `#ifndef CONFIG_PSTORE`,
без них DRAM-писатель останется без bounds-проверки. Флаги консоли
`CON_PRINTBUFFER | CON_ANYTIME` означают, что после фикса в теле должна лечь вся
загрузка с первого `printk`, включая `Linux version`.

INFERENCE (метод): различай «нет ни магии, ни текста» (не тот адрес / область не
выжила / не дошло до инициализации) и «магия и поля заголовка есть, тело пусто»
(инициализация прошла, мёртв путь записи). Второй случай — дефект кода, а не
ранняя смерть, и маркерами не диагностируется. Развилок по `CONFIG_PSTORE` в
этом файле несколько: починив одну, надо grep'ом проверить остальные, иначе тот
же пустой лог получается второй раз подряд (что и произошло между P9 и P10).

Этот опыт вынесен в переиспользуемый скилл `~/.claude/skills/mtklogs/` (каналы
логов по этапам загрузки, дерево диагностики пустого окна, обязательная проверка
свежести, ловушки toybox/TWRP/квотинга, скрипт `scripts/pull_dram.sh`, проверенный
на этом телефоне).

Открыто: первый настоящий текст лога 4.9 — после P11. В момент записи телефон
оставлен в TWRP в ожидании P11; резервная копия рабочего 3.18-boot лежит на
устройстве как `/sdcard/ba.img`.
