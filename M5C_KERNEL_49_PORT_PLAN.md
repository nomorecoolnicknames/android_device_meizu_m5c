# M5c — план перехода на ядро 4.9 (kernel-4.9-lc) для Android 9/10+

Дата: 2026-08-17. Автор: агент k49-plan (исследование по GitHub REST API +
локальные деревья). Все нетривиальные утверждения помечены
FACT / INFERENCE / HYPOTHESIS / REJECTED по правилам `/srv/forge/android/CLAUDE.md`.

Контекст (установлено ранее, не передоказывается): текущее ядро 3.18.19
(`/home/valakas/m5c/android_kernel_meizu_m5c`, HEAD `d2d6975c`), LOS 14.1
грузится, дисплей работает, два блокера — USB (PMIC EINT / CHRDET) и тач
(нет gt9xx-драйвера). Карта железа — `M5C_CHIP_MAP.md` (снята с живого стока).

---

## A. Какие базы 4.9 реально существуют для MT6735/MT6737

### A.1 Главный вывод: линия «kernel-4.9-lc» — официальный MTK T-ALPS-Q0

FACT: существует семейство зеркал одного и того же MTK-релиза
**kernel-4.9-lc** («lc» = low cost / legacy chips), все — kernel **4.9.188**
(проверено `Makefile` каждого по raw.githubusercontent.com):

| Репозиторий | Ветка | Версия | Комментарий |
|---|---|---|---|
| `nyancrimew/mtk-t-alps-release-q0-kernel-4.9-lc` | master | 4.9.188 | имя прямо кодирует релиз: **T-ALPS release Q0** |
| `memediatek/kernel-4.9-lc` | q | 4.9.188 | зеркало |
| `deadman96385/android_kernel_alps_4.9-lc` | master | 4.9.188 | зеркало (push 2023) |
| `mixa232323/kernel-4.9-lc` | master | 4.9.188 | зеркало |
| `mtk-watch/android_kernel-4.9-lc`, `OpenWatchProject/…` | — | не качал | по имени — то же |
| `mhdzumair/MhDzMR-woods-nicklaus-4.9` | master | **4.9.117** | «Alps 4.9-lc MT6737 kernel source», **вендорский релиз 2020 г. реально отгружавшегося устройства на MT6737** |

FACT (клон `mhdzumair/…woods-nicklaus-4.9`, локально
`…/scratchpad/woods-49`): в `arch/arm/configs/` лежат
`k37mv1_bsp_k49_defconfig` и `k37mv1_bsp_k49_debug_defconfig` —
**заводской конфиг reference-платы K37MV1 = MT6737M на ядре 4.9**, с
`CONFIG_MACH_MT6735M=y`, `CONFIG_MTK_PLATFORM="mt6735"`,
`CONFIG_MTK_GAUGE_VERSION=20`, `CONFIG_USB_CONFIGFS_*=y`,
`CONFIG_MTK_GPU_VERSION="mali midgard r26p0"`,
`CONFIG_MTK_FLASHLIGHT_LM3642=y`.

INFERENCE (из двух FACT выше): MTK довёл mt6735m до **продакшн-качества на
4.9** (Android 10 Go-устройства на MT6737 отгружались на 4.9-lc). Это не
любительский бэкпорт — база надёжная.

FACT (критично): в обоих склонированных 4.9-lc деревьях `MACH_MT6580 /
MACH_MT6735 / MACH_MT6735M` объявлены **только в `arch/arm/Kconfig`**
(проверено grep по HEAD обоих клонов); в `arch/arm64/Kconfig.platforms`
mt6735 нет, в `arch/arm64/boot/dts/Makefile` ссылок на mt6735/m5c нет,
`arch/arm64/boot/dts/mediatek/` содержит только mt6761/63/65/2712 и пр.
→ **официальная поддержка mt6735m в 4.9-lc — только ARM32 (zImage-dtb)**.

### A.2 MTKZU/android_kernel_meizu_m5c — разбор по веткам

FACT (GitHub API): репо **не форк**, создано 2022-02-10, две ветки.

