# M5c — лента «камера повёрнута на 180°»

Отдельная линия работ: и видоискатель, и сохранённые снимки перевёрнуты на 180°
(подтверждено владельцем, 2026-08-17). Цвет (радужные пятна / отсутствие OTP)
— **другая** линия, её ведёт отдельный агент; здесь цвет не трогаем.

Дата: 2026-08-17. Устройство: `710HVBR923RYK`, LOS 14.1 (userdebug, SELinux
Permissive, adb-shell = root `u:r:su:s0`).

Итог линии: значение приходит из **хардкод-фолбэка в
`libcam.metadataprovider.so`**, потому что для наших сенсоров в блобах нет
таблицы статических метаданных. Правка — 4 байта в этом блобе (§6). Первая
версия этого документа указывала на `libcameracustom.so`; она **опровергнута на
железе**, разбор сохранён в §5 как REJECTED.

## 1. Идентичность артефактов

FACT: `mediaserver` (pid 376) — это процесс, в котором живёт `CameraService`;
отдельного `/system/bin/cameraserver` в этой сборке нет.

FACT: в `/proc/376/maps` подгружены **32-битные** библиотеки
`/system/lib/libcameracustom.so` и `/system/lib/libcam.halsensor.so`
(адреса `f2c43000`, `f0b26000`). 64-битные копии в `/system/lib64/` присутствуют,
но mediaserver их не загружает. FACT (родительская сессия): каталога
`/system/vendor/lib/` на устройстве нет вовсе, поэтому `preloadM681MtkCameraDeps()`
из `CameraService.cpp` (он ждёт блобы в `M681_VENDOR_LIB_DIR`) молча не делает
ничего.

FACT: размеры на устройстве совпадают с копиями в дереве байт-в-байт:

| файл | размер | md5 (в дереве) |
|---|---|---|
| `proprietary/lib/libcameracustom.so` | 16866932 | `d4b5c4b1b34b13285edaff50fe45858c` |
| `proprietary/lib64/libcameracustom.so` | 17138288 | `6c6901b416d6e2b457f50ab1cd169872` |
| `proprietary/lib/libcam.metadataprovider.so` | 222828 | `4bd55c6520af555499b8bff19814abbe` |

## 2. Что фреймворк сообщает приложениям (ground truth)

FACT (`adb shell dumpsys media.camera`, 2026-08-17):

```
Camera module HAL API version: 0x100
Number of camera devices: 1
Camera 0 information:
  Facing: BACK
  Orientation: 90
  Resource Cost: 0
  Conflicting Devices: NONE
```

Т.е. приложениям (`org.cyanogenmod.snap`) отдаётся `CameraInfo.orientation = 90`,
камера ровно одна — только main. Фронтальный S5K5E8YX не перечисляется.

INFERENCE: одна ошибка в 180° в этом значении объясняет **оба** симптома. Camera1
считает поворот превью как `(orientation − display_rotation)`, а поворот JPEG как
`(orientation + display_rotation)`; если реально нужно 270, а отдаётся 90, и
превью, и снимок уезжают ровно на 180°. Согласуется с тем, что снятый кадр
`IMG_20260817_151905.jpg` — портретный 1920x2560, т.е. HAL честно повернул его на
объявленные 90°.

## 3. Полная цепочка: откуда берётся 90

Всё ниже — FACT из дизассемблера прибилдов и из исходников ROM.

**3.1. Фреймворк ничего не хардкодит.**
`CameraService::getCameraInfo()`
(`frameworks/av/services/camera/libcameraservice/CameraService.cpp:506-512`)
делает `mModule->getCameraInfo(cameraId, &info)` и копирует
`info.orientation` как есть. `generateShimMetadata()` (там же, :544) кладёт то же
значение в `ANDROID_SENSOR_ORIENTATION` для HAL1-шима. Наши m681-патчи в этом
файле ориентацию не трогают.

**3.2. HAL-модуль `camera.mt6737m.so` (42800 B).**
`NSCam::CamDeviceManagerBase::getDeviceInfo(int, camera_info&)` (vaddr `0x4c24`)
копирует поля из своего `EnumInfo`:

