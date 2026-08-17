# M5c — лента «камера повёрнута на 180°»

Отдельная линия работ: и видоискатель, и сохранённые снимки перевёрнуты на 180°
(подтверждено владельцем, 2026-08-17). Цвет (радужные пятна / отсутствие OTP)
— **другая** линия, её ведёт отдельный агент; здесь цвет не трогаем.

Дата: 2026-08-17. Устройство: `710HVBR923RYK`, LOS 14.1 (userdebug, SELinux
Permissive, adb-shell = root `u:r:su:s0`).

**Итог линии.** Значение, которое видит Android, пишет таблица
`constructCustStaticMetadata_DEVICE_CAMERA_COMMON` в
`libcam.metadataprovider.so` — MTK-дефолт «facing 0 → 90, facing 1 → 270».
Правка — 4 байта: одна константа `mov.w sl,#90` → `mov.w sl,#270` (§4).
Две предыдущие версии этого документа указывали на другие места; **обе
опровергнуты на железе**, разборы сохранены в §6 как REJECTED — вместе с
причиной, почему они выглядели правдоподобно.

## 1. Идентичность артефактов и живого процесса

FACT: `CameraService` живёт внутри `/system/bin/mediaserver` (отдельного
`/system/bin/cameraserver` в этой сборке нет).

FACT: HAL-модуль, реально загруженный в mediaserver (pid 2478,
`/proc/2478/maps`, сегменты `r-xp`):

```
/system/lib/hw/camera.mt6737m.so
/system/lib/libmeizucamera.so
/system/lib/libmtkcamera_client.so
/system/lib/libcam.metadataprovider.so
/system/lib/libcam.halsensor.so
/system/lib/libcameracustom.so
```

Всё 32-битное; 64-битные копии в `/system/lib64/` есть, но не грузятся.
FACT (родительская сессия): каталога `/system/vendor/lib/` на устройстве нет,
поэтому `preloadM681MtkCameraDeps()` из `CameraService.cpp` молча не делает
ничего.

REJECTED: «ориентацию подменяет Meizu». `libmeizucamera.so` экспортирует только
`MZCamera`/`MZ_CamClient` (вспышка, torch, температура, scene mode, JNI) —
ни `camera_info`, ни orientation в нём нет.

| файл | размер | md5 (сток) |
|---|---|---|
| `proprietary/lib/libcam.metadataprovider.so` | 222828 | `4bd55c6520af555499b8bff19814abbe` |
| `proprietary/lib/libcameracustom.so` | 16866932 | `d4b5c4b1b34b13285edaff50fe45858c` |
| `proprietary/lib64/libcameracustom.so` | 17138288 | `6c6901b416d6e2b457f50ab1cd169872` |

## 2. Ground truth: HAL сам печатает ориентацию

FACT: в `camera.mt6737m.so` есть формат
`[%s] [0x%02x] DeviceVersion:0x%x metadata:%08p facing:%d orientation(wanted/setup)=(%d/%d)`,
он печатается в `enumDeviceLocked`. Живой `logcat -d -v time`:

```
08-17 16:03:19.156 I/MtkCam/devicemgr( 2108): [enumDeviceLocked] i4DeviceNum=1
08-17 16:03:19.156 I/MtkCam/devicemgr( 2108): [enumDeviceLocked] [0x00] DeviceVersion:0x100 metadata:0xf5ee2000 facing:0 orientation(wanted/setup)=(90/90)
08-17 16:03:19.156 I/MtkCam/devicemgr( 2108): [enumDeviceLocked] [0xff] DeviceVersion:0x100 metadata:0x000000 facing:0 orientation(wanted/setup)=(0/0)
08-17 16:04:18.873 I/MtkCam/devicemgr( 2478): ... facing:0 orientation(wanted/setup)=(90/90)
```

Это **самая дешёвая проверка в этой линии** — быстрее и информативнее
`dumpsys media.camera`, и снимается без записи в `/system`. Использовать её
первой при любой следующей попытке.

FACT: строка от pid 2108 снята в прогоне, где была загружена **пропатченная**
`libcam.metadataprovider.so` с занопленным фолбэком (§6.2) — и всё равно `90/90`.
Два независимых вывода из одной строки:

- `setup = 90`, а `getDeviceSetupOrientation()` читает тег
  `MTK_SENSOR_INFO_ORIENTATION` (`0x000F000B`) **без** проверки на пустоту →
  значит тег в метаданных **есть** и равен 90;
- `wanted = 90` при занопленном фолбэке, который форсировал 270, → ветка
  фолбэка не выполнялась, т.е. `entryFor(0x000F0012).isEmpty()` = false →
  `MTK_SENSOR_INFO_WANTED_ORIENTATION` тоже **есть** и равен 90.

FACT: `dumpsys media.camera` в том же состоянии — `Number of camera devices: 1`,
`Camera 0 … Facing: BACK, Orientation: 90`. Приложениям (`org.cyanogenmod.snap`)
уходит 90.

INFERENCE: одна ошибка в 180° объясняет оба симптома. Camera1 считает поворот
превью как `(orientation − display_rotation)`, а поворот JPEG как
`(orientation + display_rotation)`; при нужных 270 и отданных 90 и превью, и
снимок уезжают ровно на 180°. Согласуется с тем, что кадр
`IMG_20260817_151905.jpg` — портретный 1920x2560, т.е. HAL повернул его на
объявленные 90°.

## 3. Полная цепочка

**3.1. Фреймворк ничего не хардкодит.** `CameraService::getCameraInfo()`
(`frameworks/av/services/camera/libcameraservice/CameraService.cpp:506-512`)
делает `mModule->getCameraInfo(cameraId, &info)` и копирует `info.orientation`
как есть; `generateShimMetadata()` (:544) кладёт то же значение в
`ANDROID_SENSOR_ORIENTATION` для HAL1-шима. Наши m681-патчи в этом файле
ориентацию не трогают.

**3.2. `camera.mt6737m.so`.** `CamDeviceManagerBase::getDeviceInfo(int, camera_info&)`
(vaddr `0x4c24`) копирует поля из своего `EnumInfo`:

```
0x4c9a  EnumInfo[8]  -> camera_info[8]  = device_version
0x4c9e  EnumInfo[16] -> camera_info[0]  = facing
0x4ca2  EnumInfo[20] -> camera_info[4]  = orientation
0x4ca6  EnumInfo[12] -> camera_info[12] = static_camera_characteristics
        camera_info[16] = resource_cost = 0, [20] = [24] = 0
```

**3.3. `CamDeviceManagerImp::enumDeviceLocked()`** (vaddr `0x437c`) после
`IMetadataProvider::create(i)` вызывает шесть виртуальных методов провайдера:

| call site | слот | пишет | что это |
|---|---|---|---|
| `0x4458` | `+32` | `EnumInfo+8` | `getDeviceVersion()`; перекрывается prop `debug.camera.force_device` (`1`→`0x100`, `3`→`0x302`, см. `property_get` на `0x442c`) |
| `0x4468` | `+24` | `EnumInfo+12` | `getStaticCharacteristics()` |
| `0x4478` | `+36` | `EnumInfo+16` | `getDeviceFacing()`, через `clz/lsr #5`: `facing = (mtk_facing == 0) ? 1 : 0` |
| `0x448e` | `+40` | `EnumInfo+20` | **`getDeviceWantedOrientation()`** |
| `0x449e` | `+44` | `EnumInfo+24` | `getDeviceSetupOrientation()` (в `camera_info` не идёт, но печатается в лог) |
| `0x44ae` | `+48` | `EnumInfo+28` | `getDeviceHasFlashLight()` |

**3.4. Провайдер отдаёт значение из метаданных.**
`MetadataProvider::getDeviceWantedOrientation()` (`0x16de8`) читает тег
`0x000F0012`, и, поскольку запись есть (§2), возвращает её значение
(`itemAt(0)` через `[vtable+56]`), а не хардкод.

**3.5. Кто пишет теги.** `HalSensorList::buildStaticInfo(Info const&, IMetadata&)`
в `libcam.halsensor.so` (`0xf524`) в цикле собирает имена символов через
`String8::format(...)` по списку категорий (`CAMERA`, `LENS`, `SENSOR`,
`FLASHLIGHT`, `TUNING_3A`; в провайдере ещё `REQUEST`, `SCALER`, `FEATURE`) и
дёргает загрузчик; **при промахе форматирует второе имя и пробует снова** —
двухуровневый поиск «по сенсору, иначе дефолт» (`0xf548`…`0xf5a4`, второй базис
берётся из `[sp,#8]`).

