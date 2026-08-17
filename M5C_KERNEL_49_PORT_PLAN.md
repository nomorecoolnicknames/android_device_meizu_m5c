# M5c — план v2: ядро 4.9 (arm64) как энейблер Android 13 GSI, vendor на `custom`

Дата: 2026-08-17, ревизия v2 (v1 от того же дня пересмотрена по трём решениям
владельца: цель — **Android 13**, **только arm64**, vendor-образ живёт на
разделе **`custom`**). Все нетривиальные утверждения помечены
FACT / INFERENCE / HYPOTHESIS / REJECTED по `/srv/forge/android/CLAUDE.md`.

Закрыто со времени v1 и здесь не пересматривается: оба блокера 3.18 починены и
проверены на железе (adb по USB из Android, gt9xx на 1-005d с мультитачем и
правильной ориентацией, fan5405 биндится; коммиты ядра `2f918464`, `b83303d7`,
`4137458e`); дефект «экран после resume» был нашей кривой реверс-таблицей —
эталонные LCM-таблицы извлекаются байт-в-байт из
`/home/valakas/m5c/kernel-reverse/vmlinux.elf` (ili9881c: VA
`0xffffffc00101c5e8`, 192 × 72-байтные `struct LCM_setting_table`) — этот метод
обязателен для всех остальных реверс-таблиц; MTKZU android-9 — это 3.18.119
под ДРУГОЙ вариант m5c (jd9365 + FocalTech, без fan5405/imgsensor,
BRINGUP_STATE коммит `6cd008a`). Единственный авторитет по нашему железу —
`M5C_CHIP_MAP.md`.

---

## 1. Решающий вопрос: существует ли где-нибудь arm64 4.9 для MT6735M?

**Короткий ответ: нет. Проверено. Но графт дешевле, чем казалось в v1.**

### 1.1 Что искалось и что нашлось

- FACT: в эталонном T-ALPS-Q0 (`nyancrimew/mtk-t-alps-release-q0-kernel-4.9-lc`)
  `arch/arm64/configs/k37mv1_bsp_defconfig` **отсутствует** (HTTP 404 на raw),
  arm32 `arch/arm/configs/k37mv1_bsp_k49_defconfig` — есть (HTTP 200).
- FACT: в MTKZU android-10 `arch/arm64/configs/` есть
  `k37mv1_bsp_defconfig` и `k37mv1_bsp_debug_defconfig`, но `git log --follow`
  (клон углублён `--deepen=10`) показывает: они добавлены коммитом
  `9be5d2018` «Copy arm k37 and arm64 k57 config to arm64 folder» и
  **байт-в-байт равны arm32-оригиналам** (diff = 0 строк). Это копии, а не
  вендорский arm64-конфиг.
- FACT: в вендорском 4.9-lc дереве `mhdzumair/MhDzMR-woods-nicklaus-4.9`
  (4.9.117) `arch/arm64/configs/` содержит только mt2712/mt8173/ranchu —
  никакого k37/mt6735.
- FACT: поиск GitHub по `k37mv1`, `k37tv1`, `mt6737m`, `mt6737t`,
  `6737 android-10`, `mt6735 android_kernel 4.9` не дал ни одного 4.9-дерева
  mt6737 кроме уже известных; все community-деревья mt6737m/t — 3.18.x.
  (Code-search API без токена недоступен — покрыты repo-search и прямые
  raw-пробы; это ограничение поиска, зафиксировано.)
- FACT (поправка к v1): «woods/nicklaus» — кодовые имена Moto C Plus / E4 Plus
  (репозитории dhirajms и MhDzMR-Kernel-Nicklaus), которые retail-шипились на
  3.18. Дерево woods-nicklaus-4.9 — это **порт-попытка энтузиаста поверх
  ALPS 4.9-lc**, а не заводское ядро устройства. Утверждение v1 «вендоры
  реально отгружали MT6737 на 4.9» ослабляется до: **MTK выпустил
  production-intent 4.9-lc с reference-конфигом k37mv1 (=MT6737M), но retail-
  устройства на нём я не нашёл.** Контрольный замер: Nokia NE1 (mt6737m,
  Android 9 Go, дамп `Firmware-Dumper/nokia_ne1_dump`) — ядро из boot.img
  дампа: `Linux version 3.18.119+ … May 15 2019`, arm64 (kernel @0x40080000,
  `bootopt=64S3,32N2,64N2` — тот же, что у нас).