**Ветка `android-9`** — это **НЕ 4.9**: `Makefile` = **3.18.119**
(raw fetch). История (API `/commits?sha=android-9`): 2022-02-10 «Import
Kernel Source» → серия реальных m5c-коммитов: «Add stock DTS»
(`arch/arm64/boot/dts/m5c.dts`, 3577 строк — размер совпадает с нашим
декомпилированным стоковым DTS), «Add LCM Driver»
(**jd9365_dsi_vdo_holitech_hd720**, +586 строк), «Add Touch Driver»
(**focaltech_touch ft5446** — вариант тача для ДРУГОЙ ревизии панели, у
нашего экземпляра Goodix), «Change IMGSENSOR», «Enable Charger driver»
(правки `charging_hw_fan5405.c`/`fan5405.c`). Итоговый defconfig
`arch/arm64/configs/m5c_defconfig` (3794 строки, полный):
`CONFIG_ARCH_MT6735M=y`, `CONFIG_CUSTOM_KERNEL_LCM="jd9365…"`,
`CONFIG_USB_G_ANDROID=y`.
INFERENCE: ветка android-9 — осмысленный порт m5c на 3.18.119 (ALPS N/O
vintage) под ALPS-Android-9; парное device-дерево
`MTKZU/android_device_meizu_m5c` (ветка `alps9`) — ALPS-стиль
(`TARGET_BOARD_PLATFORM := mt6737m`, включает `device/mediatek/mt6735`).
Загружалось ли оно на железе — **неизвестно** (релизов в репо нет; артефакт,
который бы это решил: собранный boot.img/скриншот от автора — отсутствует).

**Ветка `android-10`** — это и есть «4.9.188-кандидат» из брифа. FACT:
история — всего 5 коммитов за 3 дня (2025-07-10…12, автор XRed_CubeX):
«Import Android 10 4.9lc Kernel Source» → «Copy arm k37 and arm64 k57 config
to arm64 folder» → «Import A64 changes to m5c» (этот коммит **добавляет один
файл** — рукописный `arch/arm64/configs/m5c_defconfig` на 358 строк) →
«Fix yylloc». m5c-содержимое ветки: **только этот defconfig**. Проверено по
клону (`…/scratchpad/mtkzu-a10`, 68265 файлов):
- `jd9365`, `ili9881c_dsi_vdo_dj_hd720`, `lp3101`, `mc3xxx`, `akm09912`,
  `stk3x1x`, `s5k4h8` — **0 файлов**;
- `m5c.dts` — **нет вообще** (ни в arm, ни в arm64), хотя defconfig просит
  `CONFIG_BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES="m5c"`;
- defconfig ставит `CONFIG_MACH_MT6735M=y`, но в arm64-Kconfig такого
  символа нет (см. A.1) → символ молча выпадает при olddefconfig;
- `CONFIG_LCM_WIDTH="1280"` / `HEIGHT="720"` — перепутаны местами;
  `CONFIG_CUSTOM_KERNEL_LCM=""` — пусто.

INFERENCE (из перечисленных FACT): ветка android-10 — **незаконченная
заготовка**: импорт стокового 4.9-lc Q0 + скопированный k37-конфиг. Она не
могла собраться как arm64 и тем более не грузилась. Ценность MTKZU
android-10 ≈ ценность чистого kernel-4.9-lc; брать в качестве базы лучше
само зеркало T-ALPS-Q0 (история чище), а MTKZU держать как референс.

### A.3 Остальные известные деревья

- `XRedCubeX/android_kernel_m5c` (nougat/oreo, 3.18.79): REJECTED как база
  4.9 (это 3.18), но FACT из брифа — там живой jd9365 и IMGSENSOR
  "s5k4h8_mipi_raw s5k5e8_mipi_raw" → запасной источник портов.
- `XRedCubeX/android_kernel_meizu_mt6735` (lineage-16.0): FACT — `Makefile`
  = **3.18.119**. То есть чужой LOS-16 для mt6735 ехал на 3.18, не на 4.9.
- `Skyrimus/*` (Wileyfox Porridge, MT6735): 3.18.x — REJECTED как база 4.9.
- Поиск GitHub API по `mt6735 kernel 4.9` / `mt6737 4.9` / `"4.9-lc"` других
  независимых баз **не дал** (единственный вендорский хит — woods-nicklaus).
  Полного code-search без токена нет; если появится токен — можно добить
  запросами `path:arch/arm/configs k37 4.9`, но новых баз не ожидаю.