FACT: таблицы первого уровня в блобах есть **только** для референсных сенсоров
MediaTek — `GC0310_MIPI_YUV`, `GC2145_MIPI_YUV`, `GC2355_MIPI_RAW`,
`IMX135_MIPI_RAW`, `IMX219_MIPI_RAW` (25 символов в `libcam.halsensor.so`,
16 в `libcam.metadataprovider.so`). Ни одного `..._S5K4H8_...` / `..._S5K5E8_...`
нет; `strings | grep -oE 'SENSOR_DRVNAME_[A-Z0-9_]+' | sort -u` даёт ровно те же
пять имён.

INFERENCE: для наших сенсоров всегда берётся дефолт —
`constructCustStaticMetadata_DEVICE_CAMERA_COMMON` (`0x7bf4`,
`libcam.metadataprovider.so`).

**3.6. Хардкод в COMMON-таблице.** Литеральный пул на `0x7f38` = `0x000F000B`
(`MTK_SENSOR_INFO_ORIENTATION`), на `0x7f3c` = `0x000F0012`
(`..._WANTED_ORIENTATION`). Код:

```asm
7cb6: ldr.w r7, [sl]              ; селектор (facing)
7cba: cbz   r7, 7cc8              ; 0 = main  -> ветка 90
7cbc: cmp   r7, #1
7cbe: mov.w r7, #270              ; 1 = front -> 270
7cc2: beq.w 7e8a                  ; ветка front пишет тот же тег значением r7
7cc8: IEntry(tag 0x000F000B)      ; ORIENTATION
7cd0: mov.w sl, #90               ; <-- НАША КОНСТАНТА
7cd6: str.w sl, [sp, #20]
7ce0: IEntry::push_back(int); IMetadata::update() через [vtable+28]
7d28: IEntry(tag 0x000F0012)      ; WANTED_ORIENTATION
7d30: str.w sl, [sp, #20]         ; ТОТ ЖЕ sl -> одна правка закрывает оба тега
7d3c: IEntry::push_back(int); IMetadata::update()
```

Ровно это и печатается как `(wanted/setup)=(90/90)`.

Замечание на будущее: `movs r6,#90` на `0x7ec6` и `movs r6,#66` на `0x7d0a` —
это **номера строк** в лог-вызовах, а не ориентация. Слепой `grep '#90'` по
дизассемблеру даёт ложные попадания; проверять контекст обязательно.

**3.7. Свойств нет.** FACT: поиск по строкам всех `.so` в
`vendor/meizu/m5c/proprietary` на `(ro|persist|debug|mtk)\.[…](orient|rotat)[…]`
даёт единственное `ro.sf.hwrotation` (поворот всего SurfaceFlinger). FACT
(родительская сессия): на устройстве `getprop | grep -i -E "orient|camera"` →
только `camera.disable_zsl_mode`, `ro.camera.disable_zsl_mode`,
`ro.camera.sound.forced`. REJECTED: «переопределить prop-ом».

## 4. Правка

```
файл  vendor/meizu/m5c/proprietary/lib/libcam.metadataprovider.so
смещение 0x00006CD0   (vaddr 0x7cd0; .text Addr 0x7a20 / Off 0x6a20, т.е. −0x1000)
было  4f f0 5a 0a     mov.w sl, #90
стало 4f f4 87 7a     mov.w sl, #270
```

Та же длина инструкции, ничего не сдвигается. Меняется только ветка
`facing == 0`, т.е. **camera 0**; ветка фронталки уже давала 270. Оба тега
(`ORIENTATION` и `WANTED_ORIENTATION`) берут значение из того же `sl`, поэтому
правка одна.

Инструмент: `device/meizu/m5c/patch_camera_orientation.py`
(`--check` / `--apply` / `--revert`). Он опознаёт блоб по размеру, принимает
только «сток» или «уже пропатчено», идемпотентен, и в `--check` печатает заодно
состояние обоих тупиков из §6 (включая предупреждение, если фолбэк остался
занопленным).

Результат: md5 `f4932f4f448570491749c1414e8d6391` (сток
`4bd55c6520af555499b8bff19814abbe`), размер не меняется.

