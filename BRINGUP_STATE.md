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

## 4.9 arm64: P11 — ПЕРВЫЙ НАСТОЯЩИЙ ЛОГ, обрыв на подъёме вторичных CPU (2026-08-17)

Прошит `boot_49_p11.img` (sha256 `07f341b5a9063274394d2a66dc2d39b9ab0b88d7f6a392af6945e0f55f6c8d12`),
в котором DRAM-писатель вынесен из ветки `#else` в always-compiled
`ram_console_dram_save()` и вызывается из обоих вариантов `sram_log_save`.
Readback раздела бит-в-бит, md5 `e5b65d8666af27f0c0c4de7ece3b015e`.

FACT: путь записи ожил. В окне `0x5f000000` 9275 ненулевых байт, 103 строки,
`log_size=0x2420`. Свежесть: `Linux version 4.9.188-m5c+ … #21 SMP PREEMPT Mon
Aug 17 18:14:28 MSK 2026` — сборка P11. Капчур:
`captures/20260817-49-p11/` (`rc49_p11.bin` sha256 `8db055f5…cb92`,
плюс расшифрованный `rc49_p11.log`).

FACT: фолбэк раскладки работает как задумано —
`ram_console: [DT] offset:0x0 illegal` → `no LK memory_info, using m5c debug
layout @0x5f000000` → `buffer start: 0xffffff8008015000, size: 0x10000` →
`console [ram-1] enabled`.

FACT: `start_kernel` пройден ЦЕЛИКОМ. Пройдены init_IRQ, arch timer
(`Architected cp15 timer(s) running at 13.00MHz`), `console [ttyMT0] enabled`,
calibrate_delay, pid_max, Security Framework, `SELinux: Initializing.`,
mount-cache. Последние строки:

```
init_heavy_tlb: cid=-1 is out of nr=1   (cpu=0..3, thresh_l=0 thresh_h=0 max_capaicy=0)
[0.000000]  (0)[1:swapper/0]Invalid sched_group_energy for CPU0
[0.000000]  (0)[1:swapper/0]CPU0: update cpu_capacity 1024      <- последняя
```

FACT: обрыв не по переполнению — занято 9248 из 64064 байт, оборачивания нет.
FACT: префикс сменился с `[0:swapper]` на `[1:swapper/0]`, то есть `rest_init`
отработал и это поток `kernel_init`. Ожидаемых `CPU1: Booted secondary
processor` и `Brought up 4 CPUs` нет.

INFERENCE: зависание в `kernel_init` → `sched_init_smp`/`smp_init`, на подъёме
вторичных ядер, с последующим сбросом по watchdog (характер смерти установлен на
P10).

Гипотезы с опровергающими тестами (в работе у лоты 4.9):
- H1 (главная): виснет подъём вторичных CPU; PSCI v0.1 с function ID из DT,
  MTK hotplug/MCDI. Тест: `maxcpus=1` — если лог уходит дальше, подтверждено.
- H2: MTK-шные EAS/heavy-tlb получают пустую топологию (`nr=1`, `max_capaicy=0`,
  `sched-energy: CPU device node has no sched-energy-costs`) и зацикливаются.
  Тест на различение: печатает ли наше рабочее 3.18 те же строки.
- H3: ядро живо, а ослепла запись — `ram_console_write` выходит сразу при
  `rc_in_fiq`, который ставят `aee_disable_ram_console_write()` и
  `aee_sram_fiq_log()`. Тест: маркер-слот ПОСЛЕ `smp_init`; выставится при пустом
  хвосте лога — виснем не там, где кончился текст.

Два расхождения, подлежащие сверке с 3.18 (могут быть безвредны, но подозрительны):
FACT `sched_clock: 64 bits at 250 Hz` — дженерик jiffies-овый, а не arch timer на
13 МГц; отсюда все метки времени `0.000000`. Если 3.18 регистрирует sched_clock от
arch timer, то в 4.9 источник времени не встал, а от него зависят и watchdog kick,
и таймауты подъёма CPU — тогда H1 становится следствием, а не причиной.
FACT `NR_IRQS:64 nr_irqs:64 0` — у рабочего 3.18 на этом же железе живёт IRQ 494,
то есть домен там заведомо больше 64; сверить, не поднял ли GIC в 4.9 урезанный домен.
`Fail to set polarity of interrupt 29/30` — это PPI, регистров полярности в MTK
SYSIRQ у них нет; вероятно шум, сверить заодно.

## 4.9 arm64: P12/P13 — вис в pre-smp initcalls, подъём вторичных ядер НЕ ВИНОВАТ (2026-08-17)

### P12 (`maxcpus=1`): улики уничтожены жёстким сбросом

Прошит `boot_49_p12.img` (sha256 `41a15259377a01be56abe49e538b21b0283ae16d20715d28845376f767116727`)
— ядро p11 байт-в-байт, изменена только cmdline (добавлен `maxcpus=1`).

FACT: телефон завис **на бутлого** (наблюдение владельца; логотип рисует LK) и,
в отличие от P10/P11, сам в recovery не вернулся: за 200+ с ни adb, ни fastboot,
и на USB-шине девбокса устройства нет вовсе (`lsusb` показывает только хаб,
клавиатуру и второй телефон). Отдельно проверено, что пустой `adb devices` был
следствием умершего adb-сервера в контейнере, а не отсутствия устройства: после
`kill-server/start-server` второй телефон вернулся, m5c нет.

FACT: после ручного входа в TWRP окно `0x5f000000` не содержит магии `DBGC`
(мусор, 4486 ненулевых байт со смещения ~0x5000), а окно маркеров `0x7f000000`
**полностью нулевое** — при том, что маркеры 1–20 присутствовали в каждом
предыдущем чтении. Вывод: DRAM потеряла содержимое. Вис без watchdog прерывается
только длинным нажатием power, то есть жёстким сбросом питания через PMIC, а он
гасит DRAM. Лога и маркеров P12 не существует; дамп сохранён как
`captures/20260817-49-p13/markers_p12_wiped.bin` для сравнения.

Методический вывод, обязательный для дальнейших диагностических сборок: пока
ядро умирает рано, WDT даёт **тёплый** сброс и улики выживают; как только ядро
доходит до ядерного драйвера WDT и разоружает железный watchdog, любой
последующий вис стирает DRAM вместе с логом. Поэтому диагностические сборки
должны либо не включать `CONFIG_MTK_WDT`, либо не давать драйверу разоружать
железный WDT. Иначе прогресс по загрузке выглядит как регресс по улике.

HYPOTHESIS (не подтверждена, улики стёрты): отсутствие сброса по watchdog на P12
означало, что ядро дошло до device-initcalls и разоружило WDT, то есть
`maxcpus=1` снял вис. С учётом P13 (вис уже на 12 мс, до smp_init) плохо
согласуется; отдельно не проверяется — `initcall_debug` даст ответ дешевле.

### P13 (mt_gpt + маркеры SMP-пути): H1 REJECTED

Прошит `boot_49_p13.img` (sha256 `5ecd987784e73f1037e6c266c85701d2dd04f9748d8c8090276af18422b7b320`),
вернулся в recovery через 65 с (WDT, улики целы). Капчур:
`captures/20260817-49-p13/`.

FACT: фикс mt_gpt (второй `CLOCKSOURCE_OF_DECLARE` на стоковый
`compatible="mediatek,mt6735-apxgpt"`) работает — метки времени настоящие.
Первая `[0.000000]`, последняя `[0.012000]`: **ядро умирает через 12 мс**, а
watchdog добивает его лишь через ~60 с.

FACT: лог обрывается точно там же, где на P11, теми же строками:
`init_heavy_tlb start.` → `cid=-1 is out of nr=1` / `cpu=0..3 thresh_l=0
thresh_h=0 max_capaicy=0` → `[0.011985] (0)[1:swapper/0]Invalid
sched_group_energy for CPU0` → `[0.012000] (0)[1:swapper/0]CPU0: update
cpu_capacity 1024`.

FACT: слоты маркеров (`0x7f000000`, зеркало `0xb0000000` совпадает): выставлены
1–18, 20 и **21, 22, 23, 24**; **НЕ выставлены 25–30**. Слот 19 содержит
указатель `0xffffff80bd085c7d` (штатная разметка, не маркер).

REJECTED (H1, «зависает подъём вторичных ядер»): слот 25 «cpu_boot вошёл» не
выставлен — путь подъёма вторичного ядра вообще не начинался, ни SMC PSCI, ни
mtcmos POWER_ON-полл к делу не относятся. Прежняя формулировка «виснет на
подъёме вторичных CPU» (P11) была слишком широкой и теперь снята.

INFERENCE (локализация): слот 22 «после `smp_prepare_cpus`» выставлен, слот 28
«до `smp_init`» — нет. Значит вис строго в окне между возвратом
`smp_prepare_cpus` и вызовом `smp_init`; в 4.9 `kernel_init_freeable()` в этом
окне содержит `do_pre_smp_initcalls()` и `lockup_detector_init()`. Последняя
строка лога напечатана из PID 1, что согласуется.

INFERENCE (уточнение до цикла): в раннем проходе (PID 0) этот код печатал пару
строк на каждое ядро — CPU0, затем CPU1. В проходе из PID 1 напечатан только
CPU0, до CPU1 дело не дошло. То есть вис внутри цикла по ядрам в MTK-шном
energy/capacity-коде, получающем пустую топологию. H2 становится главной.

Следующие пробы (переданы в лоту 4.9): (1) `initcall_debug` в cmdline — в логе
P13 ноль строк `calling `, флаг выключен, а рабочее 3.18 грузится с ним; с ним
последняя строка назовёт зависший initcall по имени без правки кода; (2)
маркеры-скобки на `do_pre_smp_initcalls()` и `lockup_detector_init()`; (3)
конфиг-опыт: выключить MTK-шные EAS/heavy-tlb, которых на рабочем 3.18 нет
вовсе, вместо попыток починить топологию.

## 4.9 arm64: P15 — вис локализован в `workqueue_init()` (2026-08-17)

Прошит `boot_49_p15.img` (sha256 `42952abc72e51767d14b22e5ae0e375fc5763b3a01e7db8f38ae66435a5aeea5`)
= p13 + `initcall_debug` в cmdline + маркеры 31 (`workqueue_init` прошёл) и 32
(pre-smp initcalls прошли). Капчур: `captures/20260817-49-p15/`.

FACT (улика 1, маркеры): выставлены 21–24, **не выставлены 25–32**, включая новые
31 и 32. `workqueue_init()` не завершился.

FACT (улика 2, независимая): `initcall_debug` доехал до ядра (присутствует в
`Kernel command line`), но в логе **ноль** строк `calling ` — ни один initcall не
исполнялся. Лог кончается той же строкой, что на P11 и P13:
`[0.011967] (0)[1:swapper/0]CPU0: update cpu_capacity 1024`.

INFERENCE: зависание внутри **`workqueue_init()`**, до первого initcall.
`do_pre_smp_initcalls()` и `lockup_detector_init()` из подозреваемых выбывают.
В 4.9 `kernel_init_freeable()` вызывает `workqueue_init()` сразу после
`smp_prepare_cpus()`, что согласуется с маркерами 22 (стоит) и 31 (нет).

REJECTED (моя трактовка P13 «виснет в цикле energy-кода на переходе к CPU1»):
проверено прямым подсчётом строк лога — в раннем проходе (PID 0) цикл прошёл ВСЕ
четыре ядра (строки 37–44: CPU0, CPU1, CPU2, CPU3, затем четыре
`Invalid sched_group_energy` подряд), а строка при PID 1 одиночная и печатается
из `store_cpu_topology(cpu0)` внутри `smp_prepare_cpus`. Цикл к висанию
отношения не имеет; та строка — просто последняя печать перед тихой зоной.

Следующая проба (в работе): скобки-маркеры внутри `workqueue_init()` по
участкам — `wq_numa_init()`; цикл `for_each_online_cpu` с созданием per-cpu пулов
и `BUG_ON(!create_worker(pool))`; создание unbound/ordered wq; `wq_watchdog_init()`
— и отдельно вокруг первого `create_worker()`, то есть первого в этом окне
создания и пробуждения kthread. Замечание: `create_worker()` при неудаче даёт
`BUG_ON`, а не вис, поэтому «висит» указывает скорее на пробуждение/планировщик,
чем на нехватку памяти. Косвенно в ту же сторону: `init_heavy_tlb start.`
печатается на 0.011714 и вызывается лениво из планировочного хука
`sched_update_nr_heavy_prod`, то есть хук MTK уже срабатывал.

FACT (уточнение к конфиг-опыту H2, чтобы не строить вывод на ложной посылке):
`init_heavy_tlb` живёт в `drivers/misc/mediatek/sched/sched_avg.c` под
`CONFIG_MTK_SCHED_RQAVG_KS`. Эта опция включена и в 3.18-defconfig
(`CONFIG_MTK_SCHED_RQAVG_KS=y`, `_US=y`, строки 1338–1339) — просто в
3.18-исходниках функции `init_heavy_tlb` нет вовсе. То есть конфиги тут
совпадают, различается код за одним и тем же именем опции; выключение в 4.9
остаётся осмысленным опытом, но не как «приведение к рабочему конфигу».
FACT: `CONFIG_MTK_UNIFY_POWER`, `CONFIG_SCHED_TUNE`, `CONFIG_ENERGY_AWARE` в
m5c_defconfig отсутствуют — upower-ветки `cpu_core_energy`/`cpu_cluster_energy`
скомпилированы вне, полноценный EAS не включён, поэтому механизм «вис в
energy-aware выборе ядра при пробуждении» ослаблен.

## 4.9 arm64: P16 — вис сузился до bind/attach/wake первого воркера (2026-08-17)

Прошит `boot_49_p16.img` (sha256 `a1a399fb3c66c8a4e9a7c19b3047e1bd58304907018d7781da228c6a73e6d888`),
recovery через 65 с. Слоты (`captures/20260817-49-p16/fD_p16.bin`):

FACT: 33 (+272) вход в `workqueue_init` — стоит; 38 (+312) первый `create_worker`
вошёл — стоит; **39 (+320) `kthread_create_on_node` вернулся — СТОИТ**;
40 (+328) первый воркер разбужен — НЕТ; 35 (+288) per-cpu цикл — НЕТ;
36 (+296) unbound-пулы — НЕТ.

REJECTED (гипотеза «вечно ждём kthreadd»): `kthread_create_on_node()` ставит
запрос в `kthread_create_list`, будит `kthreadd_task` и блокируется на
`wait_for_completion_killable()`. Раз она вернулась (маркер 39), запрос обслужен,
то есть **kthreadd (PID 2) исполнялся и планировщик способен переключать
задачи**. Оговорка: маркер 39 стоит до проверки `IS_ERR`, поэтому формально не
различает «создан» и «ошибка»; но при ошибке был бы `goto fail` → NULL →
`BUG_ON(!create_worker(pool))` → печать BUG, которой в логе нет. Значит поток
создан.

INFERENCE: вис в участке между 39 и 40, где ровно четыре шага —
`set_user_nice()`, `kthread_bind_mask()`, `worker_attach_to_pool()`, затем блок
`spin_lock_irq(&pool->lock)` → `worker_enter_idle()` → `wake_up_process()` →
`spin_unlock_irq()`.

HYPOTHESIS (главная, с проверкой): `kthread_bind_mask()` →
`__kthread_bind_mask()` → `wait_task_inactive()`, который в цикле зовёт
`schedule_timeout_uninterruptible(1)`. Это **первая точка за всю загрузку, где
требуется продвижение jiffies**, то есть таймерное прерывание: до неё ядро ни
разу не спало и не ждало таймаута. Метки времени в логе идут от `sched_clock`
(mt_gpt) и про приход тика ничего не доказывают — механизмы независимы. К этому
же примыкает незакрытое расхождение с 3.18: там clockevent — MTK-шный
`ca53_timer`, у нас дженерик `arm_arch_timer`, и только у 4.9 печатается
`Fail to set polarity of interrupt 29/30` (ранее списано в косметику — снято с
косметики). Falsification: записать ЗНАЧЕНИЯ `jiffies` и
`arch_counter_get_cntpct()` в слоты в двух точках; растущий счётчик при
неподвижных jiffies = тик не приходит.

HYPOTHESIS (вторая): `wake_up_process()` внутри `spin_lock_irq(&pool->lock)` —
прерывания выключены, поэтому вис в пути размещения задачи при вырожденной
топологии (`cluster_id=-1` у всех ядер, capacity 0) даёт абсолютную тишину без
watchdog-печатей. Falsification: скобки после каждого из четырёх шагов.

P17 (маркеры внутри `kthreadd`) НЕ прошивался: он отвечает на вопрос, уже
закрытый маркером 39. Запрошен P18 = скобки 39→40 + свидетели-значения jiffies /
arch counter + опционально маркер в `arch_timer_handler_phys()`.

## 4.9 arm64: P18 — ДОКАЗАНО, таймерное прерывание не приходит ни разу (2026-08-17)

Прошит `boot_49_p18.img` (sha256 `8c39250af0b44876cd30ae20ba143235ddb3d7e61763b4b52a857e0169d5ec68`),
recovery через 65 с. Слоты: `captures/20260817-49-p18/fD_p18.bin`.

FACT (скобки): 33, 38, 39, 41, 42, 43, **44 (`set_user_nice` прошёл)** —
выставлены; **45 (`kthread_bind_mask` прошёл)**, 46, 40, 35, 36 — нет.
Вис внутри `kthread_bind_mask()`. Слоты 41–43 подтверждают вторично, что kthreadd
исполнялся и `create_kthread` вернулся.

FACT (свидетели-значения, прямое измерение):
- `jiffies` перед bind = `0x00000000fffedb08`; `jiffies` внутри цикла
  `wait_task_inactive` = `0x00000000fffedb08` — **не продвинулись**;
- витков цикла = 1;
- **маркер в `arch_timer_handler_phys` = 0 — обработчик не вызывался ни разу**;
- **счётчик тиков за загрузку = 0**;
- CNTVCT во всех трёх точках = 0; `jiffies` после bind = 0 (точка не достигнута).

Итог: **за всю загрузку не произошло ни одного таймерного тика**, jiffies стоят на
стартовом значении (`0xFFFEDB08` = −75000 = −300×HZ при HZ=250), и ядро висит в
первом же таймерном сне — `kthread_bind_mask()` → `wait_task_inactive()` →
`schedule_hrtimeout()`. Гипотеза P16 подтверждена положительным измерением.
Почему это первая такая точка: до неё ядро ни разу не спало и не ждало таймаута,
а метки времени в логе идут от `sched_clock`/mt_gpt — независимого механизма,
который про приход тика ничего не говорит.

Две инструментальные заметки: (1) слот `jiffies` усечён до 32 бит (настоящее
64-битное значение старта = `0xFFFFFFFFFFFEDB08`), по смыслу верно, но писателя
значений надо починить на полные 64 бита; (2) CNTVCT = 0 сам по себе не улика —
читается ВИРТУАЛЬНЫЙ счётчик, а ядро при `arch_timer_uses_ppi=0` работает с
ФИЗИЧЕСКИМ, и CNTVOFF выставляет ATF; мерить надо `CNTPCT_EL0`.

REJECTED (проверено по исходникам и `.config`, чтобы не тратить прошивку):
«включение системного счётчика выпало из сборки». В `drivers/clocksource/mt_gpt.c`
функция `setup_syscnt()` вызывает `mt_cpuxgpt_map_base()`, `set_cpuxgpt_clk()` и
`enable_cpuxgpt()` под `#if defined(CONFIG_MACH_MT6735M) || ...`; в `.config`
`CONFIG_MACH_MT6735M=y` (строка 336), то есть блок собран. В логе есть
`cpuxgpt_r.start = 0x10200000` и нет ни `No timer`, ни
`map phy addr of CPUXGPT fail`, значит маппинг прошёл.

