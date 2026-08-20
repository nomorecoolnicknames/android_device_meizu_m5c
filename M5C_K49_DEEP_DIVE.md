# M5C k49 (kernel 4.9) — глубокий анализ зависания на логотипе: полный пакет для внешнего анализа

Дата: 2026-08-20. Ветка ядра: `m5c-arm64` @ `479f6366d`.
Этот документ — самодостаточный пакет для анализа сильной моделью: контекст,
обе ветки ядра, вся доказательная цепочка, вся инструментация, все правки,
ранжированные гипотезы и точный запрос (в конце).

---

## 0. TL;DR — что сломано

Ядро 4.9.337 (MTK BSP k37mv1_bsp_k49, порт с Meizu M6/MT6750 на Meizu m5c/MT6737T)
**загружается далеко** (по косвенным признакам — живы кнопки kpd), но:

1. **USB не энумерится вообще** (ни adb, ни гаджет, ни даже preloader-подобных
   окон после старта ядра) — с момента включения `CONFIG_USB_G_ANDROID=y`
   (legacy-гаджет `/sys/class/android_usb/android0`, нужен рамдиску LOS 14.1);
2. **Экран навсегда остаётся на LK-логотипе** (дисплей в 4.9 пока не портирован —
   это отдельный известный фронт, НЕ симптом бага);
3. **Ни один механизм самосброса/дампа не срабатывает наблюдаемо**: WDT-дедлайны
   не дают видимого мигания логотипа, eMMC-зеркало маркеров не пишется;