### A.4 Наличие наших компонентов в 4.9-lc (проверено по клонам, оба дерева совпадают)

| Компонент (из M5C_CHIP_MAP) | В 4.9-lc | Где / что именно |
|---|---|---|
| Панель jd9365_dsi_vdo_holitech_hd720 | **нет** | портировать |
| Панель ili9881c_dsi_vdo_dj_hd720 | **нет** (есть только ilitek-варианты под nt50358/rt5081 — другой init-код и bias) | портировать |
| Bias lp3101 (1-003e) | **нет** | портировать (`lcm/lp3101.c` из 3.18) |
| Тач gt9xx hotknot (1-005d, GT917D) | **частично**: `GT9XX_hotknot{,_phone,_scp}` выпотрошены до одних Kconfig; но есть полный **`gt9xxtb_hn_new`** (gt9xx_driver/update/extents/goodix_tool, hotknot=28 вхождений, tpd_dts_data-стиль) | адаптировать gt9xxtb_hn_new ИЛИ портировать наш GT9XXTB_hotknot из 3.18 |
| Зарядник fan5405 (1-006a) | **да**: `power/mt6735/{fan5405.c,charging_hw_fan5405.c}` + `CONFIG_MTK_FAN5405_SUPPORT` (`drivers/power/supply/mediatek/Kconfig:116`) | внимание: `FAN5405_BUSNUM` захардкожен = 3, у нас шина 1 |
| Аксель MC3XXX (2-0018) | **нет** (есть родственный шаблон `sensors-1.0/accelerometer/mc3410-i2c`) | портировать mc3xxx.c на sensors-1.0 |
| Магнитометр akm09912 (2-000c) | **нет** (есть akm09911/09915/09918 как шаблоны) | портировать |
| ALS/PS stk3x1x (2-0048) | **нет** (есть только cm36558/cm36652) | портировать |
| Камера S5K4H8 (0-0010) | **нет** | портировать (у mt6735m в 4.9-lc остался СТАРЫЙ фреймворк kd_sensorlist — см. B) |
| Камера S5K5E8 (0-003c) | **есть вариант** `common/v1/s5k5e8yx_mipi_raw` (v1-фреймворк, НЕ подключён к mt6735m) + наш 3.18 тоже s5k5e8**yx** | проще портировать наш в kd_sensorlist |
| AF DW9714 (0-0018) | **да**: `lens/main/common/dw9714af` (+sub) | конфиг/DTS |
| Вспышка LM3642 (1-0063) | **да**: новый flashlight-фреймворк, `flashlights-lm3642.c`; k37mv1 включает `CONFIG_MTK_FLASHLIGHT_LM3642=y` | сменился ABI к userspace (см. B) |
| Дисплейный движок | **да**: `video/mt6735/{dispsys,videox}` — та же ddp_* структура, что в 3.18 | |
| GPU Mali-T720 | **да**: `gpu/gpu_mali/mali_midgard`, `gpu/mt6735`; k37mv1: "mali midgard r26p0" | нужны userspace-блобы под r26p0 |
| USB | **да**: `usb20/mt6735` (musb+QMU) + configfs-гаджет | |
| Заряд/боевой стек | **да**: старый `battery_common.c`/`battery_meter.c`/`switch_charging.c` сохранён в `drivers/power/supply/mediatek` + fg_20 (`battery_common_fg_20.c`) | |
| Часы/домены | **да**: legacy clkmgr (`base/power/mt6735`), **CCF для mt6735 нет** (в `drivers/clk/mediatek` mt6735 отсутствует) | m681-стиль CCF/MTCMOS-боли не ожидается |

---

## B. Покомпонентно: откуда берётся 4.9-версия и что укусит при порте

Источник портов почти всюду — **наше собственное 3.18-дерево** (в нём
проверенно есть всё: jd9365, ili9881c_dsi_vdo_dj_hd720, lp3101, GT9XXTB_hotknot,
fan5405, mc3xxx_auto, akm09912, stk3x1x, s5k4h8/s5k5e8yx, dw9714af,
leds-lm3642 — пути перечислены выше и проверены `git ls-files`).