```
0x4c9a  r2 = EnumInfo[8]  -> camera_info[8]  = device_version
0x4c9e  r4 = EnumInfo[16] -> camera_info[0]  = facing
0x4ca2  r3 = EnumInfo[20] -> camera_info[4]  = orientation
0x4ca6  r0 = EnumInfo[12] -> camera_info[12] = static_camera_characteristics
        camera_info[16] = resource_cost = 0, [20] = [24] = 0
```

т.е. **`camera_info.orientation` ← `EnumInfo+20`**.

**3.3. Кто заполняет `EnumInfo+20`.**
`NSCam::CamDeviceManagerImp::enumDeviceLocked()` (vaddr `0x437c`) после
`IMetadataProvider::create(i)` вызывает шесть виртуальных методов провайдера:

| call site | vtable-слот | пишет в | что это |
|---|---|---|---|
| `0x4458` | `+32` | `EnumInfo+8` | `getDeviceVersion()` (перекрывается prop `debug.camera.force_device`: `1`→`0x100`, `3`→`0x302`, см. `0x442c` `property_get`+`atoi`) |
| `0x4468` | `+24` | `EnumInfo+12` | `getStaticCharacteristics()` |
| `0x4478` | `+36` | `EnumInfo+16` | `getDeviceFacing()`, причём через `clz/lsr #5`, т.е. `facing = (mtk_facing == 0) ? 1 : 0` — конверсия MTK→Android |
| `0x448e` | `+40` | `EnumInfo+20` | **`getDeviceWantedOrientation()`** |
| `0x449e` | `+44` | `EnumInfo+24` | `getDeviceSetupOrientation()` (в `camera_info` не попадает) |
| `0x44ae` | `+48` | `EnumInfo+28` | `getDeviceHasFlashLight()` |

Слот `+40` идёт сразу за `getDeviceFacing()` (`+36`), и порядок совпадает с
порядком экспортов в `libcam.metadataprovider.so`, поэтому привязка
`+40 = getDeviceWantedOrientation` — не догадка, а следствие двух независимых
признаков (конверсия facing на `+36` и порядок методов).

**3.4. Хардкод.** `android::NSMetadataProvider::MetadataProvider::
getDeviceWantedOrientation()` в `libcam.metadataprovider.so`, vaddr `0x00016de8`:

```asm
16dea: add.w r5, r0, #28            ; &this->mStaticMetadata
16dee: ldr   r1, [pc, #56]          ; tag = 0x000F0012 (MTK_SENSOR_INFO_WANTED_ORIENTATION)
16df4: blx   IMetadata::entryFor(unsigned)
16dfc: blx   [vtable+12]            ; IEntry::isEmpty()
16e00: cbz   r0, 16e10              ; не пусто -> взять значение из метаданных
16e02: ldr   r5, [r6, #8]           ; this->mOpenId
16e04: cmp   r5, #0
16e06: ite   eq
16e08: moveq r0, #90                ; <-- main
16e0a: movne r0, #270               ; <-- front
16e0e: pop
16e10: ...                          ; entryFor(tag).itemAt(0) через [vtable+56]
```

Что `[vtable+12]` — это `isEmpty()`, подтверждается соседним
`getDeviceHasFlashLight()` (`0x16e4c`): там при ненулевом результате того же
слота возвращается `false`, т.е. «записи нет → дефолт». Тег
`MTK_SENSOR_INFO_ORIENTATION` = `0x000F000B` читается в
`getDeviceSetupOrientation()` вообще без проверки на пустоту.

**3.5. Почему работает именно фолбэк.** Таблицы статических метаданных
скомпилированы в блобы **только для референсных сенсоров MediaTek**:

```
constructCustStaticMetadata_DEVICE_CAMERA_SENSOR_DRVNAME_GC2355_MIPI_RAW  @0x16ba0
                                              ..._GC2145_MIPI_YUV        @0x16f2c
                                              ..._IMX135_MIPI_RAW        @0x172b8
                                              ..._GC0310_MIPI_YUV        @0x17644
                                              ..._IMX219_MIPI_RAW        @0x179d0
```

(в каждой из них — своя пара `mov #90` / `mov #270`). FACT: строк и символов
`..._S5K4H8_...` / `..._S5K5E8_...` **нет ни в одном** блобе
(`libcam.halsensor.so`, `libcam.metadataprovider.so`, `libcameracustom.so`,
`camera.mt6737m.so`); `strings | grep -oE SENSOR_DRVNAME_[A-Z0-9_]+ | sort -u`
даёт ровно те же пять имён. Механизм подгрузки —
`MetadataProvider::impConstructStaticMetadata_by_SymbolName()`, т.е. поиск по
имени символа; для наших сенсоров он не находит ничего, `WANTED_ORIENTATION`
остаётся незаполненным, и срабатывает хардкод `mOpenId == 0 ? 90 : 270`.