### 1.2 Почему графт arm64 — это wiring, а не порт

- FACT: `drivers/misc/mediatek/base/power/mt6735/Makefile` в 4.9-lc содержит
  `ifneq ($(CONFIG_ARM64), y)` вокруг arm32-SMP объектов
  (`mt-smp.o hotplug.o mt-headsmp.o`); `smp.h` там же — с arm64-ветками.
  То есть MTK **сохранил arm64-условия в платформенном коде mt6735** при
  переносе на 4.9 (код унаследован от arm64-способного 3.18/M-дерева).
- FACT: единственный arm32-специфичный asm под mt6735 —
  `base/power/mt6735/{mt-headsmp.S, mt_hotplug.S}` (arm32 SMP-bringup, на
  arm64 не нужен: SMP поднимает ATF через spin-table/psci, как на нашем 3.18)
  и `base/power/cpuidle_v1/cpu_dormant*.S` (arm32 dormant). Оба уже за
  Makefile-гардами либо отключаемы конфигом.
- FACT: `MACH_MT6735M` упоминают 104 файла дерева, но это `#ifdef`-гарды и
  Makefile-условия — они заработают на arm64, как только символ появится в
  arm64 Kconfig. Прецедент: наш 3.18 собирает практически тот же вендорский
  код mt6735 в arm64 (FACT — текущее ядро #11 arm64 живёт на устройстве).
- FACT: загрузчик менять не надо — стоковый LK m5c грузит arm64 Image+DTB
  уже сейчас (наше 3.18-ядро), `bootopt=64S3`; DTB у нас байт-в-байт
  стоковый; механизм `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE` в 4.9-lc есть.

INFERENCE: графт = переписать несколько десятков строк арх-обвязки, а не
портировать платформу. Конкретный объём работ:

1. `arch/arm64/Kconfig.platforms`: добавить `config MACH_MT6735M` по образцу
   существующего `MACH_MT6765`, НЕ перенося arm32-селекты
   (`CPU_V7`, `VFP_OPT`, `NEED_MACH_MEMORY_H` — их в arm32-блоке видно в
   `arch/arm/Kconfig`); оставить селекты MTK-подсистем
   (`MTK_SYS_CIRQ`, `MTK_EIC`, `MTK_GPIO`, systracker и т.п. — сверить с
   тем, что реально требует сборка).
2. DTS: перенести `arch/arm/boot/dts/{mt6735m.dts, mt6735m-pinfunc.h,
   cust_mt6735_msdc.dtsi}` в `arch/arm64/boot/dts/mediatek/` + строка
   `dtb-$(CONFIG_MACH_MT6735M)` в Makefile. Первую сборку делать вообще без
   своего DTS — приложить **стоковый DTB** (md5 `e17a0910…`, HYPOTHESIS v1 о
   его совместимости с 4.9-биндингами остаётся в силе: биндинги одной эпохи,
   фальсификация = именно этот тест).
3. Defconfig: не тащить рукописный MTKZU-конфиг; взять arm32
   `k37mv1_bsp_k49_defconfig` как список включённых MTK-фич + наш боевой
   3.18 `m5c_defconfig` как список m5c-специфики, собрать arm64-defconfig
   заново (`ARCH=arm64 make olddefconfig` и итерации по ошибкам сборки).
4. Чинить фактические ошибки компиляции по мере появления. Ожидаемые зоны
   (по консумерам `MACH_MT6735M`): `drivers/clocksource/mt_gpt.c`,
   `drivers/cpuidle/`, `base/power/{spm,sleep,clkbuf}`-заголовки, aee/mrdump.
   У всех есть либо arm64-ветки (проверено точечно), либо mt6763/65-образцы
   в том же дереве.
5. НЕ включать в первый проход: GPU (`MTK_GPU_SUPPORT`), imgsensor, тач,
   сенсоры, свой LCM — минимальное ядро до init.

**Минимальный тест графта (go/no-go гейт всего плана):** собрать arm64
`Image.gz` + стоковый DTB, упаковать с текущим LOS14.1-рамдиском (+ forge-
логгер), прошить boot (p7), снять маркеры.
- Проверка успеха: `$D adb -s 710HVBR923RYK shell cat /proc/version` →
  `4.9.188`; либо файл этапов логгера в `/data/forge/`.
- Проверка провала: TWRP (живёт на стоковом ядре, канал не теряется) →
  `cat /proc/last_kmsg` / expdb — где встало.
- Критерий no-go: если после ~4 сессий нет ни одного маркера жизни ядра
  (даже раннего printk в last_kmsg) — фиксируем REJECTED с логами. Запасной
  arm32-путь по решению владельца вне скоупа, так что no-go = остановка
  4.9-трека и возврат к вопросу целей (честно заявляю это следствие).

## 2. Реалистичен ли Android 13 на 4.9 — и где потолок

- FACT (webfetch source.android.com/docs/core/architecture/kernel/android-common):
  официальная GKI-матрица A13 называет только `android13-5.15/5.10` и
  `android12-5.10`. Это матрица **launch/ACK-веток**, не upgrade-устройств.
- INFERENCE: для upgrade-устройств и кастомов действует VTS-минимум, и для
  A13 он равен 4.9 (в A14 минимум поднят до 4.14) — 4.9 исторически
  последняя LTS-ветка ACK c поддержкой до 2023 (android-4.9-q). Прямую
  страницу с VTS-матрицей в этой сессии не фиксировал — при исполнении
  Phase G проверить одной строкой (vts_kernel_version test в A13 CTS).
  Практика сообщества: phh AOSP 13 и AndyYan LineageOS 20 TD GSI регулярно
  загружаются на MTK-устройствах с 4.9 — INFERENCE из публичных тредов, не
  проверено мной лично; фальсификация встроена в Phase G (первая же загрузка).
- INFERENCE (ключевое «почему 4.9, а не 3.18»): Android 11+ netd требует
  eBPF (cgroup-BPF, удалён fallback на xt_qtaguid) — ядра 3.18 этого не
  умеют, 4.9 ACK — умеет. Именно это делает 4.9 энейблером A11/A12/A13, а
  3.18 — потолком на уровне A10. Фальсификация: на готовом 4.9 проверить
  `bpfloader`-лог и `/sys/fs/bpf` при загрузке GSI.
- Потолок: **A13 — реалистичная цель; A14+ — нет** (минимум ядра 4.14+,
  наш SoC-класс на 4.14 никогда не существовал). Если A13-GSI на практике
  упрётся в незакрываемое (см. риски), честный fallback — A12L GSI на том же
  стеке; разница для этого плана нулевая (та же механика, тот же vendor).

Что нужно от нас для A13 GSI arm64 на legacy-устройстве (non-A/B, ext4,
без dynamic partitions, AVB нет):
1. **arm64-ядро 4.9** — Phase 0–2.
2. **Treble-vendor** с VINTF-манифестом и split-sepolicy на своём разделе —
   раздел `custom` (см. §3).
3. **Boot-flow**: A10+ = system-as-root; на legacy это решается first-stage
   ramdisk'ом в нашем boot.img: init первой стадии из ramdisk монтирует
   /system (p23) и /vendor (p17=custom) по fstab из ramdisk'а и делает
   switch_root. DT-нода `firmware/android/fstab` не обязательна при
   ramdisk-fstab (в отличие от MX6-кейса B, где ramdisk выбрасывался; урок
   MX6 §7a учтён — контексты selinux должны быть доступны первой стадии).
4. **GSI-образ**: AndyYan LOS 20 TD `arm64_bvN` или phh AOSP 13 arm64 —
   raw ext4, шьётся в system через TWRP. FACT: наш system p23 =
   2 621 440 KiB = **2.5 GiB**; размеры современных A13-GSI подползают к
   этому пределу. Замерить фактический img на момент исполнения; если не
   влезает — варианты: vndklite/lite-сборки GSI, resize2fs образа после
   заливки, или (крайнее) пересборка GPT — отдельное решение владельца.

## 3. Vendor на `custom` (mmcblk0p17, 512 MiB)

FACT (живое устройство + дамп, 2026-08-17):
- p17 `custom` = 524 288 KiB ровно; бэкап снят:
  `/tmp/m5c-backup-20260817/custom.img` на девбоксе, sha256
  `ad8f6a88aed0d8f1cf6e244e35ac133233aa0b14dbb3862ce4d95e34f98b9174`.
- ФС: ext4 (has_journal, extent, uninit_bg — старый mke2fs), last mounted on
  `/custom`, занято ~18.3 K блоков ≈ **72 MiB, полезного контента 56 MiB**.
- Содержимое (смонтирован дамп, инвентаризация): `3rd-party/apk/{TouchPal,
  SpanishPack, SkinPackOEMMeiZu, DataMigration}` (56M), `app/Gba/Gba.apk`,
  `plugin/FwkPlugin`, `cip-build.prop` (VoLTE/gemini-пропсы от 2017-11-11).
  **Это предустановочный Flyme-блоат + CIP-пропсы; ни одного HAL, ни одной
  библиотеки, ни прошивок.** Потеря при перезаписи: на LOS — ничего (LOS его
  и не монтирует); на стоке — исчезнут предустановки и cip-пропсы
  (VoLTE-флаги волью́тся в наш vendor при необходимости). Бэкап полный, откат
  тривиален.
- Полная карта разделов снята (`/proc/partitions` + by-name): system p23
  2.5G, cache p24 400M, userdata p25 11.06G, nvdata p19 32M, nvram p2 5M.

INFERENCE (пределы уверенности названы): preloader/LK судьбой `custom` не
интересуются — стоковый LK читает lk/boot/logo/tee/seccfg/para; `custom`
монтировался только Android-fstab'ом стока. Проверка при исполнении: после
перезаписи custom убедиться, что сток-recovery и LK грузятся как прежде
(они у нас в неизменном виде).

### 3.1 Откуда берётся сам vendor-образ

Прайор-арт того же цеха:
`/srv/forge/android/meizu_mx6_m95/TREBLE_VENDOR_PARTITION_PLAN.md` (MT6797,
тот же трюк с custom). Его главные уроки, применимые здесь: (1) vendor-раздел
и Treble и VNDK-enforcement — **три разных вещи**, и enforcement для legacy-
блобов недостижим и не нужен; (2) первый риск — first-stage mount и
*_contexts для первой стадии; (3) `custom` не пустой — инвентаризация до
перезаписи (здесь сделана, см. выше); (4) ловушки измерений (dd bs=1M,
debugfs -c и т.д.) — перечитать §0.1 перед работой на девбоксе.

Отличие от MX6-кейса: нам нужен не «LOS14.1 с vendor-разделом», а vendor,
который скормится **A13 GSI**. GSI требует от vendor: VINTF device manifest,
HIDL-HALы (binderized или passthrough), split-sepolicy P-эпохи+
(vndk 28+ обслуживается самим GSI). Наш Flyme A6-набор этому не
удовлетворяет сам по себе. Донор:

- FACT: дамп **Nokia NE1** (`Firmware-Dumper/nokia_ne1_dump`, ветка master) —
  mt6737m, Android 9 Go, fingerprint `Nokia/NE1_00WW_FIH/NE1:9/PPR1…`,
  security patch 2019-05, **non-AB, VNDK 28**, и его vendor —
  **64-битный**: `vendor/lib64/egl/libGLES_mali.so`,
  `vendor/lib64/hw/android.hardware.{audio@4.0,bluetooth@1.0,
  camera.provider@2.4,…}-impl-mediatek.so`, `hwcomposer.mt6735.so` (64-bit),
  `gralloc.mt6737m.so`, оба vintf-манифеста на месте (241 файл в lib64).
  Ядро NE1 — 3.18.119 arm64 (см. §1.1).
- INFERENCE: NE1-vendor — лучший донор каркаса: тот же SoC (mt6737m), та же
  арх (arm64 ядро + 64-битные HALы), готовые HIDL-обёртки MTK P-эпохи,
  VNDK 28 → класс vendor'ов, который современные GSI заявленно
  поддерживают. Наши Flyme-блобы доливаются поверх точечно (camera 3A/NVRAM-
  специфика, аудио-параметры, gps conf) — как на M6.
- Сшивка ABI с ядром 4.9 — два узких места, оба названы в §4: (a) GPU: NE1
  `libGLES_mali` 64-bit рассчитан на kbase 3.18-эпохи → в 4.9-lc для mt6735
  сохранён **старый kbase `gpu/mt6735/mali-r7p0`** (275 файлов, FACT) — им и
  собираться, а не midgard r26p0; (b) disp: `hwcomposer.mt6735.so` P-эпохи
  против `video/mt6735` Q-эпохи — HYPOTHESIS о совместимости ioctl,
  фальсификация в Phase E.

### 3.2 Механика custom→vendor

1. Образ: собирать vendor.img (ext4, ≤ 512 MiB) из донор-каркаса + наших
   блобов. Оценка объёма: NE1 vendor нужно замерить при исполнении
   (дамп качается посекционно); типичный legacy-MTK vendor 150–250 MiB —
   INFERENCE, 512 MiB достаточно с запасом ×2.
2. fstab: (a) first-stage ramdisk fstab:
   `/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/custom /vendor ext4 ro wait`;
   (b) fstab TWRP — добавить `/vendor` на ту же ноду (существующее TWRP-
   дерево: `Dekompilyator/twrp_meizu_m5c`, обновить его fstab).
3. sepolicy: метка `vendor_block_device` на `custom` в file_contexts донauра/
   нашем; для GSI план sepolicy split уже внутри donor-vendor (P-стиль).
4. Прошивка vendor.img в p17 — TWRP `flash to custom` (описать в TWRP-дереве
   как отдельный partition target) или dd из recovery; всегда с ручным
   подтверждением, как принято.
5. Прежде чем шить GSI: смок «vendor-раздел как таковой» можно доказать ещё
   на 3.18+LOS14.1 (MX6-стадия A: наш нынешний vendor-каталог выносится на
   custom, `TARGET_COPY_OUT_VENDOR` + fstab) — этот трек параллелен ядру и
   не блокируется графтом. Опционален, но дёшев и снимает механику
   (fstab/метки/TWRP) с критического пути.

## 4. Матрица компонентов

Полная таблица (проверено по клонам 4.9-lc; источники портов — наше 3.18-дерево,
пути в нём проверены `git ls-files`):

| Компонент (M5C_CHIP_MAP) | В 4.9-lc | Действие |
|---|---|---|
| Панель ili9881c_dsi_vdo_dj_hd720 | нет (только ilitek-варианты под другой bias) | порт из 3.18 + **stock-таблица из vmlinux.elf** |
| Панель jd9365_dsi_vdo_holitech_hd720 | нет | порт из 3.18 (таблицу тоже сверить с vmlinux) |
| Bias lp3101 (1-003e) | нет | порт `lcm/lp3101.c` из 3.18 |
| Тач gt9xx hotknot GT917D (1-005d) | `GT9XX_hotknot*` выпотрошены до Kconfig; полный `gt9xxtb_hn_new` есть | порт нашего **уже проверенного** 3.18-драйвера (ориентация!) либо адаптация gt9xxtb_hn_new |
| Зарядник fan5405 (1-006a) | да: `power/mt6735/{fan5405,charging_hw_fan5405}.c`, `MTK_FAN5405_SUPPORT` (`drivers/power/supply/mediatek/Kconfig:116`) | включить; `FAN5405_BUSNUM` захардкожен = 3 → тот же busnum-фикс на 1, что уже сделан у нас |
| Аксель MC3XXX (2-0018) | нет (шаблон `sensors-1.0/accelerometer/mc3410-i2c`, API `acc_driver_add` тот же + factory) | порт по шаблону |
| Магнитометр akm09912 (2-000c) | нет (шаблоны akm09911/15/18) | порт по шаблону |
| ALS/PS stk3x1x (2-0048) | нет (только cm3655x) | порт по шаблону alsps |
| Камера S5K4H8 + OTP (0-0010) | нет; mt6735m остался на СТАРОМ `kd_sensorlist` | порт из 3.18 почти как есть |
| Камера S5K5E8 (0-003c) | `common/v1/s5k5e8yx` есть, но не для mt6735m | порт нашего s5k5e8yx в kd_sensorlist |
| AF DW9714 (0-0018) | да: `lens/main/common/dw9714af` | конфиг |
| Вспышка LM3642 (1-0063) | да: новый flashlight-core + `flashlights-lm3642.c` | ABI к userspace сменился — camera-HAL донора уже P-эпохи, совместим |
| Дисплейный движок | да: `video/mt6735/{dispsys,videox}`, та же ddp_* структура | — |
| GPU Mali-T720 | да, **два kbase**: старый `gpu/mt6735/mali-r7p0` (275 файлов) и midgard r26p0 | строить **r7p0** под 64-битные donor-блобы NE1 |
| USB | да: `usb20/mt6735` musb+QMU, configfs-гаджет (+legacy G_ANDROID ещё жив) | Phase A |
| Батарейный стек | да: старый `battery_common/battery_meter/switch_charging` + fg_20 | как k37mv1 (GAUGE 20), fallback старый метр |
| Клоки/домены | legacy clkmgr (`base/power/mt6735`), CCF для mt6735 нет | рисков m681-типа нет |
| LCM API | `lcm_drv.h` диф косметический (`unsigned`→`unsigned int`, `struct LCM_*`, новый опц. `set_te_pin`) | механика |
| DTS | `arch/arm/boot/dts/mt6735m.dts` generic (без наших нод), биндинги той же эпохи, что стоковый DTB | Phase 0 — стоковый DTB как есть; свои ноды графтить из декомпилированного стокового DTS позже |

Главное отличие от v1: тач/зарядка/USB перестали быть неизвестными — на 4.9
переносятся наши **уже проверенные на железе** драйверы и фиксы, а не
гипотетические порты.

## 5. Фазы (переупорядочены: графт — первый и решающий)

Обвязка: `$D = /home/n8n/.claude/skills/devbox/scripts/dev.sh`, серийник
`710HVBR923RYK` (на девбоксе два телефона — только `-s`!), логгер →
`/data/forge`, аварийный канал — TWRP на стоковом ядре + last_kmsg/expdb.

**Phase 0 — arm64-графт, go/no-go гейт.** Содержание и тест — §1.2.
Выход: `/proc/version` = 4.9.188 на устройстве (или маркеры логгера).
Оценка: 2–4 сессии. Всё остальное — только после этого.

**Phase A — USB/adb на 4.9.** configfs-гаджет (для смока с LOS14.1-рамдиском
можно временно `USB_G_ANDROID=y` — в 4.9-lc он ещё есть; для GSI — configfs
в first-stage rc). Выход: `$D adb devices` видит устройство под 4.9.
Маркеры: dmesg `musb`, `CHRDET`, `/sys/class/power_supply/usb/online`=1.
Оценка: 1–2 сессии.

**Phase B — дисплей.** lp3101 + ili9881c (+jd9365) со stock-таблицами из
vmlinux.elf; `CUSTOM_KERNEL_LCM` как на 3.18. Выход: bootlogo/fb0.
Маркеры: id панели 0x98/0x81 в логе LCM-пробы, dmesg DSI. Оценка: 2–4 сессии.

**Phase C — тач, зарядка, сенсоры, камера (kernel-side).** Порты по §4;
каждая подсистема — свой мини-выход (getevent; power_supply online/status;
данные трёх сенсоров; probe s5k4h8/s5k5e8 в dmesg). Оценка: 3–6 сессий
суммарно. Параллелится с Phase D.

**Phase D — vendor-на-custom, параллельный трек (не ждёт ядра).**
§3.2: сборка vendor.img из NE1-каркаса + наших блобов, fstab/TWRP/метки;
опциональный смок на 3.18+LOS14.1. Выход: устройство грузит LOS14.1 с
/vendor, смонтированным с p17. Оценка: 2–4 сессии.

**Phase E — стыковка: 4.9 + donor-vendor + LOS14.1-рамдиск.** Гибридный смок
графики: hwcomposer.mt6735 (донор) на 4.9-dispsys, Mali r7p0 blob на r7p0-
kbase. Выход: композиция на экране (UI LOS14.1 или хотя бы bootanimation).
Это главный тест HYPOTHESIS про disp-ioctl. Маркеры: logcat hwc/gralloc,
`/sys/kernel/debug/dispsys`. Оценка: 2–5 сессий (широкая дисперсия — это
риск №2 плана).

**Phase F — first-stage boot-flow под GSI.** system-as-root ramdisk: fstab
(system p23, vendor p17), *_contexts первой стадии (урок MX6 §7a), AVB/verity
нет. Выход: наш boot.img с first-stage init монтирует оба раздела и передаёт
управление /system/bin/init GSI-образа до логотипа. Оценка: 1–3 сессии.

**Phase G — A13 GSI.** AndyYan LOS20 TD `arm64_bvN` (или phh AOSP 13) в
system p23 (проверить fit в 2.5 GiB ДО прошивки — `ls -l` образа), vendor
p17 из Phase D/E. Выход: загрузка в UI. Диагностика первой загрузки: logcat
через adb (configfs включён в Phase A), `bpfloader`-статус (проверка
INFERENCE про eBPF), vintf-несовместимости в logcat init. Оценка: 3–8 сессий
на доводку (sepolicy denials, overlays, fstab-мелочи; phh-overlay для
устройства). Fallback при системном затыке — A12L GSI, той же механикой.

**Phase H — телефония/Wi-Fi/BT/камера userspace, хардening.** Отдельным
планом после первого UI.

## 6. Риски (топ-3) и решающие критерии

1. **Графт не оживает** (Phase 0). Вероятность понижена фактами §1.2
   (arm64-гарды в коде, 3.18-прецедент, тот же LK), но фолбэка нет —
   arm32 вне скоупа по решению владельца. No-go после ~4 сессий без
   единого маркера жизни → остановка трека, разговор о целях.
2. **Графика на стыке эпох** (Phase E): donor-hwc (P) ↔ dispsys 4.9-lc (Q),
   mali-blob ↔ kbase. Митигание: r7p0-kbase из коробки 4.9-lc; при провале
   hwc — запасной вариант drm_hwcomposer/hwc2on1, но это уже инженерный
   проект. Настоящий ответ даст только Phase E.
3. **GSI-периферия**: размер образа против 2.5 GiB system; first-stage
   контексты; A13-sepolicy против P-vendor (compat-матрицы GSI). Каждое —
   решаемое, но в сумме даёт длинный хвост Phase G.

Суммарно до «A13 GSI показывает UI»: **грубо 14–26 рабочих сессий**.
Паритет с текущим LOS14.1 по периферии — поверх этого (камера/телефония —
самые дорогие).

## 7. Артефакты этой ревизии

- Клоны/снимки (эфемерный скретчпад
  `/tmp/claude-1000/-srv-forge-android-m5c/145b2c58-…/scratchpad`):
  `mtkzu-a10` (углублён до 10 коммитов), `woods-49`, `k37_bsp.cfg`,
  `k37_bsp_k49.cfg`, `ne1_boot.img` (банер ядра NE1), `ne1_files.txt`
  (инвентарь дампа NE1), `mt6735m_a10.dts`, `lcm_drv_49.h`.
- Девбокс: `/tmp/m5c-backup-20260817/custom.img` (бэкап p17, sha256 выше);
  дамп смонтирован/размонтирован read-only, устройство отпущено.
- Внешние: `nyancrimew/mtk-t-alps-release-q0-kernel-4.9-lc` (базовое дерево
  для Phase 0), `Firmware-Dumper/nokia_ne1_dump` (донор vendor),
  `Dekompilyator/twrp_meizu_m5c` (TWRP-дерево для fstab-правок),
  `/srv/forge/android/meizu_mx6_m95/TREBLE_VENDOR_PARTITION_PLAN.md`
  (прайор-арт custom→vendor).