Реальные API-сдвиги 3.18→4.9-lc, проверенные по коду (не по памяти):

1. **LCM: сдвига почти нет.** FACT: diff функциональных указателей
   `lcm/inc/lcm_drv.h` (наш 3.18 vs 4.9-lc) — только косметика
   (`unsigned`→`unsigned int`, `LCM_setting_table_V3`→`struct …`, новый
   опциональный `set_te_pin`). `MTK_LCM_DEVICE_TREE_SUPPORT` в Kconfig есть,
   но включать не нужно — путь `CONFIG_CUSTOM_KERNEL_LCM="строка"` сохранён.
   Порт обеих панелей + lp3101 = механический (обёртки `struct LCM_*`,
   запись в `mt65xx_lcm_list.c/h`, каталоги с Makefile).
2. **Тач: фреймворк тот же (mtk_tpd/tpd_driver_t), но DTS-центричный.**
   FACT: `gt9xxtb_hn_new/gt9xx_driver.c` использует `tpd_driver_t`,
   `tpd_dts_data`, `of_match_table` — то же семейство API, что наш 3.18.
   Кусают: перенос `tpd_custom_gt9xx.h` конфигов (у 4.9-версии include
   только `config_1024x768` — наш 720x1280 конфиг надо принести), EINT
   через DTS-ноду `touch@…` (в стоковом DTB она есть), и выбор варианта
   (наш стоковый — hotknot; `GT9XX_hotknot` в 4.9-lc выпотрошен, так что
   либо восстановить его из 3.18, либо ехать на gt9xxtb_hn_new).
3. **Зарядка: СТАРЫЙ фреймворк сохранён — большого рефакторинга нет.**
   FACT: в 4.9-lc жив `battery_common.c` + `switch_charging.c` +
   `charging_hw_fan5405.c` (mt6735) — mtk_charger/charger_class появляется
   только у mt676x. k37mv1 задаёт `CONFIG_MTK_GAUGE_VERSION=20` →
   `battery_meter_fg_20.c`. Кусают: `FAN5405_BUSNUM=3` (нам нужна шина 1,
   как на стоке `1-006a`), и выбор gauge-версии (сток Flyme на 3.18 жил на
   старом метре; начать с fg_20 как у k37mv1, откатить на старый при
   странностях).
4. **Сенсоры: v1-скелет сохранён, но переехал в `sensors-1.0` + factory.**
   FACT: `mc3410-i2c.c` в 4.9-lc по-прежнему зовёт `acc_driver_add`,
   `acc_control_path`/`acc_data_path`, batch — то же, что наш 3.18
   `mc3xxx.c` (проверено grep обоих). Добавилось `*_factory_public`
   (заводские ioctl). Порт mc3xxx/akm09912/stk3x1x = взять in-tree шаблон
   (mc3410 / akm09911 / любой alsps) и перелить в него код общения с чипом
   из наших 3.18-файлов. Sensor hub у нас отсутствует — `CONFIG_CUSTOM_KERNEL_SENSORHUB` не включать.
5. **Imgsensor: mt6735m остался на СТАРОМ kd_sensorlist.** FACT: в 4.9-lc
   `imgsensor/src/mt6735m/kd_sensorlist.c` (старый фреймворк), новый
   `common/v1/imgsensor.c` — для mt676x. Значит s5k4h8/s5k5e8yx из нашего
   3.18 встают в mt6735m-каталог почти как есть (kd_sensorlist.h — вписать
   ID). OTP-код внутри сенсорных файлов едет вместе с ними. DW9714 — в
   4.9-lc уже есть.
6. **Вспышка: единственный компонент со СМЕНОЙ фреймворка.** FACT: вместо
   3.18 `constant_flashlight`/leds-LM3642 в 4.9-lc — новый
   `flashlight-core` + `flashlights-lm3642.c` (DT-нода, /dev/flashlight).
   Ядро готово, но **userspace-ABI другой** — старый A6-камерный HAL зовёт
   старые ioctl; это удар не по ядру, а по совместимости blob'ов (см. C).