INFERENCE: наблюдаемые `Orientation: 90` для camera 0 — это ровно эта константа.

**3.6. Свойства (property) не помогают.** FACT: поиск по строкам всех `.so` в
`vendor/meizu/m5c/proprietary` на `(ro|persist|debug|mtk)\.[…](orient|rotat)[…]`
даёт единственное попадание — `ro.sf.hwrotation` (поворот всего SurfaceFlinger).
FACT (родительская сессия): на устройстве `getprop | grep -i -E "orient|camera"`
даёт только `camera.disable_zsl_mode`, `ro.camera.disable_zsl_mode`,
`ro.camera.sound.forced`. REJECTED: «переопределить prop-ом» — переопределять
нечего.

## 4. Ядерная сторона: сенсор уже перевёрнут драйвером

FACT (`/home/valakas/m5c/android_kernel_meizu_m5c/drivers/misc/mediatek/imgsensor/src/mt6735m/`):

| драйвер | `.mirror` | `sensor_output_dataformat` | вызов |
|---|---|---|---|
| `s5k4h8_mipi_raw/s5k4h8mipi_Sensor.c` (main) | `IMAGE_HV_MIRROR` (стр. 231) | `SENSOR_OUTPUT_FORMAT_RAW_Gb` (стр. 216) | `set_mirror_flip(IMAGE_HV_MIRROR)` жёстко во **всех** режимах (стр. 4397, 4445, 4463, 4484, 4504) |
| `s5k5e8yx_mipi_raw/s5k5e8yxmipiraw_Sensor.c` (sub) | `IMAGE_NORMAL` (стр. 173) | `SENSOR_OUTPUT_FORMAT_RAW_Gr` (стр. 161) | `set_mirror_flip(imgsensor.mirror)` |

FACT: `set_mirror_flip()` в S5K4H8 пишет `0x0101 = 0x03` для `IMAGE_HV_MIRROR`
(комментарий самого драйвера помечает этот случай как «Gb»), `0x00` для
`IMAGE_NORMAL` — «Gr». Объявленный порядок Байера **согласован** с включённым
H+V-зеркалом: драйвер внутренне непротиворечив.

INFERENCE: H+V-зеркало тождественно повороту на 180°, значит поток, который HAL
отдаёт для camera 0, повёрнут на 180° относительно того, что описывает `90`.
`CameraInfo.orientation` по контракту Android — «угол, на который нужно повернуть
кадр по часовой, чтобы он смотрелся верно на экране в его естественной
ориентации», т.е. описание **доставляемого изображения**, а не кристалла.
Правдивое значение — **270**.

Альтернатива в ядре (`.mirror` → `IMAGE_NORMAL` **и** `dataformat` → `RAW_Gr`,
иначе поедет Байер и сломается цвет) не выбрана: это две связанные правки в
чужом дереве, задевающие активную цветовую линию. Кто из двух звеньев отличается
от стока — открытый вопрос, см. §8.

## 5. REJECTED: таблица `getSensorOrientation()` в `libcameracustom.so`

FACT: `NSCamCustomSensor::getSensorOrientation()` возвращает адрес const-структуры
в `.rodata`. Заглушка из двух инструкций:

```
arm    0x00101f74: ldr r0,[pc,#4]; add r0,pc; bx lr
       литерал 0x00c9379e + pc 0x00101f7a       -> vaddr 0x00d95718
       .rodata Addr 0x001046f0 / Off 0x000fe6f0 -> файловое смещение 0x00d8f718
arm64  0x0014e484: adrp x0,0xde1000; add x0,x0,#88; ret -> vaddr 0x00de1058
       .rodata Addr 0x0014f930 / Off 0x0012d930 -> файловое смещение 0x00dbf058
```

По обоим смещениям — `5a000000 0e010000 5a000000 00000000`, т.е.
`{ main=90, sub=270, main2=90, unused=0 }`. Совпадение `main=90` с показанным
`dumpsys` выглядело как объяснение — и оказалось совпадением.

