# M5c — вспышка/фонарик (flashlight lane)

Дорожка по фонарику Meizu M5c (`710HVBR923RYK`) на LineageOS 14.1 с нашим ядром
3.18.19. Ведётся отдельно от `BRINGUP_STATE.md`; сюда пишем всё по flash/torch.

Ветка ядра: `forge/torch` в `/srv/forge/android/m5c/k-worktrees/torch`, база
`master d9c41e0e`.

---

## 2026-08-17 Чип — не LM3642, а SY7806; DT-узел вспышки вообще не биндится

### Исходное состояние (дано)

FACT (из `BRINGUP_STATE.md`, раздел «2026-08-17 (поздний вечер)»): userspace
доходит до HAL (`cust_getFlashHalTorchDuty devid main id1`,
`onTorchStatusChangedLocked cameraId=0 newStatus=2`), в ядре при нажатии — ни
одной строки, LED не светит. i2c-клиент `1-0063 strobe_main` привязан к
`leds-LM3642`.

### REJECTED: «включить dynamic debug для leds_strobe.c и посмотреть»

REJECTED. `drivers/misc/mediatek/flashlight/src/mt6735/constant_flashlight/leds_strobe.c`
строки 45–50: `/*#define DEBUG_LEDS_STROBE*/` закомментирован, поэтому
`#define PK_DBG(a, ...)` — **пустой макрос**, а не `pr_debug`. То же самое в
`kd_flashlightlist.c` строки 60–65: `DEBUG_KD_STROBE` не определён →
`#define logI(a, ...)` пуст. Ни одной записи в `dynamic_debug/control` для этих
файлов не существует, потому что вызовов `pr_debug` там нет — они вырезаны
препроцессором. INFERENCE: «тишина в dmesg» не является уликой вообще; она
полностью объясняется конфигурацией сборки и ничего не говорит о том, доходит ли
вызов до `FL_Enable`.

### FACT 1: в DTB есть узел вспышки с pinctrl, и он ни к кому не привязан

FACT: `dtc -I dtb -O dts captures/20260817-los-first-boot/dtb_stock.dtb`
(md5 `e17a091033c1e9188df898186be2761f`, байт-в-байт наш DTB), строки 928–939:

```
flashlight {
        compatible = "mediatek,mt6737-flashlight";
        pinctrl-names = "default","hwen_low","hwen_high","torch_low","torch_high","flash_low","flash_high";
        pinctrl-0..6 = <...>;
        status = "okay";
};
```

FACT: пины этих состояний (узлы `flashlight@0..5` в `pinctrl@0x10211000`,
строки 1938–2002 того же DTS), в кодировке `MTK_PIN_NO(x) = x << 8`:

| состояние | `pins` | GPIO | уровень |
|---|---|---|---|
| `hwen_low` / `hwen_high`   | `0x900`  | **GPIO9**  | low / high |
| `torch_low` / `torch_high` | `0x4e00` | **GPIO78** | low / high |
| `flash_low` / `flash_high` | `0x5000` | **GPIO80** | low / high |

FACT: `grep -rn "mt6737-flashlight" --include=*.c --include=*.h` по всему нашему
дереву ядра даёт **только** `arch/arm64/boot/dts/hq6737m_65_1mz_m0.dts:929`.
Ни один драйвер этот compatible не матчит. То же с `mediatek,hq-torch`
(`led@7`, строка 3474) — консьюмера нет.

FACT (снято живьём с устройства `710HVBR923RYK`, 2026-08-17 ~15:47, только
чтение):

```
$ ls /sys/bus/platform/devices/ | grep -i flash
bus:flashlight
kd_camera_flashlight.0

$ ls -l /sys/bus/platform/drivers/kd_camera_flashlight/
kd_camera_flashlight.0 -> ../../../../devices/platform/kd_camera_flashlight.0
   (bind / unbind / uevent)

$ ls -l /sys/bus/platform/devices/bus:flashlight/ | grep -i driver
driver_override            # symlink "driver" ОТСУТСТВУЕТ
```