4. Все DRAM-капчи (маркеры + ram console) после холодного выключения = `0xFF`
   (DRAM переинициализируется preloader'ом).

До включения legacy-гаджета то же ядро **доходило до userspace и энумерило USB**
(p30poll: хост видел `18d1:d001` через configfs-гаджет).

**Задача анализа:** объяснить, как включение legacy android-гаджета (код которого
инициализируется на `late_initcall`, ~6-15с) может давать картину «ноль USB +
нет ресетов + маркерные механизмы молчат», и предложить конкретный следующий
код/эксперимент.

---

## 1. Железо и бут-цепочка

- Устройство: **Meizu m5c**, SoC **MT6737T** (4×Cortex-A53 @1.3ГГц, Mali-T720),
  eMMC 16GB, PMIC MT6328, дисплей jd9365 (DSI), тач GT1151.
- Бут-цепочка: **preloader (BROM→PL) → LK (логотип, кнопки Vol+/Vol-) → kernel →
  LOS 14.1 ramdisk (Android 7.1)**.
- Телефон прошивается через TWRP adb: `dd of=/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/boot`.
- Возврат в TWRP: только ручной тёплый перехват **Vol+** в окне LK после ресета;
  долгий power (10-15с) = PMIC hard-off = **холодный** ресет = DRAM стирается.
- RTC spare-регистр FAC_RESET (механизм `reboot recovery`) ядро выставляет, но
  **LK по WDT-ресету в TWRP НЕ роутит** (проверено p29) — только ручной Vol+.
- UART нет. Вся обсervability — через: DRAM-маркеры (тёплые ресеты), ram console,
  pstore (пустой — известная проблема), expdb (eMMC, новый канал, писался в p36).

## 2. Два ядра

### 2.1. Эталон: 3.18.19 (stock, read-only)

- Путь: `/home/valakas/m5c/android_kernel_meizu_m5c` (master `a33114b6`,
  зеркало: github `nomorecoolnicknames/android_kernel_meizu_m5c-old`).
- Источник: официальный исходник Meizu (Flyme) для m5c. **Работает полностью**
  (Flyme сток); на нём же LOS 14.1 дошла до полного Android с adb
  (капча `captures/20260817-los-first-boot/`: props, `persist.sys.usb.config=adb`).
- Ключевые конфиги: `CONFIG_USB_G_ANDROID=y` (legacy-гаджет!), `CONFIG_CPU_IDLE=y`,
  `CONFIG_MTK_DISABLE_SODI=y`, `CONFIG_CPU_IDLE_GOV_MTK=y` (кастомный MTK-гавернор
  cpuidle, уважает `idle_switch[]`).
- Таймеры: `drivers/misc/mediatek/mach/mt6735/mt_gpt.c` (BSP-расположение),
  `mt_cpuxgpt.c` там же. `mt_gpt_set_next_event` = stop/cmp/start **без**
  переключения клока (см. §5.2).
- cpuidle: `drivers/cpuidle/cpuidle-mt6735.c`, 4 состояния (dpidle/SODI/slidle/
  rgidle), но выбор через `mt_idle_select` + `idle_switch[]` = {dp=1, so=0, sl=1, rg=1}
  для MACH_MT6735M.
- USB: legacy android.c инклюдит в свой TU: f_fs.c, f_audio_source.c, f_midi.c,
  f_mass_storage.c, f_adb.c, f_mtp.c, f_accessory.c, f_rndis.c, rndis.c, f_ecm.c,
  f_eem.c, u_ether.c — полностью self-contained, configfs-стэндэлоунов нет.

### 2.2. Порт: 4.9.337 (активная работа)

- Путь: `/srv/forge/android/m5c/kernel-m5c-4.9-lc`, ветка `m5c-arm64`.
- Происхождение: BSP `k37mv1_bsp_k49` (Meizu M6-эпохи, MT6750) + графт на arm64
  + сток-DTB m5c (байт-идентичный Flyme, md5 `e17a0910…`, конкатенируется к
  Image.gz; `CONFIG_BUILD_ARM_APPENDED_DTB_IMAGE`-стиль).
- Сборка: `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- Image.gz-dtb`,
  defconfig `arch/arm64/configs/m5c_defconfig`. Образ: `abootimg -u` на базе
  `boot_k16.img` (LOS), cmdline `bootopt=64S3,32N2,64N2 androidboot.selinux=permissive
  buildvariant=userdebug` (+`idle=poll` в poll-вариантах).
- **В дереве `-Werror`** (mediatek Makefile) — варнинги = ошибки.
- Что уже допортировано и ЗАКОММИЧЕНО в `m5c-arm64` (хронология):
  - `f7eaac260` deadman `MTK_WDT_DIAG_HARD` (WDT kick-тред);
  - P18-P22 серия маркеров + **`68e66c073` SIP ID фикс** (см. §5.1);
  - `0b19cb314` aee/mrdump выживание без minirdump + DT-compatibles под сток-2017;
  - `f94e2b320` msdc host id из node name (eMMC грузится) + маркеры 70-86;
  - `fdeb90897` accdet compatible + jd9365 битая ячейка таблицы;
  - `d13987dc9` (p29) таймстамп-маркеры hotplug/mtcmos + RTC FAC_RESET;
  - `4a6f5e61c` (p31) **legacy USB_G_ANDROID** + дедмэн kick-forever;
  - `0e496ca4a` (p32) **mt_gpt broadcast 32кГц фикс** (см. §5.2);
  - `da647555e` (p33) дедлайн 180с, отменяется `forge_userspace_alive`;
  - `4a5f59eea` (p34) дедлайн по счётчику циклов (120) + маркеры 102/103/104/105;
  - `a53493bc9` (p35) ISOLATION: таблица гаджета урезана до ffs+acm+mtp+ptp;
  - `44fe08f69`+`479f6366d` (p36/p36b) eMMC-зеркало маркеров в expdb.
- Офлайн-ветки портов (собраны, НЕ вмержены, ждут живого железа; worktrees в
  `/srv/forge/android/m5c/k49-worktrees/`): `forge/cam49` (s5k4h8/s5k5e8+DW9714),
  `forge/sensors49` (mc3410/akm09912/stk3x1x legacy hwmsen), `forge/conn49`
  (wmt/consys/gps/wlan-gen2/fm), `forge/gpu49` (mali r7p0, тот же DDK что 3.18),
  `forge/av49` (eccci1 модем + vdec/venc/jpeg), `forge/aud49` (mt_soc_v3).

## 3. LOS 14.1 сторона (что ждёт ядро)

- Дерево: `/srv/forge/android/m5c/los14.1-m5c-patched/` (device/meizu/m5c).
- `product/prop.mk`: `persist.sys.usb.config=mtp,adb` — **дефолтный конфиг USB**.
- `rootdir/root/init.mt6735.usb.rc`: пишет ТОЛЬКО в legacy-пути
  `/sys/class/android_usb/android0/*` (idVendor 0BB4, functions, enable).
  Никакого configfs-пути для adb нет → **без USB_G_ANDROID adb невозможен
  по построению**. Есть `on property:sys.usb.charging=yes → write
  /sys/class/udc/musb-hdrc/device/cmode 2` (musb UDC виден как musb-hdrc).
- На 3.18 этот рамдиск даёт рабочий adb (доказано первым бутом).
- На 4.9 с configfs-only (p30poll) рамдиск поднял **charging-only** гаджет
  `18d1:d001` (видимо, через какой-то configfs-фолбэк), adb не было.

## 4. Система маркеров и капч (как читать улики)

### 4.1. DRAM-маркеры (forge_kmark)

- Код: `arch/arm64/kernel/setup.c:276/295` (`forge_kmark`, `forge_kmark_ptr`).
- Две страницы DRAM: **0x7f000000** (A) и **0xb0000000** (B), магия "FORGE49\0",
  слот ms по смещению `8+8*ms`, значение = sched_clock нс (или произвольное u64
  для `_ptr`). Запись + `__flush_dcache_area` (переживает виз CPU, читается из
  TWRP через `/dev/mem` — видит DRAM).
- Снятие из TWRP: `dd if=/dev/mem bs=1024 skip=2080768 count=1` (A),
  `skip=2883584` (B). Ram console: `skip=1556480 count=64` (0x5f000000, 64КБ).
- **Переживают только ТЁПЛЫЙ ресет** (WDT/panic). Холодный PMIC-off → всё `0xFF`.
- Карта слотов (актуальная):
  - 10-16: ранние milestones init/main.c; 31/32: pre-smp окно; 33-46: workqueue/kthread
    бисекция (P15-P16); 39/40: скобки вокруг тика; 70/71: DVFS; 72: PTP;
    73: musb_gadget pullup; 75/76/78: msdc; 77: **USB heartbeat (50мс hrtimer)**;
    80: usb_gadget_connect; 81/82: mt_usb_enable/disable; 83/84: musb_start/stop;
    85: cpu_die; 86/87: mtcmos вход/выход; 88/89/90: cpu_boot скобка;
    91/92/93: cpu_down/cpu_up/выход; 95: **deadman loops** (loops | now_s<<32);
    96+cpu: **per-CPU пульс** (tick-sched, 128 тиков); 100: **GPT IRQ счётчик**;
    101: **gpt set_next_event cycles**; 102/103: **android_init вход/err**;
    104: **deadman стартанул**; 105: **deadman дедлайн сработал**.

### 4.2. Дедмэн (WDT)

- `drivers/watchdog/mediatek/wdt/mt6735/mtk_wdt.c`, под `CONFIG_MTK_WDT_DIAG_HARD=y`.
- `postcore_initcall(mtk_wdt_init)` → probe ~2-4с; таймаут WDT 30с
  (`mtk_wdt_set_time_out_value(30)`), кик-тред `forge_deadman_fn` каждую ~1с.
- RTC FAC_RESET марк на 3с, снятие на 15с; дедлайн `loops>=120 &&
  !forge_userspace_alive` → перестаёт кикать → WDT ресетит ~через 30с.
- `forge_userspace_alive` выставляется в `enable_store` android.c (запись
  userspace в android0/enable) — «здоровый бут» отменяет дедлайн.
- p36b: тред зеркалит маркеры+rc49 в eMMC expdb (mmcblk0p10, 10МБ) через
  `blkdev_get_by_dev(MKDEV(179,10))` + `submit_bio_wait` каждую секунду.

## 5. Доказательная цепочка (что уже доказано/опровергнуто)

### 5.1. P18–P22: системный счётчик стоял — SIP ID не бились со сток-ATF (РЕШЕНО)

- P18 FACT: ни одного таймерного тика за загрузку (jiffies заморожены,
  `arch_timer_handler_phys` = 0 вызовов), вис в первом же таймерном сне
  (`kthread_bind_mask` → `wait_task_inactive` → `schedule_hrtimeout`).
- P19 FACT (регистры из живого виза): `CNTPCT_EL0=0` (счётчик СТОИТ),
  `CNTP_CTL=1` (enable), `CNTP_CVAL=52000` (запрограммирован),
  `GICD_ISENABLER0`: биты 29/30 = 1 (PPI размаскированы). Т.е. компаратор
  запрограммирован, IRQ разрешён, но **счётчик не идёт** → IRQ не генерируется.
- ROOT CAUSE: включение cpuxgpt идёт через `mt_secure_call(MTK_SIP_KERNEL_MCUSYS_WRITE,…)`
  в ATF; в Q0-BSP SIP-диапазон перенумерован, а ATF на устройстве стоковый (2017).
  Таблица перенумерации (Q0 → сток):
  `MCUSYS_WRITE 0x82000287→0x82000201`, `MCUSYS_ACCESS_COUNT 0x82000288→0x82000202`,
  `L2_SHARING 0x82000286→0x82000203`, `WDT 0x82000200→0x82000204`,
  `GIC_DUMP 0x82000201→0x82000205`, `DAPC_INIT 0x8200026E→0x82000206`,
  `EMIMPU_WRITE 0x82000260→0x82000207`, `EMIMPU_READ 0x82000261→0x82000208`,
  `EMIMPU_SET 0x82000262→0x82000209`, `MSG 0x82000214→0x820002ff`.
  Фикс `68e66c073` — после него счётчик идёт, тики работают, ядро грузится дальше.
- P23: eMMC ожила (msdc host id), вис переместился в Android init (~4.6с).

### 5.2. Вис 4.6с = tick-broadcast mt_gpt на 32кГц (фикс написан, НЕ прогнан)

- P29 FACT (маркеры, валидная капча `captures/20260818-49-p29/`): все скобки
  hotplug/mtcmos (85-93) закрыты, последний hotplug 2.15с; CPU1-3 легально
  запаркованы (0.40/1.13/2.05с); **CPU0 последний пульс 4.704с, USB-heartbeat
  (50мс) остановился** → CPU0 уснул в NO_HZ idle и не проснулся.
- Анализ: сток-DTB arch_timer node БЕЗ `always-on` → `arch_timer_c3stop=true`
  → nohz-CPU в idle передаёт тики broadcast-девайсу = mt-gpt (apxgpt@10004000,
  IRQ 184 = SPI 0x98, триггер 0x08).
- 4.9 `drivers/clocksource/mt_gpt.c` пришёл из mt6580-BSP: его
  `mt_gpt_clkevt_next_event()` программирует compare в 13МГц-циклах, а потом
  **переключает GPT на 32.768кГц RTC-источник**. Клокивент зарегистрирован с
  freq=13МГц (DT clock-frequency=0xc65d40) → каждый broadcast-дедлайн растянут
  ~397× (13e6/32768): 50мс hrtimer стреляет через ~20с → CPU0 «мёртв» с первого
  настоящего idle. 3.18-сток такого переключения НЕ делает (stop/cmp/start на
  SYS), SODI на m5c выключен (`idle_switch[SO]=0`) — 32кГц не нужен.
- Фикс `0e496ca4a`: убран RTC-свитч. **На железе не проверен** — регрессия
  гаджета (§6) перекрыла прогон.

### 5.3. Что работало на железе (матрица образов)

| Образ | База | cmdline | Гаджет | Результат |
|---|---|---|---|---|
| p29 (`d13987dc9`) | +маркеры | сток | configfs | дошёл до 4.6с, вис (idle-wake), маркеры валидны |
| p30poll | p29+дедмэн v3 | idle=poll | configfs | **дошёл до init, USB энумерился `18d1:d001`** (charging-only) |
| p30v2poll | то же +дедлайн 20с | idle=poll | configfs | цикл preloader↔gadget (дедлайн работал!) |
| p31poll (`4a6f5e61c`) | +USB_G_ANDROID | idle=poll | **legacy** | **ноль USB, статик-лого, кнопки ЖИВЫ** |
| p32 (`0e496ca4a`) | +mt_gpt фикс | сток | legacy | ноль USB, статик-лого, кнопки мертвы(?) |
| p33 (`da647555e`) | +дедлайн 180с | сток | legacy | ноль USB, дедлайн НЕ моргнул за 5 мин |
| p34poll (`4a5f59eea`) | +дедлайн 120 loops | idle=poll | legacy | ноль USB; телефон вернулся в TWRP ~200с (дедлайн, видимо, сработал; капча съедена холодным off) |
| p35poll (`a53493bc9`) | adb-only таблица | idle=poll | legacy min | НЕ прошит (adb отвалился до заливки) |
| p36bpoll (`479f6366d`) | +eMMC-зеркало | idle=poll | legacy | ноль USB; preloader-вспышки t=40с и t=50с (два разных device number!), потом тишина; **зеркало НЕ записало** (expdb = старый AEE-дамп + нули) |

### 5.4. Парадоксы, которые надо объяснить

1. **Кнопки живы** (по наблюдению юзера на p34poll: «щя хотя бы на кнопки
   реагирует») → ядро доходит минимум до input/PMIC-IRQ (device_initcall+),
   т.е. НЕ висит рано. Но USB не энумерится и на configfs-образах после p31
   больше не проверяли — может, регресс не в legacy-гаджете, а в чём-то ещё
   из коммита p31 (Kconfig.default/Kconfig/.config дельта)?
2. **Дедлайны не дают видимого ресета** (p33: 180с по sched_clock; p34: 120
   циклов). Если дедмэн-тред жив (а с idle=poll CPU0 не спит) — на 120-й итерации
   кики прекращаются → WDT 30с → тёплый ресет → LK перерисовывает логотип =
   видимое мигание. Юзер мигания не видел. Варианты: (а) тред не бежит
   (вис до postcore_initcall ~2с — но тогда кнопки бы не жили); (б) тред висит
   на `rtc_forge_mark_recovery(1)` на 3с (PMIC i2c вис? — но в p29 тот же вызов
   был); (в) WDT вообще не ресетит (но в p30v2poll цикл был!); (г) тёплый ресет
   НЕ перерисовывает логотип (LK на warm-boot не трогает дисплей → «мигания»
   не существует как явления → все модели «нет мигания = нет ресета» неверны!).
3. **eMMC-зеркало не пишется** (p36b): ни filp_open-вариант (нет /dev ноды до
   init — ожидаемо), ни blkdev_get_by_dev-вариант. Либо дедмэн-тред не бежит,
   либо падает в mirror (submit_bio_wait виснет/паника → panic_timeout=1 → ресет
   → возможно, те самые preloader-вспышки t=40/50с = паник-луп!), либо
   `blkdev_get_by_dev(MKDEV(179,10))` вечно возвращает -ENXIO (партиции ещё не
   отсканированы / msdc в 4.9 живёт на другом major:minor?).
4. **preloader-вспышки t=40с и t=50с** в p36b: два разных device number за 10с =
   два ресета подряд с интервалом ~10с — слишком быстро для 30с-WDT от старта
   ядра; похоже на **panic-луп** (PANIC_ON_OOPS=y, PANIC_TIMEOUT=1): паника на
   ~5-8с → 1с → ресет. Чем паника? Кандидат №1 — мой mirror-код в дедмэн-треде
   (единственная дельта p34→p36b).

## 6. Legacy-гаджет: все правки (p31, `4a6f5e61c`)

Контекст: в Q0-дереве `USB_G_ANDROID` никогда не компилировался (был выкл) —
код полусгнивший. Рамдиску нужен именно он (`/sys/class/android_usb/android0`).

1. `.config`/`m5c_defconfig`: `CONFIG_USB_G_ANDROID=y`; выкл configfs-функции
   (F_MTP/F_PTP/F_ACC/F_AUDIO_SRC/F_MIDI/F_FS) — иначе стэндэлоун-объекты
   (usb_f_mtp.o и т.д.) дают multiple definition с копиями, которые android.c
   инклюдит в свой TU (`#include "f_mtp.c"` и т.д.).
2. `drivers/misc/mediatek/Kconfig.default`: убраны `select USB_CONFIGFS_F_*`
   (они силой возвращали configfs-функции через olddefconfig).
3. `drivers/usb/gadget/Kconfig`: `USB_G_ANDROID` += `select USB_U_ETHER`
   (gether_* из u_ether.o для rndis/eem), −= `select USB_F_AUDIO_SRC`
   (нужен ALSA, CONFIG_SND off в этой ветке; рамдиск audio_source не использует).
4. `android.c`:
   - `#include "u_ether.c"` → `u_ether.h`+`u_ether_configfs.h` (u_ether.o теперь
     стэндэлоун и линкует gether_*);
   - `create_function_device` → `static android_lookup_function_device` + fwd-decl
     (configfs.c экспортирует одноимённую функцию с ДРУГОЙ семантикой — создание
     vs поиск); вызовы из f_mtp.c/f_midi.c перенаправлены;
   - `trigger_android_usb_state_monitor_work` → static (у meta.c свой глобал);
   - убраны дубли `cpumask_to_int`/`cpu_mask_show/store`/`mtp_server_show`/
     `mtp_function_attributes` (каноничные — в f_mtp.c);
   - `__maybe_unused` на mtp_setup/mtp_bind_config/acc_bind_config;
   - p33+: `int forge_userspace_alive` (export), ставится в `enable_store`;
   - p34+: маркеры 102 (перед `usb_composite_probe`) / 103 (после, =err);
   - p35: `supported_functions[]` урезана до ffs/acm/mtp/ptp (остальные struct'ы
     `__maybe_unused`).
5. Активный init: `late_initcall(init)` (ветка `#else` по CONFIG_USBIF_COMPLIANCE,
   который не задан): class_create → kzalloc android_dev → `android_create_device`
   → `usb_composite_probe(&android_usb_driver)` → HACK с composite_setup_func.

Известные риск-зоны: f_fs (adb) legacy-путь в 4.9 (functionfs с workqueue),
gethер-стек без инклюда u_ether.c, musb UDC-аттач на буте (configfs откладывал
его до userspace-записи, legacy делает сразу в probe).

## 7. Ранжированные гипотезы (текущее состояние)

- **H1. Паника в моём mirror-коде (p36b) / в probe гаджета (p31+)** → panic-луп,
  логотип «статичен» потому что тёплый ресет его не перерисовывает. FOR:
  preloader-вспышки 10с apart; PANIC_TIMEOUT=1; кнопки живы (ядро доходит далеко
  до паники). AGAINST: p31poll (без mirror) юзер мигания тоже не видел; дедлайн
  p34 вроде сработал один раз (~200с).
- **H2. Вис в `usb_composite_probe` → musb/PHY/клок-ожидание** на буте (legacy
  аттачит UDC сразу; configfs откладывал до userspace). FOR: ноль USB — даже
  charging-гаджет не поднялся, хотя в p30poll поднимался; дедмэн жив (кнопки,
  кики) но дедлайн... AGAINST: дедлайн p33/p34 должен был ресетить — не видно.
- **H3. Вис РАНЬШЕ wdt_probe (~2с), дедмэн не существует, WDT не armed** →
  вечный статик-лого. AGAINST: кнопки живы (input — поздний init). UNLESS
  «кнопки живы» = артефакт наблюдения (подсветка от LK?).
- **H4. sched_clock/таймеры сломаны снова** (не SIP — а что-то из p31+ дельты) →
  msleep(1000) вечен → дедмэн не считает → нет дедлайна, нет зеркала. AGAINST:
  кнопки живы (IRQ-таймеры работают), p30poll на той же базе грузился.
- **H5. Регресс вообще не в гаджете**, а в config-дельте p31 (configfs-функции
  выкл): например, что-то в раннем буте зависело от configfs-объектов. AGAINST:
  трудно представить механизм.

## 8. Что предлагается сделать (мои следующие шаги до обращения к модели)

1. p37: panic_notifier → тот же expdb-дамп (паника = тёплый ресет, маркеры
   выживают + дамп на eMMC); mirror стартует с 10-го цикла (block layer точно
   готов), defensive null-checks; маркер 106 = «зеркало успешно записало».
2. Отдельно: прогнать p32-фикс mt_gpt БЕЗ гаджета (выкл USB_G_ANDROID,
   configfs обратно) — проверить, что idle-wake починен и бут доходит до
   configfs-энумерации без idle=poll. Это закрывает вопрос «таймер vs гаджет»
   окончательно.
3. Если гаджет подтвердится убийцей: бисект функций (p35 уже урезан до
   ffs/acm/mtp/ptp — прошить и проверить), затем маркеры внутри
   android_init_functions (по одному на function .init).

## 9. Файлы-артефакты

- Ядро 4.9: `/srv/forge/android/m5c/kernel-m5c-4.9-lc` (HEAD `479f6366d`).
- Сток 3.18 (read-only): `/home/valakas/m5c/android_kernel_meizu_m5c`.
- Стейт: `device/meizu/m5c/BRINGUP_STATE.md` (секции P15–P32 + ночные порты).
- Матрица компонентов: `device/meizu/m5c/M5C_COMPONENT_MATRIX.md`.
- Капчи: `device/meizu/m5c/captures/2026081*/` (p18-p29 валидные; p32+ — съедены
  холодными ресетами, отсюда eMMC-зеркало).
- Рамдиск USB: `device/meizu/m5c/rootdir/root/init.mt6735.usb.rc`.
- Образы и скрипты сборки: scratchpad `mk_boot49.sh`, `bootimg_k16.cfg`/
  `bootimg_p31.cfg` (idle=poll), `dtb_stock.dtb` (md5 e17a0910…), `boot_k16.img`.

---

## 10. ЗАПРОС ДЛЯ МОДЕЛИ (копировать вместе с этим документом)

Ты — сильнейший kernel/Android-BSP инженер. Вложен документ
`M5C_K49_DEEP_DIVE.md` — полная история порта kernel 4.9 (MTK BSP) на Meizu m5c
(MT6737T) с доказательной цепочкой. Прочти его целиком.

Сейчас ядро зависает/недоступно так: после включения legacy-гаджета
`CONFIG_USB_G_ANDROID` (коммит p31) телефон показывает вечный LK-логотип,
USB не энумерится ВООБЩЕ (хост не видит ничего после старта ядра), кнопки
питания/громкости ЖИВЫ (по наблюдению), WDT-дедлайны не дают видимого ресета,
eMMC-зеркало маркеров не пишется, DRAM-капчи съедаются холодными ресетами.
До этого коммита то же ядро доходило до userspace и энумерило USB (configfs).

Твоя задача:
1. Разбери парадоксы из §5.4 — особенно: как late_initcall-код может дать
   «ноль USB + нет наблюдаемых ресетов + молчат все дампы», и почему могут
   не срабатывать WDT-дедлайны при живых кнопках. Учти, что тёплый WDT-ресет
   может НЕ перерисовывать логотип (проверь это предположение по коду LK/
   дисплейной цепочки, если сможешь).
2. По коду путей (я дам дерево или конкретные файлы по запросу): найди
   конкретные места, где legacy android.c / musb / u_ether / f_fs в 4.9 могут
   виснуть или паниковать на буте именно в этой конфигурации (musb-hdrc UDC,
   MT6735 PHY, без configfs-функций). Особое внимание: usb_composite_probe →
   bind → android_init_functions → f_fs_init в 4.9; gether_setup без
   `#include "u_ether.c"`; probe-time UDC attach против configfs deferred attach.
3. Объясни, почему `blkdev_get_by_dev(MKDEV(179,10))` + submit_bio_wait из
   kthread'а могло не записать ни байта (паника? -ENXIO навсегда? блокировка?),
   и как сделать eMMC-дамп пуленепробиваемым (включая panic_notifier).
4. Предложи минимальный набор ТОЧНЫХ экспериментов (код + какие маркеры/логи
   читать), который за 1-2 прошивки локализует причину. Приоритет — варианты,
   дающие информацию даже при полном отсутствии USB/дисплея/сети.
5. Если найдёшь вероятный баг — дай конкретный патч (файл, строки, код).

Не предлагай: «выключи всё лишнее» широкими списками, fake-ready заглушки,
переход на configfs-рамдиск (рамдиск трогать нельзя — он общий со сток-3.18),
или «купи UART». Дисциплина: FACT/INFERENCE/HYPOTHESIS разделять явно.

---

## 11. АНАЛИЗ 2026-08-20 (Fable 5, сессия m5c): root cause p31–p34 найден в коде

Все ссылки — на дерево `kernel-m5c-4.9-lc` @ `479f6366d`.

### 11.1. BUG A: audio_source не может проинициализироваться ни на одном p31–p34 буте

- FACT: в `.config` НЕТ `CONFIG_USB_F_AUDIO_SRC` (p31 снял `select`, т.к. нужен ALSA;
  `f_audio_source.c` в android.c НЕ инклюдится; standalone `usb_f_audio_source.o`
  не собирается — `function/Makefile:53-54`). Никто не регистрирует usb-функцию
  `"audio_source"`.
- FACT: в ПРОШИТЫХ билдах p31–p34 (`git show 4a5f59eea`) `supported_functions[]`
  содержит `&audio_source_function` (таблицу урезал только p35).
- FACT: `audio_source_function_init` (android.c:1623) →
  `usb_get_function_instance("audio_source")` → -ENOENT. `f->config` при этом
  НЕ присваивается (остаётся NULL), локальный kzalloc течёт.
- INFERENCE: `request_module("usbfunc:audio_source")` не виснет: /sbin/modprobe
  в рамдиске нет, exec быстро фейлится.

### 11.2. BUG B: unwind после ошибки init крашит ядро (oops в kernel_init)

Цепочка (FACT по коду):
1. `android_init_functions` (android.c:1846): err → `err_out:
   device_destroy(f->dev)` — указатель `f->dev` НЕ обнуляется; `err_create:
   kfree(f->dev_name)` — тоже не обнуляется.
2. `android_bind` → err → `composite_bind` (composite.c:2293) → `fail:
   __composite_unbind` → `android_usb_unbind` (android.c:2460) →
   `android_cleanup_functions` по ВСЕЙ таблице.
3. Для audio_source: `if (f->dev)` — dangling → чтение `f->dev->devt` из
   освобождённой памяти (UAF) + ПОВТОРНЫЙ `kfree(f->dev_name)` (double free);
   затем `audio_source_function_cleanup` (android.c:1646): `config == NULL` →
   `config->f_aud` → **разыменование NULL → oops**. Контекст: kernel_init
   (PID 1), late_initcall, маркер 102 уже стоит, 103 НЕ будет никогда.

### 11.3. BUG C: oops в этом окне = ВЕЧНЫЙ silent hang, а не ребут

- FACT: arm64 die() → notify_die → `ipanic_die`
  (aee/ipanic/ipanic_rom.c:170; CONFIG_MTK_AEE_IPANIC=y) → пишет oops-дамп в
  ram console/aee sram → `aee_exception_reboot()` (aee-common.c:367).
- FACT: `aee_exception_reboot` → `get_wd_api()`; `g_wd_api_obj.ready`
  выставляется только в `wd_api_init()`, который зовётся из `wdk_work_callback`
  (wd_common_drv.c:884) — workqueue, запланированная из `init_wk` =
  late_initcall в drivers/watchdog/. А drivers/usb/ линкуется РАНЬШЕ
  (drivers/Makefile:105 vs 118) → на момент oops из USB-init `get_wd_api` = -2 →
  ветка `while (1) cpu_relax();` (aee-common.c:378) — **вечный спин, ребута НЕТ**.
- INFERENCE: IRQ остаются включёнными, остальные CPU и нити живут → дедмэн
  продолжает кикать WDT как ни в чём не бывало.

### 11.4. Как это объясняет ВСЮ матрицу §5.3 и парадоксы §5.4 (INFERENCE на FACT-базе)

| Образ | Модель |
|---|---|
| p31poll | oops@~7-10с → вечный спин; дедмэн p31 = kick-forever → WDT НИКОГДА не сработает → вечный логотип, ноль USB, ни одной preloader-вспышки. Совпадение 1:1. |
| p33 | тот же oops; дедлайн 180с (sched_clock) → кики стоят на 180с → WDT-ресет ~210с → цикл ~220с. Тёплый ресет визуально не меняет логотип → «не моргнул за 5 мин». |
| p34poll | дедлайн 120 циклов ≈ 125с + 30с WDT → ресет ~155с; юзер с Vol+ поймал TWRP ~200с ✓. |
| p36b | таблица УЖЕ урезана (p35 в предках) → BUG A/B не применимы. ОТКРЫТ (см. 11.6). |

Парадоксы:
- «Кнопки живы» — long-press power = аппаратный PMIC hard-off, Vol+ ловит LK
  после ресета. Оба работают при полностью мёртвом ядре. Наблюдение не несёт
  информации о ядре (FACT о природе механизмов).
- «Нет мигания = нет ресета» — ложная посылка. LK-исходников в дереве нет
  (проверить redraw-код нельзя), но p30v2poll-цикл юзер обнаружил ПО USB, а не
  по логотипу → тёплые ресеты эмпирически незаметны на экране (INFERENCE).
- «Дампы молчат» — ipanic УСПЕВАЕТ записать oops в rc49 (0x5f000000) до спина.
  Тёплая капча rc49 из TWRP должна показать бэктрейс
  `audio_source_function_cleanup → android_cleanup_functions →
  __composite_unbind → usb_composite_probe`. Это ГЛАВНАЯ проверка гипотезы.

### 11.5. Ловушка-мина: все forge-окна — обычная выделяемая память

- FACT: сток-DTB memory node = 0x40000000 + 0x1f000000 (496МБ, конец РОВНО на
  0x5f000000), но p29-факт (маркеры по 0x7f000000/0xb0000000 пишутся через
  phys_to_virt и читаются) доказывает: LK отдаёт реальные ~2ГБ, окна в linear map.
- FACT: НИ setup.c, НИ mtk_ram_console.c не делают memblock_reserve для
  0x5f000000 (rc 64К + pstore 0xe0000 по 0x5f010000), 0x7f000000, 0xb0000000 →
  все эти страницы лежат в buddy-аллокаторе как свободные.
- INFERENCE: ram console непрерывно пишет 64К, forge_kmark — 1К×2 (heartbeat 77
  каждые 50мс!) в память, которую аллокатор может отдать кому угодно. Ранний бут
  (<100-150МБ, раздача с верхних адресов) обычно не задет, но полный Android-бут
  дойдёт и до 0x7f000000, и до 0x5f000000 → случайная коррапция. Фикс P4
  обязателен ДО любых «странных» падений в userspace.

### 11.6. p36b: открыт; почему зеркало молчало

- FACT: MKDEV(179,10) корректен (CONFIG_MMC_BLOCK_MINORS=32, EFI_PARTITION=y,
  GPT тот же → p10=expdb). -ENXIO-навсегда исключён.
- FACT (дефекты кода зеркала): (а) `forge_write_at` игнорирует возврат
  `submit_bio_wait` — тихие EIO невидимы; (б) зеркало сидит В ТОЙ ЖЕ нити, что
  кикает WDT → любой затык submit_bio_wait = стоп киков = WDT-ресет через 30с,
  диагноз спутан; (в) rc49 читается через КЭШИРУЕМЫЙ linear-алиас, а ram_console
  пишет через некэшируемый vmap → риск чтения стейла; (г) паник/дай-хука нет.
- HYPOTHESis-ранжирование для «вспышек t=40/50с»: H1 зеркало открылось на ~5-8с
  и повисло в submit_bio_wait → кики встали → WDT-ресет ~35-40с (t=40 ✓), второй
  цикл умер иначе/быстрее (t=50); ПРОТИВ: третьей вспышки не было. H2 ffs-гейтинг:
  бут жив, enable=1 при неоткрытом ffs → нет pullup пока adbd не запишет
  дескрипторы; ноль USB при живом ядре; ПРОТИВ: не объясняет вспышки и молчание
  зеркала. H3 коррапция из 11.5. Разрешается p37 (слоты 106/111-114).

### 11.7. p37 — одна прошивка, закрывающая всё (патчи P1–P5)

**P1 android.c (обязателен):** в `android_init_functions` err-путях обнулить
указатели; guard в audio_source cleanup:
```c
 err_out:
 	device_destroy(android_class, f->dev->devt);
+	f->dev = NULL;
 err_create:
 	kfree(f->dev_name);
+	f->dev_name = NULL;
 	return err;
```
```c
 static void audio_source_function_cleanup(struct android_usb_function *f)
 {
 	struct audio_source_function_config *config = f->config;
+	if (!config)
+		return;
```
(Таблицу оставить урезанной p35: ffs+acm+mtp+ptp. audio_source в неё НЕ
возвращать, пока не появится ALSA.)

**P2 aee-common.c (обязателен):** убить вечный спин:
```c
 	if (res < 0) {
 		pr_info("arch_reset, get wd api error %d\n", res);
+		/* forge p37: wd_api готов только после wdk workqueue
+		 * (late_initcall + schedule). Исключение раньше этого
+		 * зависало тут навечно: ни ребута, ни дампа. PSCI-ресет
+		 * стокового ATF доступен с early boot. */
+		emergency_restart();
 		while (1)
 			cpu_relax();
 	}
```
(psci.c:572 ставит `arm_pm_restart = psci_sys_reset` рано; стандартный
PSCI SYSTEM_RESET — не MTK SIP, стоковый ATF его обслуживает: FACT для
cpu_on/off по p29, INFERENCE для system_reset.)

**P3 mtk_wdt.c:** die/panic-нотификаторы (слоты 107-110, приоритет INT_MAX —
раньше ipanic_die) + зеркало в ОТДЕЛЬНОЙ нити + слот 106:
```c
#include <linux/kdebug.h>
static int forge_die_cb(struct notifier_block *nb, unsigned long cmd, void *p)
{
	struct die_args *a = p;

	forge_kmark_ptr(107, 0xD1E0000 | (cmd & 0xffff));
	if (a && a->regs) {
		forge_kmark_ptr(108, a->regs->pc);
		forge_kmark_ptr(109, a->regs->regs[30]);
	}
	return NOTIFY_DONE;
}
static struct notifier_block forge_die_nb = {
	.notifier_call = forge_die_cb, .priority = 0x7fffffff };
static int forge_panic_cb(struct notifier_block *nb, unsigned long ev, void *p)
{
	forge_kmark_ptr(110, (unsigned long)p); /* msg ptr; факт паники */
	return NOTIFY_DONE;
}
static struct notifier_block forge_panic_nb = {
	.notifier_call = forge_panic_cb, .priority = 0x7fffffff };
/* в probe: register_die_notifier(&forge_die_nb);
 * atomic_notifier_chain_register(&panic_notifier_list, &forge_panic_nb); */
```
Ключевое свойство: слоты ≥106 здоровый бут никогда не штампует → они переживают
ЛЮБОЕ число тёплых циклов до первого холодного off. Зеркало: `forge_write_at`
возвращает статус; отдельная нить `forge_mirror_fn` (kthread из probe), дедмэн
только кикает; после каждой попытки `forge_kmark_ptr(106, (ok<<32)|(-err))`.

**P4 setup.c (обязателен):** после `arm64_memblock_init()`:
```c
	/* forge: окна маркеров/rc/pstore — вывести из buddy-аллокатора */
	memblock_reserve(0x5f000000, 0x100000);
	memblock_reserve(0x7f000000, PAGE_SIZE);
	memblock_reserve(0xb0000000, PAGE_SIZE);
```
и там же (конец setup_arch) копия предыдущей страницы A:
`memcpy(phys_to_virt(0x7f000400), phys_to_virt(0x7f000000), 0x400)` + flush —
история умершего бута переживает перештамповку новым.

**P5 android.c (маркеры userspace-прогресса):**
- `functions_store` вход: `u64 v=0; memcpy(&v, buff, min(sizeof(v), size));
  forge_kmark_ptr(111, v);` (увидим «mtp,adb» как ASCII);
- `enable_store`: `forge_kmark_ptr(112, enabled);`
- `functionfs_ready_callback`: `forge_kmark(113);`
- `android_enable` перед `usb_gadget_connect`: `forge_kmark(114);`

**Чтение (TWRP, тёплый Vol+ после ~4 мин):** страница A (`dd if=/dev/mem
bs=1024 skip=2080768 count=1`), rc49 (`skip=1556480 count=64`), expdb.
Decision table:
| Наблюдение | Вывод |
|---|---|
| 102 есть, 103 нет, 107/108 есть | oops внутри probe; PC/LR по System.map = имя виновника (при урезанной таблице НЕ ожидается) |
| 103=0, 111 нет | ядро живо/умерло позже — смотреть пульсы 95/96 и 107; init не дошёл до usb rc |
| 111=«mtp,adb», 112=1, 113 нет | ядро чисто; adbd/functionfs не открыл ep0 — фронт userspace |
| 113 и 114 есть, хост молчит | инструментировать musb (расширить слот 77 байтом MUSB_POWER) — прошивка №2 |
| 106 hi>0 | зеркало пишет → конец капча-лотереи; если hi=0 — lo=errno |
| rc49 содержит oops-бэктрейс | прямое подтверждение 11.2 (для p31-p34-стиля) |

**Прошивка №2** (только после чистой №1): тот же бинарь со сток-cmdline (без
idle=poll) — валидация p32 mt_gpt фикса: пульсы 95/96 продолжаются после
первого idle → фикс верен; замирают на ~5с → фикс неверен (данные всё равно
соберутся через 106/107).

### 11.8. Ответ на вопрос §3 (blkdev_get_by_dev / submit_bio_wait)

`blkdev_get_by_dev(MKDEV(179,10))` до завершения GPT-скана (mmc_rescan —
асинхронная workqueue, ~3-8с) возвращает -ENXIO — ретраи в коде корректны.
Номер (179,10) верен (MINORS=32; boot0/boot1/rpmb — отдельные gendisk со
своими минорами, нумерацию p10 не сдвигают). На p31–p34-модели зеркала ещё не
было; на p36b нулевая запись объясняется либо H1 (повис в submit_bio_wait —
киков нет — ресет на 30-й секунде раньше первой успешной записи… при этом
`forge_write_at` глотает ошибки), либо смертью бута до скана. Паник-запись в
eMMC из panic-контекста НЕ делать (block layer мёртв); вместо этого: паника →
слоты 107-110 в DRAM (дёшево, не может отказать) → тёплый ресет → следующий
бут зеркалит DRAM в expdb, как только блок-слой поднялся. Это и есть
«пуленепробиваемо»: запись на eMMC всегда выполняется ЗДОРОВОЙ фазой
следующего бута, а не умирающей.


### 11.9. p37 — исполнение (2026-08-20, лайв-сессия)

- Ядро: `m5c-arm64` @ `75d761e44` (p37: P1–P5 из §11.7 + ERR_PTR-гигиена
  ffs/acm/audio_source, зеркало отдельной нитью, слоты 106–114,
  `forge_preserve_prev`, memblock_reserve окон, `emergency_restart()` вместо
  `while(1)` в `aee_exception_reboot`). Сборка чистая (0 ошибок/варнингов в
  затронутых файлах), System.map сохранён как `System.map-p37`.
- Образ: `boot_49_p37poll.img` (md5 `220a2807c2c0bc363c0fe0a1b946db16`),
  Image.gz+сток-DTB (`e17a0910…`), cmdline p31 (idle=poll), база boot_k16.
- FACT (девбокс, TWRP): `expdb -> mmcblk0p10` — MKDEV(179,10) подтверждён на
  железе; expdb offset 0 = старый AEE-заголовок `adde e0ae`, «FORG» нет →
  p36b-зеркало не записало ни байта (подтверждено). Бэкапы до прошивки:
  `expdb_pre_p37.bin` (md5 `e7e9aee2…`), `boot_pre_p37.img` (`c7fca7d6…`),
  лежат в scratchpad `p37cap/`.
- Прошивка: dd в mmcblk0p7 через TWRP adb (девбокс), верификация ПОБАЙТНО
  (`cmp -n 9459712`) = OK. Ловушка: два md5-замера частичного чтения через
  toybox dd дали РАЗНЫЕ суммы при идентичном содержимом — на TWRP доверять
  только полному pull+cmp, не `dd bs=… | md5sum`.
- Ребут в 16:23:12. Новая карта слотов p37: 106=(зеркало ok<<32)|errno;
  107=die(cmd), 108=PC, 109=LR, 110=panic; 111=functions_store (8 симв.),
  112=enable, 113=ffs ready, 114=pullup. Чтение страницы A: `dd if=/dev/mem
  bs=1024 skip=2080768 count=2` (вторая КБ = копия предыдущего бута).

### 11.10. РЕЗУЛЬТАТ p37 (2026-08-20 16:23–16:28): зеркало сработало, найден ИСТИННЫЙ первый блокер

Прогон: p37poll прошит (верифицирован побайтно), ребут 16:23:12, телефон САМ
вернулся в TWRP ≈16:27 (≈200с). DRAM-страницы после этого ребута = 0xFF
(этот тип ресета DRAM не сохранил), **но eMMC-зеркало отработало**: expdb
offset 0 = FORGE49-слоты умершего бута, offset 1КБ = prev-копия (p36b!),
offset 1МБ = rc49 (DBGC, хвост printk-лога до ~196.7с). Капча-лотерея закрыта.

FACT (слоты LIVE-блока):
- вехи 1–46 пройдены; slot 95: loops=120, now_s=121 — дедмэн отработал ВСЕ
  120 циклов, sched_clock жив; slot 105: дедлайн сработал; slot 106:
  **ok=197, errno=0** — 197 успешных записей зеркала;
- **102/103 НЕТ** — `usb_composite_probe` даже не начинался;
- **107–110 НЕТ** — ни oops, ни panic за все ~197с;
- **111–114 НЕТ** — userspace не написал ни functions, ни enable;
- slot 19 (текущий initcall) = `ram_console_early_init` — артефакт ранней
  фазы, не показатель зависшего initcall.

FACT (rc49-лог, хвост 144–196.7с): **userspace ЖИВ** — healthd (pid 172),
init, bat_routine, pmic_thread; `[MUSB]do_connection_work: !is_ready,
retrigger after 50 ms` каждые 50мс — musb вечно ждёт гаджет-драйвер;
**`wdtk-0` кикает WDT каждые ~20с** (CONFIG_MTK_WD_KICKER жив!) — поэтому
остановка киков дедмэна НЕ даёт WDT-ресета; возврат в TWRP на ~200с —
это userspace-инициированный reboot recovery (init/vold), а не WDT.

**ROOT CAUSE (FACT, закрыт в p38):** `configfs.c: gadget_cfs_init`
(module_init → device_initcall, libcomposite) при
CONFIG_USB_CONFIGFS_UEVENT=y создаёт класс `"android_usb"` РАНЬШЕ
late_initcall'а android.c → `class_create` в android.c = **-EEXIST** →
init() выходит до маркера 102 и до создания android0 → рамдиск пишет в
никуда → ноль USB. Это же объясняет p31–p34 (BUG A/B из §11.1–11.2 реальны,
но ЛАТЕНТНЫ — до них исполнение не доходило) и «charging d001» на p30:
configfs.c сам эмулирует `/sys/class/android_usb/android0` (строка 1766),
поэтому рамдиск смог поднять charging-гаджет без G_ANDROID.

Ревизия статусов: BUG A/B — латентные, починены в p37; BUG C (aee while(1))
— реален, но в этих прогонах не срабатывал (oops'ов не было); ранняя смерть
p36b (prev-блок: loops=1, смерть в первые ~2с дедмэна при живом wdtk) —
не воспроизвелась на p37; вероятные лечения — memblock_reserve окон и вынос
зеркала из кик-нити (INFERENCE).

**p38** (`configfs.c`): при CONFIG_USB_G_ANDROID libcomposite НЕ создаёт
класс/девайс android_usb (три `#ifndef`-гарда: gadget_cfs_init,
gadgets_make, gadgets_drop) — класс принадлежит legacy-гаджету.

### 11.11. РЕЗУЛЬТАТ p38 (16:35–16:38): класс-фикс сработал; следующий фронт — userspace-маунты

FACT (слоты p38): **102 = milestone — probe ВОШЁЛ** (p38-фикс подтверждён);
дедмэн 114 циклов, зеркало ok=112, oops'ов нет (107–110 пусто). Слот 103
отсутствовал В ДЕКОДЕ — но выяснилось, что `forge_kmark_ptr(103, err)` при
err=0 пишет 0 = неотличимо от нештампованного (та же слепота у 73 при
is_on=0 и 112 при enable=0). p39 добавляет сентинелы (103: 0x600D при
успехе; 73: 0x10|is_on; 112: 0x100|val).

FACT (rc49 p38, раскрутка ринга по таймстампам): **userspace жив и init
работает**: `[166:init] fs_mgr __mount ... = -1 … error: No such file or
directory` для `by-name/cache` (61с), `protect1` (81с), `protect2` (101с),
по 20с ретраев на раздел — значит /system и /data упали ещё раньше (до окна
ринга). Пути fstab: `/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/…`
— **источники не существуют** в 4.9-бутe. Без /data нет persist-пропов →
`sys.usb.config` не выставляется → USB rc не запускается → слоты 111/112
пусты и USB молчит ДАЖЕ при исправном гаджете. Плюс `usb_state<DISCONNECTED>`
каждые ~3с (монитор android0 живёт → android0 создан ✓).

INFERENCE: возврат в TWRP на ~200с — init не смог смонтировать критические
разделы → reboot в recovery (тот же механизм, что и на p34/p37).

Сток-DTB иерархия верна (`mtk-msdc.0 {simple-bus} → msdc0@11230000` →
плат-девайс `11230000.msdc0` с родителем `mtk-msdc.0`) — вопрос, что реально
создаёт ueventd на 4.9. p39: маркеры цепочки probe 115–125 + **ранний
одноразовый снапшот rc49 в expdb offset 2МБ** (первые секунды: ueventd,
msdc, by-name) + сентинелы нулевых слотов.

### 11.12. РЕЗУЛЬТАТ p39 (16:44–16:48): ГАДЖЕТ ЭНУМЕРИРУЕТСЯ; msdc-rename ломает fstab; adb гейтится aliases

**Главное: хост увидел `0bb4:0c02 Android`** (16:46:49, t≈+128с) — legacy-гаджет
живой конец-в-конец. FACT (слоты): вся цепочка probe зелёная —
115→116→117→118→119→120→121→122→123→124→125, 103=0x600D (probe=0);
111=`"mtp,adb"` (functions_store от init!), 112=0x101 (enable=1 →
forge_userspace_alive → дедлайн корректно отключён, дедмэн дожил до 216
циклов без ресета); 114 есть (pullup выдан); 73=0x11; лог: `high-speed
config #1: android` (126.9с), `usb_state<CONFIGURED>` стабильно до 216с.
**113 (ffs ready) НЕТ** → в конфиге только MTP (bNumInterfaces=1, class 255)
→ adb-интерфейса нет, хост-adb устройство не видит. INFERENCE: `f_ffs/aliases`
не был записан/не сработал → "adb" в functions_store не распознан как ffs
(ожидаемая строка `Cannot enable 'adb'` — вне окна ринга). adbd/functionfs
проверяются после починки /data.

**FACT (ранний rc-снапшот, канал работает!):** `[msdc][msdc0] device renamed
to bootdevice.` / `[msdc1] … externdevice` (msdc_cust.c:983-990, Q0 BSP) —
sysfs DEVPATH уезжает в `/devices/platform/bootdevice` → ueventd публикует
`/dev/block/platform/bootdevice/by-name/*`, а fstab общего рамдиска ждёт
`mtk-msdc.0/11230000.msdc0` → ВСЕ fs_mgr-маунты ENOENT (п.11.11) → нет
/data → нет persist-пропов → USB rc деградирован. **Это и есть маунт-фронт.**
Также в снапшоте: msdc0 DT-probe ок (irq 111), «GPT: iniit», msdc1 CMD
таймауты (SD-карты нет — норм). android_init_functions: все 4 функции
success на 0.61с; `android_usb ready`.

**p40** (`msdc_cust.c`): rename убран — путь остаётся стоковым
`mtk-msdc.0/11230000.msdc0` (как на 3.18). Проверено: на «bootdevice» в
дереве завязан только dm-crypt strstr-хинт (без rename берёт generic-путь) и
UFS (не наш). Ожидание от p40: fstab-маунты проходят → /data/persist живы →
init.usb.rc отрабатывает полностью (aliases+adbd+functionfs) → adb.

### 11.13. ПОБЕДА (2026-08-20 17:03): adb работает на ядре 4.9

p41 (`086f17767`): бут ~15с до гаджета, интерфейс **255/66/1 (ADB)** на шине,
после рестарта adb-сервера на девбоксе (хост просто не пересканировал):
`710HVBR923RYK device product:lineage_m5c` — **полноценный adb shell**.
FACT с живой системы: `uname -r` = `4.9.188-m5c+`; `sys.usb.state=adb`;
`ls /dev/block/platform/` = `mtk-msdc.0` (p40 ✓); `/system` и `/data`
смонтированы; `ro.build.display.id = lineage_m5c-userdebug 7.1.2 NJH47F`;
`/sys/class/android_usb/android0/f_adb` существует; `dmesg` через adb
работает. `sys.boot_completed` пуст (zygote=0) — дальнейший userspace/дисплей
— следующие фронты, не USB.

**Итоговая цепочка убийц «вечного логотипа» p31+ (все закрыты):**
1. p38: `configfs.c` (libcomposite, device_initcall) забирал класс
   `android_usb` → `class_create` android.c = -EEXIST → гаджет не создавался.
2. p40: Q0 msdc rename `bootdevice`/`externdevice` уводил DEVPATH →
   ueventd публиковал не те by-name пути → все fstab-маунты ENOENT →
   не было /data/persist → USB rc деградирован, init уходил в recovery ~200с.
3. p41: рамдиск не знает functionfs/aliases — его adbd ходит в
   `/dev/android_adb` (legacy **f_adb**), который Q0 выпилил. Возвращён
   байт-в-байт из стока 3.18.
Плюс латентные бомбы, найденные и обезвреженные по пути (p37): крашащий
unwind таблицы функций (UAF/double-free/NULL), вечный спин
`aee_exception_reboot` при неготовом wd_api, незарезервированные окна
маркеров/rc/pstore (memblock_reserve), зеркало в кик-нити WDT.

**Методологическая база победы — eMMC-зеркало улик** (p36b-провал → p37-фикс):
маркер-слоты + rc49-ринг + ранний rc-снапшот в expdb, переживают ЛЮБОЙ ресет,
читаются из TWRP за секунды. Плюс сентинелы для нулевых значений (p39) и
prev-boot копия страницы (p37). Капча-лотерея DRAM закрыта навсегда.

Образ: `boot_49_p41poll.img` md5 `e31649721d240087da6f49ea4174e9d9`
(cmdline пока idle=poll; следующий шаг — прогон БЕЗ idle=poll для валидации
p32 mt_gpt-фикса, затем display-фронт).
