# M5c — журнал сборки ядра 4.9 arm64 (Phase P0+)

Исполнитель: субагент k49-build. План: `M5C_KERNEL_49_PORT_PLAN.md` (v2).
Авторитет по железу: `M5C_CHIP_MAP.md`. Формат: FACT / INFERENCE /
HYPOTHESIS / REJECTED по `/srv/forge/android/CLAUDE.md`.

## 2026-08-17 Phase P0: arm64-графт 4.9-lc

### Дерево

- FACT: база — `nyancrimew/mtk-t-alps-release-q0-kernel-4.9-lc`, shallow-клон
  (единственный коммит `3aff4df04 Initial commit`), kernel **4.9.188**
  (`Makefile`: VERSION=4, PATCHLEVEL=9, SUBLEVEL=188). Рабочее дерево:
  `/srv/forge/android/m5c/kernel-m5c-4.9-lc`, ветка `m5c-arm64`.
- FACT: тулчейн — gcc 4.9 aarch64 из
  `los14.1-m5c-patched/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9`
  (тот же, каким собирается наше 3.18).

### Разведка перед графтом (все — FACT, проверено в дереве)

- `arch/arm64/Kconfig.platforms` 4.9-lc УЖЕ содержит MTK-платформы
  (`MACH_MT6758/MT6765/MT6761/MT6763/MT6580/MT3887`), перенесённые из arm32
  вместе с arm32-селектами (`CPU_V7`, `HAVE_SMP`, `NEED_MACH_MEMORY_H`) —
  select несуществующего символа в Kconfig игнорируется, прецедент в дереве
  массовый. Наш проверенный 3.18-arm64 `ARCH_MT6735M` устроен так же.
- Кастомный GIC-драйвер mt6735 (`drivers/misc/mediatek/irq/mt6735/irq.c`,
  `IRQCHIP_DECLARE("mediatek,mt6735-gic")` — тот же compatible, что в стоковом
  DTB) держит весь FIQ-код под `#if defined(CONFIG_FIQ_GLUE)` — на arm64
  символа нет, код выпадает сам.
- Сборочная механика appended-DTB на arm64 в дереве есть целиком:
  `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE(_NAMES)`, цель `Image.gz-dtb`,
  `arch/arm64/boot/Makefile` конкатенирует Image.gz + DTB_OBJS.
- drvgen: `scripts/drvgen/drvgen.mk` генерит `cust.dtsi` из
  `drivers/misc/mediatek/dws/mt6735/k37mv1_bsp_k49.dws` (файл есть) тулзой
  `tools/dct/DrvGen.py`.
- MTKZU:android-10 (клон в скретчпаде) подтверждён как НЕ-графт: коммит
  `26fb53449 "Import A64 changes to m5c"` добавляет только
  `arch/arm64/configs/m5c_defconfig` (358 строк), `MACH_MT6735M` в их arm64
  Kconfig не заведён — их arm64-конфиг мёртвый. Совпадает с оценкой плана v2.

### Сделано (коммиты в kernel-m5c-4.9-lc, ветка m5c-arm64)

1. `arch/arm64/Kconfig.platforms`: добавлен `config MACH_MT6735M` — копия
   arm32-блока минус arm32-only селекты (`CPU_V7`, `VFP_OPT`,
   `NEED_MACH_MEMORY_H`, `ARM_CRYPTO`/`CRYPTO_*_ARM_CE`,
   `ARM_ERRATA_836870`, `ARM_MT6735_CPUIDLE` — последний вообще нигде не
   определён, select был мёртвый и на arm32). Оставлены реально существующие:
   `MTK_SYSTRACKER, MTK_SYS_CIRQ, MTK_EIC, MTK_GPIO, MTK_IRQ, PINCTRL_MT6735,
   MFD_SYSCON, CPU_IDLE, MTK_BASE_POWER, MTK_IRQ_NEW_DESIGN, MTK_POWER_GS,
   HW_RANDOM_MT67XX, SDCARD_FS, OVERLAY_FS` (все проверены grep'ом по
   Kconfig-ам дерева).
2. DTS: `mt6735m.dts`, `mt6735m-pinfunc.h`, `cust_mt6735_msdc.dtsi`,
   `k37mv1_bsp_k49.dts` скопированы из `arch/arm/boot/dts/` в
   `arch/arm64/boot/dts/mediatek/`; `#include <trusty.dtsi>` заменён на
   `"trusty.dtsi"` (angle-include не резолвится из подкаталога mediatek;
   файл в mediatek/ уже был). В `mediatek/Makefile` добавлено
   `dtb-$(CONFIG_MACH_MT6735M) += mt6735m.dtb k37mv1_bsp_k49.dtb`.