INFERENCE (из FACT выше): platform-устройство `bus:flashlight` создано из
DT-узла, но не привязано ни к одному драйверу, поэтому pinctrl-состояния
`hwen_*`/`torch_*`/`flash_*` никогда не выбираются, и GPIO9 (HWEN) остаётся в том
состоянии, в котором его оставили preloader/LK. Это тот же класс дефекта, что уже
трижды встречался сегодня (charger `swithing_charger`, alsps, lp3641
`lcd_bais_pinctrl`), только здесь не совпадает не имя, а вообще отсутствует
драйвер-консьюмер.

### FACT 2: сток берёт pinctrl из `kd_flashlightlist.c` (правка Huaqin «by likai»)

Источник: стоковое ядро `/home/valakas/m5c/kernel-reverse/vmlinux.elf`
(ELF с symtab, дизассемблер `aarch64-linux-android-4.9-objdump`).

FACT: в стоке есть GLOBAL-символы, которых у нас нет вообще:
`flashlight_gpio_init` (`0xffffffc0005db674`), `flashlight_gpio_set`
(`0xffffffc0005db978`), объект `FLASHLIGHT_of_match` (`0xffffffc000b95ce8`,
`compatible` по смещению 0x40 = `"mediatek,mt6737-flashlight"`).

FACT: `flashlight_gpio_init(pdev)` = `devm_pinctrl_get(&pdev->dev)` +
шесть `pinctrl_lookup_state` со строками `hwen_high`, `hwen_low`, `torch_high`,
`torch_low`, `flash_high`, `flash_low` (строки по file offset `0xd9c850`…`0xd9c8a0`).

FACT: `flashlight_gpio_set(pin, state)` → `pinctrl_select_state`, нумерация
`pin`: **0 = HWEN, 1 = TORCH, 2 = FLASH**; `state`: 0 = low, 1 = high; в конце
всегда `printk("%s : pin(%d) state(%d)")`.

FACT: все 13 вызовов `flashlight_gpio_set` в стоке передают `pin = 0`. То есть
GPIO78/GPIO80 (TORCH/FLASH) в стоке **не используются** — управление только по
i2c плюс HWEN.

FACT: стоковый `flashlight_init` (`0xffffffc000f61810`) регистрирует и
platform_device вручную, и platform_driver с `of_match_table` — то есть в стоке
драйвер ловит оба устройства.

### FACT 3: чип на 1-0063 — SY7806-класс, а не LM3642. Наш регистровый набор бьёт мимо

FACT: имя i2c-драйвера в стоке действительно `leds-LM3642`, и хелперы называются
`LM3642_write_reg`/`LM3642_read_reg` — но это только унаследованные имена
MTK-шаблона. Живой код стокового `leds_strobe.c` — это функции
`SY7806_set_torch_mode` (`0x5dcd78`), `SY7806_set_torch_for_meizu_mode`
(`0x5dcea4`), `SY7806_set_flash_mode` (`0x5dcfd0`), `SY7806_enable` (`0x5dd124`),
`SY7806_led_enable`, `SY7806_init`, `SY7806_close` (`0x5dd1bc`),
`SY7806_for_engmode_close`, `SY7806_disable`.

FACT: **`FL_Enable` в стоке (`0xffffffc0005dd388`) не вызывается ниоткуда.**
Поиск `bl ... <FL_Enable>` по полному дизассемблеру стокового образа даёт 0
попаданий. Тело этого `FL_Enable` — ровно наш код (регистры 9 и 0x0A), то есть
LM3642-последовательность в стоке — мёртвый код. `FL_Disable` и `FL_Uninit` в
стоке вообще `return 0`.

FACT: регистры, которые пишет живой стоковый путь:

| регистр | назначение | значения из стока |
|---|---|---|
| `0x08` | Timing config | `0x0F` (пишется первым в каждой последовательности) |
| `0x05` | LED1 torch brightness | из таблицы torch |
| `0x06` | LED2 torch brightness | из таблицы torch |
| `0x03` | LED1 flash brightness | из таблицы flash |
| `0x04` | LED2 flash brightness | из таблицы flash |
| `0x01` | Enable / mode | `0x0B` torch оба канала, `0x0F` flash оба, `0x09`/`0x0A` один канал, `0x00` off |

