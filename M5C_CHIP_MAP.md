# M5c — карта реального железа (снята со стокового ядра)

Источник: живой Meizu M5c `710HVBR923RYK` в TWRP 3.7.0_9-0 (recovery работает на
**стоковом** ядре `3.18.19+ flyme@Mz-Builder-l10 Wed Apr 3 17:12:37 CST 2019`),
2026-08-17. Всё ниже — FACT из sysfs/procfs/dmesg живого устройства, не из DTS и
не из реверса.

## I2C: узел → адрес → драйвер, которым его биндит СТОК

`/sys/bus/i2c/devices/*/name` + `readlink driver`:

| шина-адрес | DTS-имя узла        | сток-драйвер        | что это |
|-----------|---------------------|---------------------|---------|
| `0-0010`  | `camera_main`       | `kd_camera_hw`      | S5K4H8, main |
| `0-0018`  | `camera_main_af`    | `MAINAF`            | DW9714 AF |
| `0-003c`  | `camera_sub`        | `kd_camera_hw_bus2` | S5K5E8, front |
| `1-003e`  | `i2c_lcd_bias`      | **`lp3101`**        | bias дисплея |
| `1-005d`  | `cap_touch`         | **`gt9xx`**         | Goodix GT917D |
| `1-0063`  | `strobe_main`       | `leds-LM3642`       | вспышка |
| `1-006a`  | `swithing_charger`  | **`fan5405`**       | зарядник (sic: опечатка в DTS стока) |
| `2-000c`  | `msensor`           | `akm09912`          | магнитометр |
| `2-0018`  | `gsensor`           | `MC3XXX`            | акселерометр |
| `2-0028`  | `nfc`               | — (не биндится и в стоке) | посадочное место |
| `2-0048`  | `alsps`             | `stk3x1x`           | свет/приближение |
| `2-0068`  | `gyro`              | — (не биндится и в стоке) | посадочное место |
| `3-006b`  | `ext_buck`          | — (не биндится и в стоке) | внешний buck |

Адаптеры: `i2c-0..3`, все `mt-i2c`.

## Input-устройства стока

`input0 ACCDET`, `input1 mtk-kpd`, `input2 hwmdata`, `input3 m_alsps_input`,
`input4 m_acc_input`, `input5 m_mag_input`, `input6 mtk-tpd`, `input7 mtk-tpd-kpd`.
Гироскопа среди input нет — на этом экземпляре гироскопа физически нет.

## Тач: как ведёт себя сток

FACT (dmesg стока в TWRP): драйвер `gt9xx`, теги `<<-GTP-INFO->>` /
`<<-GTP-DEBUG->>`, кастом-строки `[GTP][HQ]20160525tpd_down`, ESD-поток
(`[Esd]0x8040 = 0xFF, 0x8041 = 0xAA`), `Init external watchdog`,
`GTP wakeup sleep`, реальные координаты (`tpd_down x:287 y:792`).
Также `Request firmware failed - gt9xx_fw.bin (-11)` — сток пробует
request_firmware и продолжает работать без него.
В `/sys/class/misc/` есть узел `hotknot` → сток использует **hotknot-вариант**
gt9xx-драйвера.

FACT: параллельно в стоке присутствует и FocalTech (`[FTS][fts]
fts_enter_charger_mode write value fail`), но на этом экземпляре он не
обслуживает панель — работает Goodix.

## Прерывания стока (сокращённо)

`104 musb-hdrc.0.auto`, `196 mtk-kpd`, `350 mt-eint 62 mtk-tpd`,
`353 mt-eint 65 ALS-eint`, `294 mt-eint 6 accdet-eint`,
**`494 mt-eint 206 pmic-eint` — счётчик 1** (сработал на подключение кабеля),
`218/225/227/229/232 DISPSYS`, `178 m4u`, `183 mtk_cmdq`.

## Питание стока (с тем же кабелем, в тот же момент)

`/sys/class/power_supply/usb/online = 1`, `ac/online = 0`,
`battery/status = Charging`, `capacity = 93`.

## DTB

FACT: DTB, приложенный к нашему собранному ядру #11, **байт-в-байт совпадает со
стоковым**: 69427 B, md5 `e17a091033c1e9188df898186be2761f` (файлы
`captures/20260817-los-first-boot/dtb_ours.dtb` и `dtb_stock.dtb`).
INFERENCE: расхождения нашего ядра со стоком лежат в **драйверах и
defconfig**, а не в описании железа.