### Живая проверка (без пересборки ROM)

Файл на девбоксе: `/tmp/libcam.metadataprovider.common270.so`, md5
`f4932f4f448570491749c1414e8d6391`. Запись в `/system` делает родительская
сессия; каждая команда — отдельный вызов `dev.sh` (он ломает `;` в строке):

```sh
D=/home/n8n/.claude/skills/devbox/scripts/dev.sh
S=710HVBR923RYK
$D adb -s $S shell "mount -o rw,remount /system"
$D adb -s $S shell "cp /system/lib/libcam.metadataprovider.so /data/local/tmp/libcam.metadataprovider.so.orig"
$D adb -s $S push /tmp/libcam.metadataprovider.common270.so /system/lib/libcam.metadataprovider.so
$D adb -s $S shell "chmod 644 /system/lib/libcam.metadataprovider.so"
$D adb -s $S shell "setprop ctl.restart media"
$D adb -s $S shell "logcat -d -v time" | grep -i orientation | tail -3
$D adb -s $S shell "dumpsys media.camera" | grep -i Orientation
```

Доказательство (два независимых): в логе
`[enumDeviceLocked] [0x00] … facing:0 orientation(wanted/setup)=(270/270)`
и в `dumpsys` `Orientation: 270`. Затем владелец открывает камеру — превью
ровное, снимок ровный. Откат: вернуть
`/data/local/tmp/libcam.metadataprovider.so.orig` и `setprop ctl.restart media`.

**Если лог покажет `(90/90)` при пропатченном блобе** — значит `[0x00]` идёт не
через COMMON-таблицу; следующий шаг тогда не гадать, а поймать сам факт
подстановки: включить более подробный лог MtkCam
(`setprop debug.camera.log 1`, `setprop debug.MtkCam.log 3`) и перечитать
`logcat` на строках `MtkCam/MetadataProvider` — провайдер логирует, по какому
имени символа он нашёл или не нашёл таблицу.

### Постоянная правка

После подтверждения на железе:

```sh
python3 device/meizu/m5c/patch_camera_orientation.py --apply \
  vendor/meizu/m5c/proprietary/lib/libcam.metadataprovider.so
```

64-битная копия (`lib64`, 321312 B) не тронута: mediaserver её не грузит
(FACT §1), а в arm64-коде последовательность другая, смещение надо выводить
отдельно. Асимметрия сознательная.

Сознательно **не сделано до подтверждения**: правленый блоб в git.
Закоммичены документ и скрипт.

## 5. Ядерная сторона: почему 270 — это правда, а не подгонка

FACT (`/home/valakas/m5c/android_kernel_meizu_m5c/drivers/misc/mediatek/imgsensor/src/mt6735m/`):

| драйвер | `.mirror` | `sensor_output_dataformat` | вызов |
|---|---|---|---|
| `s5k4h8_mipi_raw/s5k4h8mipi_Sensor.c` (main) | `IMAGE_HV_MIRROR` (стр. 231) | `SENSOR_OUTPUT_FORMAT_RAW_Gb` (стр. 216) | `set_mirror_flip(IMAGE_HV_MIRROR)` жёстко во **всех** режимах (стр. 4397, 4445, 4463, 4484, 4504) |
| `s5k5e8yx_mipi_raw/s5k5e8yxmipiraw_Sensor.c` (sub) | `IMAGE_NORMAL` (стр. 173) | `SENSOR_OUTPUT_FORMAT_RAW_Gr` (стр. 161) | `set_mirror_flip(imgsensor.mirror)` |

FACT: `set_mirror_flip()` в S5K4H8 пишет `0x0101 = 0x03` для `IMAGE_HV_MIRROR`
(комментарий драйвера помечает этот случай «Gb»), `0x00` для `IMAGE_NORMAL` —
«Gr». Объявленный порядок Байера согласован с включённым H+V-зеркалом: драйвер
внутренне непротиворечив.

INFERENCE: H+V-зеркало тождественно повороту на 180°, значит поток для camera 0
повёрнут на 180° относительно объявленных 90. `CameraInfo.orientation` по
контракту Android — «угол, на который нужно повернуть кадр по часовой, чтобы он
смотрелся верно на экране в естественной ориентации», т.е. описание
**доставляемого изображения**. Правдивое значение — 270.