Это регистровая карта SY7806 / AW3644 (bits [3:2] = режим, bits [1:0] = разрешение
каналов). INFERENCE: наши записи в `0x09` и `0x0A` попадают у SY7806 в
Temperature и Flag1 (Flag1 — read-only), поэтому **никакого влияния на LED не
оказывают**, даже если i2c-транзакция проходит.

FACT: таблицы яркости, вынутые байт-в-байт из `.kernel` стокового образа по
`0xffffffc000b961a8` (шаг 4 байта, значение в младшем байте):

* torch LED1 и LED2 (4 записи, индекс = duty 0..3): `0x23 0x31 0x6A 0x7F`
* meizu-torch LED1/LED2 (6 записей): `0x10 0x22 0x34 0x46 0x58 0x6A`
* flash LED1 и LED2 (17 рабочих записей): `0x03 0x08 0x0C 0x10 0x19 0x21 0x2A
  0x32 0x3B 0x43 0x4C 0x54 0x5D 0x65 0x6E 0x77 0x7F`

FACT: каждая включающая последовательность в стоке начинается с
`flashlight_gpio_set(0, 1)` (HWEN high) и только потом идут i2c-записи; полное
выключение — `gpio_set(0,1)` → `write(0x01, 0x00)` → `gpio_set(0,0)`.

FACT (побочно, для будущего): в стоке есть ещё два пути к тому же чипу —
sysfs-атрибуты `flash1`/`flash2` на устройстве flashlight (строки
`flashlight store flash1_level = %d`) и LED-класс: `mt_mt65xx_led_set_cust`
(`0xffffffc00045f968`) вызывает `SY7806_led_enable`/`SY7806_for_engmode_close`
для узла `mediatek,hq-torch`. Плюс procfs `torch_value_config_write_proc`.
Мы их не портировали — LOS дергает фонарь через camera HAL и
`/dev/kd_camera_flashlight`, а не через `/sys/class/leds`.

FACT: в стоке `strobe_getPartId` возвращает 1 для main/sub при strobeId 1..2 —
как у нас, то есть `setFlashDrv` для main/strobe1 идёт в
`constantFlashlightInit` (это `leds_strobe.c`), а для main/strobe2 — в
`strobeInit_main_sid2_part1`. При этом чип в стоке программируется **только из
пути strobeId == 2** (`constant_flashlight_ioctl` в `strobe_main_sid2_part1.c`
вызывает `SY7806_enable`/`SY7806_close`), а путь strobeId == 1 лишь выставляет
флаги `LED1Closeflag`/duty и таймаут. Это легко не заметить.

### Гипотезы и их проверка

1. HYPOTHESIS «`FL_Enable` не вызывается вообще (обрыв в
   `kd_flashlightlist.c`/`setFlashDrv`)». Проверка: `PK_LOG`(pr_info) в
   `constant_flashlight_open`/`ioctl`/`FL_dim_duty` — если после нажатия в dmesg
   нет `FLASHLIGHT_ONOFF: 1`, гипотеза подтверждается. Пока НЕ проверено.
2. HYPOTHESIS «вызывается, но чип в shutdown, потому что HWEN (GPIO9) низкий»
   — опирается на FACT 1 (узел не биндится) и FACT 3 (сток всегда поднимает
   HWEN перед i2c). Проверка: в новом коде `flashlight_gpio_set` печатает
   `pin(0) state(1) ret(0)`; если ret != 0 или строки нет — pinctrl не поднялся.
3. HYPOTHESIS «вызывается, HWEN не при чём, но регистры не те» — опирается на
   FACT 3. Проверка: `sy7806_write` печатает `pr_err` на каждую неудачную
   запись, а `FL_Enable` печатает readback `0x01`/`0x0B`/`0x0C`; если записи
   проходят (нет `pr_err`) и readback `0x01` == `0x0B`, а LED не светит —
   гипотеза неверна, дефект в питании/пайке LED.

INFERENCE (наиболее вероятное объяснение, ставка этого патча): работают
одновременно 2 и 3 — чип держится в shutdown по HWEN, а даже при поднятом HWEN
наш регистровый набор LM3642 физически не может включить SY7806.

### Что изменено (ветка `forge/torch`)

