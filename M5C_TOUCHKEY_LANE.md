# M5c — лейн физической ёмкостной клавиши (Meizu mBack)

Дата: 2026-08-17. Лейн: `mback`. Ядерный worktree:
`/srv/forge/android/m5c/k-worktrees/mback`, ветка `forge/mback`, база
`d9c41e0e`.

Симптом (со слов владельца, подтверждён после починки калибровки тача):
нажатие физической клавиши mBack даёт **тап где-то по экрану**, а не событие
BACK.

Правила доказательности — `/srv/forge/android/CLAUDE.md §2`.

---

## 1. Что даёт device tree

FACT. `captures/20260817-los-first-boot/dtb_stock.dtb` (md5
`e17a091033c1e9188df898186be2761f`), узел `touch@`, декомпиляция
`dtc -I dtb -O dts`:

```
tpd-resolution    = <720 1280>;
use-tpd-button    = <1>;
tpd-key-num       = <3>;
tpd-key-local     = <0x9e 0xfa 0xfb 0x00>;   /* KEY_BACK=158, 250, 251, 0 */
tpd-key-dim-local = <360 1400 100 40
                     180 1400 100 40
                     540 1400 100 40
                       0    0   0  0>;       /* cx cy w h */
```

FACT. Все три окна клавиш имеют `cy = 1400`, то есть лежат на 120 px **ниже**
панели 720x1280. INFERENCE (из этого FACT): ни одно окно клавиш физически не
может пересечься с настоящим касанием пальца, поэтому перехват по окну клавиши
безопасен для тача.

FACT. Телефон физически имеет **одну** клавишу (mBack), а DT описывает
референсный ряд из трёх. Из трёх кодов Android понимает только первый
(`KEY_BACK`); 250 и 251 для Android — мусор.

## 2. Что даёт живое устройство

Все команды — read-only, через `/home/n8n/.claude/skills/devbox/scripts/dev.sh`,
serial `710HVBR923RYK`, 2026-08-17. Устройство не прошивалось, `logcat -c` не
вызывался.

FACT. `getevent -lp /dev/input/event6`:

```
name: "mtk-tpd-kpd"
KEY (0001): KEY_BACK   00fa   00fb
```

то есть `tpd->kpd` создан, и бит `KEY_BACK` на нём выставлен. Значит
`tpd_button_init()` (`drivers/input/touchscreen/mediatek/tpd_button.c:41`)
реально вызвался и `tpd_keycnt == 3` из DT.

FACT. `/system/usr/keylayout/mtk-tpd-kpd.kl` на устройстве:

```
key 158   BACK             VIRTUAL
```

INFERENCE: userspace-половина «ядерного» маршрута уже полностью готова — если
ядро выдаст `KEY_BACK` на `event6`, Android доставит `KEYCODE_BACK`.

FACT. `/sys/board_properties/virtualkeys.mtk-tpd` существует и содержит
правильную таблицу, но `wc -c` = **150** при 75 байтах реальной строки:

```
0x01:158:360:1400:100:40:0x01:250:180:1400:100:40:0x01:251:540:1400:100:40\n
+ 75 байт \0
```

(`od -An -c` показывает ровно 75 нулей после `\n`.)

FACT. В ядре включено `CONFIG_GTP_DEBUG_ON=y`, **но это ни на что не влияет**:
в `GT9XXTB_hotknot/include/tpd_gt9xx_common.h:305-317` и `GTP_INFO`, и
`GTP_DEBUG` заглушены через `#if 0`. Поэтому наш gt9xx полностью молчит в
dmesg — в отличие от стокового (у стока в TWRP видны `<<-GTP-INFO->>` и
`[GTP][HQ]...`). Любой живой маркер по клавише приходится добавлять явным
`pr_info`.

REJECTED. «Драйвер не биндится / клавиш нет в input». Отвергнуто: `event6`
существует с нужными кодами, `virtualkeys` заполнен из DT — вся инициализация
клавиш прошла.

## 3. Корневая причина

FACT (по исходникам, `drivers/input/touchscreen/mediatek/GT9XXTB_hotknot/`,
до патча):

1. `gt9xx_driver.c:40` — `static struct touch_virtual_key_map_t maping[] =
   GTP_KEY_MAP_ARRAY;`, а `include/tpd_gt9xx_common.h:39` —
   `#define GTP_KEY_MAP_ARRAY {{60, 850}, {180, 850}, {300, 850},}`.
   Это compile-time таблица референс-дизайна на панель **480x800**.
2. `gt9xx_driver.c:2400-2422` — при выставленном бите в байте `key_value`
   драйвер **не выдаёт клавишу**, а синтезирует касание:
   `input_x = maping[i].x; input_y = maping[i].y; tpd_down(input_x, input_y, 0, 0);`
3. `gt9xx_driver.c:1991-1995` / `2011-2015` — `tpd_down()`/`tpd_up()` зовут
   `tpd_button()` (единственную функцию, которая превращает координату в
   `input_report_key`) **только** при `FACTORY_BOOT` или `RECOVERY_BOOT`.