3. `arch/arm64/configs/m5c_defconfig` (новый): перевод
   `arch/arm/configs/k37mv1_bsp_k49_defconfig` на arm64 + P0-минимизация по
   плану §1.2(5). Ключевое:
   - `CONFIG_MACH_MT6735M=y`, `MTK_PLATFORM="mt6735"`,
     `ARCH_MTK_PROJECT="k37mv1_bsp_k49"` (проект референсный, пока не m5c —
     смена проекта = отдельная тема после P0);
   - **`CONFIG_COMPAT=y`** — наш userspace LOS 14.1 32-битный; в первом
     прогоне defconfig COMPAT не выставился (это ловил и
     `ANDROID_DEFAULT_SETTING`-warning про `ARMV8_DEPRECATED needs COMPAT`);
   - `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE=y`,
     `NAMES="mediatek/k37mv1_bsp_k49"`;
   - выключено на P0: GPU (`MTK_GPU_SUPPORT`), дисплей (`MTK_FB`, `MTK_LCM`,
     `MTK_VIDEOX`, `MTK_CMDQ`, `MTK_SMI_EXT`), камеры (`MTK_IMGSENSOR`,
     `MTK_LENS`, `MTK_FLASHLIGHT`), тач (`INPUT_TOUCHSCREEN`), сенсоры
     (`MTK_SENSOR_SUPPORT`), связь (`MTK_COMBO*`, `MTK_BTIF`), модем
     (`MTK_ECCCI_DRIVER`), видеокодеки/JPEG, звук MTK;
   - оставлено живым: eMMC/MSDC (`MMC_MTK_PRO`, `MTK_EMMC_SUPPORT`), UART
     (`MTK_SERIAL`), PMIC wrap, clkmgr, GPT, watchdog, RTC, батарейный стек
     (`MTK_SMART_BATTERY`, GAUGE 20), USB musb (`USB_MTK_HDRC`+QMU),
     `MTK_RAM_CONSOLE`+`MTK_AEE_FEATURE` (канал last_kmsg), SELinux, ION.
4. FACT (сборочные грабли, чтобы не переоткрывать):
   - drvgen/dtboimg: при `CONFIG_MTK_DTBO_FEATURE=y` (default y!)
     `PROJ_DT_NAMES` берётся из `BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES` (у нас
     пусто) → `dtboimg.cfg` падает `mv: cannot stat`. Наш LK — не DTBO;
     лечится `# CONFIG_MTK_DTBO_FEATURE is not set` в defconfig.
   - Самый первый прогон make после голого defconfig упал там же из-за ещё
     не сгенерированного `include/config/auto.conf` — просто перезапуск.
   - Upstream-коммит дерева сделан из тарболла: у ВСЕХ `.sh/.py/.pl/.awk`
     и прешипнутых бинарей потерян exec-бит (`gen_vdso_offsets.sh`,
     `tools/dct/old_dct/DrvGen`, `scripts/dtc/dtc_overlay`) → серия
     `/bin/sh: Permission denied`. Вылечено tree-wide chmod-коммитом;
     заодно в дерево добавлен `.gitignore` (в тарболле его не было — без
     него `git add -A` тащит .o/.config в индекс).
   - `scripts/dtc`: `yylloc` — multiple definition под хостовым gcc 10+
     (`-fno-common`); `extern` в `dtc-lexer.lex.c_shipped` (тот же фикс,
     что первый коммит MTKZU).
   - drvgen вызывает `DrvGen.py` голым (`$(python)` пуст, shebang
     `/usr/bin/python` на хосте отсутствует) → в `drvgen.mk` добавлен
     `python ?= python2`; сам `.dws` старого (не-XML) формата, поэтому
     реально работает `tools/dct/old_dct/DrvGen` (статический ELF32,
     запускается на x86-64 хосте после chmod).
   - **Первый настоящий arm64-компилятивный дефект дерева**: в
     `arch/arm64/include/asm/cputype.h` MTK переименовал 5-аргументный
     `MIDR_RANGE` → `MIDR_IN_RANGE`, но `_MIDR_ALL_VERSIONS` остался на
     `MIDR_RANGE` → `cpufeature.c` (kpti_safe_list) не собирался. FACT:
     arm64-ветку этого дерева никто никогда не компилировал (ошибка в
     базовом arch-файле). Фикс: `_MIDR_ALL_VERSIONS` → `MIDR_IN_RANGE`.

### Закрытые ошибки компиляции/линковки arm64 (все — FACT, по build0N.log)

Хронология ошибок и фиксов (детали в сообщениях коммитов ветки `m5c-arm64`):

1. `cpufeature.c` (kpti_safe_list): `_MIDR_ALL_VERSIONS` разворачивался в
   переименованный `MIDR_RANGE` → `MIDR_IN_RANGE` (`arch/arm64/include/asm/
   cputype.h`). Ошибка в базовом arch-файле = arm64-ветку дерева никто
   никогда не собирал.