`drivers/misc/mediatek/flashlight/inc/kd_flashlight.h`
: объявления `flashlight_gpio_set`, константы `FLASHLIGHT_PIN_{HWEN,TORCH,FLASH}`
  и `FLASHLIGHT_PIN_{LOW,HIGH}`, объявления `strobe_flash_{set_duty,enable,disable}`.

`drivers/misc/mediatek/flashlight/src/mt6735/kd_flashlightlist.c`
: добавлен pinctrl-слой (`flashlight_gpio_init` + экспортируемый
  `flashlight_gpio_set`, все шесть состояний по стоковым именам); в
  `flashlight_platform_driver` добавлен `of_match_table` с
  `mediatek,mt6737-flashlight`, чтобы DT-узел наконец биндился; `flashlight_probe`
  берёт пины у того устройства, у которого есть `of_node`, а chrdev/класс создаёт
  только один раз (`chrdev_inited`), чтобы второе устройство не ломало первое.
  Логи pinctrl — `pr_info`/`pr_err`, видны в dmesg.

`drivers/misc/mediatek/flashlight/src/mt6735/constant_flashlight/leds_strobe.c`
: `FL_Init`/`FL_Enable`/`FL_Disable` переписаны на регистровую карту SY7806 с
  подъёмом HWEN и стоковыми таблицами яркости; `duty <= 3` → torch (`0x01 = 0x0B`),
  выше → flash (`0x01 = 0x0F`); выключение — `0x01 = 0x00` и HWEN low. Добавлен
  макрос `PK_LOG` (pr_info) и переведены на него ключевые точки, потому что
  `PK_DBG` компилируется в пустоту. Экспортированы
  `strobe_flash_{set_duty,enable,disable}`.

`drivers/misc/mediatek/flashlight/src/mt6735/strobe_main_sid2_part1.c`
: пустые `FL_Enable`/`FL_Disable`/`FL_dim_duty` (шаблон MTK, `sky81296`) заменены
  на проброс в те же экспортируемые функции — чтобы путь strobeId == 2 управлял
  тем же физическим чипом. Это шире, чем сток, и намеренно: неизвестно, какой
  strobeId дергает наш HAL-блоб.

Что НЕ менялось: DTS (наш DTB остаётся байт-в-байт стоковым, md5
`e17a091033c1e9188df898186be2761f` — проверено внутри собранного образа),
`defconfig`, `strobe_part_id.c`, TORCH/FLASH GPIO (GPIO78/GPIO80) не трогаются,
как и в стоке.

### Допущения патча (важно для других ревизий m5c)

* Чип на `1-0063` — SY7806-совместимый (регистры 0x01/0x03..0x06/0x08). Это FACT
  для стокового ядра **этого** экземпляра; на ревизии с настоящим LM3642 новый
  код фонарь не включит (нужен будет выбор карты по `readReg(0x0C)`).
* HWEN — GPIO9 из DT-узла, а не легаси-дефайны `GPIO12/GPIO13`, которые лежат
  закомментированными в `leds_strobe.c` (они от другой платы).
* Оба канала LED1/LED2 включаются вместе (`0x0B`/`0x0F`), как в стоке по
  умолчанию. Если на плате распаян один LED, второй канал просто уйдёт в
  open-LED флаг, это стоковое поведение.

### Артефакт для прошивки (прошивает владелец сессии, НЕ агент)