7. **USB: musb сохранён, гаджет — configfs.** FACT: `usb20/mt6735` есть;
   k37mv1/MTKZU-конфиги включают `CONFIG_USB_CONFIGFS_*` (G_ANDROID в
   k37mv1 отсутствует). Для Android 10 это штатно; для гибридного теста
   «4.9 + наш LOS14.1» надо либо включить legacy `USB_G_ANDROID` (Kconfig
   в 4.9-lc ещё существует — MTKZU-a9 путь), либо перевести init.usb.rc на
   configfs. CHRDET-путь (`pmic_chr_type_det.c` в power/mt6735) в 4.9-lc
   переписан относительно нашего 3.18 → наш баг «Unbalanced enable IRQ 494»
   не переносится автоматически (но и чинится отдельно — см. E).
8. **Клоки/домены: риска m681-типа нет.** FACT: mt6735 в 4.9-lc остался на
   legacy clkmgr (`base/power/mt6735`), CCF-драйверов mt6735 нет. SPM/MTCMOS
   код тот же вендорский.
9. **DTS.** FACT: `arch/arm/boot/dts/mt6735m.dts` в 4.9-lc — generic ALPS
   (в нём НЕТ gt9xx/lp3101/fan5405/cap_touch-нод; kd_camera ноды есть),
   2041 строка против 3577 у стокового. Стиль биндингов тот же legacy
   (та же `mediatek,mt6735-pinctrl`, тот же topckgen, без `#clock-cells`) —
   графтинг наших нод из декомпилированного стокового DTS
   (`/home/valakas/m5c/kernel-reverse/meizu-m5c.dts`) механический, но
   обязательный. HYPOTHESIS: приложенный к 4.9-zImage наш **стоковый DTB**
   может завестись и без графта (биндинги одной эпохи); фальсификация —
   Phase 1: собрать с ним и посмотреть, доходит ли до init.
10. **SELinux.** Наша LOS14.1-сборка несёт policydb v29 (BRINGUP_STATE
    2026-08-17), 4.9-lc это переварит; для A10-userspace политика идёт из
    GSI/vendor — отдельная тема userspace, не ядра.
11. **ion/m4u/ged/cmdq/disp ioctl ABI.** Не проверял построчно (нужен diff
    include/ соответствующих uapi между 3.18 и 4.9-lc — объём большой).
    HYPOTHESIS (главный гибридный риск): A6-эпохи gralloc/hwc
    (`hwcomposer.mt6737m.so`) может не совпасть с disp-session ioctl 4.9-lc
    Q-эпохи → чёрный экран при живом ядре. Фальсификация — Phase 3 (гибрид):
    dmesg/logcat hwc ошибки + `cat /sys/kernel/debug/dispsys`.

### Арх-развилка ARM32 vs ARM64 (ключевое решение плана)

- FACT: официальный 4.9-lc = ARM32 для mt6735m; вендор так и отгружал
  (k37mv1_bsp_**k49**_defconfig в arch/arm/configs).