FACT (проверка на железе, родительская сессия 2026-08-17): патч `main=270`
(md5 `888e060fa07af624f9cf7bb95ab0239a`) залит в `/system/lib/libcameracustom.so`,
`setprop ctl.restart media`, 12 с — `dumpsys media.camera` показывает
**по-прежнему `Orientation: 90`**. Второй прогон с `main=270` **и** `main2=270`
(md5 `e72abb9403de33087cc4fcbfc19d5ad0`), 14 с — снова `90`. Оригинал восстановлен
(md5 вернулся к `d4b5c4b1…`).

FACT (объяснение промаха): единственный потребитель символа —
`libcam.halsensor.so`, и оба его call site (`0x12802`, `0x12936`, второй — рядом с
`isRetFakeMainOrientation()`) лежат внутри
`ImgSensorDrv::sendCommand(SENSOR_DEV_ENUM, …)`, т.е. значение идёт **вниз, в
ядерный драйвер**, а не в `camera_info`. `isRetFakeSubOrientation()` возвращает 0
(`mov w0,#0; ret`), «поддельный» путь выключен.

INFERENCE: моя первая версия связала «единственный импортёр символа» с «источник
для camera_info» без проверки call site. Это и была ошибка. Правило на будущее:
для прибилда доказательством является не наличие символа, а **функция, в которой
находится call site**, и подтверждающая правка на железе.

Эту таблицу трогать **не надо**: она уходит в `sendCommand` и может влиять на
другое поведение драйвера. `patch_camera_orientation.py --check` печатает её
только для справки и писать в неё отказывается.

## 6. Правка

Занопить условие в фолбэке, чтобы он отдавал 270 в обеих ветках:

```
0x00016e02  ldr   r5,[r6,#8]     ; остаётся, результат больше не нужен
0x00016e04  cmp   r5,#0          ; остаётся
0x00016e06  ite eq / moveq #90   ; 0c bf 5a 20  ->  00 bf 00 bf  (nop; nop)
0x00016e0a  movne.w r0,#270      ; f4 4f 87 70  ->  теперь безусловный mov.w #270
```

Файловое смещение: `.text` Addr `0x7a20` / Off `0x6a20`, т.е. `vaddr − 0x1000`
→ **`0x00015E06`** в `lib/libcam.metadataprovider.so`.

Область действия — ровно camera 0: ветка front уже возвращала 270, так что её
поведение не меняется, а сам фолбэк срабатывает только для сенсоров без таблицы
метаданных (у нас — оба). Ветка «запись в метаданных есть» не тронута.

Инструмент (правка воспроизводима и рецензируема, а не «кто-то подправил байтик»):

```
device/meizu/m5c/patch_camera_orientation.py
  --check  <lib...>   # показать состояние (по умолчанию)
  --apply  <lib>      # main -> 270
  --revert <lib>      # вернуть сток 90/270
```

Скрипт опознаёт блоб по размеру, требует, чтобы за патч-местом стоял
`mov.w r0,#270`, принимает только «сток» или «уже пропатчено», идемпотентен.

Результат: md5 `a694265bdc1265e61538012b365859db`
(сток — `4bd55c6520af555499b8bff19814abbe`).

### Живая проверка (без пересборки ROM)

Патченный файл лежит на девбоксе: `/tmp/libcam.metadataprovider.main270.so`,
md5 `a694265bdc1265e61538012b365859db`. Записи в `/system` делает родительская
сессия; каждая команда — отдельный вызов `dev.sh` (он ломает `;` внутри строки):

```sh
D=/home/n8n/.claude/skills/devbox/scripts/dev.sh
S=710HVBR923RYK
$D adb -s $S shell "mount -o rw,remount /system"
$D adb -s $S shell "cp /system/lib/libcam.metadataprovider.so /data/local/tmp/libcam.metadataprovider.so.orig"
$D adb -s $S push /tmp/libcam.metadataprovider.main270.so /system/lib/libcam.metadataprovider.so
$D adb -s $S shell "chmod 644 /system/lib/libcam.metadataprovider.so"
$D adb -s $S shell "setprop ctl.restart media"
$D adb -s $S shell "dumpsys media.camera" | grep -i Orientation
```

Доказательство: `Orientation: 270` вместо `90`, затем владелец открывает
камеру — превью ровное, снимок ровный. Откат: положить назад
`/data/local/tmp/libcam.metadataprovider.so.orig` и `setprop ctl.restart media`.