* Сборка ядра: `EXIT=0`, `Image.gz-dtb` = 7 844 933 B, баннер
  `Linux version 3.18.19 (n8n@n8nagent) ... #1 SMP PREEMPT Mon Aug 17 15:45:22 MSK 2026`.
  Внутри: `Image.gz` 7 775 506 B (проверен `gunzip -t`) + DTB 69 427 B,
  md5 `e17a091033c1e9188df898186be2761f` (= стоковый).
  Для справки: ядро `boot_k19.img` (#26) — 7 841 456 B, то есть конфиг тот же,
  разница +3 477 B — это только код фонарика.
* Образ: `/tmp/claude-1000/-srv-forge-android-m5c/145b2c58-faa9-45b2-84d1-967d0b509fd8/scratchpad/boot_torch1.img`
  * 9 469 952 B, sha256 `b511145a2992e9a262225f6102351cc3862dd529e59cdb6ea3f788144a761be2`,
    md5 `ce5bedae4aa7845ae2150fb925d70cbc`
  * состав: наш `Image.gz-dtb` + **ramdisk и заголовок от `boot_k19.img`**
    (ramdisk 1 620 974 B, page 2048, kernel@0x40080000, ramdisk@0x44000000,
    second@0x40f78000 (size 0), tags@0x4e000000, board `mt6737`, cmdline
    `bootopt=64S3,32N2,64N2 androidboot.selinux=permissive buildvariant=userdebug`),
    поле `os_version` скопировано с `boot_k19.img`, `id` пересчитан как SHA1 по
    mkbootimg.
  * gzip-поток ядра внутри образа проверен распаковкой; DTB на месте.
* Партиция: **boot (p7)**. Аварийный канал: TWRP на стоковом ядре.

### Маркеры успеха и провала

Проверять в этом порядке, `dmesg` (НЕ `logcat -c`):

1. Загрузка: `grep -i flashlight` в dmesg должно появиться
   `[KD_CAMERA_FLASHLIGHT]flashlight_gpio_init done, ret = 0`. Если вместо этого
   `cannot get pinctrl` или `cannot find pinctrl state hwen_high` — DT-узел
   биндится, но состояния не нашлись (тогда правим имена).
   Если строки нет вообще — узел всё ещё не биндится.
2. При нажатии кнопки фонаря должно появиться:
   * `[leds_strobe.c]constant_flashlight_open: open, strobe_Res = 0`
   * `[leds_strobe.c]constant_flashlight_ioctl: FLASHLIGHT_DUTY: N`
   * `[leds_strobe.c]constant_flashlight_ioctl: FLASHLIGHT_ONOFF: 1`
   * `[KD_CAMERA_FLASHLIGHT]pin(0) state(1) ret(0)` ← HWEN поднят
   * `[leds_strobe.c]FL_Enable: torch on, duty = N, level = 0x..`
   * `[leds_strobe.c]FL_Enable: readback enable = 0x0b flag1 = 0x.. devid = 0x..`
   * при отпускании: `FL_Disable: off` и `pin(0) state(0) ret(0)`
   * ЛИБО (если HAL использует strobeId 2):
     `[strobe_main_sid2_part1.c]FL_Enable: forwarding to the constant flashlight strobe`
3. **Физическое наблюдение владельца:** светодиод вспышки на задней крышке
   должен ровно светиться, пока фонарь включён (не мигать, не гаснуть через
   секунду). Таймаут в драйвере 1000 мс по умолчанию, но HAL для torch обычно
   ставит `FLASH_IOC_SET_TIME_OUT_TIME_MS = 0` — если LED гаснет ровно через
   секунду, смотреть строку `FLASH_IOC_SET_TIME_OUT_TIME_MS`.
4. Провал с диагностикой: если в логе есть `write reg 0x01 = 0x0b failed,
   ret = -6` (`-ENXIO`) — чип не отвечает даже с поднятым HWEN, значит HWEN не
   тот пин или на чип не подано питание. Если записи проходят, `readback
   enable = 0x0b`, а LED не светит — дефект вне i2c (питание LED / пайка), см.
   гипотезу 3.

### Не проверено / открыто

* Ничего из этого пока не проверено на железе: устройство ушло из adb в момент
  сборки образа (`710HVBR923RYK not found`, остался только `95AHACQC5KQVM`).
* Неизвестно, какой `strobeId` использует наш HAL-блоб. Патч закрывает оба.
* `readReg(0x0C)` (Device ID) добавлен в логи именно для того, чтобы
  зафиксировать реальный ID чипа — это первый живой FACT, который надо внести
  сюда после прошивки.
* LED-класс (`mediatek,hq-torch`) и sysfs `flash1`/`flash2` из стока не
  портированы. Если понадобится фонарь из TWRP или из EngineerMode — брать
  `mt_mt65xx_led_set_cust` (`0xffffffc00045f968`) и `SY7806_led_enable`
  (`0xffffffc0005dd18c`) из стокового `vmlinux.elf`.