Альтернатива в ядре (`.mirror` → `IMAGE_NORMAL` **и** `dataformat` → `RAW_Gr`;
одну без другой нельзя — поедет Байер и сломается цвет) не выбрана: две
связанные правки в чужом дереве, задевающие активную цветовую линию.

## 6. REJECTED: два тупика (оба проверены на железе)

### 6.1. Таблица `getSensorOrientation()` в `libcameracustom.so`

FACT: `NSCamCustomSensor::getSensorOrientation()` — заглушка из двух инструкций,
возвращающая адрес const-структуры в `.rodata`:

```
arm    0x00101f74: ldr r0,[pc,#4]; add r0,pc; bx lr
       литерал 0x00c9379e + pc 0x00101f7a       -> vaddr 0x00d95718
       .rodata Addr 0x001046f0 / Off 0x000fe6f0 -> файловое смещение 0x00d8f718
arm64  0x0014e484: adrp x0,0xde1000; add x0,x0,#88; ret -> vaddr 0x00de1058
       .rodata Addr 0x0014f930 / Off 0x0012d930 -> файловое смещение 0x00dbf058
```

Обе копии содержат `5a000000 0e010000 5a000000 00000000`, т.е.
`{ main=90, sub=270, main2=90, unused=0 }`. Совпадение `main=90` с `dumpsys`
выглядело как объяснение — и было совпадением.

FACT (железо, родительская сессия): патч `main=270` (md5
`888e060fa07af624f9cf7bb95ab0239a`) и затем `main=270` + `main2=270` (md5
`e72abb9403de33087cc4fcbfc19d5ad0`) заливались в `/system/lib/libcameracustom.so`,
`setprop ctl.restart media`, 12–14 с; `dumpsys media.camera` оба раза — `90`.
`/proc/<pid>/maps` подтверждал, что грузится именно этот файл (inode 1235).
Оригинал восстановлен (`d4b5c4b1…`).

FACT (причина промаха): единственный импортёр символа — `libcam.halsensor.so`,
и **оба** его call site (`0x12802`, `0x12936`) лежат внутри
`ImgSensorDrv::sendCommand(SENSOR_DEV_ENUM, …)`, т.е. значение уходит вниз, в
ядерный драйвер, а не в `camera_info`. `isRetFakeSubOrientation()` возвращает 0
(`mov w0,#0; ret`), «поддельный» путь выключен.

Эту таблицу трогать не надо: она уходит в `sendCommand`.

### 6.2. Хардкод-фолбэк внутри `getDeviceWantedOrientation()`

FACT: в `libcam.metadataprovider.so` (`0x16de8`) действительно есть хардкод:

```asm
16dfc: blx [vtable+12]        ; IEntry::isEmpty()
16e00: cbz r0, 16e10          ; не пусто -> взять значение из метаданных
16e02: ldr r5,[r6,#8]         ; mOpenId
16e06: ite eq
16e08: moveq r0, #90
16e0a: movne r0, #270
```

(что `[vtable+12]` — это `isEmpty()`, подтверждает соседний
`getDeviceHasFlashLight()` на `0x16e4c`: при ненулевом результате того же слота
возвращается дефолт `false`).

FACT (железо, родительская сессия): `ite eq / moveq #90` заноплены на смещении
`0x00015E06` (md5 `a694265bdc1265e61538012b365859db`), файл залит, `media`
перезапущен (pid 376 → 2108), `/proc/2108/maps` подтверждает загрузку именно
этой библиотеки — `dumpsys` по-прежнему `90`.

FACT (причина промаха): фолбэк недостижим, потому что COMMON-таблица тег всё же
ставит (§2, вывод из `setup=90` при отсутствии у `getDeviceSetupOrientation`
всякой проверки на пустоту). Моя ошибка была в шаге «таблицы для наших сенсоров
нет → тег не заполнен»: я не учёл **второй уровень** поиска символа в
`buildStaticInfo` (§3.5), т.е. дефолтную таблицу.

Урок, общий для обоих тупиков: в прибилдах доказательством является не наличие
символа и не найденная константа, а **лог самого HAL** (§2) или замер после
правки. Обе мои ошибки — «нашёл 90 в подходящем месте» без проверки, что
исполняется именно этот путь.