HYPOTHESIS (главная): per-cpu IRQ таймера не размаскирован. В 4.9
`enable_percpu_irq()` для PPI вызывается из hotplug-состояния
`CPUHP_AP_ARM_ARCH_TIMER_STARTING` (`arch_timer_starting_cpu`), а не явным
вызовом, как в 3.18. Успешный `request_percpu_irq ... err=0` в логе означает
только регистрацию, но не размаскирование. Falsification: маркер в
`arch_timer_starting_cpu()` + чтение `GICD_ISENABLER0` (биты 29/30).

Запрошено в P19 (полными 64 битами, в двух точках — после `arch_timer_register` и
внутри цикла `wait_task_inactive`): `CNTPCT_EL0` (счётчик идёт или стоит),
`CNTP_CTL_EL0` (bit0 ENABLE / bit1 IMASK / bit2 ISTATUS — различает «компаратор не
запрограммирован», «прерывание выставлено, но не доставляется GIC» и «компаратор в
далёком будущем»), `CNTP_CVAL_EL0` против `CNTPCT`, `GICD_ISENABLER0`.

## 4.9 arm64: P19 — причина найдена: СИСТЕМНЫЙ СЧЁТЧИК НЕ ИДЁТ (2026-08-17)

Прошит `boot_49_p19.img` (sha256 `5aef805b2917d26942e2e94d55404a028de2284c1f85e9b5fb4c3c89cdce33f4`),
recovery через 65 с. Слоты: `captures/20260817-49-p19/fD_p19.bin`.

FACT (регистры, прочитаны внутри цикла `wait_task_inactive`):
```
CNTPCT_EL0      = 0x0000000000000000     <- физический счётчик стоит на нуле
CNTP_CTL_EL0    = 0x1 -> ENABLE=1, IMASK=0, ISTATUS=0
CNTP_CVAL_EL0   = 52000 (0xcb20)
GICD_ISENABLER0 = 0x6000dfff -> бит29=1, бит30=1   <- оба PPI размаскированы
jiffies64       = 0xfffedb08 (стартовое), витков цикла = 1
маркеры: 44 ✔; 45, 46, 40, 61, 62 — ✘
```

INFERENCE (взаимно подтверждённый двумя регистрами): таймер включён, не
замаскирован, компаратор запрограммирован на 52000, PPI на дистрибьюторе
включены — а прерывания нет, потому что **счётчик не идёт**. Арифметика:
компаратор заряжен на ~0.6 мс, чтение на ~12 мс; при 13 МГц счётчик прошёл бы
~143000 > 52000 и `ISTATUS` был бы 1. Он ноль.

REJECTED: вся линия «PPI замаскирован / не то тиковое устройство / cpuhp не
проехал». Биты 29/30 стоят к моменту виса. Находка про `gic_cpu_init`
(`0xffff0000` в `GIC_DIST_ENABLE_CLEAR` гасит все PPI) верна как факт, но не
является нашей причиной.

FACT (эталон, снят с живого 3.18 в TWRP на этом же телефоне):
```
/sys/devices/system/clockevents/clockevent0/current_device = arch_sys_timer
/sys/devices/system/clocksource/clocksource0/current_clocksource = mt6735-gpt
/proc/interrupts:  29: 0 arch_timer   30: 11047 arch_timer   184: 0 mt-gpt
```
То есть на этом железе тиковое устройство — **ARM-таймер**, прерывания приходят на
**PPI 30**, GPT1 (SPI 184) в тиках не участвует. Это подтверждает рейтинги
(arch timer 450 против GPT 300) рантайм-истиной и, что важнее, доказывает: **на
этом SoC системный счётчик исправен и запускается**. Дефект софтовый.

FACT (проверено по исходникам, чтобы не расходовать прошивки):
1. `setup_syscnt()` в 4.9 вызывается (`drivers/clocksource/mt_gpt.c:642`), её
   печать `fwq sysc count` присутствует в логе → `mt_cpuxgpt_map_base()`,
   `set_cpuxgpt_clk(CLK_DIV2)`, `enable_cpuxgpt()` исполнялись.
2. Тело `setup_syscnt()` в 3.18 (`drivers/misc/mediatek/mach/mt6735/mt_gpt.c:485+`)
   идентично нашему: те же три вызова, тот же `CLK_DIV2`.
3. `CPUXGPT_BASE` (= `cpuxgpt_regs`), `INDEX_BASE` (+0x674), `CTL_BASE` (+0x670),
   `EN_CPUXGPT` (0x01) — идентичны в обоих деревьях.
4. `mcusys_smc_write` на arm64 в обоих деревьях — обычная запись
   `mt_reg_sync_writel`, без SMC; `mt_secure_api.h` совпадает строка в строку.
5. Маппинг корректен: `cpuxgpt_r.start = 0x10200000` (MCUCFG), нет ни `No timer`,
   ни `map phy addr of CPUXGPT fail`.

Итог: код запуска счётчика исполняется, совпадает с рабочим ядром, а счётчик
стоит. Значит запись либо не доходит до регистра, либо её отменяют.

Запрошено в P21: обратное чтение `__read_cpuxgpt(INDEX_CTL_REG)` в трёх точках —
перед `enable_cpuxgpt()`, сразу после, и внутри цикла `wait_task_inactive`; плюс
`CNTFRQ_EL0` и два подряд чтения `CNTPCT_EL0`. Разрез: бит `EN_CPUXGPT` не встал
после enable → запись в MCUCFG глотается, и фикс лежит в секурном пути
(`mcusys_smc_write_phy` через `MTK_SIP_KERNEL_MCUSYS_WRITE`), а на 3.18 счётчик,
вероятно, уже был запущен LK и потому дефект незаметен; бит встал, а CNTPCT не
растёт → счётчик не тактируется, смотреть делитель `set_cpuxgpt_clk` и CNTFRQ;
бит встал и потом пропал → кто-то отключает счётчик позже (`disable_cpuxgpt` /
`restore_cpuxgpt` из idle/hotplug).

P20 (пробы тикового устройства 63/64) не прошивался: вопрос «кто должен тикать»
закрыт эталоном с живого 3.18.

### Причина стоящего счётчика: неверные номера секурных вызовов (SMC SIP ID)

FACT (найдено диффом, без прошивки). Счётчик включается так:
`enable_cpuxgpt()` → `__write_cpuxgpt()` → при `CONFIG_MTK_PSCI=y` (он `=y` в
ОБОИХ деревьях) это `mcusys_smc_write_phy()` =
`mt_secure_call(MTK_SIP_KERNEL_MCUSYS_WRITE, ...)`, то есть **SMC-вызов в ATF**.
Прямой записи в MCUCFG в этом пути нет вовсе.

В `drivers/misc/mediatek/include/mt-plat/mt6735/include/mach/mt_secure_api.h`
номер этого вызова у нас другой, чем у рабочего ядра на том же устройстве:

```
                                   4.9 (наш)     3.18 (рабочий = что реализует ATF)
MTK_SIP_KERNEL_MCUSYS_WRITE        0x82000287 -> 0x82000201   <- включение счётчика
MTK_SIP_KERNEL_MCUSYS_ACCESS_COUNT 0x82000288 -> 0x82000202
MTK_SIP_KERNEL_L2_SHARING          0x82000286 -> 0x82000203
MTK_SIP_KERNEL_WDT                 0x82000200 -> 0x82000204
MTK_SIP_KERNEL_GIC_DUMP            0x82000201 -> 0x82000205
MTK_SIP_KERNEL_DAPC_INIT           0x8200026E -> 0x82000206
MTK_SIP_KERNEL_EMIMPU_WRITE        0x82000260 -> 0x82000207
MTK_SIP_KERNEL_EMIMPU_READ         0x82000261 -> 0x82000208
MTK_SIP_KERNEL_EMIMPU_SET          0x82000262 -> 0x82000209
MTK_SIP_KERNEL_MSG                 0x82000214 -> 0x820002ff
```

Расходятся ВСЕ десять общих ID: заголовок в 4.9-дереве приехал из более новой BSP
с перенумерованным SIP-диапазоном, а ATF на устройстве стоковый (2017) и мы его не
меняли, то есть эталон — значения 3.18. Плюс в 4.9 есть три ID, которых в
3.18-заголовке нет: `GPIO_READ`, `GPIO_WRITE`, `ICACHE_DUMP`.

INFERENCE: вызов уходит с номером, которого стоковый ATF не знает, отбрасывается,
запись в CPUXGPT не происходит, бит `EN_CPUXGPT` не встаёт, `CNTPCT` остаётся
нулём — ровно то, что измерено в P19.

HAZARD (отдельно, требует проверки): `0x82000201` в нашем дереве занят под
`GIC_DUMP`. Любой вызов `GIC_DUMP` из 4.9 попадёт в обработчик `MCUSYS_WRITE`
стокового ATF и запишет в регистр MCUSYS аргументы, предназначавшиеся для дампа
GIC. Это не «вызов не сработал», а потенциальная порча регистров процессорной
подсистемы; проверить, зовётся ли `GIC_DUMP` на пути загрузки.

Фикс (в P21): привести весь блок ID к значениям рабочего 3.18 (эталон — тот же
путь файла в `/home/valakas/m5c/android_kernel_meizu_m5c`), а три отсутствующих в
3.18 ID заглушить, чтобы не улетали в чужие обработчики. Это шестое по счёту
расхождение того же класса, что fan5405, alsps, lp3101, вспышка и apxgpt:
несовпадение с тем, что реально реализует стоковая платформа. Заодно объясняет,
почему `MTK_SIP_KERNEL_WDT` (deadman) тоже мог не работать.

Ожидаемая цепочка после фикса: SMC доходит → `EN_CPUXGPT` встаёт → `CNTPCT` идёт →
компаратор на 52000 срабатывает → PPI 30 приходит (размаскирован по P19; на
рабочем 3.18 на нём 11047 прерываний) → jiffies идут → `wait_task_inactive`
возвращается → `workqueue_init` завершается → загрузка уходит в initcalls.

## 4.9 arm64: P22 — SIP-фикс сработал, ядро в device initcalls; новый блокер BUG() в mrdump_mini_init (2026-08-17, зафиксировано вечерней офлайн-сессией)

FACT (по капче p22 и транскрипту дневной сессии): после фикса SIP ID
(`68e66c073`) контрольный замер показал `EN_CPUXGPT` встаёт (`0x201`), CNTPCT
идёт; ядро прошло `workqueue_init`, pre-smp initcalls, `smp_init` — 4 CPU
подняты, лог 466 строк, последняя метка 1.154 с (было 116 строк / 0.012 с).
Новый блокер другого качества — честная паника: `BUG()` внутри
`mrdump_mini_init`, затем AEE/ipanic уходит в рекурсивную панику.

FACT (root cause, разобран офлайн по `rc49_p22.bin` + `System.map-p22`,
полный разбор: `M5C_KERNEL_49_MRDUMP_P22.md`): PC = `mrdump_mini_fatal+0x34`,
вызван из `mrdump_mini_init+0x6fc` (inlined `mrdump_mini_elf_header_init`,
`mrdump_mini.c:1004`) — ветка «addr==0 && size==0 → FATAL:illegal addr size».
LK 2017 не отдаёт memory_info, fallback-ветка ram_console не зовёт
`mrdump_mini_set_addr_size()`; `mrdump_mini.o` собирается по
**CONFIG_MTK_AEE_IPANIC=y** (не по MRDUMP — поэтому «MRDUMP is not set» на
p22 ничего не давало). Рекурсия: обработчик паники `mrdump_mini_cpu_regs`
при NULL ehdr повторно зовёт `mrdump_mini_init()` → тот же BUG. Эталон 3.18
в той же ситуации делает kmalloc-fallback и не падает.

P23 (предложение, PROPER-FIX/BOOT-UNBLOCK, ещё не собрано): 3 правки в
`mrdump_mini.c` — fatal→LOGE+return в elf_header_init (и снять `__init`),
guard `ehdr==NULL` в начале `mrdump_mini_init`, убрать повторный вызов
`mrdump_mini_init()` из `mrdump_mini_cpu_regs` (return -1). Запасной вариант
(ISOLATION): выключить `CONFIG_MTK_AEE_IPANIC`, но теряется ipanic-лог.
Expected marker: «minirdump: disabled (no buffer)», `initcall
mrdump_mini_init returned 0`, далее `mt_cirq_init`, рост лога за 1.154 с.
Прогноз следующих блокеров (INFERENCE): mt_cirq/lastpc/systracker →
MTK_M4U (IOMMU) → mtkthermal/mt_auxadc/msdc. Уже видны WARN'ы: «[GIC] not
correct trigger type» ×4 (mt_cpu_dormant_init), «[SPM] find SCP_I2Cx node
failed».

## Офлайн-анализы вечерней сессии 2026-08-17 (4 субагента, без прошивок)

FACT: GAP-анализ порта 4.9 против 3.18 записан в
`M5C_KERNEL_49_GAP_ANALYSIS.md`: из 35 подсистем ГОТОВО 10, СЛОМАНО 6,
ВЫКЛ/частично 11, НЕТ 6. Топ-блокеры Android-загрузки: **msdc** —
`msdc_cust.h:42` «mediatek,msdc» против стокового «mediatek,mt6735m-mmc»
(eMMC не probe → нет rootfs); дисплейный блок выключен + `mtkfb.c:2603`
«mediatek,mtkfb» vs сток «mediatek,MTKFB», `lp3101.c:169` vs сток
«mediatek,lcd_bais_pinctrl»; тач `mtk_tpd.c:53` vs сток «mt6735-touch»;
keypad `kpd.c:468` vs сток «mt6735-keypad»; connectivity (wmt/stp/wlan/gps)
в 4.9-дереве отсутствует полностью (Phase H — самый большой порт).
«Седьмое расхождение» — это кластер одного класса: Q0-дерево синхронизировало
compatible под свой референс-DTS, а мы грузим стоковый DTB 2017.

FACT: разбор камеры дописан как §10 в `M5C_CAMERA_OTP_LANE.md` (+заметка в
`M5C_CAMERA_ORIENTATION_LANE.md`). Механика «после camcal хуже» доказана:
HAL открывал `/dev/S5K4H8_SUNWIN_OTP`, чей буфер никогда не заполнялся
(EEPROM читается только в dev варианта ST), и программировал ISP из нулей
(`LayoutType=0x5`, `ERR_NO_3A_GAIN`); хрома-ошибка выросла 25.2/36.6 →
33.5/39.5. В worktree camotp лежат две незакоммиченные правки: open()
пустого OTP-узла → -ENODEV (прямое лечение) и LOG_PROBE для S5K5E8 через
pr_info (его xlog компилируется в ((void)0) — фронталка молчала по
построению). Следующий шаг лана: закоммитить, собрать, снять серый лист;
маркеры — «module id 8 -> variant 1», «S5K4H8_ST_OTP LSC 1868 bytes read»,
отсутствие ERR_NO_3A_GAIN/ERR_NO_SHADING.