Если `dumpsys` снова покажет `90` — фолбэк не тот путь, значит
`MTK_SENSOR_INFO_WANTED_ORIENTATION` где-то всё-таки заполняется, и надо искать,
кто пишет тег `0x000F0012` (следующий кандидат —
`HalSensorList::buildStaticInfo()` в `libcam.halsensor.so`, vaddr `0xf525`).

### Постоянная правка

После подтверждения на железе:

```sh
python3 device/meizu/m5c/patch_camera_orientation.py --apply \
  vendor/meizu/m5c/proprietary/lib/libcam.metadataprovider.so
```

64-битная копия (`lib64`, 321312 B) **не** тронута: mediaserver её не грузит
(FACT §1), а её arm64-код содержит другую последовательность (`csel`/ветвление),
для которой смещение надо выводить отдельно. Асимметрия сознательная и
зафиксирована здесь; если 64-битный HAL когда-нибудь понадобится, вывести
смещение тем же способом (символ → `adrp/add` → `.rodata`/`.text` Addr vs Off).

Сознательно **не сделано до подтверждения**: правленый блоб в git. Закоммичены
документ и скрипт.

### Компромиссы и альтернативы

- **Правка `.rodata`/`.text` в прибилде** (выбрано). Плюсы: 4 байта, ноль влияния
  на другие линии (цвет, фонарик), проверяемо на живой системе за две минуты.
  Минусы: живёт в бинарнике, при повторном `extract-files.sh` затирается.
  Митигация: скрипт в дереве + эта запись.
- **Добавить настоящую таблицу метаданных для S5K4H8/S5K5E8** (символы
  `constructCustStaticMetadata_DEVICE_*_SENSOR_DRVNAME_S5K4H8_MIPI_RAW`). Это
  «правильный» путь MTK и он заодно закрыл бы прочие дефолты, но требует своей
  библиотеки в цепочке `dlsym` mediaserver-а, т.е. патча `DT_NEEDED` в блобе —
  дороже и рискованнее, чем 4 байта.
- **`CameraWrapper` (канонический приём LOS)**: свой `camera.mt6737m.so` в device
  tree, `dlopen` переименованного вендорского модуля и правка
  `camera_info.orientation` в `get_camera_info`. Устойчив к переизвлечению
  блобов, но требует переименования блоба в `proprietary-files-mtk.txt`,
  перегенерации vendor-`.mk` для 32 и 64 бит и корректной проброски всех полей
  `camera_module_t` (включая `set_torch_mode` и `get_vendor_tag_ops`). Фонарик и
  камера сейчас в активной работе других агентов — держим как план Б.
- **Правка `frameworks/av`** отвергнута: дерево ROM общее с m681, глобальная
  подмена ориентации сломает другой аппарат.

## 7. Фронтальная камера

FACT: `Number of camera devices: 1` — фронталка не перечисляется, проверить её
ориентацию нечем. FACT: её драйвер зеркало не включает (`IMAGE_NORMAL` +
`RAW_Gr`), а фолбэк для `mOpenId != 0` и до, и после правки даёт 270 — штатное
значение для фронталки. INFERENCE: правка её не касается; когда фронталка
заведётся, значение перепроверить.

## 8. Открытые вопросы

1. Кто из двух звеньев отличается от стока — ядерное `IMAGE_HV_MIRROR` или
   метаданные — не установлено. Falsify: снять стоковое ядро (в разделе
   `recovery` живёт TWRP, собранный на стоковом ядре 3.18.19) и найти в его
   mode-функциях S5K4H8 запись `0x0101`: `0x03` → сток тоже зеркалит,
   `0x00` → расхождение в нашем порте. **Артефакт отсутствует**: стокового
   `boot.img`/исходников m5c на build station нет (`/home/valakas/m5c/*.img` —
   все наши сборки, `decompiled_src/` пуст). Пока не сделано — «правка в ядре
   была бы правильнее» остаётся HYPOTHESIS.
2. Отсутствие таблиц метаданных для S5K4H8/S5K5E8 (§3.5) — это не только
   ориентация: по тому же фолбэк-пути идут и другие статические
   характеристики. Может пересекаться с цветовой линией (`camotp`); передано
   как наблюдение, не как вывод.
3. 64-битная `libcam.metadataprovider.so` осталась стоковой (§6).