INFERENCE (опирается на FACT 1-3 и на FACT из §1):

- Нажатие клавиши превращается в тап по координате `(60, 850)`, которая лежит
  **внутри** панели 720x1280 → владелец видит «тап где-то по экрану». Это в
  точности заявленный симптом.
- Даже в recovery/factory режиме клавиша не заработала бы: `tpd_button()`
  сравнивает координату с окнами из DT (`360±50, 1400±20` и т.д.), а
  `(60, 850)` не попадает ни в одно окно. То есть путь клавиши в этом драйвере
  сломан во всех boot-режимах.

Дополнительный дефект (FACT, там же): цикл `for (i = 0; i < TPD_KEY_COUNT; i++)`
использует `TPD_KEY_COUNT == 4`
(`include/tpd_gt9xx_common.h:35`), а в `maping[]` только **три** элемента →
чтение `maping[3]` за границей массива, если контроллер поднимет бит 3.

Второй, независимый дефект (FACT, `tpd_button.c:10-20` до патча):

```c
for (i = 0, j = 0; i < tpd_keycnt; i++)
        j += sprintf(buf, "%s%s:...", buf, ...);
return j;
```

каждый проход перепечатывает буфер целиком, а `j` суммирует длины частичных
строк: для 3 клавиш возвращается 150 при реальной строке 75 байт. Отсюда те
самые 75 хвостовых `\0` в `/sys/board_properties/virtualkeys.mtk-tpd` (§2).

HYPOTHESIS (способ проверки — ниже, в §6): Android'овый
`VirtualKeyMap::Parser` токенизирует весь отданный буфер и отвергает **весь**
файл, встретив токен, отличный от `0x01`; хвост из `\0` — как раз такой токен.
Тогда виртуальных клавиш у `mtk-tpd` нет вовсе, и «userspace-маршрут» (тап в
полосе `y≈1400` → BACK) тоже нерабочий. Falsification: после патча
`wc -c /sys/board_properties/virtualkeys.mtk-tpd` должен дать 75, а не 150.

## 4. Выбранный механизм

Решение: **выдавать настоящий `EV_KEY` из ядра на `tpd->kpd` (`event6`)**, а не
синтезировать касание и не рассчитывать на трансляцию в Android.

Почему так, а не «починить координаты и довериться virtualkeys»:

- ядерный маршрут детерминирован и уже полностью обеспечен userspace-ом:
  `event6` имеет бит `KEY_BACK` (FACT §2), `mtk-tpd-kpd.kl` даёт
  `key 158 BACK VIRTUAL` (FACT §2);
- маршрут через `virtualkeys` зависит от парсера Android и от того, что
  контроллер сообщит координату именно в полосе `y≈1400`, — два лишних условия,
  одно из которых (§3, второй дефект) прямо сейчас сломано.

Прошивка GT9xx может объявить клавишу двумя способами, и оба обработаны:

- бит в байте `key_value` сразу за координатными записями;
- обычная координатная запись, попавшая в внезапанельную полосу клавиш.

Оба сводятся к одному вызову `gtp_touch_key_report()` за цикл прерывания.

Три кода DT свёрнуты в один: репортится `tpd_dts_data.tpd_key_local[0]`
(= `KEY_BACK`) независимо от того, какой слот подняла прошивка, потому что
физическая клавиша одна (FACT §1).

## 5. Патч

Ветка `forge/mback`, коммит «input: gt9xx: report the mBack capacitive key as
KEY_BACK, not a fake touch».

`drivers/input/touchscreen/mediatek/GT9XXTB_hotknot/gt9xx_driver.c`:

- удалены `struct touch_virtual_key_map_t` и `maping[] = GTP_KEY_MAP_ARRAY`
  (вместе с ними — чтение за границей массива из §3);
- добавлен `gtp_touch_key_report(bool down)`: по фронту репортит
  `tpd_dts_data.tpd_key_local[0]` на `tpd->kpd` + `input_sync()`, и печатает
  живой маркер `pr_info("[mtk-tpd] gt9xx touch key -> code %u down|up")`
  (маркер нужен, потому что весь `GTP_DEBUG` в этом драйвере заглушен, FACT §2);
- добавлен `gtp_is_touch_key_point(x, y)`: попадание точки в окна
  `tpd-key-dim-local` из DT (не в compile-time таблицу);
- в `touch_event_handler()`: ветка `key_value` больше не зовёт
  `tpd_down()`/`tpd_up()`, а только выставляет `key_down`; в координатном цикле
  точка, попавшая в окно клавиши, идёт в `key_down` и `continue` (пальцем не
  репортится); один вызов `gtp_touch_key_report(key_down)` за цикл;
- убран ставший ненужным `static u8 pre_key` (фронт теперь считает
  `gtp_touch_key_report`).

`drivers/input/touchscreen/mediatek/tpd_button.c`:

- `mtk_virtual_keys_show()` переписан на `scnprintf(buf + len, PAGE_SIZE - len, ...)`
  с корректным возвратом длины → хвостовые `\0` из sysfs-узла уходят.

Что **не** тронуто (сознательно): матрица калибровки
`config_default/gt9xx_config.h` (`TPD_CALIBRATION_MATRIX_ROTATION_*`),
`TPD_WARP_X/Y`, DTS/DTB, `m5c_defconfig`, `BRINGUP_STATE.md`,
`M5C_CHIP_MAP.md`.

FACT. Собрано: `make ARCH=arm64 CROSS_COMPILE=.../aarch64-linux-android-4.9/bin/aarch64-linux-android- -j8 Image.gz-dtb`,
EXIT=0. Единственный warning в этом файле —
`gt9xx_driver.c:2681 unused variable 'ret'` в `gtp_enter_sleep()`, он
предсуществующий и к патчу не относится.

FACT. Хосту gcc нужен `HOSTCFLAGS="... -fcommon"` — иначе прешипнутый
`scripts/dtc` не линкуется (`multiple definition of yylloc`, тот же дефект, что
описан в `M5C_KERNEL_49_BUILD_LOG.md` для ветки 4.9). Это флаг сборки, дерево
им не правилось.

Артефакты (в worktree, `artifacts/`):

| файл | sha256 |
|------|--------|
| `Image.gz-dtb-mback1` (7841789 B) | `f43e83b952102a3c2863a7398fb9c311bc94cb186c7da7778a6707b30cbf06b5` |
| `System.map-mback1` | `c77eb6eda152a5ed1f8ab806dbc2365d7d80afcec5d65fa946e056808d06b12d` |
| `config-mback1` | `8b955e0c50cbb755338f9cf09c8f7dc51c7eb7360e25f1de67974ab7a03b2043` |

FACT. Приложенный DTB не изменился: он найден в `Image.gz-dtb` по смещению
7772362, хвоста после него нет, md5 `e17a091033c1e9188df898186be2761f` — то есть
байт-в-байт стоковый (сверено с `captures/20260817-los-first-boot/dtb_stock.dtb`).

Раздел для прошивки: `boot`. Ядро отдано родительской сессии, самостоятельно не
прошивалось.

## 6. Что считать доказательством успеха

После прошивки нового `boot`, при нажатии mBack:

1. Живой маркер в ядре (главный):

   ```
   adb shell dmesg | grep 'gt9xx touch key'
   → [mtk-tpd] gt9xx touch key -> code 158 down
     [mtk-tpd] gt9xx touch key -> code 158 up
   ```

2. Событие на `event6`, и **никакого** ABS на `event5`:

   ```
   adb shell getevent -lt /dev/input/event6
   → EV_KEY  KEY_BACK  DOWN / UP
   adb shell getevent -lt /dev/input/event5
   → тишина при нажатии клавиши (координат нет)
   ```

3. Android принял клавишу:

   ```
   adb shell dumpsys input | grep -A3 mtk-tpd-kpd
   ```
   плюс поведенческий признак — экран уходит «назад».

4. Побочная проверка §3 (второй дефект):

   ```
   adb shell wc -c /sys/board_properties/virtualkeys.mtk-tpd
   → 75   (было 150)
   ```

5. Регресс-контроль тача (он подтверждён владельцем и ломать его нельзя):
   обычный тап по центру экрана по-прежнему даёт на `event5` корректные
   `ABS_MT_POSITION_X/Y`.

## 7. Открытый вопрос

HYPOTHESIS. Точный способ, которым GT917 объявляет нажатие, ещё не снят с
живого устройства: заказан, но на момент коммита не получен, capture
`getevent -t` по `event5`+`event6` во время физического нажатия mBack.
Патч намеренно закрывает оба варианта (байт `key_value` и координата в полосе
клавиш), поэтому от исхода capture он не зависит.

Чем capture всё же важен: он различает варианты и подтверждает §3 напрямую.
Falsification для §3 — если до патча нажатие даёт на `event5`
`ABS_MT_POSITION_X = 60`, `ABS_MT_POSITION_Y = 850`, `BTN_TOUCH 1`,
`ABS_MT_PRESSURE = 100`, `ABS_MT_TOUCH_MAJOR = 100` и **без**
`ABS_MT_TRACKING_ID` (`tpd_down(x, y, 0, 0)` при `size == 0 && id == 0` идёт по
ветке без tracking id, `gt9xx_driver.c:1972-1980`) — это подпись именно
`maping[]`-пути, и §3 подтверждён побайтово.

REJECTED-кандидат, если capture покажет иное: если нажатие даёт нормальную
координату **внутри** панели с обычным `ABS_MT_TRACKING_ID`, значит заводская
конфигурация GT917 вообще не выделяет клавишу, и тогда нужен другой лейн —
отдельная зона на сенсоре ниже активной области, а не touch-key механизм.
В этом случае патч из §5 безвреден, но недостаточен.