## 7. Почему не «добавить нормальную таблицу метаданных»

Вопрос родительской сессии: если корень в том, что для S5K4H8/S5K5E8 нет
таблицы, честнее добавить её, а не гнуть дефолт. Оценка:

- Таблицы — это **скомпилированный C++ внутри блобов** (`IEntry(tag)`,
  `push_back<int>` с `Type2Type`, `IMetadata::update()` через `[vtable+28]`).
  Вендорского исходника (`custom/<proj>/hal/…`) у нас нет — в дереве ROM нет
  `vendor/mediatek` вовсе.
- Поиск идёт через `dlsym` по имени, поэтому теоретически хватило бы своей
  библиотеки в адресном пространстве mediaserver, экспортирующей
  `constructCustStaticMetadata_DEVICE_CAMERA_SENSOR_DRVNAME_S5K4H8_MIPI_RAW`.
  Это было бы даже безопасно для m681 (имя символа содержит имя сенсора, у
  m681 сенсоры другие). Но: библиотеку надо затащить в процесс (правка
  `DT_NEEDED` в блобе либо добавление символа в системную библиотеку, которую
  mediaserver и так грузит), и главное —
- таблица первого уровня **заменяет всю категорию** `DEVICE_CAMERA`, а не
  дополняет её. Нам пришлось бы воспроизвести все теги, которые ставит
  COMMON-таблица (это ~1.5 КБ кода на категорию), реализовав их против
  реверс-инженерного C++ ABI. Любой пропущенный тег — молча потерянная
  характеристика камеры.

INFERENCE: правильный путь требует либо вендорского исходника, которого нет,
либо переписывания целой категории метаданных по реверсу — с риском потерять
теги. Поэтому берём прагматичный вариант: 4 байта в дефолтной таблице, которые
меняют ровно одно значение (ориентацию задней камеры) и ничего больше.
Компромисс: правка живёт в бинарнике и будет затёрта повторным
`extract-files.sh`; митигация — скрипт в дереве и эта запись.

Альтернатива, устойчивая к переизвлечению, — `CameraWrapper` по канону LOS
(свой `camera.mt6737m.so`, `dlopen` переименованного вендорского модуля, правка
`camera_info.orientation` в `get_camera_info`). Требует переименования блоба в
`proprietary-files-mtk.txt`, перегенерации vendor-`.mk` для 32 и 64 бит и
корректной проброски всех полей `camera_module_t` (включая `set_torch_mode` и
`get_vendor_tag_ops`); фонарик и камера сейчас в активной работе других
агентов — держим как план Б. Правка `frameworks/av` отвергнута: дерево ROM
общее с m681.

## 8. Фронтальная камера

FACT: `Number of camera devices: 1` — фронталка не перечисляется, проверить
нечем. FACT: её драйвер зеркало не включает (`IMAGE_NORMAL` + `RAW_Gr`), а
ветка `facing == 1` COMMON-таблицы и до, и после правки даёт 270 — штатное
значение для фронталки. INFERENCE: правка её не касается.

## 9. Открытые вопросы

1. Кто из двух звеньев отличается от стока — ядерное `IMAGE_HV_MIRROR` или
   метаданные — не установлено. Важно, что стоковый Flyme использовал **эти же
   блобы**, т.е. и на стоке ориентация приходила из COMMON-таблицы как 90;
   INFERENCE: значит на стоке зеркала в драйвере, скорее всего, не было. Это
   HYPOTHESIS. Falsify: снять стоковое ядро (в разделе `recovery` живёт TWRP,
   собранный на стоковом ядре 3.18.19) и найти в mode-функциях S5K4H8 запись
   `0x0101`: `0x03` → сток тоже зеркалит, `0x00` → расхождение в нашем порте.
   **Артефакт отсутствует**: стокового `boot.img`/исходников m5c на build
   station нет (`/home/valakas/m5c/*.img` — все наши сборки, `decompiled_src/`
   пуст).
2. Отсутствие таблиц первого уровня для S5K4H8/S5K5E8 касается не только
   ориентации: по дефолтному пути идут **все** статические характеристики наших
   сенсоров. Передано в линию `camotp` как наблюдение, не как вывод.
3. 64-битная `libcam.metadataprovider.so` осталась стоковой (§4).