2. `mach/mt_gpt.h` и весь класс `mach/*` не находились: в
   `arch/arm64/Makefile` нет MTK include-пути; добавлен
   `-Idrivers/misc/mediatek/include/mt-plat/$(MTK_PLATFORM)/include` под
   `MACH_MT6735M` (зеркало arm32).
3. `cpuidle-mt6735.c`: 3.18-овский `cpu_init_idle()` → 4.9 `arm_cpuidle_init()`.
4. `mt_gpt.c`: печать указателя через `(u32)` — на arm64 int-cast error.
5. `irq/mt6735/irq.c`: нет `IOMEM()` на arm64 (68 ошибок одной причины) —
   добавлен локальный `#define`. FIQ-код уже был под `CONFIG_FIQ_GLUE`.
6. `mach/irqs.h`: `NR_IRQS redefined` против asm-generic — раскомментирован
   родной `#undef NR_IRQS`.
7. uart: подкаталожный `mt6735/Makefile` не имел `-I uart/include` и
   `-I uart/mt6735` (и юзал `$(CONFIG_MTK_PLATFORM)` с кавычками);
   `uart.c` не включал `linux/clk.h`. Плюс рантайм-мина: CCF-ветка
   `devm_clk_get()` завалила бы probe на стоковом DTB (в нём нет
   `skip_pinmux_clk`) — под `CONFIG_MTK_CLKMGR` теперь принудительный skip,
   клоки ведёт `platform_uart.c` через clkmgr, как на 3.18.
8. `mach/mt_thermal.h` → `"mt_gpufreq.h"`: в `base/power/mt6735/Makefile`
   не было `-I` собственного каталога.
9. m4u: `m4u_platform.c` (подкаталог `mt6735m/`) не видел свой же
   `m4u_reg.h` — добавлен `-I` собственного каталога.
10. `compat_ion.c`: `ION_MM_GET_IOVA(_EXT)` есть в компат-коде и в
    `struct ion_mm_data`, но отсутствовали в enum `ION_MM_CMDS` —
    полусмерженное состояние; добавлены в хвост enum.
11. devapc: ATF-ветка была под `TEE || ARM_PSCI || MTK_PSCI` → добавлен
    `CONFIG_ARM64` (на этой платформе arm64 всегда под ATF) и явный
    include `mach/mt_secure_api.h`.
12. **`mt_psci.c` — ключевая находка**: стоковый DTB m5c грузит CPU через
    `enable-method = "mt-boot"`, который реализует именно этот файл
    (`cpu_operations mt_cpu_psci_ops`), а `arch/arm64/kernel/cpu_ops.c`
    4.9-lc уже знает `mt_cpu_psci_ops` из коробки. Включён
    `CONFIG_MTK_PSCI=y` (ровно как в нашем проверенном 3.18 arm64
    конфиге); файл портирован на 4.9-сигнатуры cpu_operations
    (`cpu_init`/`cpu_init_idle` без device_node).
13. `MTK_IRQ_NEW_DESIGN`: потребители в `kernel/irq/{manage,proc}.c` есть,
    а провайдеры (`update_affinity_settings`, `irq_need_migrate_list`)
    были только в `arch/arm/kernel/irq.c` — блок перенесён дословно в
    `arch/arm64/kernel/irq.c` (в нашем 3.18 arm64 он там же).
14. systracker: `backtrace_64bit.c` ссылался на v2-глобал
    `BUS_PROTECT_BASE` при v1-интерфейсе — дамп-строка под guard.
15. cameraisp: собирался безусловно и тянул выключенные CMDQ/MMDVFS;
    Makefile посажен на `CONFIG_MTK_CAMERA_ISP` (P0: off). Грабля kbuild:
    при полностью пустом obj-y каталог оставляет СТАРЫЙ built-in.o и
    линкует его — поэтому dummy-объект оставлен безусловным (паттерн MTK).

### Результат P0: ядро собирается (FACT)

- `EXIT=0`, `arch/arm64/boot/Image.gz-dtb` = 6 076 510 B (build20.log).
- Баннер: `Linux version 4.9.188-m5c+ (n8n@n8nagent) (gcc 4.9) #6 SMP
  PREEMPT Mon Aug 17 15:40:53 MSK 2026`; magic arm64 `ARMd`, TEXT_OFFSET
  0x80000 — 64-битный Image, не zImage.
- Дерево: `/srv/forge/android/m5c/kernel-m5c-4.9-lc`, ветка `m5c-arm64`,
  14 коммитов поверх `Initial commit` (см. `git log --oneline`).

### Тестовый образ P0 (не прошит — прошивает владелец сессии)

- `boot_49_p0.img`, sha256
  `46b891adcfb4f8556f2e40121f6a8e4d6c3e5a581c888a3669b21a899d43e1d6`,
  9 459 712 B; путь (скретчпад):
  `/tmp/claude-1000/-srv-forge-android-m5c/145b2c58-…/scratchpad/boot_49_p0.img`.