FACT: триаж первого бута LOS записан в `M5C_LOS_FIRST_BOOT_TRIAGE.md`:
3 блокера (fan5405 of_match — с паникой в `fan5405_read_byte` из
pmic_thread, фикс уже в #12+; тач — ft5x46 без chip-id захватил
`cap_touch@5d`, фикс в #12+; mBack как следствие тача), 17 дефектов, ~20
шума. Новые находки: msensord падает (нет `service akmd09912` в
init.mt6735.rc — компас), mtk_agpsd краш-луп (ICU 55
UCNV_FROM_U_CALLBACK_STOP_55), AudDrv_GPIO — 9 pinctrl-состояний отсутствуют,
9 демонов из init.rc отсутствуют в vendor. Подтверждено работающим: WiFi
полностью (consys E1, скан сетей), модем (ready, USIM ×2), дисплей+GPU,
шифрованная /data, акселерометр.

### 2026-08-17 p23: mrdump BUG-fix + пять compatible под стоковый DTB (kernel-m5c-4.9-lc commit `0b19cb314`)

Category: PROPER-FIX (mrdump) + BOOT-UNBLOCK (msdc, kpd) + подготовительные inert-правки (mtkfb, lp3101, mtk_tpd — драйверы пока не собираются).

Hypothesis: паника p22 — BUG() в `mrdump_mini_init` из-за нулевых addr/size (LK 2017 не отдаёт memory_info, ноды minirdump в DTB нет), плюс рекурсия через повторный вызов init из panic-пути. Пять compatible-строк Q0-дерева не матчат стоковый DTB 2017 (тот же класс дефекта, что fan5405/apxgpt/SIP).

Evidence: `rc49_p22.bin` + `System.map-p22` (разбор в `M5C_KERNEL_49_MRDUMP_P22.md`); dtc-дамп `dtb_stock.dtb` (md5 e17a0910…): msdc0/1 «mediatek,mt6735m-mmc», «mediatek,MTKFB», «mediatek,lcd_bais_pinctrl», «mediatek,mt6735-touch», «mediatek,mt6735-keypad»; те же строки в рабочем 3.18.

Files changed: `mrdump_mini.c` (fatal→LOGE+return ×2, guard ehdr==NULL в init с печатью «minirdump: disabled (no buffer)», ранний return в ke_cpu_regs, return -1 вместо ре-инициализации в cpu_regs); `ComboA/mt6735/msdc_cust.h` DT_COMPATIBLE_NAME→«mediatek,mt6735m-mmc» (собирается: CONFIG_MMC_MTK_PRO=y); `kpd.c`→«mediatek,mt6735-keypad» (собирается: CONFIG_KEYBOARD_MTK=y); `mtk_tpd.c`→«mediatek,mt6735-touch», `mtkfb.c`→«mediatek,MTKFB», `lp3101.c`→«mediatek,lcd_bais_pinctrl» (inert до включения дисплея/тача).

Expected next marker: `boot_49_p23.img` (sha256 `23566aa346e80c5ffde58e0e69a480e5384ee2bd94b90711fff5a5fc174c41ae`) — «minirdump: disabled (no buffer)», initcall mrdump_mini_init returned 0, рост лога за 1.154 с в mt_cirq_init / M4U / mtkthermal / msdc probe.

Rollback condition: новый вис/паника на или до mrdump_mini_init, либо падение msdc на base_top → откат соответствующего куска (`git revert 0b19cb314` целиком либо точечно).

Verification commands: прошить p23; из recovery снять ram-console; strings по капче: «minirdump: disabled», «mt_cirq», «msdc»; новые PC декодировать строго по `System.map-p23`.

FACT: параллельно закоммичены камерные правки ветки forge/camotp (3.18, `/home/valakas/m5c/android_kernel_meizu_m5c`, commit `96f7eb44`): open() пустого OTP-узла → -ENODEV (лечение «после camcal хуже»), LOG_PROBE через pr_info для фронталки S5K5E8. Собраны, но образ 3.18 не пересобирался — следующий шаг камерного лана.

## 4.9 arm64: P23–P26 — eMMC ожил, найден вис ~4.6 с в Android init; убийца локализуется маркерами (2026-08-17 вечер)

FACT (p23, sha256 23566aa3…): mrdump-фикс работает — ядро прошло все initcalls
без паники и ушло в Android init (PID 1, Mount_START 1.34 с). kpd
забиндился (input0). «minirdump: disabled» не видно — ранняя часть лога
затёрта рингом. cfg80211 WARN_ONCE (reg.c:516 «db.txt is empty»,
regulatory_init+0xa4 = brk) — нефатальный, отдельный дефолт: в дереве
пустой regulatory db.

FACT (p24, dd39fd96…): msdc index-fallback оживил eMMC: «DT probe msdc00!»,
«device renamed to bootdevice», mmc0 DF4016 14.7 GiB HS400, разделы p1..p26.
FACT: телефон стабильно умирает на ~4.6 с (p23: 4.612, p24: 4.591,
p24idleoff: 4.599, p25: 4.616, p26: 4.603) — тотальный стоп ВСЕХ CPU,
init доходит до Mount_START и молчит (ни EXT4, ни fs_mgr в логе).

REJECTED (проверками): cpuidle (p24+cpuidle.off=1 — идентичный стоп);
WDT как причина (p27 с DIAG_HARD=off: wdtk кикают, а телефон всё равно
встал колом с мёртвой кнопкой — наблюдение юзера; дедмэн был СПАСЕНИЕМ
от виза, bootloop = WDT-респаун после заморозки); DVFS-транзакция
(слоты 70/71 парные — завершена); msdc hw (слот 78 = XFER_COMPL|
DXFER_DONE — чтение завершено); USB pullup (слот 73 = 0 — не дошли);
PTP (слот 72 записан — завершён).

FACT (p26 маркеры): heartbeat-слот 77 = 67 тиков по 50 мс → смерть ≈4.6 с;
слот 75 = CMD18 (read) host0 — в момент смерти шло чтение eMMC (mount
init'ом), транзакция на железе завершилась.

HYPOTHESIS (текущая): вис — либо CPU-hotplug/MTCMOS-путь (HPS глушил
ядра 1.25–2.13 с; ATF cpu_die / spm_mtcmos), либо зона между записью
init в android_usb и входом в musb_gadget_pullup (слот 73 не сработал,
но 3.18 в этой фазе как раз реконфигурирует гаджет ~4.7 с).

NEXT (подготовлено, ждёт оживления телефона): (а) ISOLATION p26+maxcpus=1
(boot_49_p26mc1.img md5 adc196a7…) — разрез «hotplug vs остальное» без
пересборки; (б) boot_49_p28.img (md5 c32c0fa0…, DIAG_HARD обратно
включён) с маркерами 80 usb_gadget_connect / 81-82 mt_usb_enable/disable /
83-84 musb_start/stop / 85 cpu_die / 86 spm_mtcmos_ctrl_cpu — локализует
точку смерти. kernel commit f94e2b320.

## 2026-08-18 (ночь) — офлайн-порты, пока телефон разряжается (p27-вис)

Телефон после p27 (DIAG_HARD=off) завис насмерть, разряжается; adb пуст.
Проведена серия офлайн-портов 4.9 (без железа, критерий = компиляция/линк):

FACT (все работы зафиксированы коммитами):
1. kernel m5c-arm64 `fdeb90897`: accdet compatible + jd9365 таблица.
   accdet: сток-DTB `mediatek,mt6735-accdet`(+m-fallback), Q0-дерево
   матчило только mt8173/pmic → accdet никогда не пробился (тот же класс,
   что 6 фиксов p23). jd9365: повреждённая ячейка `{0x01,0x00,{0x00}}` →
   `{0x00,0x01,{0x00}}` по сток-vmlinux таблице; после фикса init 227/227
   и suspend 6/6 бьются с captures/lcm-stock-tables/jd9365_stock_tables.c.
2. Камера — ветка forge/cam49 (worktree k49-worktrees/cam49), 6 коммитов
   `cdd3becb2..ed0ca1525`: порт S5K4H8+S5K5E8 драйверов из 3.18, sensorlist
   = стоковому порядку (инд. 0-3 s5k5e8варианты, 4-7 s5k4h8варианты —
   критично для camcal-блоба), DW9714 AF (DWS i2c 0x0C→0x18 под сток-DTB),
   legacy constant_flashlight с GPIO-фиксами ba5b9145/b400984c (DWS канал
   I2C 2→1), CMDQ include-fix, mmdvfs bring-up (BOOT-UNBLOCK, честно
   помечен). Полный Image.gz-dtb 6.3MB собран, 0 ошибок. CONFIG-список —
   в M5C_COMPONENT_MATRIX.md и коммите ed0ca1525.
3. Сенсоры — ветка forge/sensors49 (worktree k49-worktrees/sensors49),
   4 коммита `bf73835ff..b22b2e536`: legacy hwmsen-стек из 3.18 целиком
   (core/mc3410/akm09912/stk3x1x). КЛЮЧЕВОЙ FACT: HAL-блоб
   sensors.mt6737m.so говорит в /dev/hwmsensor (legacy ABI) — sensors-1.0
   из 4.9-дерева несовместим, потому порт legacy, а не адаптация под 1.0.
   Починена stk3x1x legacy BOOL-проблема (в 3.18 не собиралась вообще) +
   добавлен __weak-стаб pmic_ldo_suspend_enable (иначе гарантированный
   NULL-call при PS enable — в стоке никогда не выполнялся из-за
   собранного-выкл stk3x1x). of_match всех трёх чипов со сток-DTB
   совпали без правок. Полный Image.gz-dtb собран, 0 ошибок/0 варнингов.
   Адаптации 4.9: wakelock→pm_wakeup, i2c suspend/resume→dev_pm_ops,
   misc_deregister void — задокументированы в коммитах.

Состояние веток: m5c-arm64 = fdeb90897 (линия расследования виза 4.6с
не загрязнена — оба порт-домена в side-ветках, мерж после прогона на
железе). Матрица компонентов обновлена: M5C_COMPONENT_MATRIX.md.

RUNTIME НЕ ПРОВЕРЕН (офлайн): camera probe/OTP/AF/вспышка, sensor
probe/данные — за будущими прогонами после фикса виза.

NEXT: (а) как оживёт телефон — вернуться к p26mc1/p28 (см. секцию выше);
(б) офлайн следующее: Phase H connectivity wmt/consys (WiFi/BT/GPS/FM) —
самый большой оставшийся порт; Phase C аудио (конфиги + pinctrl-состояния
AudDrv_GPIO из дефекта A2); GPU Phase E.

### Продолжение 2026-08-18 (ночь) — Phase H-1 connectivity

4. Connectivity — ветка forge/conn49 (worktree k49-worktrees/conn49),
   4 коммита `c9c1fcd96..6688d86cd`: wmt/stp/consys (common_detect +
   conn_soc + mt6735 platform) + gps. КЛЮЧЕВОЙ FACT скоупа: common/combo
   НЕ нужен — в 3.18 он только для MT6620/6628/6630; для CONSYS_6735 весь
   core живёт в common/conn_soc. connadp-шимы 4.9 исключены из линковки
   (дублируют gConEmiPhyBase, рассчитаны на отсутствующий standalone-репо).
   Чар-девайсы в vmlinux: /dev/stpwmt(190), /dev/stpbt(192),
   /dev/wmtWifi(153), /dev/stpgps(191), /dev/gps(mt3326-gps),
   /dev/wmtdetect(154) — полное совпадение с 3.18. consys@18070000 и
   consys-reserve-memory в DT байт-в-байт = сток-DTB. eccci1 (не eccci) —
   include-пути и ipc_ilm адаптированы. Полный Image.gz-dtb 6.2MB,
   0 ошибок (лог conn49-logs/full-build-3.log).
   Осталось: wlan gen2+cfg80211 (Phase H-2, отдельный прогон),
   fmradio (в 4.9-дереве нет вообще), BT runtime.

Итог ночи: 3 side-ветки (cam49/sensors49/conn49) поверх fdeb90897,
все полные сборки зелёные. Мерж в m5c-arm64 — ТОЛЬКО после прогона
на железе (линия виза 4.6с не загрязнена).

### Продолжение 2026-08-18 (ночь) — Phase H-2 wlan + Phase E GPU

5. WiFi — forge/conn49 поверх H-1, коммиты `aae484074`+`dc7cc3833`:
   wlan gen2 (69 .c) verbatim из 3.18 (FACT: CONSYS_6735→gen2, gen3 —
   только MT6630/6797), cfg80211 3.18→4.9 адаптация ПОЛНАЯ без TODO-гардов
   (scan_done→scan_info, del_station→station_del_parameters, vendor_event
   +wdev, sched_scan→scan_plans, IEEE80211_BAND→NL80211_BAND 33 сайта,
   wakelock→локальный shim над wakeup_source). P2P/GSCAN/PNO/WEXT/MET
   компилируются. g_IsNeedDoChipReset strong symbol замкнул H-1 мост.
   Полный Image.gz-dtb 6.4MB, 0 ошибок/0 варнингов (full-build-h2-04.log).
6. GPU — forge/gpu49, коммиты `d637bee3b`+`4bf07405f`: platform/mt6735
   восстановлен verbatim из 3.18 (4.9 BSP его выкинул), dma-attrs compat,
   mt_gpufreq include. FACT: обе ветки — Mali Midgard DDK r7p0-02rel0 →
   ABI к NE1-блобам низкий риск. gpu-узлы в собранном dtb байт-в-байт =
   сток-DTB (MALI@13040000 550MHz, G3D_CONFIG). Image.gz-dtb 0 ошибок.

Итог: 4 side-ветки поверх fdeb90897 (cam49, sensors49, conn49, gpu49),
все сборки зелёные. Осталось офлайн: fmradio (нет драйвера в 4.9),
модем eccci enablement, VDEC/VENC/JPEG compile-check. Мерж — после
прогона на железе.

### Продолжение 2026-08-18 (ночь) — FM + модем + видео

7. FM — forge/conn49 `7be1cca09`: fmradio mt6627 из 3.18 (47 файлов);
   FACT: 3.18 CONFIG_MTK_FM_CHIP="MT6625_FM" собирает тот же mt6627-код
   (Makefile-ветка) — противоречия «MT6627 FM config» в dmesg нет.
   /dev/fm + /proc/fm, ioctl magic 0xf5 — ABI как в 3.18. Единственная
   4.9-адаптация: file_inode(). mtk_wcn_fm_init замкнут на H-1.
8. Модем+видео — forge/av49 `9771cb929`+`bf0f3d7f1`: eccci1 включён
   (MTK_ECCCI_DRIVER/CLDMA, MD1_SUPPORT=5 lwg), vdec/venc/jpeg + SMI_EXT.
   КЛЮЧЕВОЙ FACT: 4.9 eccci1 = строгий суперсет 3.18 ABI (все ioctl и
   /dev/ccci_* сохранены, только добавлены новые) → mtkrild/ccci_fsd под
   3.18 не сломаются. DT: SIM1 hot-plug EINT полярность исправлена под
   сток (LEVEL_LOW, drvgen cust.dtsi давал LEVEL_HIGH), лишний SIM2-узел
   удалён; VDEC/VENC/JPEG-узлы = стоку. mmdvfs DISP_GetScreenWidth гард
   под MTK_FB (BOOT-UNBLOCK, самоустраняется при включении дисплея).
   Image.gz-dtb 0 ошибок.

Итог ночи: 5 side-веток поверх fdeb90897 — cam49 (камера), sensors49
(сенсоры), conn49 (wmt/gps/wlan/fm), gpu49 (GPU), av49 (модем+видео).
Все полные сборки зелёные. Осталось офлайн: аудио Phase C (MT_SND_SOC_V3
compile-enablement). Мерж — после прогона на железе.

### Финал ночи 2026-08-18 — аудио Phase C, все домены закрыты

9. Аудио — forge/aud49 `19c54c81f`+`2a1e333b1`: 4.9-native mt_soc_v3
   (mt6735/) собрался с НУЛЯ правок кода под -Werror (ASoC API-дельт не
   возникло); DT = стоку 1:1 (32 аудио-узла), extamp-пин исправлен
   (GPIO68=0x4400, не GPIO129 чужого vz6737t). КЛЮЧЕВОЙ FACT: 9
   pinctrl-состояний AudDrv_GPIO (дефект A2) отсутствуют И в сток-DTB —
   сток-faithful, не баг порта; 4.9 AudDrv_Gpio деградирует мягко.
   ASoC route SPEAKER PGA→Voice Mux в 4.9 не аудирован (Phase D).

ИТОГ офлайн-портов: ВСЕ домены матрицы закрыты — 6 side-веток поверх
fdeb90897: cam49 (камера+вспышка+AF), sensors49 (hwmsen: mc3410/akm09912/
stk3x1x), conn49 (wmt/stp/gps/wlan gen2/fm), gpu49 (mali r7p0),
av49 (модем eccci1 + vdec/venc/jpeg), aud49 (mt_soc). Все полные сборки
Image.gz-dtb зелёные, все DT сверены со сток-DTB (7 класс-p23 правок).
CONFIG-списки — в матрице/коммитах. Мерж в m5c-arm64 и прогон — после
оживления телефона и фикса виза 4.6с.

### Довесок 2026-08-18 — два неядреных должка (офлайн)

10. akmd09912 — device/meizu/m5c коммит `e21324d`: алиас service
    akmd09912 → /system/bin/akmd09911 (msensord просит сервис по имени
    чипа; блоб 9912 не поставляется, 9911 — та же AKM099xx-семья).
    Rollback: если блоб отвергнет chip-id — искать настоящий akmd09912
    в Flyme.
11. P4 (battery_profile) ПЕРЕКЛАССИФИЦИРОВАН: battery_profile_t0..t3
    отсутствуют И в сток-DTB (проверено dtc-дампом) → фолбэк на cust
    header и capacity=50 — сток-faithful поведение, не баг порта/ядра.
    Не чинить против сток-истины; убрано из «Ещё не сделано» в матрице.

## 4.9 arm64: P29–P32 — вис 4.6с = tick-broadcast mt_gpt на 32кГц (РЕШЕНО офлайн, ждёт прогона) (2026-08-18/20)

### P29 (коммит d13987dc9): hotplug/MTCMOS/ATF ПОЛНОСТЬЮ эконерированы
Таймстамп-маркеры (sched_clock нс) на все скобки cpu_down/up/mtcmos +
RTC FAC_RESET автовозврат. Капча `captures/20260818-49-p29/` (валидная,
A==B). FACT: все скобки 85-93 закрыты, последний hotplug 2.15с; CPU1-3
легально запаркованы (0.40/1.13/2.05с); **CPU0 последний тик 4.704с,
USB-heartbeat (50мс hrtimer, слот 77) остановился** → CPU0 уснул в NO_HZ
idle и не проснулся. Это НЕ hotplug — это таймерное wake-событие/доставка
IRQ (тот же класс, что P18-P22).

### P30/p30poll/p30v2poll: idle=poll доказал idle-wake; дедмэн v2/v3
- `idle=poll` в cmdline обходит вис: телефон дошёл до init, USB-гаджет
  поднялся (dmesg хоста: `18d1:d001 m5c serial 710HVBR923RYK`).
- Дедмэн: v2 = kthread кикает WDT каждую секунду (здоровый бут живёт),
  метка RTC FAC_RESET на 3с, снятие на 15с; v3 (p30v2poll) = дедлайн 20с
  (диагностический, убивает и здоровый бут). FACT: RTC-метка печатается,
  но LK по WDT-ресету в TWRP НЕ роутит — ручной тёплый Vol+ остаётся
  надёжным путём; из TWRP `reboot recovery` работает.
- p30v2poll прогон: капча НЕ снята (холодный ресет сгнил DRAM).

### P31 (коммит 4a6f5e61c): legacy android_usb гаджет — adb-путь
ROOT CAUSE отсутствия adb: 3.18 имеет `CONFIG_USB_G_ANDROID=y`, рамдиск
LOS пишет в `/sys/class/android_usb/android0/*` (init.mt6735.usb.rc);
в 4.9-конфиге был только CONFIGFS → adb невозможен по построению.
Включён USB_G_ANDROID; configfs-функции (F_MTP/F_PTP/F_ACC/F_AUDIO_SRC/
F_MIDI/F_FS) выключены — legacy android.c инклюдит f_mtp/f_accessory/
f_rndis/f_hid/f_midi в свой TU, дубли-объекты давали multiple definition.
Kconfig.default: убраны select'ы configfs-функций (иначе olddefconfig их
возвращает). USB_G_ANDROID: +select USB_U_ETHER (gether_* из u_ether.o),
-select USB_F_AUDIO_SRC (нужен ALSA, CONFIG_SND off). android.c:
create_function_device → static android_lookup_function_device (configfs.c
экспортирует одноимённую с ДРУГОЙ семантикой), static
trigger_android_usb_state_monitor_work (у meta.c свой глобал).
Образ `boot_49_p31poll.img` md5 d78e63da81c2129d738c4db9a87e007c
(idle=poll). Прошивка отложена: телефон ушёл в цикл preloader↔gadget
(p30v2poll дедлайн), mtkclient на gunwest не поймал preloader за 150с.

### P32 (коммит 0e496ca4a): mt_gpt broadcast на 32кГц — PROPER-FIX
ROOT CAUSE виза 4.6с (офлайн-анализ, сток-истина по 3.18):
- Сток-DTB arch_timer node БЕЗ "always-on" → arch_timer_c3stop=true →
  nohz-CPU в idle передаёт тики broadcast-девайсу = mt-gpt (apxgpt,
  IRQ 184, SPI 0x98).
- 4.9 mt_gpt.c пришёл из более нового BSP (mt6580-эра): его
  `mt_gpt_clkevt_next_event()` программирует compare в 13МГц-циклах,
  а потом ПЕРЕКЛЮЧАЕТ GPT на 32.768кГц RTC-источник. Клокивент
  зарегистрирован с freq=13МГц → каждый broadcast-дедлайн растянут
  ~397× (13e6/32768): 50мс hrtimer стреляет через ~20с → CPU0 "мёртв"
  с первого настоящего idle. Это и есть вис 4.704с.
- 3.18 сток (mach/mt6735/mt_gpt.c) set_next_event = stop/cmp/start БЕЗ
  переключения клока, на том же железе, и работает. SODI на m5c выключен
  (idle_switch[IDLE_TYPE_SO]=0) → 32кГц-ради-SODI не нужен.
Фикс: убрано переключение на GPT_CLK_SRC_RTC, остаёмся на GPT_CLK_SRC_SYS
(как 3.18 сток). Маркеры: слот 100 = счётчик GPT IRQ (gpt_handler),
слот 101 = cycles из set_next_event.
Образ `boot_49_p32.img` md5 81447ee71a5194ca6efc89db952f41a4, cmdline
СТОКОВЫЙ (без idle=poll). Ожидание: бут проходит 4.6с, слот 100 растёт,
сердцебиения 77/96+cpu живут >5с, android0 + adb (из p31).
Rollback: если слот 101 стрелял, а 100 = 0 → железный путь GPT (клок-
гейтинг / GIC SPI 184) — вернуть idle=poll и читать регистры GPT.

### Транспорт/стенд
Телефон 710HVBR923RYK: devbox ↔ gunwest (юзер переносит). mtkclient
есть на gunwest (/home/gun/mtkclient, .venv, mtk.py) — preloader-окно
ловить не смог. Чужие устройства на стендах НЕ трогать: MX6
95AHACQC5KQVM, nx569j cb16fcca, iPhone7Plus F2LVD2HGHFY7, M5s
612MZCQH447WD (0e8d:201d в lsusb подписан "M5s" — это usb.ids-маппинг,
наш preloader).

### NEXT (при телефоне на devbox)
1. Прошить p32 (сток-cmdline) → ждать adb ~60с. Если adb — Android на
   4.9 впервые жив БЕЗ idle=poll: вис закрыт proper-fix'ом.
2. Если вис — капча fA/fB + rc49 из TWRP (тёплый Vol+), декод слотов
   100/101 решает: GPT-железо vs дальше по цепочке.
3. Запасной: p31poll (idle=poll) — adb-бриингап при живом вопросе таймера.
4. После adb: мерж 6 side-веток (cam/sensors/conn/gpu/av/aud) + железные
   прогоны; cfg80211 WARN_ONCE (reg.c:516) — отложен, нефатально.

## 2026-08-20 — внешний анализ: полный пакет для сильной модели

Вся цепочка P15→P36b, обе ветки ядра, инструментация, правки гаджета,
парадоксы и ранжированные гипотезы собраны в `M5C_K49_DEEP_DIVE.md`
(включая текст запроса для внешней модели). Ключевые новые FACT этой
сессии: p31poll/p33/p34poll/p36bpoll — ноль USB, статик-лого, кнопки
живы (p34poll); капчи p32/p34 съедены холодным off (DRAM=0xFF); eMMC-
зеркало (p36/p36b) не записало (filp_open: нет /dev до init;
blkdev_get_by_dev: не записало — либо дедмэн не бежит, либо паника в
mirror → подозрение на panic-луп по preloader-вспышкам t=40/50с).
Образы: p31poll d78e63da…, p32 81447ee7…, p33 12705109…, p34poll
316d4056…, p35poll f3c7221d… (не прошит), p36bpoll 0a962d0c….

## P37–P41 (2026-08-20, лайв-сессия на девбоксе): ADB РАБОТАЕТ НА 4.9

Полный разбор с уликами — `M5C_K49_DEEP_DIVE.md` §11 (11.1–11.13). Итог:
`710HVBR923RYK device product:lineage_m5c`, `uname -r = 4.9.188-m5c+`,
`/system`+`/data` смонтированы, `sys.usb.state=adb`, adb shell/dmesg живые.

Три реальных убийцы «вечного логотипа» p31+ (все FACT, все закрыты):
1. **p38 `7f2e67bdc`** — libcomposite/configfs.c (device_initcall) при
   CONFIGFS_UEVENT=y создавал класс `android_usb` раньше нашего
   late_initcall → `class_create` android.c = -EEXIST → android0 не
   создавался → рамдиск писал в никуда. (Отсюда же «charging d001» p30:
   configfs.c сам эмулирует android0.)
2. **p40 `9f0029fcd`** — Q0 msdc rename `bootdevice`/`externdevice` уводил
   DEVPATH → ueventd публиковал `/dev/block/platform/bootdevice/…` → ВСЕ
   fstab-маунты ENOENT (fs_mgr по 20с/раздел) → нет /data/persist → USB rc
   мёртв; init уходил в recovery ~200с (это и были «возвраты в TWRP»).
3. **p41 `086f17767`** — рамдиск НЕ монтирует functionfs и не пишет
   f_ffs/aliases: его adbd ходит в `/dev/android_adb` = legacy **f_adb**,
   выпиленный из Q0. Возвращён байт-в-байт из стока 3.18 (+глю в android.c,
   гейтинг adbd оставлен #if 0 как в стоке).

Латентные бомбы, обезврежены в **p37 `75d761e44`**: (a) audio_source init
всегда -ENOENT при отсутствии USB_F_AUDIO_SRC + крашащий unwind таблицы
(UAF f->dev / double kfree / NULL f->config) — до p35-таблицы это был бы
oops в kernel_init; (b) `aee_exception_reboot` → `while(1)` при неготовом
wd_api (wd_api_init живёт в wdk-workqueue ПОСЛЕ usb late_initcall) — oops
превращался в вечный тихий hang; починено на emergency_restart (PSCI);
(c) окна 0x5f000000 (rc49+pstore!), 0x7f000000, 0xb0000000 НЕ были в
memblock_reserve — ram console непрерывно писала в память buddy-аллокатора;
(d) зеркало сидело в кик-нити WDT.

Канал улик, который всё вскрыл (p37/p39): **eMMC-зеркало в expdb p10** —
offset 0: маркер-страница 2КБ (live + prev-boot копия), 1МБ: rc49-ринг,
2МБ: ранний одноразовый снапшот rc49 (первые секунды бута). Переживает
любой ресет, читается из TWRP. Обязательные уроки: НУЛЕВОЕ значение слота
неотличимо от нештампованного — только сентинелы (103=0x600D и т.п.);
`wdtk-0` (MTK_WD_KICKER) кикает WDT независимо от дедмэна — «стоп киков»
НЕ даёт ресета; ре-энумерации 0bb4 каждые ~20с = рестарты adbd.

Слоты p37+: 106=(mirror ok<<32)|early<<16|errno; 107-109=die cmd/PC/LR;
110=panic; 111=functions_store (8 симв.); 112=0x100|enable; 113=ffs ready;
114=pullup; 115-125=трасса probe-цепочки (см. §11.7/11.12 дока).

Образы: p37poll 220a2807…, p38poll c5058088…, p39poll 32f5e181…,
p40poll 665e328d…, **p41poll e3164972… (рабочий, adb)**. System.map-p37…41
в корне дерева. Бэкапы до сессии: expdb_pre_p37 e7e9aee2…, boot_pre_p37
c7fca7d6… (scratchpad p37cap/).

Открыто: возврат в recovery ~215с при живом userspace (боот не completed,
zygote=0 — вероятно crash-loop critical-сервиса без дисплея/GPU HAL);
валидация p32 mt_gpt-фикса прогоном БЕЗ idle=poll; затем display-фронт.

## P42–P45 (2026-08-20 вечер): idle=poll снят, SF-петля доказана, дисплей-стек собран, p44-клин, p45-инструментация

- **P42 FACT:** p41-ядро со СТОКОВЫМ cmdline (без idle=poll) — adb за 21с.
  p32 mt_gpt-фикс подтверждён железом; костыль idle=poll снят навсегда.
- **A0.1 FACT (logcat):** петля recovery ~215с = SurfaceFlinger: нет
  fbdev/gralloc-fb/mtkfb, MTK hwcomposer виснет в hwc_open_1 → краш-луп →
  init reboot recovery. На брингап-сессиях лечится `adb shell stop`.
- **P43** (`90620e0e4`): WDT DDR-reserve включён (mtk_rgu_dram_reserved(1)
  в probe — DRAM переживёт HW-WDT-ресет), usb_state-лог только по смене.
- **P44** (`79faa74be`): дисплей-стек ВКЛЮЧЁН и СОБРАН: MTK_FB, MTK_LCM,
  CUSTOM_KERNEL_LCM="ili9881c_dsi_vdo_dj_hd720 jd9365...", MTK_CMDQ,
  MTK_SMI_EXT (легаси smi_legacy для mt6735), SW_SYNC. Панель ili9881c
  синхронизирована из 3.18 (реверс-блок DSI: PLL 212, 4 lane — фикс
  resume-мусора); jd9365 оставлен 4.9-версии (фикс ячейки по vmlinux).
  Сборочные фиксы: compat_mtkfb.h для mt6735 (Q0 потерял), typedef
  compat_mtk_dispif_info_t (=struct, раскладка 32/64 идентична), DISPDBG
  include, cmdq v2/mt6735 Makefile -I.
- **P44 РАН FACT:** клин ДО USB (ни adb, ни recovery за 4 мин), дедмэн
  ресетит циклами ~3-6 мин (preloader-вспышка 20:29:39). Капчи нет —
  телефон физически недоступен (юзер уехал), p44 крутится на аппарате.
- **Код-анализ клина (без капчи):** mt6735 power/mtcmos в 4.9 ≈ байт-в-байт
  рабочий 3.18-оракул (дельта = наши маркеры) → DIS-спины сами по себе не
  главный подозреваемый; smi = легаси-вариант (3.18-совместим); cmdq =
  subsys_initcall (порядок smi(arch)→cmdq(subsys)→mtkfb(module) корректен);
  parse_tag_videolfb эквивалентен 3.18; disp_helper stage=NORMAL. Videox/
  dispsys Q0 сильно отличается от 3.18 (3.5к строк дельты в
  primary_display.c) — угадывать нельзя, нужна точка.
- **P45** (`08088208e`, ГОТОВ К ПРОШИВКЕ): лестница шагов дисплей-инита в
  слоте 126: 0x40..0x44 cmdq init/probe; 0x11..0x1F mtkfb_probe (74=fb_base
  из LK-тега); 0x20..0x2F primary_display_init (76=plcm; 0x26-0x29 вокруг
  cmdq trigger loop); 0x30 disp_lcm_probe; 0x60|state/0x6F MTCMOS DIS.
  Decision tree: слот 126 ПУСТ → клин до cmdq subsys_initcall (тогда
  p45a: infra-only образ CMDQ+SMI без MTK_FB); 0x42..0x44 → клин в
  cmdq probe (GCE); 0x14 без 0x15 → внутри primary_display_init — смотреть
  последний под-шаг 0x2x; 0x26/0x27 без 0x28 → GCE trigger loop (клок/IRQ
  GCE); 0x60 без 0x6F → MTCMOS DIS ack; 107-109 при BUG() → PC/LR по
  System.map-p45. Плюс rc49-ринг покажет последний printk.
  Образ: `boot_49_p45.img` md5 `96a4036c…` (сток-cmdline).
  **По возвращении телефона:** Vol+ TWRP → прошить p45 → один цикл ~3 мин →
  TWRP → expdb-капча → точка клина.

### P45 доп. (2026-08-20, ночь): preloader-канал ЗАКРЫТ, бисект-образы готовы

- **FACT (экономит время в будущем): mtkclient через preloader на m5c НЕ
  работает.** Установлен на девбокс (`~/mtkclient-main` + venv `~/mtkvenv`,
  зависимости + libfuse2/3 доставлены), порт `0e8d:2000` ловится штатно, но
  `Status: Handshake failed` **9 раз из 9** подряд. Это не тайминг-лотерея
  (окно ~1с из 11с цикла ловилось каждый раз), а систематический отказ:
  preloader этого аппарата DA-рукопожатие не принимает → нужен BROM
  (тест-пойнт, вскрытие). Вывод: **удалённая прошивка/чтение разделов без
  рук человека на m5c невозможна**; единственный путь — Vol+ → TWRP.
- **FACT: p44 не «висит», а РАНО ПАНИКУЕТ.** Цикл ресета ~11с (номера
  USB-устройств preloader бегут непрерывно, 113→127→wrap→29). До userspace
  не доходит (p41/p42 доходили до adb за 15-21с). Косвенно подтверждает, что
  p37-фикс `aee_exception_reboot` работает: ранняя авария теперь ресетит, а
  не висит вечно.
- **FACT: `CONFIG_MTK_SMI_EXT=y` без `CONFIG_MTK_FB=y` НЕ ЛИНКУЕТСЯ** —
  `mmdvfs_mgr.c:92` требует `DISP_GetScreenWidth/Height` (те же грабли, что
  обошёл cam49-коммит `914b837f6` через mmdvfs bring-up implementation).
  Поэтому «инфра без дисплея» = только CMDQ.
- **Бисект-образы готовы (ждут рук):**
  1. `boot_49_p45.img` md5 `96a4036c…` — полный дисплей-стек + лестница
     маркеров (слот 126). ПЕРВЫЙ на прошивку: один цикл ~11с уже даст точку.
  2. `boot_49_p45a.img` md5 `bd6b2e43…` — CMDQ-only (SMI/FB/LCM off),
     System.map-p45a. Нужен, только если слот 126 окажется ПУСТ (клин до
     cmdq subsys_initcall) — тогда: доходит до adb → cmdq невиновен, клин в
     smi/videox; тот же 11с-цикл → виновен cmdq probe (GCE clk/IRQ).
  3. Откат `boot_49_p42.img` md5 `98ab7ccc…` — заведомо рабочий adb-бинарь
     (p41-ядро, сток-cmdline), если нужно быстро вернуть телефон в строй.
- Дерево ядра оставлено в состоянии p45 (полный дисплей-стек, `.config`
  восстановлен из `config-p45-full`).

## P46 (2026-08-21): p44 root cause = SMI probe против стокового DTB 2017

**Улики (взяты из TWRP в 11:55, DRAM пережила ресеты — DDR-reserve p43
РАБОТАЕТ, это первое подтверждение):**
- Страница A: слот 107 = `0xd1e0001` (die, cmd=1), **108 = PC
  `smi_register+0x88`**, 109 = LR `smi_register+0x40` (System.map-p44).
- rc49-ринг: `mtk-smi-common 14017000.smi_common: common nr_larbs read
  failed -22` → `probe of 14017000.smi_common failed with error -22` →
  `Unable to handle kernel NULL pointer dereference at virtual address 0`
  → `PC is at smi_register+0x88`, `Call trace: mtk_smi_init+0x7c`.
- expdb-зеркало содержало данные ЧУЖОГО бута (p41/p42: 200с, USB bound) —
  p44 умирал раньше первой записи зеркала (~5-8с). Урок: сверять слот 95
  (loops) прежде чем верить содержимому зеркала.

**ROOT CAUSE (FACT):** `drivers/memory/mtk-smi.c` (Q0, mainline-стиль)
требует DT-свойства, которых в стоковом DTB 2017 нет: `nr_larbs` у
`smi_common` и `cell-index` у larb-узлов (там только
`compatible = "mediatek,smi_larb0..2"` и reg-диапазоны). Probe common
выходил по -EINVAL ДО `devm_kcalloc` массива `larbs`, а
`smi_legacy.c:smi_register()` (arch_initcall_sync через `mtk_smi_init`)
индексировал этот NULL → oops на ~2-4с → PANIC_TIMEOUT=1 → ресет-цикл 11с.
Тот же класс, что p23/p38/p40: Q0-код против сток-DTB.

**Фикс p46 (`303562a05`):**
1. `nr_larbs` выводится из reg-диапазонов узла `smi_common` (COMMON + по
   одному окну на larb: 4 диапазона → 3 larb'а, что совпадает с
   `SMI_LARB_NUM=3` в `smi_config_mt6735m.h`);
2. индекс larb'а берётся из суффикса compatible, если нет `cell-index`;
3. проверка границ по `common->index` перед записью в `larbs[]`;
4. `smi_register()` возвращает -ENXIO вместо разыменования NULL.

**Плюс ONE-SHOT-защита дисплея (p46):** `mtkfb_probe` помечает попытку в
зарезервированной ячейке DRAM (страница A + 2048, переживает тёплый ресет);
если метка ещё стоит — прошлый бут умер внутри дисплей-инита, и этот бут
probe пропускает, доходя до adb. Снимается при успехе и при холодном
бутe. Смысл: **каждая следующая итерация дисплея прошивается удалённо**, а
не ждёт руки на Vol+ (сегодня это стоило ~15 часов простоя).
Образ: `boot_49_p46.img` md5 `b6326773…` (сток-cmdline), прошит 12:04.

## P47–P55 (2026-08-21): дисплей на 4.9 — SF ЖИВЁТ, композиция идёт

**Итог дня: SurfaceFlinger на ядре 4.9 перестал падать и композитит кадры.**
`dumpsys SurfaceFlinger`: `Display[0] 720x1280, xdpi=294.967, refresh=17146776
(58.32 fps), powerMode=2, isDisplayOn=1, flips=27`, слой `BootAnimation`
через HWC. Краши SF = 0 (было 30+ за бут). Картинки на панели пока нет.

**Пять разрывов ABI, закрытых по пути (все — Q0-ядро против 3.18-userspace):**
1. **p47** `537f41c63` — `GET_DISPLAY_CAPS`: 3.18 = nr 218 / 24 байта, Q0
   вставил `GET_IS_DRIVER_SUSPEND` на 218 и раздул структуру. HWC вис в
   `hwc_open_1` («Failed to get display device cap»).
2. **p48** `43c96e5bf` — `CMDQ_IOCTL_QUERY_DTS`: таблица подсистем выросла с
   27 (реальные для mt6735) до 39 → размер в номере ioctl не совпал → MDP
   не стартовал. Плюс мерж **gpu49** (mali r7p0 + mt6735-глю).
3. **p52** `458d27d58` — `GET_SESSION_INFO`: 3.18 = nr 208 / 72 байта (18
   слов), Q0 вставил `physicalWidthUm/HeightUm/density` в середину. Пока
   вызов не находил обработчика, HWC отдавал мусорные размеры, SF ставил
   фолбэк 1080×1920 на 720-панель — **это и был диагональный сдвиг**.
4. **p53** `5266243dd` — фенс-ioctl'ы `SYNC_IOC_WAIT/MERGE/FENCE_INFO`
   (nr 0/1/2) удалены в 4.6 в пользу `sync_file` (nr 3/4). Возвращены.
5. **p55** `b36ed4372` — **главный**: kbase r7p0 прячет всю работу с фенсами
   за `#ifdef CONFIG_SYNC`, которого в 4.9 нет → `KBASE_FUNC_STREAM_CREATE`
   всегда отвечал ошибкой (24 отказа за бут, все от surfaceflinger) → блоб
   разыменовывал NULL в `eglp_swap_buffers`. Написан слой на 4.9-фенсах
   (`mali_kbase_sync_49.c`): таймлайн за anon-inode, фенсы через MTK-шные
   `timeline_create/fence_create/timeline_inc`, ожидание — на
   `fence_add_callback`. Оригинальный код сохранён под `#ifndef`.

**Метод, который сработал (записать как правило):** инструментировать ядро
и читать, а не гадать. Ключевые улики: шпион на ioctl'ах disp_mgr
(`pr_err`, потому что `DISPMSG` в этом файле заглушён `g_mobilelog`) назвал
`nr=208 size=72`; шпион в отказной ветке kbase назвал STREAM_CREATE. Две
гипотезы (буфер без HW_FB, путь internal-fbdev) отвергнуты A/B-прогоном на
эталонном 3.18 с тем же ROM — там ровно те же строки лога.

**Открыто:** панель не показывает содержимое (SF при этом флипает);
mt-pwm probe падает (`-16`, конфликт IRQ 109), хотя DISP_PWM рапортует
`backlight is on (409)`; телефон уходит в recovery по другой причине (SF
больше не виноват); PQ-ioctl'ы (magic 'x', nr 60/64/65/67/69) не
обслужены. Образ: `boot_49_p55.img` md5 `cd23579b…`.

## p56–p61 — чёрная панель: шестая щель ABI, теперь в самом пиксельном пути

**Итог:** OVL не показывал ничего, потому что **ни один слой не был
включён**. Все прочие регистры при этом читались как «работает», из-за чего
предыдущие подходы уходили в ложные версии (тактирование CCORR/DITHER,
отсутствие M4U-маппинга) — обе **REJECTED**, см. ниже.

### Как нашли (метод тот же, что и в p47–p55: инструментировать и читать)

**FACT.** Расширенный `forgedump` (p60, коммит `38ee9240d`) впервые прочитал
регистры, решающие, забирается ли сконфигурированный слой:

```
OVL0 EN=0x1 ROI=0x50002d0 L0_CON=0x10020ff L0_ADDR=0xbf330000
OVL0 SRC_CON=0x0 BGCLR=0x0 L0_SRC_SIZE=0x50002d0 L0_PITCH=0xb80 RDMA0_CTRL=0x0
ROUTE OVL0_MOUT=0x2 DITHER_MOUT=0x2 COLOR0_SEL=0x0 DSI0_SEL=0x0 RDMA0_SOUT=0x1
MUTEX0 MOD=0x2f900 SOF=0x1 EN=0x1
```

`SRC_CON=0x0` — все четыре бита разрешения слоёв нулевые, поэтому OVL выдаёт
`ROI_BGCLR=0x0`, то есть непрозрачный чёрный, поверх идеально настроенных
ROI, адреса и pitch. Маршрутизация и mutex при этом корректны.

**FACT.** `L0_ADDR=0xbf330000` и `L0_PITCH=0xb80` — это значения, которые
оставил **LK**, а не ядро: 0xb80 = 2944 (выравненный шаг загрузчика), тогда
как 720×4 = 2880 = 0xb40. То есть ядро вообще ни разу не сконфигурировало
слой.

**FACT.** Шпион ioctl показал причину прямым текстом: каждый кадр
`UICompThread_0` шлёт `nr=206 size=1168`, и ядро отвечает
`ioctl not supported`. Плюс `nr=216 size=12` от surfaceflinger — тоже отказ.

### Причина (FACT, подтверждена побайтово)

`DISP_IOCTL_SET_INPUT_BUFFER` (nr 206) несёт список слоёв кадра. Между 3.18
и 4.9 `disp_input_config` обзавёлся полями фенса, dirty-ROI и compression,
геометрия ужалась с u32 до u16, флаги стали u8, а массив вырос с 8 слоёв до
12. Размер уехал **1168 → 1648**, вместе с ним уехал номер `_IOW`, и HAL
промахивался мимо обработчика на каждом кадре.

С 215-го вся таблица сдвинута на единицу (4.9 вставил `GET_VSYNC_FPS` на
215), поэтому «216» у HAL — это `GET_PRESENT_FENCE`, у которого ещё и два
выходных поля идут в обратном порядке.

Эталон взят из **`/srv/forge/android/m5c/k-worktrees/universal`** —
дерево 3.18.19 m5c, из которого собран рабочий `boot_k16.img`. Размеры
восстановленных структур проверены отдельной компиляцией: **1168 и 12
байт** — ровно то, что шлёт HAL.

**p61** `6e7c9e7a0` — обе легаси-раскладки описаны в `disp_session.h`,
транслируются по полям в 4.9-структуры и диспетчеризуются по легаси-номерам.
Фенса в слое 3.18 нет, а драйвер синхронизируется по `next_buff_idx` —
перевод без потерь.

### Проверка на устройстве (FACT)

| регистр | до p61 | после p61 |
|---|---|---|
| `OVL0 SRC_CON` | `0x0` | `0x1` |
| `RDMA0_CTRL` | `0x0` | `0x1` |
| `L0_ADDR` | `0xbf330000` (fb от LK) | `0x400000` (реальная MVA gralloc) |
| `L0_PITCH` | `0xb80` (2944, LK) | `0xb40` (2880 = 720×4) |

Отказов по 206 и 216 в dmesg больше нет. Остались неопознанными только
PQ-ioctl'ы (magic `'x'`, nr 60/64/65/67/69) — это picture quality, не
пиксельный путь.

### Отвергнутые версии

- **REJECTED — тактирование CCORR/DITHER.** `MMSYS_CG_CON0` показывал биты
  15/18 как gated, но p59 прочитал сами блоки: `EN=0x1 SIZE=0x2d00500`.
  Ручное снятие гейта (`forgeclk`) картинку не вернуло.
- **REJECTED — отсутствие маппинга в M4U.** `/sys/kernel/debug/m4u/buffer`
  содержит `0xbf330000 … DISP_OVL0_PORT0` — адрес был отображён.
- **REJECTED — маршрутизация MMSYS / mutex.** Прочитаны в p60, корректны.

### Открытые фронты

1. **Кадры не сменяются.** `L0_ADDR` держится на `0x400000` шесть секунд
   подряд; `surfaceflinger` спит в epoll, `bootanimation` заблокирован в
   binder. `/sys/kernel/debug/sync/info`: `timeline-primary-0-0: 11` при
   активном фенсе `12/11`, present-таймлайн `0-5` дошёл до 52. Схема
   освобождения N−1 в `primary_display.c:4549` корректна, значит встала
   подача кадров, а не релиз. **HYPOTHESIS:** голодание по буферам —
   продюсер ждёт release-фенс, который выдаётся только со следующим кадром.
   Проверить: снять `sync/info` дважды с интервалом и посмотреть, движется
   ли `0-0`; при остановке — сколько буферов в очереди bootanim.
2. **Уход в recovery через ~3–4 минуты.** Съедает каждое окно наблюдения.
   pstore на устройстве **несвежий** (ядро в записи `3.18.19 #28`, время
   14:28 при событии в 17:30) — отброшен как чужая улика; наше 4.9 в pstore
   ничего не пишет. **HYPOTHESIS:** init перезагружается в recovery из-за
   критического сервиса, падающего 4 раза за 4 минуты. Проверяется потоковым
   logcat до момента пропажи устройства.
3. `mt-pwm` probe падает (`-16`, IRQ 109) — отдельный дефект.

**Ловушка devbox (записать):** в `dev.sh adb shell '…'` перенаправления и
`;`-цепочки исполняет шелл контейнера, а не телефон. Из-за этого один прогон
дал ложную картину («debugfs не смонтирован, dmesg запрещён»). Все проверки
на устройстве гнать через скрипт, положенный на телефон.

## p63 — «уход в recovery каждые ~3 минуты» оказался нашим же скриптом

**FACT.** В логе перед пропажей устройства:

```
avc: denied { execute_no_trans } for path="/system/bin/reboot"
     scontext=u:r:init:s0
```

`/system/bin/reboot` запускал шелл под init. Источник — **`/init.forge.sh`
в рамдиске**, оставшийся с этапа, когда adb ещё не работал:

```
service forge_log /system/bin/sh /init.forge.sh   (init.forge.rc, on post-fs-data)
...
i=0; while [ $i -lt 30 ]; do … sleep 5; i=$(($i+1)); done
echo "=== forge_log: returning to recovery for log collection ==="
sync
reboot recovery
```

30 итераций × 5 с = **150 секунд**, дальше намеренный `reboot recovery` —
ровно наблюдавшиеся «3 минуты до TWRP». Дефекта ядра здесь нет; гипотеза
«crash-loop критического сервиса» **REJECTED**.

**Что сделано.** Строка `reboot recovery` убрана **только в нашем образе**:
рамдиск распакован из `boot_k16.img`, пропатчен и переупакован в
`boot_49_p63.img` (`cpio -H newc -R root:root` + gzip; 54 записи, размер
1616110 → 1615529). Сам `boot_k16.img` (эталон 3.18) **не изменён** — у
каждого boot.img своя копия рамдиска, общий файл не тронут.

**FACT (побочный, важный).** `/data` на устройстве зашифрован FDE. vold
подбирает дефолтный пароль (`Password matches`, `Master key saved`,
`Password is default - restarting filesystem`) и делает
`trigger_restart_framework`; при этом перезапускается adbd и adb
отваливается. Поэтому всё, что тестировалось раньше, шло в
**предрасшифровочной фазе на tmpfs `/data`**. После расшифровки система
поднимается дальше: `/data` = `dm-0`, живут `zygote64`, `zygote`,
`system_server`. Крутятся в падении только `agpsd`/`mnld` — известный
дефект, не критичные сервисы, к перезагрузке отношения не имеют.

**Открыто (главное):** конвейер кадров стоит. `L0_ADDR` не меняется
десятки секунд, `screencap` не завершается, `bootanimation` заблокирован в
binder, `surfaceflinger` спит в epoll. p62 (`7ff0ecd75`) ставит счётчики по
обе стороны: приход кадров в `SET_INPUT_BUFFER` и отпускание фенсов в
CMDQ-колбэке — они и покажут, какая половина петли сломана.

## p64–p66 — почему картинка не доходит до панели: путь собран, но не подключён

**FACT (регистры кроссбара на свежей загрузке, p64/p65):**

```
OVL0_MOUT=0x2  DITHER_MOUT=0x2  COLOR0_SEL=0x0  DSI0_SEL=0x0  RDMA0_SOUT=0x1
```

Расшифровка по таблицам `mout_map`/`sel_in_map`/`sel_out_map` из `ddp_path.c`:
`OVL0→WDMA0`, `DITHER→UFOE`, `COLOR0←RDMA0`, `DSI0←UFOE`, `RDMA0→COLOR0`.

**FACT (цепочка сценария, `dispsys/mt6735m/ddp_reg.h:36`):**
`DDP_SCENARIO_PRIMARY_DISP` для этого чипа =
`OVL0→COLOR0→CCORR→AAL→GAMMA→DITHER→RDMA0→PWM0→DSI0`, чему соответствуют
значения `0x1 / 0x1 / 0x1 / 0x1 / 0x2`.

**FACT:** прочитанные значения складываются в другую пару цепочек —
`PRIMARY_RDMA0_COLOR0_DISP` + `PRIMARY_OVL_MEMOUT`, то есть **decouple**.

**FACT:** в узле `DISPSYS` (`mt6735m.dts:1504`) у `DISP_UFOE` запись `<0 0>` —
блок на этом чипе не отображён. Хвост decouple-цепочки идёт через UFOE.

**FACT:** `__build_path_direct_link` исполняется на 0.638 с и создаёт путь
успешно (`pr_warn` в dmesg), но `dpmgr_create_path` **не подключает**
кроссбар: `dpmgr_path_connect` зовётся только из resume-путей — и в 4.9, и
в 3.18 одинаково (`ddp_manager.c`).

**INFERENCE (на этих FACT):** на загрузке кроссбар остаётся тем, что оставил
LK. Ядро идеально настраивает OVL — `SRC_CON=0x1`, верный gralloc-адрес,
pitch 2880 — но его пиксели уходят в память через WDMA0, а панель продолжает
сканировать то, что LK оставил в RDMA0. Это ровно наблюдавшееся «кроме
бутлого ничего нет», а после очистки буфера — чёрный экран.

**Проверка на живом устройстве:** сырая запись правильных значений в
регистры (`forgeroute`) **не держится** — драйвер перезаписывает их из
своего состояния (замерено: через ~30 минут значения вернулись к
`0x2/0x2/0x0/0x0/0x1`). Поэтому p66 добавляет `forge_reconnect_primary()` —
подключение через `dpmgr_path_connect` + `dpmgr_path_start`, что заодно
обновляет mutex, и шпион `pr_err` на каждый `ddp_connect_path` с именем
вызывающего (`%pS`), чтобы назвать, кто именно ставит decouple.
`DISPDBG` в этом файле разворачивается в пустоту — потому вызов и был невидим.

### Отвергнутые и отозванные версии

- **REJECTED — расхождение enum `DISP_MODE`.** Значения
  `DIRECT_LINK=1 / DECOUPLE=2 / …` в 3.18 и 4.9 совпадают.
- **REJECTED — `MTK_OVL_DECOUPLE_SUPPORT`.** Макрос не определён ни в одном
  дереве, оба по умолчанию `DIRECT_LINK_MODE`.
- **REJECTED — расхождение `disp_buffer_info` (ioctl 204).** Побайтово
  одинаков в 3.18 и 4.9; релиз-фенсы продюсеру выдаются корректно.
- **REJECTED — сломанный CMDQ-колбэк релиза фенсов.** p62 показал строгую
  пару: `setinput #1…#8` ↔ `release #1…#8`, обе половины петли живы.
- **REJECTED — расхождение `DSI_PHY_clk_setting`.** 267 строк в обоих
  деревьях, отличия косметические.
- **ОТОЗВАНО — «встроенный генератор DSI не даёт картинки, значит панель
  мертва».** Тест ставился на прошлой загрузке, а `BIST_CON/BIST_PATTERN`
  тогда не читались; на следующей загрузке они оказались чистыми. Улика
  недействительна, вывод снят.
- **НЕУБЕДИТЕЛЬНО — заливка фона OVL красным (`forgered`).** Модули DDP
  защёлкивают конфигурацию по началу кадра, а конвейер стоял; отсутствие
  красного ничего не доказывает.

### Состояние конвейера кадров (FACT, p62)

`setinput` и `release` идут парами и обрываются на 6-й секунде. Дальше:
`timeline-primary-0-0` = 19 при активном фенсе `20/19`, present-таймлайн
`0-5` = 56, GPU-таймлайн bootanimation = **92** — то есть анимация
рисуется, но до дисплея доходит малая часть, и через 16 секунд все три
счётчика стоят намертво. `screencap` не завершается. Стеки: главный поток
bootanimation в обычном binder-пуле, поток анимации спит в
`clock_nanosleep`, surfaceflinger спит в epoll — **никто не заблокирован**,
просто композиция никому не нужна, потому что кадры некуда отдавать.

### Следующий шаг (образ готов, ждёт телефона)

`boot_49_p66.img` md5 `efa4f0aa32ad6f000cc5418ced650a59`.
Порядок: загрузиться → `dmesg | grep forge-path` (кто и на какой сценарий
подключал путь) → `printf forgeconnect > /sys/kernel/debug/dispsys` →
сверить `ROUTE` и посмотреть на панель. Если после подключения через
менеджер путь встаёт в `0x1/0x1/0x1/0x1/0x2` и появляется картинка —
причина подтверждена, и штатное лечение: подключать путь при инициализации,
а не только на resume.

## p67 — сужение по коду: пять версий отвергнуто, осталась одна проверяемая

Телефон был отключён, работа шла по исходникам, сверкой с 3.18-оракулом
(`/srv/forge/android/m5c/k-worktrees/universal`).

### Поправка к записи p64–p66

**ОТОЗВАНО:** «на этом чипе нет UFOE, поэтому цепочка decouple физически
невозможна». Запись `<0 0>` в стоковом DTB (проверено `dtc` по самому
`dtb_stock.dtb`, узел `DISPSYS`) и слот `0` в таблице драйверов
(`ddp_info.c:282`) доказывают лишь, что **ядро не отображает и не
программирует** UFOE. Ровно то же верно для 3.18, который показывает
картинку. Вывод снят; остаётся факт рассогласования: железо в decouple,
драйвер в direct-link.

### Отвергнуто по коду

- **REJECTED — таблица цепочек разъехалась.** `module_list_scenario` в
  `dispsys/mt6735m/ddp_reg.h` **побайтово идентична** в 3.18 и 4.9 (59 строк,
  diff пуст).
- **REJECTED — мы заявляем HWC поддержку decouple.** `DISP_HW_MODE_CAP`
  выбирается по `CONFIG_MTK_GMO_RAM_OPTIMIZE`, и он `=y` в **обоих** ядрах
  (4.9 `.config:2965`, 3.18 `.config:2876`) → оба заявляют
  `DISP_OUTPUT_CAP_DIRECT_LINK`.
- **REJECTED — принудительный decouple по состоянию дисплея.**
  `primary_display_switch_mode` подменяет запрошенный режим на DECOUPLE при
  `DISP_FREEZE`/`DISP_BLANK` (новый код Q0, в 3.18 этих состояний нет вообще
  — 0 вхождений против 6). Но `DISP_BLANK` ставит только `display_enter_tui`,
  `DISP_FREEZE` — только `display_freeze_mode`; на обычной загрузке состояние
  `DISP_ALIVE` (`primary_display.c:5477`).
- **REJECTED — `init_decouple_buffers()` перестраивает путь.** Функция только
  выделяет буферы и заполняет структуры конфигурации, кроссбар не трогает.
- **REJECTED — расхождение `disp_input_config`/`disp_session_config`
  в trigger-ioctl.** Структура `disp_session_config` (nr 203/209) идентична
  по полям в обоих деревьях; enum `DISP_MODE` тоже (`DIRECT_LINK=1`,
  `DECOUPLE=2`).

### Новый FACT: resume на загрузке не делает ничего

`primary_display_resume()` (`primary_display.c:5911`) выходит сразу, если
`pgc->state != DISP_SLEPT`. На загрузке состояние `DISP_ALIVE`, поэтому все
четыре `late_resume` (3.4 / 3.9 / 8.0 / 8.4 с в dmesg) — пустые, и
`dpmgr_path_connect` в них не исполняется. То есть кроссбар на холодной
загрузке остаётся **тем, что оставил LK**, и это одинаково верно для 3.18.

### Мелкий дефект, найденный попутно

Под тем же `CONFIG_MTK_GMO_RAM_OPTIMIZE` 3.18 задаёт
`DISP_INTERNAL_BUFFER_COUNT 3`, а 4.9 — **1**; и вызов
`init_decouple_buffers()` в 3.18 этим макросом отключён, а в 4.9 гард снят.
Не причина чёрного экрана, но расхождение с рабочим деревом — записать в
список на выравнивание.

### Исправлено

`_ioctl_get_display_caps_legacy` (наш p47) заполнял не все поля после
`copy_from_user`: `is_support_frame_cfg_ioctl` и `is_output_rotated`
возвращались в userspace такими, какими их прислал HAL. Ненулевой
`is_support_frame_cfg_ioctl` увёл бы HAL на frame-config вместо
`SET_INPUT_BUFFER`. Структура обнуляется перед заполнением (`86da16321`).

### Что снимет следующая загрузка (образ готов)

`boot_49_p67.img` md5 `996f5d36dc8a25bd99328c82179cb0ea`.

1. `dmesg | grep forge-path` — кто и на какой сценарий звал
   `ddp_connect_path` (печатается вызывающий через `%pS`), плюс
   `driver session_mode` против регистров.
2. `dmesg | grep forge-mode` — какой режим просит HWC (1 = direct link,
   2 = decouple) и просит ли вообще.
3. `dmesg | grep forge-irq` — счётчики прерываний RDMA0/DSI0/OVL0/MUTEX.
   В видеорежиме vsync для SurfaceFlinger — это `DDP_IRQ_RDMA0_DONE`
   (`primary_display.c:2233`). Конвейер замирает при том, что **никто не
   заблокирован** (SF спит в epoll, поток анимации в `nanosleep`,
   GPU-таймлайн 92 против дисплейного 19) — так выглядит именно умерший
   vsync. Счётчик это и покажет.
4. `printf forgeconnect > /sys/kernel/debug/dispsys` — подключить путь через
   менеджер и посмотреть на панель.

## p68–p69 — два офлайн-фронта закрыты по исходникам

### p68 — probe `mt-pwm` больше не валится из-за диагностического прерывания

**FACT.** `mt_pwm_probe` (`drivers/misc/mediatek/pwm/mtk_pwm.c:1822`)
запрашивал IRQ и **возвращал ошибку** при неудаче, поэтому всё
PWM-устройство оставалось непривязанным.

**FACT (оракул).** Рабочий 3.18 (`mt_pwm.c:1720`) это прерывание **вообще
не запрашивает**: блок закрыт `#if 0`, вызов `request_irq` закомментирован,
остаются только отображение регистров и клок. То есть драйвер заведомо
работоспособен без IRQ.

**FACT.** При `PWM_LDVT_FLAG = 0` (`mtk_pwm.c:48`) обработчик только
подтверждает прерывание и пишет в лог — ни completion, ни waitqueue, ничего
в драйвере его не ждёт.

**FACT.** В стоковом DTB на `0x11006000` объявлены **два** узла с одним и тем
же прерыванием `<0x00 0x4d 0x08>` (SPI 77 → Linux IRQ 109): `mediatek,PWM` и
`mediatek,pwm`. Драйвер есть только у второго (сравнение регистронезависимое
не работает — DT матчинг чувствителен к регистру), поэтому **кто именно
держит линию, из исходников не доказать**. Патч печатает реальный код
возврата и virq — следующая загрузка скажет.

Фикс: не прерывать probe, залогировать и продолжить (`f418084d8`).

### p69 — ABI-щель №7: PQ-параметры

Номера ioctl'ов magic `'x'` в 3.18 и 4.9 **идентичны**, разъехались размеры
структур, а `_IOW` кодирует размер.

| nr | ioctl | шлёт HAL | в 4.9 | причина расхождения |
|---|---|---|---|---|
| 60 | `SET_PQPARAM` | 56 | 60 | в конец `DISP_PQ_PARAM` добавлено `u4ColorLUT` |
| 64 | `SET_PQINDEX` | 2764 | много больше | массивы `u8`/`u16` → `u32`, плюс `S_GAIN_BY_Y`, `S_GAIN_BY_Y_EN`, `LSP_EN`, `LSP`, `COLOR_3D` |
| 65 | `SET_TDSHPINDEX` | 3984 | 7008 | `THSHP_PARAM_MAX` 83 → 146 (TDSHP_3_0) |
| 67 | `SET_PQ_CAM_PARAM` | 56 | 60 | то же поле |
| 69 | `SET_PQ_GAL_PARAM` | 56 | 60 | то же поле |

Размеры 3.18-раскладок проверены **отдельной компиляцией на хосте**:
`DISP_PQ_PARAM` = 56, `DISPLAY_PQ_T` = 2764 — совпадают с тем, что шлёт HAL,
побайтово. `DISPLAY_TDSHP_T` = 12 × 83 × 4 = 3984 — тоже.

**Сделано (`f8a3777ef`):** три вызова с `DISP_PQ_PARAM` (60/67/69)
обслуживаются через `struct DISP_PQ_PARAM_LEGACY` с переносом по полям;
`u4ColorLUT` остаётся тем, что держит драйвер — у HAL нет мнения о поле,
которого при его сборке не существовало.

**Намеренно НЕ сделано:** 64 и 65. Это не перенос, а вопрос по существу:
для `DISPLAY_PQ_T` надо расширять таблицы из `u8`/`u16` в `u32` и решать,
чем заполнять пять новых полей; для `DISPLAY_TDSHP_T` HAL заполняет только
первые 83 записи из 146 в каждой строке, и что должно быть в оставшихся 63 —
вопрос к более новому блоку TDSHP, а не к копированию. Делать вслепую, без
устройства, — это гадание; числа зафиксированы, работа осознанная.

**Образы:** `boot_49_p68.img` md5 `b23abeec39eaf13171744a26a9cf4f92`,
`boot_49_p69.img` md5 `55e03abcd0ece3a309b936c62585bfb2` (включает p60–p69).

## p70–p71 — чёрный экран закрыт; остался затык композиции (день на устройстве)

### ЗАКРЫТО: картинка доходит до панели

Пользователь наблюдал загрузочную анимацию на экране. Значит панель, DSI,
MIPITX, подсветка, маршрутизация и прерывания исправны. Чёрный экран как
дефект закрыт правкой p61 (шестая щель ABI).

### Снятые утверждения (были ошибочны)

- **СНЯТО — «рассогласование драйвера и железа: кроссбар в decouple, драйвер
  в direct link».** Шпион p66 назвал виновника: поток `display_idle_de`
  (`_disp_primary_path_idle_detect_thread`) штатно уводит путь в decouple
  через 12 с бездействия — `primary_all` → `primary_rdma0_color0_disp` +
  `primary_ovl_memout`, — а на 28.5 с возвращает обратно. Драйвер при этом
  сам сообщает `session_mode=2`, то есть знает, где находится. Рассогласования
  нет. Замерший кадр на панели — следствие: в decouple RDMA продолжает светить
  последним композитом из памяти.
- **СНЯТО — «HWC просит decouple».** Все 12 вызовов `set_session_mode`
  запрашивают режим **1 = DIRECT_LINK** (p67, `forge-mode`).
- **СНЯТО — «умер vsync».** `forge-irq`: RDMA0 = 9508 прерываний за 44 с.
- **СНЯТО — «у SurfaceFlinger умер пул binder-потоков».** На одной загрузке
  так и было (`ready threads 0`, три неразобранные транзакции, потоки 288/290/441
  есть в binder, но отсутствуют в `/proc`). Однако на следующей загрузке пул
  здоров (`requested threads 0+4/4`, `ready threads 4`), во всей системе **ноль**
  `BC_EXIT_LOOPER` (ftrace по `binder_command`/`binder_return` с фильтром на
  0x630b/0x630c/0x630d/0x720d), а затык воспроизвёлся точно такой же. Значит
  это следствие, а не причина.

### Что установлено о самом затыке (FACT)

- Кадры перестают подаваться: `SET_INPUT_BUFFER` (nr 206) — 14–24 вызова за
  всю загрузку и дальше ноль. Гистограмма по номерам ioctl добавлена в p70.
- Стек bootanimation: `BufferQueueProducer::waitForFreeSlotThenRelock` ←
  `dequeueBuffer` ← `BnGraphicBufferProducer::onTransact`. Свободных слотов нет.
- `dumpsys SurfaceFlinger`: `mMaxAcquiredBufferCount=1`,
  `mMaxDequeuedBufferCount=2`, `FIFO(1)` — кадр лежит в очереди, слот 02
  `ACQUIRED`, при этом у слоя `queued-frames=0`, то есть SF о лежащем кадре
  не знает и не защёлкивает его.
- Пинок `service call SurfaceFlinger 1004` поднял `flips` 872 → 890 (SF
  отработал 18 циклов), но **в ядро не ушло ни одного нового кадра** и таймлайн
  не сдвинулся. То есть кадры теряются между SF и ядром, в вендорском HWC.
- Вендорский HWC пишет `[OVL] (0) Waiting for available OVL` тысячами строк.
- GPU против дисплея: на одной загрузке mali-таймлайн дошёл до 871 при 18
  дошедших до дисплея; на другой — 12 при 11. Разброс между загрузками большой.

### Проверено и НЕ подтвердилось (p71, `797cbc7e8`)

Гипотеза: ядро отпускает фенс слоя как `cur_fence − 1`, то есть держит кадр,
который на экране, до прихода следующего; HWC не подаёт следующий, пока не
вернут оверлей, а тот возвращается по этому же фенсу — обе половины ждут друг
друга. Добавлена команда `forgerel:N`, отпускающая все фенсы слоя.

**Результат отрицательный.** Освобождение сработало (таймлайн 11 → 12), но
конвейер не поехал: `SET_INPUT_BUFFER` остался 14, GPU-таймлайн не сдвинулся,
через 13 с без изменений. Фенс — не то, чего ждёт конвейер. Гипотеза снята.

Отдельно сверено и **не является расхождением**: `_ovl_fence_release_callback`
в 3.18 и 4.9 совпадает (отличия — только наша инструментация p62);
`primary_display_save_power_for_idle` совпадает; `maxLayerNum` считается
одинаково (`CONFIG_MTK_ROUND_CORNER_SUPPORT` не задан, ветка вырождается);
`isOVLDisabled`/`const_layer_num`/`updateFPS` не заполняются **ни в одном** из
деревьев.

### Куда копать дальше

Кадры теряются в вендорском HWC: SF композитит, ядро новых кадров не получает.
Следующий шаг — не ядро, а сам HWC: разобрать `hwcomposer.mt6737m.so` по
строке `Waiting for available OVL` и найти, какое условие он ждёт (какой ioctl
или какое поле session-info опрашивает — nr 208 вызывается 86 раз на 24 кадра).
Ядерные рычаги, которые могли бы это объяснить, проверены и исключены.

**Образы:** `boot_49_p70.img` md5 `2e14d516c9ceb33b9b80d77df5ac25b0`,
`boot_49_p71.img` md5 `7744fb83b9a0d762601079b9458c20e9`.

## ЗАГРУЗИЛОСЬ В СИСТЕМУ (2026-08-24) — блокером был вендорский hwcomposer

**FACT.** LOS 14.1 на ядре 4.9 дошла до полностью рабочего UI. Сырой дамп
`/dev/graphics/fb0` (3686400 байт, 720×1280 RGBA, собран в PNG на хосте, без
участия GPU-путей) содержит корректный экран блокировки: часы, дата,
статус-бар с зарядом, уведомление об отладке по USB, нижние ярлыки, меню
питания. `sys.boot_completed=1`, `dev.bootcomplete=1`,
`init.svc.bootanim=stopped` (анимация завершилась штатно),
`ActivityManager: Displayed com.cyanogenmod.trebuchet/…Launcher: +1s973ms`.

**Что было блокером.** `hwcomposer.mt6737m.so` (вендорский, собран под 3.18):
он принимал кадры от SurfaceFlinger и не подавал их в ядро, бесконечно
печатая `[OVL] (0) Waiting for available OVL (cnt=…)`. Диагностика: SF
композитил (`flips` рос), а счётчик `SET_INPUT_BUFFER` в ядре стоял намертво —
кадры терялись именно в HWC. Понижение `debug.hwc.compose_level` до 0 и
`debug.hwc.bq_count=4` давало лишь несколько лишних кадров после перезапуска
SF, но затык возвращался.

**Что сделано (обратимо).** Вендорский HAL отключён переименованием:
```
/system/lib64/hw/hwcomposer.mt6737m.so -> .forgebak
/system/lib/hw/hwcomposer.mt6737m.so   -> .forgebak
```
SurfaceFlinger перешёл на путь через fbdev (`mtkfb`), который на нашем ядре
исправен. Дисплейные ioctl'ы disp_mgr при этом исчезают из гистограммы
полностью — сессия не открывается вовсе.

**Побочный эффект, который надо знать.** Без HWC дисплей остаётся с
`powerMode=0` и `layerStack=4294967295`, слои ему не назначены, SF заливает
фреймбуфер непрозрачным чёрным (`00 00 00 ff`). Лечится пробуждением:
`input keyevent 224` — после этого `Display Power: state=ON`, слои встают на
`layerStack=0`, картинка появляется. Для постоянной работы это надо
делать штатно (питание дисплея при старте без HWC), иначе после загрузки
экран чёрный при полностью живой системе.

**Открыто:** `screencap` возвращает чёрный кадр — идёт через GPU-снимок
(mali), а не через фреймбуфер; на изображение на панели не влияет.
Вендорский HWC остаётся неисправным — его разбор по строке
`Waiting for available OVL` нужен, если захотим вернуть аппаратные оверлеи
(а с ними — энергоэффективность и MDP-пути).

**Ручки HWC, найденные в блобе** (`strings` по
`hwcomposer.mt6737m.so`): `debug.hwc.compose_level`, `debug.hwc.bq_count`,
`debug.hwc.ovl_overlap_limit`, `debug.hwc.disable_p_fence`,
`debug.hwc.dump_level`, `debug.hwc.profile_level`, `debug.hwc.SinglePassOnly`,
`debug.hwc.force_rgb_output`, `debug.sf.sw_vsync_fps`.

## Рабочая система на 4.9: тач и диагональ (2026-08-24, вечер)

**FACT.** На экране «Настройки → Состояние телефона» с надписью
`Версия ядра 4.9.188-m5c+ n8n@n8nagent #93`, снято сырым дампом `fb0`.
Пользователь дошёл до этого экрана касаниями, поверх видна отладочная
трасса указателя с нарисованным следом пальца.

### Тач (`675a15532`)

**FACT.** В `m5c_defconfig` стояло `# CONFIG_INPUT_TOUCHSCREEN is not set` —
подсистема была вырезана целиком, в системе жили только `ACCDET` и `mtk-kpd`,
узлов ввода два. Оракул 3.18 включает:
`CONFIG_INPUT_TOUCHSCREEN=y`, `CONFIG_TOUCHSCREEN_MTK=y`,
`CONFIG_TOUCHSCREEN_MTK_GT9XXTB_HOTKNOT=y`,
`CONFIG_GT9XXTB_FIRMWARE="firmware_default"`,
`CONFIG_GT9XXTB_CONFIG="config_default"`. Драйвер в дереве 4.9 присутствует
(`drivers/input/touchscreen/mediatek/GT9XXTB_hotknot`). Включено — появились
`mtk-tpd` и `mtk-tpd-kpd`, узлы `event2`/`event3`, `ABS_X` до 720.

**Осознанно НЕ включено:** `CONFIG_TOUCHSCREEN_MTK_FT5x46=y`, который есть в
оракуле для ревизий с FocalTech. Этот экземпляр — Goodix GT917, а именно эта
опция записана как ломающая дисплей в универсальной 3.18-сборке, причём
причина до сих пор не найдена.

### Диагональный сдвиг (`675a15532`)

**FACT (измерено, не на глаз).** Сырой дамп `fb0`, прочитанный с шагом 720
пикселей, собирается в идеально ровный кадр; тот же дамп с шагом 736 —
воспроизводит ровно ту диагональ, что видна на панели. Значит строки лежат
упакованно по `xres * bpp/8` = 2880 байт.

**Причина.** `mtkfb_pan_display_impl` программировал шаг оверлея как
`ALIGN_TO(var->xres, MTK_FB_ALIGNMENT)` = 736 пикселей = 2944 байта. Каждая
строка уходила на 16 пикселей. Исправлено: `src_pitch = var->xres`.
После правки `L0_PITCH=0xb40` (2880) вместо `0xb80`, текст ровный.

**Важно — это следствие обхода HWC, а не старый дефект ядра.** Пока работал
вендорский hwcomposer, кадры шли через gralloc-буферы и fbdev не
использовался вовсе.

**ОТРИЦАТЕЛЬНЫЙ РЕЗУЛЬТАТ (не повторять).** Первая попытка — согласовать шаг
через `MTK_FB_ALIGNMENT 32 → 16`, чтобы и `xres_virtual`, и `line_length`
стали 720/2880. **Запись в фреймбуфер прекратилась полностью**: все три
страницы чёрные при `powerMode=2` и `numLayers=3`. Писатель (gralloc)
рассчитывает на прежний размер буфера. Откачено; менять надо ТОЛЬКО шаг
сканирования, не трогая размещение памяти и `fix.line_length`.

### Открыто

- Тонкие косые линии по кадру. Содержимое под ними правильное и буквы чёткие,
  то есть это не сдвиг строк — отдельный артефакт, причина не установлена.
- Без HWC никто не включает дисплей при старте: `powerMode=0`,
  `layerStack=4294967295`, SF заливает чёрным. Лечится `input keyevent 224`.
  Нужно штатное включение питания дисплея на пути без HWC.
- `screencap` отдаёт чёрный кадр (GPU-путь mali), на панель не влияет.
- Вендорский HWC остаётся неисправным; аппаратные оверлеи и MDP-пути с ним
  вернутся только после разбора `Waiting for available OVL` в самом блобе.

**Образ:** `boot_49_p74.img` md5 `9be0967288e341da9ab702b30d5d7f71`.

### ОТРИЦАТЕЛЬНЫЙ РЕЗУЛЬТАТ p75 — смещение страниц трогать нельзя

Гипотеза: раз строки лежат по 2880, то и начало каждой следующей страницы
фреймбуфера должно отсчитываться шагом 2880, а `mtkfb_pan_display_impl`
считает `offset = yoffset * fix.line_length` = 2944 — расхождение 81920 байт
(≈28 строк) на каждый переход, отсюда «редко криво обновляются».

**Результат: стало заметно хуже — «экран вообще поехал».** Правка откачена,
возвращён `boot_49_p74.img` (md5 `9be0967288e341da9ab702b30d5d7f71`).

**Вывод (INFERENCE):** строки внутри страницы упакованы по 2880 (это FACT,
проверено чтением дампа двумя шагами), но **страницы разнесены по
`fix.line_length`**, то есть по 2944×1280. Одно другому не противоречит:
писатель кладёт каждую страницу как отдельный буфер шириной 720, а ядро
размещает их с выравненным шагом. Поэтому менять можно ТОЛЬКО шаг
сканирования строк (p74), а арифметику смещения страниц — нельзя.

**Идея на следующий заход (не проверена):** убрать панорамирование совсем,
сделав `yres_virtual = yres` (одна страница). Тогда вопрос о шаге между
страницами исчезает вместе с рассинхроном; ценой станет отсутствие двойной
буферизации. Проверять на живом устройстве.

**Осталось видимым:** тонкие косые линии и редкие кривые обновления кадра.

## Реверс вендорского HWC (Ghidra) — карта интерфейса и что НЕ является причиной

Блоб `hwcomposer.mt6737m.so` (arm64, 333 КБ) **сохранил все символы**, поэтому
Ghidra даёт не догадки, а имена и код. Загружается в GhidraMCP как есть,
база `0x4000`, 1381 функция.

### Цикл ожидания оверлея — расшифрован целиком

`OverlayEngine::waitUntilAvailable()` @ `0x2cc38`:

```c
cnt = 0;
do {
    cnt++;
    n = getAvailableInputNum();
    if (n != 0) return 1;                       /* успех */
    log("[%s] (%d) Waiting for available OVL (cnt=%d)", ..., cnt);
    usleep(5000);
} while (cnt != 1000);
log(" ! (%d) Timed out waiting for OVL (cnt=%d)");   /* сдаётся через 5 с */
```

`OverlayEngine::getAvailableInputNum()` @ `0x2cb8c`: зовёт виртуальный метод
устройства (vtable+0x58), и для основного дисплея вычитает резерв из
`DisplayManager` (поле +0xc), причём если резерв ≥ значения, возвращает
значение как есть — то есть **ноль возможен только если ноль пришёл снизу**.

`DispDevice::getAvailableOverlayInput(int)` @ `0x288bc`:

```c
s.session_id = ...;
ioctl(fd, 0x40484fd0, &s);      /* = наш GET_SESSION_INFO, nr 208, 72 байта */
return s.maxLayerNum;            /* второе слово структуры */
```

**То есть число доступных оверлеев HWC берёт ровно из обработчика p52.**

### ОТВЕРГНУТО измерением (p76, `670f1fbe5`)

Гипотеза: `primary_display_get_info()` умеет выйти с ошибкой до заполнения
структуры, а обработчик p52 её возврат не проверял — значит HWC мог получать
ноль. Проверка возврата добавлена (она верна сама по себе), печать показала:

```
forge-info: #1..#6 session=0x10000 ret=0 maxLayerNum=4 vsync=1 w=720 h=1280
```

Ошибок обработчика в логе нет вовсе. **Ядро отдаёт 4, а не 0** — версия
неверна, снята.

**Более того:** на этой загрузке HWC не печатал `Waiting for available OVL`
ни разу (счётчик 0), а кадры всё равно встали на 13-м. Значит цикл ожидания
оверлея — не обязательный механизм затыка, он проявляется не на каждой
загрузке. Искать надо не его.

### Карта интерфейса ядра для СВОЕГО HWC

Из символов блоба видна вся поверхность, которую нужно повторить:

- `DispDevice`: `initOverlay`, `createOverlaySession`, `destroyOverlaySession`,
  `setOverlaySessionMode`, `getOverlaySessionMode`, `getOverlaySessionInfo`,
  `getMaxOverlayInputNum`, `getAvailableOverlayInput`, `prepareOverlayInput`,
  `prepareOverlayOutput`, `prepareOverlayPresentFence`, `enableOverlayInput`,
  `enableOverlayOutput`, `disableOverlaySession`, `updateOverlayInputs`,
  `triggerOverlaySession`, `waitVSync`, `setPowerMode`, `setCapsInfo`.
- `OverlayEngine`: `prepareInput`, `setInputs`, `setInputQueue`, `updateInput`,
  `disableInput`, `trigger`, `flip`, `preparePresentFence`, `setPowerMode`.
- Прочие классы: `HWCMediator`, `HWCDispatcher`, `DispatchThread`,
  `ComposerHandler`, `LayerHandler`, `BliterHandler`, `MMLayerComposer`,
  `DisplayBufferQueue`, `GrallocDevice`, `IONDevice`, `MMUDevice`,
  `SyncFence`, `SyncControl`.

Номера ioctl'ов и раскладки структур у нас уже есть — мы сами их реализовали
(p47/p52/p61/p69), так что свой HWC пишется поверх известного ABI.

## p77 — СВОЙ HWCOMPOSER РАБОТАЕТ: конвейер кадров жив, дисплей включается сам (2026-08-24)

### Решение по стратегии (вместо починки блоба)

Выбран вариант «свой HWC поверх нашего disp_mgr-ABI», а не (а) реверс-починка
вендорного блоба, не (б) DRM/KMS. Обоснование:

- Корень затыка блоба НЕ установлен даже после реверса с символами (p76:
  цикл `Waiting for available OVL` — не механизм затыка, ядро отдаёт
  `maxLayerNum=4`); дальнейший дебаг чужого бинаря не ограничен по времени.
- DRM/KMS для mt6735m упирается в жёсткое ограничение: мы грузимся со
  **стоковым DTB 2017** (p46), а drm/mediatek требует полного display-graph
  в DT; плюс это месяцы работы. Отложен как дальний ориентир.
- Свой модуль разделён на **version-neutral движок** (сессия/кадр/фенсы/
  vsync/power поверх нативного 4.9 UAPI `disp_session.h`) и **тонкий
  HWC1-фасад** под SF Android 7. На лестнице LOS 15.1→16→18.1 движок
  переиспользуется: фасад HWC1 живёт под стандартным `hwc2on1adapter`,
  либо пишется нативный HWC2-фасад (~500 строк) поверх того же движка.
  Ядро остаётся нашим 4.9 — ABI не меняется.

### Что сделано

`device/meizu/m5c/hwcomposer/` — модуль `hwcomposer.mt6737m` (C, ~650 строк,
линкуется только против libc/liblog/libdl/libm):

- `forge_hwc.c` — движок + HWC1.1-фасад. prepare(): всё в GLES (FBT);
  set(): ждать acquire-fence FBT в userspace (FACT: ядро 4.9 НЕ потребляет
  `src_fence_fd` — ни одного читателя вне compat-конверсии) →
  `PREPARE_INPUT_BUFFER`(204, ion fd → idx + release-fence) →
  `GET_PRESENT_FENCE`(217) → `SET_INPUT_BUFFER`(206, нативная 12-слойная,
  L0 включён, L1–L3 явно выключены) → `TRIGGER_SESSION`(203,
  present_fence_idx). vsync — поток в `WAIT_FOR_VSYNC`(213);
  power — `FBIOBLANK` на fb0. ion fd и stride буфера — через
  `gralloc_extra_query` (dlopen вендорного `libgralloc_extra.so`,
  C-символ, проверен readelf'ом; фолбэк: `handle->data[0]` + ширина).
- `disp_session_uapi.h` — **байт-в-байт копия** ядерного
  `drivers/misc/mediatek/video/include/disp_session.h` (md5 совпадает).
  Размеры на LP64 (хостовый пробник): input_config=136,
  session_input_config=**1720** (уточнение: в p61 фигурировала оценка 1648 —
  неверная; ядро компилирует тот же заголовок тем же ABI, номера совпадают
  по построению), session_config=36, buffer_info=36, present=12, vsync=24,
  info=84.
- `Android.mk` (канонический путь, `PRODUCT_PACKAGES += hwcomposer.mt6737m`
  в product/display.mk) + `build_standalone.sh` (gcc 4.9 + NDK android-24
  из prebuilts дерева — бинарь за секунды, без полного парса ROM).

### Проверено на устройстве (FACT, всё после холодного ребута)

- `forge-hwc: session 0x10000 720x1280 vsyncFPS=5850 period=17094017ns
  maxLayer=4` в dmesg на **3.5 с** загрузки — SF подхватил модуль сам.
- **Конвейер не встаёт**: setinput #2500+ (счётчик p62), при вендорном
  блобе клин был на 13–24 кадрах. `dumpsys`: `frames=2548 prepare_fail=0
  trigger_fail=0 acq_timeout=0`, idx == pf_idx == flips.
- Регистры (forgedump): `SRC_CON=0x1 RDMA0_CTRL=0x1 L0_PITCH=0xb40
  L0_ADDR=0x400000` (MVA gralloc) — слой включён, шаг верный.
- Таймлайны фенсов: `timeline-primary-0-0: 992` при flips=993 (схема N−1),
  present `0-5: 993` — обе половины петли живут.
- **`powerMode=2`, state=ON с холодного старта** — болезнь «без HWC никто
  не включает дисплей (`powerMode=0`, будить keyevent 224)» ЗАКРЫТА.
- SF/WM видят **58.5 fps** (`presDeadline 17094017`). Первая сборка делила
  `vsyncFPS` как Гц и SF показывал «5850 fps» — MTK отдаёт **fps×100**
  (FACT, измерено), исправлено.
- **`screencap` впервые отдаёт картинку** (на fbdev-пути был чёрный):
  снят PNG локскрина — часы, дата, ярлыки, цвета и геометрия правильные,
  диагонали нет. (Это GLES-композиция SF, панельный OVL-путь подтверждён
  регистрами; финальную сверку цветов на стекле делает человек.)
- Цикл сна: `blank(1)`→suspend, `blank(0)`→resume, +10 кадров на
  пробуждении, ноль ошибок, ноль `DISPERR`.
- fbdev-артефакты (тонкие косые линии, рваные обновления, p74/p75)
  структурно ушли вместе с fbdev-путём: композиция идёт gralloc→ion→OVL
  с per-buffer pitch. Подтвердить глазами.

### Состояние устройства после сессии

`boot_49_p74.img` не менялся (uname тот же), вендорские блобы остаются
`.forgebak`, поверх добавлены наши
`/system/lib{,64}/hw/hwcomposer.mt6737m.so` (md5 19ffe3e9…/ff4ddfc9…).
Откат на fbdev-путь: удалить оба файла, `kill $(pidof surfaceflinger)`.

### Открыто

- Визуальная сверка на стекле (цвета OVL-пути, плавность) — за человеком.
- HW-оверлеи (прямые слои мимо GLES) и MDP не реализованы — осознанно:
  GLES-only корректен и покрывает всё; оверлеи — оптимизация энергии/полосы,
  добавлять поверх работающего движка по одному слою.
- `vsync_on=1` в моменте не пойман (SF включает HWC-vsync эпизодически для
  ресинка DispSync); косвенно жив: пейсинг кадров ровный, ворнингов DispSync
  нет. INFERENCE, не FACT.
- 32-битная копия модуля собрана и установлена, но SF 64-битный (FACT:
  ELFCLASS64) — 32-битный путь (compat-ioctl) не прогонялся.

## p78 — измерение частоты кадров на своём HWC

Метод: считать `SET_INPUT_BUFFER` (nr 206) и `WAIT_FOR_VSYNC` (nr 213) по
гистограмме `forge-ioctl` до и после одинаковой нагрузки (25 × `input swipe`).
Доля vsync'ов, получивших кадр, надёжнее абсолютных fps: `input` каждый раз
поднимает процесс, поэтому абсолютные значения занижены одинаково у всех
замеров.

**FACT.** Vsync идёт на 60 Гц (620 импульсов за ~10 с окна).

| условие | кадров / vsync | доля |
|---|---|---|
| `interactive` (793 МГц) + PointerLocation | 256 / 620 | 41 % |
| `performance` (1248 МГц) + PointerLocation | 298 / 561 | 53 % |
| `interactive` (793 МГц), PointerLocation ВЫКЛ | 1051 / 1325 | **79 %** |

**FACT.** Отладочный слой `PointerLocation` (полноэкранный RGBA, включён в
меню разработчика) стоил больше, чем разгон процессора: его отключение дало
почти двукратный прирост на том же ленивом governor'е. Выключен через
`settings put system pointer_location 0`.

**FACT (остаток до 60 Гц) — две причины, обе понятные:**

1. **CPU не разгоняется.** `scaling_max_freq=1248000`, но под нагрузкой
   `loadavg≈9` все четыре ядра стоят на `793000`. Параметры governor'а:
   `go_hispeed_load = 99`, `target_loads = 90`, `above_hispeed_delay = 20000`.
   Порог 99 % на ядро при нагрузке, размазанной по четырём ядрам, почти
   недостижим. Принудительный `performance` дал +29 % кадров.
2. **Аппаратные оверлеи не задействованы.** `dumpsys SurfaceFlinger`: все
   слои помечены `GLES` (обои, лаунчер, статус-бар) — GPU складывает их
   каждый кадр, и только результат идёт в оверлей. Железо умеет до 4 слоёв
   само (`maxLayerNum=4`), то есть проход GPU можно убрать целиком.

**Следующий шаг по производительности:** раздать слои оверлею напрямую в
`forge_hwc` (пометить пригодные как `HWC_OVERLAY` вместо `HWC_FRAMEBUFFER`),
и отдельно — выровнять параметры `interactive` со стоковыми.

## p79 — АППАРАТНЫЕ ОВЕРЛЕИ В forge_hwc + починка INTERACTION-буста (2026-08-24)

### Оверлеи: сделано и подтверждено

`prepare()` теперь раздаёт пригодные слои в `HWC_OVERLAY`; `set()` шлёт до
четырёх плоскостей одним `SET_INPUT_BUFFER` (нативная 12-слойная структура,
неиспользуемые слоты явно выключены). Правило promotion консервативное:

- слой берётся в OVL только если: без `SKIP`, есть handle, `transform=0`
  (OVL без ротатора), блендинг NONE/PREMULT/COVERAGE, кроп == кадру
  (OVL без скейлера), полностью на экране, формат RGBA/RGBX/BGRA8888/RGB565
  (HAL-формат берётся `gralloc_extra_query(GE_GET_FORMAT)` — в HWC1-слое
  формата нет);
- оверлеи набираются только НЕПРЕРЫВНОЙ полосой С ВЕРХА z-стека, чтобы
  GLES-остаток снизу был ровно тем, что представим одной FBT-плоскостью в
  OVL0 (сэндвич «OVL между двумя GLES» невозможен по построению);
- всё пригодное и слоёв ≤4 — FBT не используется вовсе; иначе OVL0=FBT и
  до трёх верхних слоёв аппаратно. Любое сомнение → GLES (всегда корректно).

Блендинг сверен с кодировкой ядра (`mt6735m/ddp_ovl.c`: `sur_aen`→бит 15,
селекторы 2-битные): PREMULT = ONE/SRC_INVERT, COVERAGE = SRC/SRC_INVERT,
NONE = opaque (`aen=0`, канал X у RGBX игнорируется). Kill-switch:
`setprop debug.forgehwc.overlays 0` возвращает GLES-only без переустановки
(prop читается в каждом prepare).

**FACT (после холодного ребута):** типовая сцена (обои RGBx NONE + лаунчер
RGBA PREMULT + статусбар RGBA PREMULT) — все три строки в
`dumpsys SurfaceFlinger` = `HWC`, `OVL0 SRC_CON=0x7` (три слоя включены
железно), `204/206 = 3.0` плоскости на кадр, FBT не задействован. За загрузку
4701 кадр: `ovl_frames=4697`, `prepare_fail=0 trigger_fail=0`, ноль DISPERR.
**GPU из композиции исключён полностью** на типовых сценах.

### Замеры (лаунчер, 13 пар горизонтальных свайпов, одинаковый контекст)

Метрика тимлида «кадры/vsync» (дельты 206/213) оказалась шумной — хвост
включённого vsync после анимации даёт разброс ±8 п.п. на ОДИНАКОВЫХ прогонах:

| прогон | кадров/vsync |
|---|---|
| A GLES-only | 1151/1338 = 86.0% |
| B оверлеи | 1235/1316 = 93.8% |
| B2 оверлеи (повтор) | 1161/1349 = 86.1% |

Чувствительная метрика — `gfxinfo` лаунчера (время кадра приложения):

| условие | p90 | p95 | p99 |
|---|---|---|---|
| GLES, interactive сток | 36ms | 38ms | 42ms |
| OVL, interactive сток | 36ms | 38ms | 44ms |
| OVL, governor performance | **23ms** | 25ms | 34ms |
| OVL + INTERACTION-boostpulse (см. ниже) | **30ms** | 34ms | 40ms |
| OVL + boostpulse + duration 250ms | 28ms | 31ms | 38ms |

**Вывод (FACT):** после ухода композиции в OVL лимитер — рендер самого
приложения, и он CPU-bound (36→23ms от одной частоты CPU). Сам по себе
переход на оверлеи время кадра ПРИЛОЖЕНИЯ не меняет (и не должен) — он
снимает GPU-работу композитора и полосу памяти.

### ОТРИЦАТЕЛЬНЫЕ результаты governor (не переигрывать)

- Runtime-ручки interactive НЕ влияют на этот профиль нагрузки:
  `go_hispeed_load 99→85`, `target_loads 90→85→75` — p90 остаётся 36ms
  (бурстовый рендер не добирает порогов на 20ms-сэмплах; частота стоит 793).
- **Мультитокенный `target_loads` («70 1040000:85») в 4.9 отвергается с
  EINVAL**: `get_tokenized_data` зовёт `kstrtouint` на ОСТАТОК строки
  (`cpufreq_interactive.c:704`), а kstrtouint строг к хвосту — парсер Q0
  сломан для любого ввода сложнее одного числа. Починка — правка ядра
  (кандидат в следующую пересборку), runtime недоступна.
- Дефолты interactive в 3.18-оракуле и 4.9 ИДЕНТИЧНЫ (99/90/20000/80ms) —
  «расхождения со стоком» в ядре нет. Блок `hispeed_freq 1300000` в
  `init.mt6735.rc` мёртв: гейт `ro.board.platform=mt6737t`, у нас `mt6737m`.

### PowerHAL: INTERACTION был пустым (второй коммит)

**FACT:** в `device/meizu/m5c/power/power.c` `POWER_HINT_INTERACTION` был
пустым case — касания никогда не поднимали частоту. При этом `boostpulse`
исправен: ручной пульс мгновенно даёт 793→1248 МГц. Починено: INTERACTION →
запись в `/sys/devices/system/cpu/cpufreq/interactive/boostpulse` (fd
кэшируется). Проверено: частота В МОМЕНТ свайпа = 1248000 (было 793000),
p90 лаунчера 36→30ms при нетронутых стоковых ручках governor.
`boostpulse_duration` оставлен дефолтным (80ms): 250ms даёт ещё −2ms p90,
записано как опция, не включено.

### Состояние устройства

boot_49_p74 не менялся. Наши подмены в /system (все с бэкапами):
- `lib{,64}/hw/hwcomposer.mt6737m.so` (018d49d2…/b23fa7d9…), вендорный —
  `.forgebak`;
- `lib{,64}/hw/power.mt6737m.so` (e61e3fd1…/a32927a5…), прежний LOS-овский —
  `.forgebak`.
Откат любого: вернуть `.forgebak` на место, `kill surfaceflinger` /
перезапуск фреймворка.

### Открыто

- Визуальная сверка оверлейного пути глазами (блендинг PREMULT на стекле,
  z-порядок при 3 плоскостях) — скриншоты это НЕ ловят (screencap рендерит
  GPU независимо от OVL).
- Правка парсера `get_tokenized_data` в ядре (мультитокенные
  `target_loads`/`above_hispeed_delay`) — в следующую пересборку ядра.
- Опция: `boostpulse_duration` 80→250ms (−2ms p90, цена — батарея).
- Клиппинг для частично-заэкранных слоёв (сейчас честный фолбэк в GLES).

## p80 — артефакт «рассыпается внизу» НЕ зависит от композиции

**FACT (проверено человеком на стекле, A/B через `debug.forgehwc.maxplanes`).**
Вариант A — оверлеи выключены, все слои через GPU (`SRC_CON=0x1`, 0 слоёв HWC).
Вариант B — три слоя на аппаратных плоскостях (`SRC_CON=0x7`).
**Разваливается одинаково в обоих.** На B при этом заметно плавнее (GPU
свободен), поэтому оверлеи оставлены включёнными.

Вывод: артефакт живёт НИЖЕ композиции, в тракте вывода, и присутствовал ещё
до перехода на оверлеи (ранее наблюдался как «тонкие косые линии»).

### Отвергнуто (не переигрывать)

- **Число одновременно читаемых плоскостей.** Опровергнуто A/B выше.
- **Недобор выборки у RDMA.** `RDMA0 INTSTA=0x0` — бит `FRAME_UNDERRUN`
  не взводится.
- **Ошибки DSI.** `DSI0 INTSTA=0x80000710` — это `BUSY` плюс штатные флаги
  видеорежима (`FRAME_DONE`, `VM_VBP/VACT/VFP_STR`), ошибочных бит нет.
- **Незасинхронизированная подмена буфера.** `MTK_FB_CMDQ_DISABLE` не
  определён, `primary_display_use_cmdq = CMDQ_ENABLE` — защёлкивание идёт
  через CMDQ по границе кадра.

### ОТОЗВАНО — инструмент оказался негодным

Сначала я принял за причину `OVL0 INTSTA=0xe03` (биты 9/10/11 =
`RDMAn_FIFO_UNDERFLOW` слоёв 0/1/2). Но регистр читается тем же значением
и при ОДНОЙ включённой плоскости, где слои 1 и 2 выключены и опустошаться
там нечему. Обработчик прерываний регистр чистит каждый кадр
(`DISP_CPU_REG_SET(DISP_REG_OVL_INTSTA, ~reg_val)` в `ddp_irq.c`), то есть
показания должны быть свежими — и всё равно противоречивы. **Вывод, сделанный
на этом регистре, снят.** Нужен более точный инструмент, прежде чем к нему
возвращаться.

Отдельная ловушка методики: `stop; start` НЕ перезапускает SurfaceFlinger, и
он держит в памяти старую библиотеку HWC. Первый перебор `maxplanes` из-за
этого измерял одно и то же — недействителен. Перезапускать надо явно
(`stop surfaceflinger; start surfaceflinger`).

### Что известно про параметры панели

Наше 4.9 несёт ИСПРАВЛЕННЫЕ значения (`LANE_NUM=4`, `PLL_CLOCK=212`,
`ssc_disable=1`, порчи 16/20/20/70) с пометками «forge: stock», а в
worktree `universal` лежат старые ошибочные (3 линии, PLL 285). Брать этот
worktree за эталон по панели НЕЛЬЗЯ — он старее.

## p81 — разрыв кадра: панель ДЕЙСТВИТЕЛЬНО 58.32 Гц, дело в фазе защёлкивания

**FACT (описание пользователя).** Это именно РАЗРЫВ, а не мусор: картинка
целая, но по горизонтали виден стык двух моментов движения. Позиция
**стабильная**, примерно на 10 % ниже середины экрана (около 60 % кадра).

**FACT (модель SF).** `dumpsys SurfaceFlinger`:
`DispSync configuration: app phase 1000000 ns, sf phase 1000000 ns,
present offset 0 ns (refresh 17146776 ns)`, `refresh-rate: 58.320001 fps`.
Ядро сообщает `vsyncFPS=5832`.

**FACT (реальная частота железа).** Прерывания RDMA0 за 20.20 с:
203331 → 206872 = 3541, то есть **175.3 IRQ/с**. На кадр приходится три
прерывания → **58.4 Гц**. Совпадает с сообщаемыми 58.32.

**ОТОЗВАНО:** гипотеза «ядро врёт про 58.32, панель идёт на 60». Неверна —
панель действительно 58.32 Гц, модель SF ей соответствует, ошибки периода
нет. (Прежняя оценка «60 Гц» была получена делением счётчика vsync на окно,
вычисленное из того же счётчика — circular, недействительна.)

**INFERENCE (остаётся).** Стабильная позиция разрыва при верной модели
периода означает, что подмена адреса буфера происходит на фиксированной фазе
развёртки, а не на границе кадра. То есть новый адрес вступает в силу
посреди активной области. Правильное поведение — защёлкивание по началу
кадра через очередь команд с ожиданием маркера завершения
(`_cmdq_insert_wait_frame_done_token`).

**Следующий шаг:** проследить путь `TRIGGER_SESSION` из нашего HWC до
записи адреса и убедиться, что он идёт через CMDQ-хендл конфигурации с
ожиданием маркера, а не прямой записью CPU. `MTK_FB_CMDQ_DISABLE` не
определён и `primary_display_use_cmdq = CMDQ_ENABLE` (проверено), значит
механизм доступен — вопрос в том, используется ли он на этом пути.

### Методическая ловушка (записать)

Мерить частоту панели по счётчику `WAIT_FOR_VSYNC` (ioctl 213) НЕЛЬЗЯ:
SurfaceFlinger выключает vsync в простое, и за 20 с набегает всего ~28
вызовов. Надёжный источник — счётчик прерываний RDMA0 (`forge-irq`),
он идёт независимо от userspace; делить на 3.

## p82 — расширение гасящего импульса: ОТРИЦАТЕЛЬНЫЙ РЕЗУЛЬТАТ

Гипотеза: в видеорежиме конфигурация защёлкивается по событию `RDMA0_EOF`, и
записи должны успеть в гасящий импульс. При `vertical_frontporch = 20` окно
составляет ~260 мкс (строка = 12.45 мкс), чего может не хватать на десятки
записей через CMDQ — тогда запись заезжает в активную область и даёт
неподвижный разрыв.

Сделано: `vertical_frontporch` 20 → 50 (окно ~650 мкс, частота 58.3 → 57.0 Гц),
заодно `vertical_vfp_lp` (был не задан вовсе, то есть ноль при уходе в простой).

**Результат: не помогло, по ощущению пользователя стало не лучше или хуже.
Правка откачена, на устройстве возвращён `boot_49_p74.img`.**

## p83 — что ещё исключено по этому артефакту

**FACT (фотография экрана).** Это не мусор и не чистый временной разрыв:
под горизонтальной границей содержимое смещено вбок, горизонтальные края
идут «лесенкой», плюс слева видны прямоугольные блоки чужого содержимого.

**ОТВЕРГНУТО — неверный шаг строки у плоскостей.** Инструментация в
`forge_hwc` (печать `forge-pitch` на каждую плоскость): запрос
`GE_GET_STRIDE` к gralloc проходит успешно (`ge=1`), все плоскости получают
`stride_px=720`, регистр `L0_PITCH=0xb40` = 2880 байт = 720×4. Совпадает.

**ОТВЕРГНУТО — наши параметры DSI расходятся с загрузчиковыми.** Прямое
сравнение регистров сразу после загрузки (когда действуют значения LK) и
после цикла гашения экрана (когда применяются наши): `PSCTRL=0x30870`,
`VACT_NL=0x500`, `HSA=0x34`, `HBP=0xc8`, `HFP=0xc8` — **идентичны**.

**ОТВЕРГНУТО — нехватка частоты CPU.** Замер во время свайпов: все ядра на
1248000 (максимум), буст PowerHAL работает. Артефакт сохраняется.

### Сводка: что по этому артефакту уже исключено

Оверлеи (одинаково с ними и без), число плоскостей, недобор RDMA
(`INTSTA` бит `FRAME_UNDERRUN` не взводится), ошибки DSI, обход CMDQ
(механизм включён, все предикаты возвращают 1 в видеорежиме), ошибка модели
периода (панель действительно 58.32 Гц), шаг строки плоскостей, расхождение
параметров DSI с загрузчиком, частота CPU, ширина гасящего импульса.

### Не проверено (кандидаты на следующий заход)

1. Параметры PHY линии DSI (`HS_TRAIL`, настройки тактовой линии) — регистры
   MIPITX снимались, но НЕ сверялись с эталоном.
2. Пропускная способность памяти и частота MM-домена (MMDVFS) — код в
   `primary_display.c` есть, работает ли он на этом профиле, не проверено.
3. Таблица инициализации панели именно этой ревизии ILI9881C.

> **Внимание: коллизия нумерации.** Записи p84–p87 существуют в ДВУХ журналах
> с разным содержимым. Здесь (дерево устройства) под этими номерами — разбор
> смерти eMMC, возможности загрузчика, карта разделов и проверка образа. В
> `BRINGUP_STATE.md` **репозитория ядра** под теми же номерами — разбор дефекта
> дисплея (панель/DSI/PHY, пороги prefetch, SMI/larb, логика кода). Оба журнала
> продолжили p83 одновременно. Сквозная p-нумерация принадлежит журналу ядра и
> продолжается с p88; записи в этом файле дальше идут датированными
> заголовками без номера.

## p84 — conn49 убивает eMMC; аппарат снят с загрузки, разобраны пути восстановления

### Что сломалось

**FACT.** Ядро с влитой веткой `forge/conn49` (мерж `e76f56bbc`: wmt/stp core,
gps, wlan gen2, mt6627 fm) загружается и поднимает adb, но eMMC не опрашивается
вообще: `/system` не смонтирован, `exec '/system/bin/sh' failed`, adb живёт
только из рамдиска. Аппарат в этом состоянии непригоден.

**FACT.** Разгон (коммит `9c69cb306`, OPP 1352/1495) к поломке отношения не
имеет: он лежит в истории НИЖЕ мержа, и в откате сохранён.

### Загрузчик: что реально умеет fastboot на m5c

Все пункты — прямые ответы устройства, серийник `710HVBR923RYK`.

- **FACT.** fastboot доступен, `unlocked: yes`.
- **FACT.** `fastboot flash boot` → `FAILED (remote: 'format for partition
  'boot' is not allowed')`.
- **FACT.** `fastboot boot <img>` → `FAILED (remote: 'unknown command')` —
  загрузки образа из ОЗУ нет.
- **FACT.** `fastboot oem recovery` / `oem boot-recovery` / `oem bootmenu` →
  `unknown command`; `oem reboot-recovery` → `not support on security`.
- **FACT.** `fastboot reboot recovery` и `fastboot reboot-recovery` отвечают
  `OKAY`, но фактически уводят в обычную загрузку — проверено дважды, каждый
  раз возвращается сломанный conn49.
- **FACT.** `getvar`: boot и recovery — raw; cache, userdata, system — ext4.
- **FACT.** Кнопки: **Vol+ + Power = fastboot**, не recovery. Аппарат оказался
  в fastboot ровно тогда, когда пользователь по нашей же (неверной) инструкции
  жал Vol+ в ожидании TWRP. Комбинация recovery — Vol− + Power, в проверке.

**INFERENCE.** Загрузчик отдаёт fastboot-протокол, но запрещает запись в `boot`
и не поддерживает ни загрузку из ОЗУ, ни программный переход в recovery.
Следовательно штатного восстановления из fastboot нет; остаются два пути:
(а) кнопочный вход в recovery, (б) запись раздела `recovery` — запрет назван
явно только для `boot`, распространяется ли он на recovery, не проверено.

**ОТВЕРГНУТО — «fastboot вообще не отвечает».** Артефакт обёртки devbox:
`dev.sh 'fastboot ...'` в виде произвольной команды идёт без sudo и виснет.
Рабочая форма — подрежимная: `dev.sh fastboot <args>`.

### Возврат

Целевой образ — `boot_49_p74.img`, md5 `9be0967288e341da9ab702b30d5d7f71`,
раздел `/dev/block/mmcblk0p7`. Перед записью снять ram console по адресу
`0x5f000000` — там причина смерти msdc.

### Почему conn49 убивает msdc — три гипотезы, каждая с опровергающей проверкой

1. **HYPOTHESIS.** Порт WMT/STP тянет конфликтующий узел pinctrl/GPIO,
   отбирающий линии msdc. *Проверка:* сравнить pinctrl-узлы conn49 и p76,
   и то, что из них реально применяется на стоковом DTB.
2. **HYPOTHESIS.** Включённый ради connectivity CONFIG меняет порядок
   инициализации или зависимости msdc. *Проверка:* diff `.config` p76 против
   conn49, отфильтровать всё, что не связано с mmc/pinctrl/clk.
3. **HYPOTHESIS.** Мерж затащил чужую ревизию общего файла (mt-plat / devinfo),
   ломающую переименование bootdevice из p40. *Проверка:* `git diff p76..conn49`
   по `drivers/mmc` и `drivers/misc/mediatek/base/power`/`mt-plat`.

Гипотеза 3 наиболее вероятна: p40 был точечной правкой именно этого пути, а
мерж — единственное, что с тех пор трогало общие файлы. Все три проверяются на
ram console, как только будет доступ в recovery.

### Гигиена веток

`m5c-arm64` опубликована на GitHub, поэтому историю не переписываем. Мерж
`e76f56bbc` снят **обратным коммитом** `56ec99e97` (`git revert -m 1`), разгон
на ветке сохранён; страховка — `m5c-arm64-backup`. Попытка conn49 сохранена
целиком в ветке `subsys49-conn49-broken`, чтобы её можно было чинить, а не
переделывать. Дальнейшие подсистемы (sensors49 и следующие) собираются на
чистой базе p76 в `subsys49`.

## p85 — eMMC убил не conn49, а подменённый DTB в образе

Все три гипотезы из p84 опровергнуты. Причина найдена и доказана, разбирать
код connectivity больше не нужно.

### Приём: улики снимаются без recovery

У сломанного ядра нет `/system`, поэтому `adb shell` падает с
`exec '/system/bin/sh' failed`. Но adbd читает файлы **своим sync-сервисом**,
шелл ему не нужен:

```
adb pull /proc/partitions      adb pull /dev/kmsg        (весь кольцевой буфер)
adb pull /proc/device-tree     adb pull /sys/bus/platform/devices/<dev>/uevent
```

Этого хватило на полный разбор. Recovery для диагностики не требовался.

### Цепочка улик

1. **FACT.** `/proc/partitions` — только `ram0`..`ram15`, ни одного `mmcblk`.
2. **FACT.** Драйвер зарегистрирован: `/sys/bus/platform/drivers/mtk-msdc/uevent`
   отвечает `Permission denied` (файл 0200), а не `does not exist`.
3. **FACT.** Устройства из DTB созданы: `/sys/bus/platform/devices/11230000.msdc/uevent`
   и `11240000.msdc/uevent` читаются.
4. **FACT.** Привязки нет: `.../11230000.msdc/driver` отсутствует. Probe не
   вызывался — отсюда и полное молчание msdc в логе.
5. **FACT.** В живом дереве узел объявлен `compatible = "mediatek,msdc"`, а
   драйвер матчится по `DT_COMPATIBLE_NAME = "mediatek,mt6735m-mmc"`
   (`drivers/mmc/host/mediatek/ComboA/mt6735/msdc_cust.h:46`). Не совпадает.
6. **FACT.** Источник чужого узла — собственный DTS ядра Q0:
   `arch/arm64/boot/dts/mediatek/mt6735m.dts:38` объявляет ровно
   `compatible = "mediatek,msdc"`.
7. **FACT (контрольное сравнение образов).**
   `boot_49_p74.img` — `mt6735m-mmc` ×2, `mediatek,msdc` ×0 (стоковый DTB);
   `boot_49_conn49.img` — `mt6735m-mmc` ×0, `mediatek,msdc` ×2 (ядерный DTB).

**Причина (FACT).** Образ conn49 собран с DTB, сгенерированным самим ядром
(`Image.gz-dtb`), вместо связки `Image.gz` + `dtb_stock.dtb`. Драйвер msdc не
находит свой узел и не биндится. Ни одна строка кода connectivity к отказу
отношения не имеет.

### Что опровергнуто по дороге (не переигрывать)

- **ОТВЕРГНУТО — мерж задел общий файл на пути msdc.** Вне connectivity мерж
  внёс только добавления: 194 строки, 0 удалений; `drivers/mmc`, `mt-plat` и
  devinfo не тронуты вовсе.
- **ОТВЕРГНУТО — CONFIG сместил инициализацию msdc.** Развёрнутые `.config`
  базы и conn49 по `MMC|MSDC|BLK_DEV|SCSI` идентичны побайтово. Всего
  расходятся 46 строк, все до одной — combo/wifi/gps/fm/wext.
- **ОТВЕРГНУТО — потеряны наши патчи msdc.** `9f0029fcd` (p40) и `f94e2b320`
  присутствуют в `subsys49-conn49-broken`.
- **ОТВЕРГНУТО — `WARNING: regulatory_init`.** Штатное «db.txt is empty» от
  cfg80211, к eMMC отношения не имеет.
- **ОТВЕРГНУТО — «устройства msdc0 нет в дереве».** Промежуточный неверный
  вывод: проверялся путь `11230000.msdc0` из fstab, тогда как узел называется
  `11230000.msdc`. По правильному имени устройство есть.

### Исправленный образ

Пересобран из того же самого ядра, без перекомпиляции: `Image.gz` вырезан по
магии DTB `d00dfeed` на смещении 6988972 (из 7062478), к нему приклеен
`dtb_stock.dtb`.

`boot_49_conn49fix.img`, md5 `88bb547763b1e6af7ab86315a03c9228`,
`gunzip -t` пройден, внутри `mt6735m-mmc` ×2 и `mediatek,msdc` ×0.

### Обязательный гейт перед прошивкой

```
gunzip -t <Image.gz>                           # ядро целое
strings <boot.img> | grep -c mt6735m-mmc       # ровно 2
strings <boot.img> | grep -c 'mediatek,msdc'   # ровно 0
```

Тем же гейтом проверить все образы подсистем, собранные тем же способом.

### Чем это НЕ лечится

Прошить исправленный образ пока нечем: `fastboot flash boot` запрещён
загрузчиком (p84), кнопочный recovery не подтверждён. Ручной bind в обход
match тоже не пройдёт: в 4.9 `bind_store()` вызывает `driver_match_device()`,
так что запись в `/sys/bus/platform/drivers/mtk-msdc/bind` будет отклонена по
той же несовпадающей строке compatible.

### Проверка исправленного образа (полная, не только DTB)

Сверка `boot_49_conn49fix.img` с эталоном `boot_49_p74.img`:

- `bootimg.cfg` **идентичен**: `kerneladdr=0x40080000`, `ramdiskaddr=0x44000000`,
  `secondaddr=0x40f78000`, `tagsaddr=0x4e000000`, `pagesize=0x800`,
  `name=mt6737`, cmdline тот же.
- рамдиск **побайтово тот же**: md5 `743c5f2dbcfafe0b8837a10f399f69b5`.
- значит единственное отличие от сломанного conn49 — DTB, как и задумано.

Connectivity в ядре действительно присутствует (счётчик совпадений в
распакованных ядрах):

| маркер | p74 | conn49fix |
|---|---|---|
| `WMT` | 0 | 840 |
| `mtk_wcn` | 0 | 55 |
| `stp_` | 3 | 61 |
| `GPS` | 3 | 36 |
| `fm_` | 1 | 56 |
| размер | 14866440 | 15810568 |

### Порядок восстановления (сводит зависимость от recovery к одному разу)

Заход в recovery на этом аппарате дорог и ненадёжен, поэтому используем его
ровно однажды:

1. TWRP → `dd` **p74** в `/dev/block/mmcblk0p7` → загрузка в систему.
   На p74 eMMC живой, значит сразу получаем полноценный Android.
2. Дальше **все** прошивки идут из живой системы через `dd` с md5-гейтом до и
   после записи; возврат к p74 — одна команда. TWRP больше не нужен.
3. Очередь проверки: conn49fix (WiFi/BT/GPS/FM) → sensors49 (`/dev/hwmsensor`,
   прирост input-устройств, дисплей+тач+adb живы) → объединённый →
   aud49 → av49 → cam49.

## p86 — раскладка разделов m5c: p10 это expdb, а не recovery

Поймано до записи, не после. В плане восстановления TWRP стоял `dd` в `p10`
по аналогии с **m2note** (там `p9=boot`, `p10=recovery`). На m5c раскладка
другая.

**FACT** (листинг `by-name`, снят с этого аппарата 2026-08-20):

```
boot  -> /dev/block/mmcblk0p7
expdb -> /dev/block/mmcblk0p10
```

**FACT** (`fastboot getvar all`): `partition-size:expdb: a00000` = 10 МБ.

Запись `recovery_ourkernel.img` (18,6 МБ) в p10 дала бы сразу три беды:
стёрла бы expdb с накопленными уликами (маркер-слоты, rc49-ринг — тот самый
канал, на котором закрыты p38/p40/p41); не поместилась бы в 10 МБ и уехала за
границу раздела в соседний; и TWRP при этом не установила бы вовсе.

Номер раздела recovery на m5c **не установлен** — в журнале его нет. Не
угадывать.

### Правило (обязательное, для любых записей)

- **Никаких зашитых номеров разделов.** Цель разрешается по имени в момент
  записи: сначала `ls -l /dev/block/platform/*/*/by-name/`, затем
  `dd ... of=/dev/block/platform/*/*/by-name/<имя>`.
- **Сверка размеров до записи**: образ должен помещаться в раздел
  (`blockdev --getsize64` на устройстве или `getvar partition-size:<имя>` из
  fastboot). Не помещается — не пишем.
- Проверка встраивается в конвейер упаковки рядом с DTB-гейтом.
- p10 остаётся запретной зоной, но **по другой причине**, чем считалось: это
  единственный канал посмертных улик, а не recovery.

### Полная карта разделов m5c (выведена, сверена по двум опорам)

`fastboot getvar all` перечисляет разделы **в обратном порядке**. Разворачиваем;
`preloader` живёт на аппаратном разделе `mmcblk0boot0` и в пользовательскую
область GPT не входит, поэтому нумерация начинается с `proinfo`:

| # | раздел | | # | раздел |
|---|---|---|---|---|
| p1 | proinfo    | | p11 | seccfg |
| p2 | nvram      | | p12 | oemkeystore |
| p3 | protect1   | | p13 | secro |
| p4 | protect2   | | p14 | keystore |
| p5 | lk         | | p15 | tee1 |
| **p6** | **para** (BCB) | | p16 | tee2 |
| **p7** | **boot** | | p17 | custom |
| **p8** | **recovery** | | p18 | frp |
| p9 | logo       | | p19 | nvdata |
| **p10** | **expdb** | | p20 | devinfo |
|   |            | | p21 | rstinfo |
|   |            | | p22 | metadata |
|   |            | | p23 | system |
|   |            | | p24 | cache |
|   |            | | p25 | userdata |
|   |            | | p26 | flashinfo |

**INFERENCE, подтверждённая двумя независимыми опорами.** Раскладка сходится
одновременно с обоими известными FACT из листинга by-name: `boot = p7` и
`expdb = p10`. Совпадение по двум разнесённым точкам делает промежуточные
номера надёжными.

Отсюда **recovery = `mmcblk0p8`**, `para` (блок команды загрузки) = `mmcblk0p6`.

Это НЕ отменяет правило p86: перед записью цель всё равно разрешать через
`by-name` на живом устройстве. Карта нужна для планирования, а не вместо
проверки.

Размеры целей (из `getvar`): `boot` 16 МБ, `recovery` 32 МБ, `para` 512 КБ,
`expdb` 10 МБ.

## p87 — fastboot на m5c не пишет НИЧЕГО; путь возврата только через кнопки или BROM

Проверено прямой попыткой записи, с разрешения пользователя.

**FACT.** Три разных раздела, один и тот же отказ:

```
fastboot flash boot     -> FAILED (remote: 'format for partition 'boot' is not allowed')
fastboot flash recovery -> FAILED (remote: 'format for partition 'recovery' is not allowed')
fastboot flash para     -> FAILED (remote: 'format for partition 'para' is not allowed')
```

Во всех трёх случаях фаза `Sending` проходит успешно (`OKAY`), падает именно
`Writing`. То есть загрузчик принимает данные и отказывает на записи.

**FACT.** Состояние загрузчика при этом:
`unlocked: yes`, `secure: no`, `warranty: no`, `kernel: lk`,
`product: HQ6737M_65_1MZ_M0`, `version: 0.5`, `max-download-size: 0x8000000`.

**INFERENCE.** Отказ не связан ни с защитой (secure: no), ни с блокировкой
(unlocked: yes), ни с конкретным разделом. LK этой сборки Meizu не разрешает
fastboot-запись как таковую. Значит `fastboot flash` на m5c — тупик при любых
условиях, и планировать восстановление через него нельзя.

**ОТВЕРГНУТО — «запрещён только boot».** Гипотеза из p84, что запрет назван
явно только для `boot` и на recovery может не распространяться, опровергнута
прямым опытом.

### Что осталось

1. **Кнопки: Vol+ + Power** после полного выключения → TWRP. Не проверено
   физически.
2. **Режим BROM + mtkclient.** Пишет любой раздел мимо запретов LK.
   Инструмент развёрнут на девбоксе в `/tmp/mtkclient` (зависимости —
   pyusb, pycryptodome, pyserial — там уже были, ставить ничего не пришлось).
   Требует физики: вынуть кабель, выключить аппарат, зажать обе кнопки
   громкости и воткнуть кабель, не отпуская.

**FACT про преloader.** В обычной загрузке преloader команд не слушает:
mtkclient видит порт (строка `Preloader` в логе) на каждом витке загрузки, но
рукопожатие падает каждый раз — 13 попыток подряд за 150 с. Ловить преloader на
перезагрузке бесполезно, нужен именно BROM.

**FACT про петлю.** Сломанный conn49 без `/system` уходит в петлю перезагрузок с
периодом ~11 с. Аппарат в ней нестабилен; парковать в fastboot.

---

**Передача смены за 2026-08-24 — `M5C_HANDOFF_20260824.md`** (рядом с этим
файлом). Там сжато: состояние аппарата, причина «смерти eMMC» и гейт упаковки,
приём снятия улик по adb без шелла, отказ fastboot писать любой раздел, карта
разделов и правило by-name, готовые образы с md5 и критериями валидации,
порядок восстановления и список уже опровергнутых гипотез.