- FACT: наш текущий стек — arm64 ядро + 64-битный userspace (в vendor-дереве
  есть lib64/hw/*.mt6737m.so).
- INFERENCE: ARM32-ядро не запустит наш нынешний arm64-userspace → гибридный
  смоук-тест «4.9 под LOS14.1» на ARM32 невозможен. Портирование mt6735m в
  arch/arm64 у 4.9-lc никем не доказано (MTKZU пытался и бросил).
- Решение в плане: **двухтрековая проверка в Phase 1** — (а) быстрая сборка
  ARM32 k37mv1 (доказывает качество базы), (б) arm64-графт Kconfig+dts
  (перенос `MACH_MT6735M` в arch/arm64, dts в arm64/boot/dts/mediatek) с
  нашим стоковым DTB. Если (б) заводится до init — едем arm64 (сохраняем
  userspace и blob'ы); если вязнет >2 сессий — честно падаем на ARM32-трек
  и arm32-userspace (см. C). У (б) шансы неплохие: платформенный код mt6735
  в 3.18 уже жил в arm64, а 4.9-lc код тот же вендорский; но это INFERENCE,
  не гарантия — где-нибудь в spm/lowlevel могут вылезти arm32-ассемблерные
  куски (фальсификация: сборка и есть тест).

---

## C. Vendor-блобы и ABI: что произойдёт с userspace

FACT: наш `vendor/meizu/m5c/proprietary` — 444 файла, 368 .so, классические
legacy-HAL модули A6-эпохи: `lib{,64}/hw/{camera,hwcomposer,gralloc,audio.primary,gps}.mt6737m.so`,
lib3a и т.д. Это дотребловый мир: без HIDL, без VNDK, собран под M (API 23).

Что меняется при 4.9 + Android 9/10:

1. **Treble/VNDK.** A9/A10-userspace требует HIDL HAL'ы
   (`android.hardware.graphics.composer@2.1`, `camera.provider@2.4`,
   `audio@4/5` и т.д.). Наши A6-модули напрямую не подключаются — их надо
   оборачивать passthrough-обёртками (стандартные default-имплементации
   HIDL поверх legacy libhardware модулей) — это тот же приём, что в
   LOS16-портax на mt6737 у других авторов и в `device/mediatek/mt6735`
   (base MTKZU alps9). Часть блобов при этом заведётся (gps, audio),
   часть — исторически самые капризные — gralloc/hwc/GPU и camera.
2. **GPU.** Mali-T720 blob'ы у нас — r7p0-эпохи A6 (в 3.18-дереве gpu
   mali-r7p0/EAC). Ядро 4.9-lc несёт midgard r26p0 → нужны **согласованные
   userspace-библиотеки Mali r26p0** под нашу арх (arm32 у Go-устройств).
   Их источник — прошивка донора, реально отгружавшегося на 4.9-lc MT6737
   (например, устройство «woods/nicklaus» из репо mhdzumair). Наши A6
   r7p0-блобы против r26p0-ядра — несовместимы (mali kbase ABI жёстко
   версионирован; это FACT уровня «version check в kbase», проверяется
   первым же logcat'ом).
3. **Camera.** Пер-девайсный NVRAM/3A-стек A6 против A10-provider —
   максимально рискованная связка; реалистично камера едет последней и
   может остаться на «работает превью через wrapped legacy HAL» (как на M6).
4. **RIL/модем.** Блобы md_ctrl/ril A6-эпохи; A10-телефония поверх них —
   через mtk-radio-обёртки; объём неизвестен, честно: не исследовал.
5. **Можно ли реюзать vendor/meizu/m5c?** Частично: firmware (modem, wifi,
   GPS conf, nvram-структуры) — да; hw-модули — только через
   HIDL-passthrough и только те, чьи kernel-ABI не уехали (см. flashlight,
   disp). Готового «vendor под A10 mt6735» в природе нет — его собирают из
   (а) донора Go-устройства на 4.9-lc и (б) наших firmware-блобов.

**Реалистичный минимально-жизнеспособный маршрут** (INFERENCE из пунктов
выше):
- Ступень 1 (низкий риск, высокая ценность): **4.9-arm64 + наш LOS14.1**
  (тот же userspace, что сейчас) — доказывает ядро отдельно от Treble.
- Ступень 2: **4.9 + LOS 16.0 device-tree** (порт по образцу
  `XRedCubeX/android_kernel_meizu_mt6735` + MTKZU alps9 device tree) —
  классический полный порт, много работы, но каждый HAL решается известными
  приёмами.
- Ступень 3 (если ступень 2 упирается): **4.9-arm32 + arm32 A10 Go GSI +
  vendor донора** — путь «как вендор», но с чужими блобами и почти
  гарантированной ручной возней с overlay/fstab/sepolicy.
  «4.9 + AOSP10 GSI поверх нашего A6-vendor» без ступени 2 — REJECTED:
  GSI требует treble-ized vendor, которого у нас нет.

---

## D. Фазовый план (каждая фаза проверяется на железе)

Обвязка проверки: adb через devbox — `/home/n8n/.claude/skills/devbox/scripts/dev.sh adb …`;
ramdisk-логгер пишет в `/data/forge` (маркеры стадий); TWRP жив на стоковом
ядре → всегда есть канал снять `/proc/last_kmsg`/pstore после неудачной
загрузки. Прошивка boot — только p-boot, по установленной для m5c процедуре,
каждая прошивка руками подтверждается.

**Phase 0 — база и «чистая» сборка (без железа).**
Взять `nyancrimew/mtk-t-alps-release-q0-kernel-4.9-lc` (или memediatek/q —
перед стартом сверить деревья diff'ом, они должны быть идентичны; расхожде-
ние = выбрать nyancrimew как именованный релиз). Собрать ARM32
`k37mv1_bsp_k49_defconfig` штатным тулчейном (gcc из prebuilts/clang по
вендорскому конфигу).
- Выход: `zImage-dtb` собирается без ошибок.
- Проверка: артефакт + лог сборки в `/data/forge`-стиле каталоге сборок.
- Оценка: 1 сессия.

**Phase 1 — арх-развилка (см. B): arm64-графт vs arm32.**
(а) Портировать `MACH_MT6735M` в arch/arm64 (Kconfig.platforms + Makefile
плат.каталогов), перенести `mt6735m.dts`+`mt6735m-pinfunc.h` в
`arch/arm64/boot/dts/mediatek/`, собрать Image.gz-dtb со **стоковым DTB**
(наш e17a091…). Дефконфиг: k37mv1 → adapt (наши строки LCM/project можно
временно оставить пустыми — цель фазы не дисплей).
(б) Параллельно держать ARM32-сборку как fallback.
- Выход: ядро доходит до init (любой userspace) ИЛИ осознанное решение
  «едем ARM32».
- Проверка: маркеры ramdisk-логгера в `/data/forge/boot-*.log`; если пусто —
  TWRP → `cat /proc/last_kmsg` (ищем `Linux version 4.9.188` и docket
  паники); `dev.sh adb shell cat /proc/version` при удаче.
- Порог: >2 сессий без прогресса на (а) → переключение на (б).
- Оценка: 2–4 сессии. **Дальше — только после доказанного Phase 1.**

**Phase 2 — USB/adb на 4.9.**
Включить configfs-гаджет (для гибрида с LOS14.1 — legacy `USB_G_ANDROID=y`,
он в 4.9-lc ещё есть; для A10 — configfs+init.rc). Проверить CHRDET.
- Выход: `dev.sh adb devices` видит устройство под 4.9-ядром.
- Проверка-маркеры: dmesg `musb`, `mt_usb`, `CHRDET`; `/sys/class/power_supply/usb/online`=1 с кабелем.
- Оценка: 1–2 сессии.

**Phase 3 — дисплей.**
Порт lp3101 + обеих панелей (jd9365, ili9881c_dsi_vdo_dj) из нашего 3.18,
`CONFIG_CUSTOM_KERNEL_LCM="ili9881c_dsi_vdo_dj_hd720 jd9365_dsi_vdo_holitech_hd720"`,
720x1280. Сначала bootlogo/fb0, затем гибрид с LOS14.1-hwc (тест HYPOTHESIS
из B.11).
- Выход: изображение (bootlogo достаточно для exit'а фазы).
- Проверка: глазами + dmesg `DSI`, id-чтение панели (0x98/0x81 или
  0x93/0x65) в логе LCM-пробы; при чёрном экране — `dispsys` debug-узлы.
- Оценка: 2–4 сессии. Самая рискованная кернел-фаза.

**Phase 4 — тач.**
Адаптировать `gt9xxtb_hn_new` (или восстановить GT9XX_hotknot из 3.18) под
GT917D: наш `tpd_custom_gt9xx.h`, DTS-нода `cap_touch@5d` + EINT62.
- Выход: события касания.
- Проверка: `dev.sh adb shell getevent -l | head` при тапе; dmesg
  `<<-GTP-INFO->>`, `tpd_down`.
- Оценка: 1–2 сессии.

**Phase 5 — зарядка/батарея.**
`MTK_FAN5405_SUPPORT=y`, busnum 3→1, gauge fg_20 (fallback старый метр).
- Выход: заряд идёт, тип кабеля определяется.
- Проверка: `dev.sh adb shell cat /sys/class/power_supply/{usb,ac}/online battery/status battery/capacity`; dmesg `fan5405`.
- Оценка: 1–2 сессии.

**Phase 6 — сенсоры.**
mc3xxx → шаблон mc3410-i2c; akm09912 → шаблон akm09911; stk3x1x → alsps.
- Выход: три input-устройства дают данные.
- Проверка: `dev.sh adb shell dumpsys sensorservice | head -40` (на LOS)
  или чтение `/sys/…/sensors-1.0` factory-узлов; dmesg init-строки драйверов.
- Оценка: 1–2 сессии.

**Phase 7 — камера (kernel-часть) + вспышка + AF.**
s5k4h8/s5k5e8yx в `imgsensor/src/mt6735m` (kd_sensorlist), dw9714 конфиг,
flashlight-нода LM3642.
- Выход: сенсоры детектятся ядром.
- Проверка: dmesg `kd_sensorlist`/`[s5k4h8]` probe-строки, `/proc/driver/camsensor`-стиль узлы, `/dev/flashlight` существует.
- Оценка: 1–2 сессии (userspace-камера — вне этой фазы, см. C).

**Phase 8 — userspace-ступень (решается ПОСЛЕ Phase 2–4).**
Ступень 1: LOS14.1 на 4.9 как daily-smoke. Ступень 2: LOS16 device-tree
порт (отдельный план, вехи по HAL'ам). Ступень 3 (fallback): arm32 A10 Go
GSI + донор-vendor.
- Выход ступени 1: LOS14.1 welcome-экран на 4.9 (паритет с 3.18).
- Оценка: ступень 1 — 1–2 сессии; ступень 2 — 8–15 сессий (honest: широкая
  дисперсия); ступень 3 — 4–8 сессий.

---

## E. Честная рекомендация

**Сначала добить два блокера на 3.18, потом стартовать 4.9.** Аргументы:

1. FACT: оба блокера уже локализованы (EINT/CHRDET; отсутствие gt9xx в
   сборке) и оба на 3.18 — работа на 1–3 сессии суммарно. Их результат —
   рабочий adb и тач — это **инструментарий, без которого 4.9-порт будет
   идти вдвое дольше** (каждая фаза D предполагает adb-проверки).
2. INFERENCE: сам тезис «для Android 9/10 нужно 4.9» — неточен: LOS16 для
   mt6735 у XRedCubeX ехал на 3.18.119 (FACT, Makefile), MTKZU-alps9 тоже
   парился с 3.18.119. 4.9-lc даёт свежий LTS, вендорскую Q-базу, configfs
   и чистую зарядку — это правильная цель, но не пререквизит A9/A10.
3. Решающие критерии старта 4.9: (а) adb на 3.18 работает; (б) выбран
   userspace-трек (LOS16-порт против A10-Go-GSI) — от него зависит
   ARM32/ARM64-развилка Phase 1; (в) есть слот на 2+ сессии подряд для
   Phase 0–1 без прошивочных рисков (TWRP-канал сохраняется всегда).

**Суммарная оценка 4.9-трека до паритета с текущим LOS14.1** (Phase 0–5 +
ступень 1): ~8–15 рабочих сессий. До «A10 на устройстве»: +8–15 сверху.

**Топ-3 вероятных провала:**
1. **Дисплей на 4.9** (Phase 3): порт LCM механический, но связка
   «4.9 disp ioctl ↔ старый hwcomposer» — непроверенная (B.11); возможен
   длинный хвост отладки dispsys.
2. **Userspace-ступень 2/3** (Phase 8): vendor под A9/A10 для mt6735
   придётся собирать из обёрток и донорских блобов (Mali r26p0!), готового
   нет; камера почти наверняка деградирует.
3. **ARM64-графт 4.9-lc** (Phase 1а): официально не существует; если в
   платформенном коде вылезут arm32-only куски (spm/lowlevel asm),
   придётся падать на ARM32 и терять текущий arm64-userspace — что
   автоматически тащит ступень 3 вместо 1.

### Артефакты этого исследования
- Клоны: `…scratchpad/mtkzu-a10` (MTKZU android-10, 4.9.188),
  `…scratchpad/woods-49` (вендорский 4.9.117 MT6737);
  defconfig-снимки: `…scratchpad/{m5c_defconfig_a9,m5c_defconfig_a10,k37mv1_defconfig}`,
  dts: `…scratchpad/mt6735m_a10.dts` (полный префикс:
  `/tmp/claude-1000/-srv-forge-android-m5c/145b2c58-faa9-45b2-84d1-967d0b509fd8/scratchpad`).
  Скретчпад эфемерен — при старте Phase 0 клонировать заново из именованных
  выше репозиториев.