- Состав: наш `Image.gz` (6 003 004 B) + **стоковый DTB** (69 427 B, md5
  `e17a091033c1e9188df898186be2761f` — проверен внутри образа по смещению
  kernel+6003004) + ramdisk LOS 14.1 c forge-логгером (1 616 110 B — тот же,
  что в `boot_k16.img`); заголовок mkbootimg скопирован с `boot_k16.img`
  (page 2048, kernel@0x40080000, ramdisk@0x44000000, tags@0x4e000000,
  cmdline `bootopt=64S3,32N2,64N2 androidboot.selinux=permissive
  buildvariant=userdebug`). gzip-поток ядра внутри образа проверен
  `gunzip -t`.
- Партиция: **boot (p7)**. Аварийный канал: TWRP на стоковом ядре.
- Ожидаемые маркеры успеха: `/proc/version` = `4.9.188-m5c+`; файлы
  логгера в `/data/forge/` (dmesg/heartbeat). Маркеры провала: last_kmsg
  через TWRP (`/proc/last_kmsg`), где встало.
- Osoбые точки внимания на первом боте 4.9 (что смотреть в dmesg):
  `mt-boot` cpu ops / подъём CPU1-3 (INFERENCE: путь mt_psci→
  cpu_psci_ops→ATF на 4.9 не проверялся на железе); mt_gpt/clocksource;
  msdc/eMMC mount `/data`; отсутствие дисплей-стека — экран останется на
  bootlogo LK, это ОЖИДАЕМО (MTK_FB off в P0).

### Подготовка Phase B (не гейтится загрузкой): jd9365 из стока

FACT: из `/home/valakas/m5c/kernel-reverse/vmlinux.elf` извлечены
байт-в-байт таблицы jd9365 (метод тот же, что для ili9881c): init VA
`0xffffffc00101fe40` — **227** записей (у нас в 3.18 дереве 225 —
расходится, диффать при порте), suspend VA `0xffffffc001023e18` — 6
записей. Самопроверка: первые записи пишут E1=0x93, E2=0x65 = compare_id
jd9365. Файлы: `captures/lcm-stock-tables/jd9365_stock_tables.c` (+
скрипт-экстрактор), коммит `2a23009`.

FACT: `jd9365_lcm_get_params` (декомпиляция `0xffffffc0004e559c`)
декодирован по словарю смещений, валидированному на ili9881c (все
верифицированные на железе значения ili9881c — PLL 212, LANE 4, порчи,
physical 62x110 — легли на те же offsets):

| поле | jd9365 | ili9881c (эталон, проверен на железе) |
|---|---|---|
| mode | 1 (SYNC_PULSE_VDO) | 1 |
| LANE_NUM | 4 | 4 |
| vsa / vbp / vfp | 4 / 12 / 24 | 4 / 16 / 20 |
| hsa / hbp / hfp | 30 / 60 / 66 | 20 / 70 / 70 |
| PLL_CLOCK | 212 | 212 |
| ssc_disable | 1 | 1 |
| noncont_clock / period | 1 / 2 | нет |
| HS_TRAIL | 6 | 6 |
| physical w×h, мм | 62×110 | 62×110 |
| esd cmd/expect | 0x09 → 0x80,0x03 (count 3) | 0x0A → 0x9C |

Подтверждено требование плана: панели НЕ делят тайминги (порчи и ESD
разные) — таблицы и параметры на 4.9 несём раздельно. Один нерешённый
байт: запись `*(u8*)(param+0xbc)=0x33` (offset 752) у jd9365 — за
пределами esd-таблицы нашего заголовка (в нашем layout это
switch_mode_enable); разобрать при порте (сдвиг stock-структуры +8
локализован хвостом ≥868, так что это может быть реально
switch_mode_enable=0x33 у стока — HYPOTHESIS, проверка: сверка с
jd9365-декомпиляцией структуры или игнор, поле не используется в
vdo-режиме).

### HYPOTHESIS к следующей загрузке

- H1: ядро дойдёт до init и логгера (проверка: `/data/forge/*` свежие).
- H2 (риск): SMP bring-up через mt-boot на 4.9 может отличаться от 3.18
  (в 3.18 `mt_psci` использует те же cpu_psci_ops+MTCMOS; ATF тот же).
  Фальсификация: в dmesg `CPU1: failed to boot` / зависание до logger.
- H3 (риск): `clk_buf`/`spm`-инициализация clkmgr-пути может залипнуть на
  ранней фазе (класс m681-проблем НЕ ожидается — clkmgr, не CCF; см. план
  §4 «рисков m681-типа нет»). Фальсификация: пустой /data/forge при живом
  last_kmsg с последней строкой в области spm/clkmgr.

