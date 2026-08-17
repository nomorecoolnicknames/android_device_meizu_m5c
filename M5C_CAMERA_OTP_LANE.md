# M5C — камера: калибровка модуля (cam_cal / OTP) и имена драйверов сенсоров

Отдельная дорожка работ по цвету камеры m5c. Ветка ядра `forge/camotp`
(worktree `/srv/forge/android/m5c/k-worktrees/camotp`, база `master d9c41e0e`).
Ориентацию 180° эта дорожка **не трогает** — ей занимается другой агент.

Правила разметки доказательств — по `/srv/forge/android/CLAUDE.md §2`.

---

## 1. Симптом

FACT: снимок `/sdcard/DCIM/Camera/IMG_20260817_151905.jpg` (JPEG 1920x2560):
геометрия и резкость нормальные, сломан только цвет — крупные плавные
радужные пятна (зелёный/маджента/циан) поверх правильной яркости.

FACT (числовой анализ того же файла, `PIL`/`numpy`):

| измерение | значение |
|---|---|
| Cb: min/max/std | 2 / 222 / 27.5 |
| Cr: min/max/std | 0 / 249 / 39.7 |
| доля клиппинга Cb/Cr | 0.000% / 0.001% |
| std Cb при блоках 2/16/32/64 px | 27.5 / 27.3 / 26.7 / 25.2 |
| corr(\|хрома\|, Y) по блокам 32 px | +0.308 |
| среднее \|хрома\| в интервалах Y [0,40) [40,80) [80,120) [120,160) [160,255) | 18.6 / 37.0 / 52.8 / 49.5 / 37.9 |

INFERENCE (из этих FACT): хрома не клиппована, её дисперсия почти целиком
низкочастотная (сохраняется при усреднении блоками 64 px), а амплитуда ошибки
растёт пропорционально сигналу до Y≈100 и потом поджимается гаммой. Это подпись
**пространственно-переменной мультипликативной ошибки поканального усиления**,
то есть неверной таблицы lens shading (LSC). Масштаб пятен ~100–240 px при
ширине 1920 соответствует сетке LSC ~17 узлов по горизонтали.

REJECTED «это цветовая шумность в темноте (сломанный chroma NR)»: ошибка хромы
максимальна не в самых тёмных блоках, а в средних (Y 80–120), см. таблицу выше.

REJECTED «сломана CCM»: FACT из логката (`isp_tuning_custom`, pid 376,
08-17 15:19:11.291) — матрица `519, 1772, 13 / 1989, 389, 1974 / 2044, 1910, 398`.
Это 11-битные знаковые числа: `519, -276, 13 / -59, 389, -74 / -4, -138, 398`,
сумма каждой строки ровно 256 (единица). Матрица корректная и мягкая.

REJECTED «сломан AWB»: `rgain 937, bgain 512, ggain 684` — глобальные
коэффициенты, они физически не могут дать пространственные пятна.

---

## 2. Что нашлось в стоке (байт-в-байт из образа)

Источник: `/home/valakas/m5c/kernel-reverse/vmlinux.elf` (стоковое ядро Flyme,
ELF с восстановленной таблицей символов; `PT_LOAD` offset `0x1c0` ↔ VA
`0xffffffc000080000`).

### 2.1 Стоковые пути и состав

FACT: OTP-драйверы стока живут **не** в `cam_cal`, а внутри дерева imgsensor,
рядом с драйвером сенсора (строки путей `__FILE__` в образе):

```
imgsensor/src/mt6735m/s5k4h8_{ofilm,st,holitech,sunwin}_mipi_raw/s5k4h8_*_otp_cal.c
imgsensor/src/mt6735m/s5k5e8_{st,qh,holitech,sunwin}_mipi_raw/s5k5e8_*_otp_cal.c
```

FACT: восемь узлов `/dev` (строки в образе, они же — имена class и chrdev):
`S5K4H8_OFILM_OTP`, `S5K4H8_ST_OTP`, `S5K4H8_HOLITECH_OTP`, `S5K4H8_SUNWIN_OTP`,
`S5K5E8_ST_OTP`, `S5K5E8_QH_OTP`, `S5K5E8_HOLITECH_OTP`, `S5K5E8_SUNWIN_OTP`.
Одна и та же строка идёт и в `class_create()`, и в `device_create()`
(проверено дизассемблированием `CAM_CAL_init` на `0xffffffc000f608e8`: аргумент
класса — `0xffffffc000e15f08` = `"S5K4H8_ST_OTP"`).

FACT: в нашем дереве до этой работы `drivers/misc/mediatek/cam_cal/src/`
содержал только `mt6735/imx135_otp`, `mt6735/imx219_eeprom` и общие eeprom'ы,
`CONFIG_MTK_CAM_CAL` в `m5c_defconfig` **вообще не задан**. Ни одного узла
`/dev/S5K*_OTP` наше ядро не создавало.

### 2.2 Главная камера: калибровка лежит в EEPROM, а не в сенсоре

FACT: `eeprom_gt24c64a_read8` каждого из четырёх драйверов S5K4H8
(`0xffffffc0005c0108`, `0x5c6d38`, `0x5cda00`, `0x5d4660`) — это

```
u8 cmd[2] = { addr >> 8, addr & 0xFF };  u16 val = 0;
iReadRegI2C(cmd, 2, (u8*)&val, 1, /* i2cId = */ 0xA0);
```

то есть **внешний i2c-EEPROM GT24C64A, 8-битный write id 0xA0** (7-битный 0x50),
двухбайтовый big-endian адрес, один байт данных. Скорость шины стоковый
`get_imgsensor_id` перед этим ставит в 300 кГц (`kdSetI2CSpeed(300)`).

FACT: ни стоковый DTB (`/home/valakas/m5c/kernel-reverse/meizu-m5c.dtb`), ни наш
`hq6737m_65_1mz_m0.dts` не описывают EEPROM: на `i2c@11007000` есть только
`camera_main@10`, `camera_main_af@18`, `camera_sub@3c`. Драйвер ходит к EEPROM
сырым хелпером, узел DT не нужен.

FACT: `s5k4h8_st_otp_cali` (`0xffffffc0005c7474`, декомпиляция
`/home/valakas/m5c/decompiled_src/sensor_s5k4h8.c:438`) заполняет глобальный
массив `s5k4h8_st_otp_data.Data` (база `0xffffffc0011df640`) так:

| Data[] | значение | источник в EEPROM |
|---|---|---|
| 0 | `0x01` (flag) | константа |
| 1..4 | `63 69 68 63` (CaliVer) | константа |
| 5..6 | SerialNum | `0x44`, `0x45` |
| 7..8 | не заполняются (нули) | — |
| 9..12 | unit AWB R/G, B/G (по u16 LE) | `0x2C`..`0x2F` |
| 13..16 | golden AWB R/G, B/G | `0x32`..`0x35` |
| 17..18 | AfInfinite | `0x42`, `0x43` |
| 19..20 | AfMacro | `0x46`, `0x47` |
| 21..22 | LscSize = `0x074C` = **1868** | константа |
| 23..1890 | **Lsc[1868]** | `0x51`..`0x7BC` |

(байты `0x30`,`0x31`,`0x36`,`0x37`,`0x48`,`0x49` читаются, но только печатаются)

Это в точности раскладка MTK «MTK format» cam_cal, та же, что у
`cam_cal/src/mt6735/imx135_otp` в нашем дереве.

INFERENCE: вот и потерянная таблица шейдинга — 1868 байт LSC на модуль,
которых HAL никогда не получал. Это замыкает §1: ошибка LSC ⇐ нет узла cam_cal
⇐ нет драйвера.

### 2.3 Фронтальная камера: только AWB, шейдинга нет вовсе

FACT: `s5k5e8_st_otp_cali` (`0xffffffc0005c4068`, декомпиляция
`sensor_s5k5e8.c:163`) читает OTP **самого сенсора**, страница 4:

```
write_cmos_sensor_8(0x0A00, 0x04);
write_cmos_sensor_8(0x0A02, 0x04);   /* страница 4 */
write_cmos_sensor_8(0x0A00, 0x01);   /* read enable */
udelay(1000);                        /* __const_udelay(0x418958) */
f0 = read(0x0A04); f1 = read(0x0A05); f2 = read(0x0A06);
base = (f2 == 1) ? 0x0A27 : (f1 == 1) ? 0x0A17 : 0x0A07;
Data[5 + i] = read(base + i), i = 0..13;   /* ровно 14 байт */
write_cmos_sensor_8(0x0A00, 0x04);
write_cmos_sensor_8(0x0A00, 0x00);
```

Заголовок `Data[0..4]` тот же (`01 63 69 68 63`), `LscSize` **остаётся нулём**.

FACT (по аргументам printk `R_G/B_G/Gold_R_G/Gold_B_G`): внутри 14 байт
`Data[9..12]` = golden AWB, `Data[13..16]` = unit AWB, `Data[5]` = module id.

INFERENCE: отсутствие `/dev/S5K5E8_*_OTP` стоит фронтальной камере только AWB
(глобальный цветовой сдвиг), радужных пятен там быть не может — шейдинга в её
OTP нет.

### 2.4 Как сток выбирает вариант модуля в рантайме

FACT (дизассемблирование `get_imgsensor_id`/`open` всех четырёх драйверов
S5K4H8, например `0xffffffc0005c6820`..`0x5c6d08`):

1. читается настоящий id сенсора самсунговской последовательностью
   `write(0x602C,0x4000); write(0x602E,0x0000); read(0x6F12)` → `0x4088`;
2. `kdSetI2CSpeed(300)`, затем `iReadRegI2C({0x00,0x01}, 2, &out, 1, 0xA0)` —
   **байт 0x0001 EEPROM = id вендора модуля**;
3. сравнение id вендора; при совпадении драйвер **подменяет** отдаваемый
   sensor id на «базовый + индекс варианта» и вызывает свой `*_otp_cali()`.

| сенсор | id вендора (адрес) | отдаваемый sensor id | drvname |
|---|---|---|---|
| S5K4H8 OFILM | 5 (EEPROM 0x0001) | 0x4088 | `s5k4h8ofilmmipiraw` |
| S5K4H8 ST | 8 | 0x4089 | `s5k4h8stmipiraw` |
| S5K4H8 HOLITECH | 9 | 0x408A | `s5k4h8holitechmipiraw` |
| S5K4H8 SUNWIN | 0x0A | 0x408B | `s5k4h8sunwinmipiraw` |
| S5K5E8 ST | 3 (OTP p4 0x0A07) | 0x5E80 | `s5k5e8stmipiraw` |
| S5K5E8 QH | 7 | 0x5E81 | `s5k5e8qhmipiraw` |
| S5K5E8 HOLITECH | 9 | 0x5E82 | `s5k5e8holitechmipiraw` |
| S5K5E8 SUNWIN | 0x0A | 0x5E83 | `s5k5e8sunwinmipiraw` |

### 2.5 Почему главная камера выдавала 5 МП и лезла в S5K5E8_ST_OTP

FACT: `libcameracustom.so` этой прошивки
(`vendor/meizu/m5c/proprietary/lib{,64}/libcameracustom.so`) знает **ровно
восемь** имён сенсоров — те, что в таблице выше. Ни `s5k4h8mipiraw`, ни
`s5k5e8yxmipiraw` (то, что отдавало наше ядро) там нет. Экспортируются
`S5K4H8_ST_CAM_CALDeviceName`, `S5K5E8_ST_CAM_CALGetCalData` и т.п.

FACT: стоковый массив `kdSensorList` вынут из образа по указателям на
`*_MIPI_RAW_SensorInit` (запись 48 байт: `u32 SensorId; u8 drvname[32]; ptr`,
массив с VA `0xffffffc00102f830`). Его порядок:

```
0: 0x5E80 s5k5e8stmipiraw        4: 0x4088 s5k4h8ofilmmipiraw
1: 0x5E81 s5k5e8qhmipiraw        5: 0x4089 s5k4h8stmipiraw
2: 0x5E82 s5k5e8holitechmipiraw  6: 0x408A s5k4h8holitechmipiraw
3: 0x5E83 s5k5e8sunwinmipiraw    7: 0x408B s5k4h8sunwinmipiraw
```

FACT: `KDIMGSENSORIOC_X_SET_DRIVER` принимает **индекс** в `kdSensorList`, а
`adopt_CAMERA_HW_CheckIsAlive()` (`kd_sensorlist.c:1441`) считает сенсор
найденным по любому id, кроме `0` и `0xFFFFFFFF` — **сверки id с записью списка
нет**. В нашем ядре компилировались только два драйвера, и индекс 0 был
S5K4H8 (главный), тогда как таблица блоба ждёт на индексе 0 `s5k5e8stmipiraw`.

INFERENCE: поэтому HAL считал главную камеру фронтальным S5K5E8_ST. Это ровно
то, что видно в логкате: `picture-size-values` заканчиваются на `2560x1920`
(5 МП, при том что наш S5K4H8 отдаёт cap `3264x2448`), `MdpMgr src_crop
W(1632) H(1224)`, `ae_mgr i4SensorDev:1` (main) — и ошибка
`CamCal s5k5e8_st: can't open CAM_CAL /dev/S5K5E8_ST_OTP` для камеры 0.
То есть главная камера получала тюнинг, статик-инфо и cam_cal чужого сенсора.

---

## 3. Что сделано (ветка `forge/camotp`)

Изменения в ядре, один коммит:

1. `drivers/misc/mediatek/imgsensor/inc/kd_imgsensor.h`
   — восемь `*_SENSOR_ID` вариантов и восемь `SENSOR_DRVNAME_*` строк, ровно те,
   что знает блоб.
2. `drivers/misc/mediatek/imgsensor/src/mt6735m/kd_sensorlist.h`
   — вместо двух записей (`s5k4h8mipiraw`, `s5k5e8yxmipiraw`) — восемь записей в
   **стоковом порядке**: сначала четыре S5K5E8, потом четыре S5K4H8. Все четыре
   записи одного сенсора указывают на его единственный `SensorInit`.
   `MAX_NUM_OF_SUPPORT_SENSOR` = 16, места хватает.
3. `.../s5k4h8_mipi_raw/s5k4h8_otp_cal.{c,h}` (новые)
   — четыре chrdev `S5K4H8_{OFILM,ST,HOLITECH,SUNWIN}_OTP`, чтение EEPROM по
   раскладке §2.2, `CAM_CALIOC_G_READ` + compat-вариант с проверкой границ
   буфера (у стока проверки нет — там userspace мог читать соседнюю память).
4. `.../s5k5e8yx_mipi_raw/s5k5e8_otp_cal.{c,h}` (новые)
   — четыре chrdev `S5K5E8_{ST,QH,HOLITECH,SUNWIN}_OTP`, чтение по §2.3.
5. `.../s5k4h8_mipi_raw/s5k4h8mipi_Sensor.c`
   — `s5k4h8_resolve_variant()`: читает id вендора из EEPROM, отдаёт sensor id
   варианта, зовёт `s5k4h8_otp_cali()` и возвращает скорость i2c сенсора.
   Вызов из `get_imgsensor_id()` и из `open()`.
6. `.../s5k5e8yx_mipi_raw/s5k5e8yxmipiraw_Sensor.c`
   — то же для фронтальной, плюс два нестатических хелпера
   `s5k5e8_otp_{read,write}_reg` для OTP-файла.
7. Makefile'ы обеих папок сенсоров.

### Осознанные отличия от стока

- Стоковый OTP-драйвер S5K5E8 жёстко использует i2c write id `0x30`. У нашего
  экземпляра фронтальный сенсор отвечает на `0x78` и сам переезжает на `0x5A`
  в `open()` (`write_cmos_sensor(0x0107,0x5a)`), поэтому OTP читается по
  **живому** `imgsensor.i2c_write_id`, а не по константе.
- Если id вендора не читается или неизвестен, драйвер не падает в
  «сенсор не найден» (как сток), а отдаёт базовый id (`0x4088` / `0x5E80`,
  то есть варианты OFILM / ST) и пропускает чтение OTP. Так неизвестная ревизия
  модуля хотя бы перечисляется. Строка в dmesg:
  `unknown camera module id N (EEPROM 0x0001)`.
- Буфер cam_cal обнулён и ограничен (2048 байт для S5K4H8, 64 для S5K5E8);
  запросы за границу отбиваются `-EINVAL`, а не выдают мусор.

### Про «быстрый нейтральный шейдинг» — почему его нет отдельным шагом

Задача просила сперва сделать нейтральный путь «нет OTP», а уже потом настоящий.
Честного нейтрального пути в ядре не существует: таблица шейдинга приходит
единым блобом из OTP, и «единичную» LSC на 1868 байт нельзя синтезировать, не
угадывая формат кодирования MTK (его разбирает `ShadingTrans_RA`/`AppLscUtil`
внутри `libcam.hal3a`, см. `D/ShadingTrans_RA [LscRaSwMain]` в логкате).
Отдать `LscSize = 0` — значит воспроизвести текущее `ERR_NO_SHADING`, то есть
ничего не изменить. Настоящее чтение EEPROM — это тот же объём кода, что и
подделка, и рецепт для него вынут из стока байт-в-байт, поэтому сделан сразу он.
Отдельный дешёвый шаг всё же есть и входит в этот же коммит: выравнивание имён
и порядка `kdSensorList` (§2.5) само по себе возвращает главной камере её
собственный тюнинг и статик-инфо.

---

## 4. Артефакт и проверка

FACT: сборка прошла чисто (новых warning'ов в добавленных файлах нет).

```
ядро:  /srv/forge/android/m5c/k-worktrees/camotp/arch/arm64/boot/Image.gz-dtb
       7 846 494 B
образ: /tmp/claude-1000/-srv-forge-android-m5c/145b2c58-faa9-45b2-84d1-967d0b509fd8/
       scratchpad/boot_camotp.img
       9 467 904 B
       sha256 07caef15e68983a94be3a3aff49d2f2df035ea2f618c2662deb6f41f29bb0b56
раздел: boot  (/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/boot)
```

Прошивка (на телефоне `dd` требует численный `bs`):

```
dd if=/data/local/tmp/boot_camotp.img \
   of=/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/boot bs=1048576
```

Сборка образа: контейнер и ramdisk взяты из `boot_k19.img`
(sha256 `45ac9d05ad1215b7a8f151bff6e40ddb5680f502273f4f851e931724a1ea961a`,
это ядро, загруженное на телефоне 2026-08-17 15:15); заменено ядро **и**
пропатчен `init.mt6735.rc` в ramdisk (см. §4.1):

```
abootimg -x boot_k19.img bootimg.cfg zImage initrd.img
sed -i 's/^bootsize = .*/bootsize = 0x0/' bootimg.cfg
# cpio newc пересобран скриптом на Python: заменено только содержимое
# init.mt6735.rc и поле filesize в его заголовке, все uid/gid/mode сохранены
# (распаковывать/запаковывать через cpio от непривилегированного юзера нельзя —
#  потеряется root:root)
abootimg --create boot_camotp.img -f bootimg.cfg \
         -k <camotp>/arch/arm64/boot/Image.gz-dtb -r initrd_camotp.img
```

Проверки образа (все прошли): вытащенное ядро побайтно совпадает с
`Image.gz-dtb`; `gunzip` даёт 19 223 232 B с магией `ARMd` по смещению `0x38`;
внутри есть строки `S5K4H8_ST_OTP`, `s5k4h8stmipiraw`, `S5K5E8_SUNWIN_OTP`;
листинг ramdisk (`cpio -itv`) совпадает с исходным по владельцам, режимам и
составу (52 записи, всё root:root), отличается только размер `init.mt6735.rc`;
в нём 16 новых строк `S5K*_OTP`. Порядок собранного `kdSensorList` (вынут из
нашего `vmlinux` тем же скриптом, что и стоковый) совпадает со стоковым из §2.5
по id и по именам.

### 4.1 Обязательная правка userspace (её надо внести в дерево)

FACT: `device/meizu/m5c/rootdir/root/init.mt6735.rc` даёт права только на
`/dev/CAM_CAL_DRV` (строки 400 и 411) — это имя из эпохи imx135. Наши восемь
узлов создаются devtmpfs как `root:root 0600`, а камерный HAL живёт в
`mediaserver`, поэтому без правки он получит `EACCES` на `open()` и ошибка
`can't open CAM_CAL` **останется**, хотя узлы будут существовать.

В тестовом `boot_camotp.img` эта правка уже внесена прямо в ramdisk, чтобы
образ был самодостаточным. В дерево её надо внести отдельно (файл принадлежит
другой дорожке, сам не правил):

`device/meizu/m5c/rootdir/root/init.mt6735.rc` — после строки
`    chmod 0660 /dev/CAM_CAL_DRV` добавить

```
    chmod 0660 /dev/S5K4H8_OFILM_OTP
    chmod 0660 /dev/S5K4H8_ST_OTP
    chmod 0660 /dev/S5K4H8_HOLITECH_OTP
    chmod 0660 /dev/S5K4H8_SUNWIN_OTP
    chmod 0660 /dev/S5K5E8_ST_OTP
    chmod 0660 /dev/S5K5E8_QH_OTP
    chmod 0660 /dev/S5K5E8_HOLITECH_OTP
    chmod 0660 /dev/S5K5E8_SUNWIN_OTP
```

и после строки `    chown system camera /dev/CAM_CAL_DRV` — те же восемь узлов с
`chown system camera`.

HYPOTHESIS: sepolicy пока не помеха — cmdline этого boot содержит
`androidboot.selinux=permissive`, так что метки узлов не проверяются. Когда
дерево пойдёт в enforcing, для восьми узлов понадобится `file_contexts` с типом
вроде `camera_device` и разрешение для домена камеры. Falsify: при enforcing в
логах появится `avc: denied { open } ... scontext=...:mediaserver`.

Заметка про сборочное окружение: хостовый `scripts/dtc` этого дерева не
линкуется современным GCC (`multiple definition of 'yylloc'`, `-fno-common`
по умолчанию). Дерево не правил, собирал с

```
make ARCH=arm64 CROSS_COMPILE=... \
  HOSTCFLAGS="-Wall -Wmissing-prototypes -Wstrict-prototypes -O2 \
              -fomit-frame-pointer -std=gnu89 -fcommon" -j8 Image.gz-dtb
```

Правильное лечение — апстримный однострочник (`extern YYLTYPE yylloc;` в
`scripts/dtc/dtc-lexer.lex.c_shipped`), это решение владельца дерева.

### Маркеры, подтверждающие успех

В `dmesg` при первом запуске камеры:

```
[S5K4H8_OTP] /dev/S5K4H8_OFILM_OTP registered (major N)      (и остальные 3)
[S5K5E8_OTP] /dev/S5K5E8_ST_OTP registered (major N)          (и остальные 3)
S5K4H8 ... camera module id N -> variant V, sensor id 0x408X
[S5K4H8_OTP] S5K4H8_<V>_OTP AWB unit R/G=.. B/G=.. golden R/G=.. B/G=..
[S5K4H8_OTP] S5K4H8_<V>_OTP LSC 1868 bytes read, first=.. last=..
```

Значение `camera module id` — это и есть ответ на «какой модуль стоит в этом
экземпляре». Если увидим `unknown camera module id N`, надо добавить N в
таблицу §2.4 (или EEPROM не отвечает — тогда проверять питание/адрес 0xA0).

В `logcat`:

- должна **исчезнуть** пара `CamCal ... can't open CAM_CAL /dev/S5K5E8_ST_OTP`
  и `Return ERROR ERR_NO_SHADING`;
- для камеры 0 префикс тега CamCal должен смениться с `s5k5e8_st` на
  `s5k4h8_<вариант>`, то есть HAL должен пойти в
  `/dev/S5K4H8_<вариант>_OTP`. Это и есть главный логкат-маркер.

CORRECTION (см. §8): маркер «`picture-size-values` должны дойти до `3264x2448`»
из первой редакции этого файла **снят как несостоятельный** — список размеров
приходит из статик-метаданных, а они у нас generic (§8.2), так что он, скорее
всего, не изменится, и судить по нему об успехе нельзя.

Визуальная проверка: свежий снимок без радужных пятен — ровный цвет по кадру,
допустимо лёгкое падение яркости к углам. Плоский серый лист или ровная стена —
самый показательный сюжет.

---

## 5. Открытые вопросы

- HYPOTHESIS: `Otp_Calibration()` в `s5k4h8mipi_Sensor.c` (строки ~3933+) — это
  донорский код, читающий OTP **самого сенсора** (страницы 0xF, 5..10) и
  применяющий цифровые усиления в регистры сенсора. У m5c калибровка в EEPROM,
  сенсорный OTP, скорее всего, пуст, и функция выходит на первой же проверке
  `module_flag`. Falsify: в dmesg должно быть
  `read otp module flag fail!!!,close otp clibration`. Если вместо этого она
  доходит до применения — её надо выключить для m5c, иначе она подмешивает
  чужие поканальные усиления. Пока не трогал: вне темы этого коммита.
- Не проверено на железе: телефон `710HVBR923RYK` отвалился от adb на девбоксе
  во время съёма логката (следом отвалился и второй девайс `95AHACQC5KQVM`,
  так что похоже на сбой adb/USB девбокса, а не на падение телефона).
  Прошивка и подтверждение — за владельцем.
- Порядок `kdSensorList` теперь совпадает со стоком, но сверка индексов
  остаётся INFERENCE: FACT — что блоб адресует драйверы индексом и что
  `CheckIsAlive` не проверяет id; что блоб берёт индексы именно из стокового
  порядка, подтвердится ровно тем, что после прошивки главная камера получит
  `s5k4h8*` статик-инфо (8 МП) вместо 5 МП.

## 6. Состояние дерева на момент коммита

FACT: в дереве устройства на момент этого коммита были незакоммиченные правки
других дорожек, они сохранены и не тронуты: `AndroidProducts.mk`,
`M5C_CAMERA_ORIENTATION_LANE.md`, `board/bluetooth.mk`, `board/kernel.mk`,
`patch_camera_orientation.py`, `product/prop.mk`, `product/ramdisk.mk`,
`rootdir/kernel`, плюс неотслеживаемые `rootdir/kernel.orig-v30` и `.omc/`.
Коммит сделан адресным `git add` только этого файла.

## 7. Прочитанные артефакты (для повторяемости)

- `/home/valakas/m5c/kernel-reverse/vmlinux.elf` — стоковое ядро с символами.
- `/home/valakas/m5c/kernel-reverse/meizu-m5c.dtb` — стоковый DTB.
- `/home/valakas/m5c/decompiled_src/sensor_s5k4h8.c`, `sensor_s5k5e8.c` —
  декомпиляции восьми `*_otp_cali`.
- `vendor/meizu/m5c/proprietary/lib{,64}/libcameracustom.so` — список из восьми
  имён сенсоров и экспорт `*_CAM_CAL*`.
- Логкаты живого устройства: сессии 2026-08-17 15:19 и 15:47 (камера открыта,
  `isp_tuning_custom`, `ShadingTrans_RA`, `CAM_Util Parameters`).

---

## 8. CORRECTION 2026-08-17 (позже): два слоя блобов, чем именно они ключуются

Поводом стала передача от дорожки ориентации: «`strings | grep -oE
'SENSOR_DRVNAME_[A-Z0-9_]+' | sort -u` по libcam.halsensor.so,
libcam.metadataprovider.so, libcameracustom.so и camera.mt6737m.so даёт ровно
пять имён: GC0310, GC2145, GC2355, IMX135, IMX219; никакого
`constructCustStaticMetadata_*_S5K4H8_*` нет». Это прямо противоречило моему
FACT из §2.5. Перепроверено.

### 8.1 Противоречие разрешено: это разные блобы

FACT (перезамер, `lib64/`):

| блоб | `SENSOR_DRVNAME_*` |
|---|---|
| `libcameracustom.so` | **ровно восемь** S5K4H8/S5K5E8 вариантов, ни одного GC/IMX |
| `libcam.halsensor.so` | ровно пять: GC0310, GC2145, GC2355, IMX135, IMX219 |
| `libcam.metadataprovider.so` | те же пять |

Оба наблюдения верны, но про разные библиотеки. Утверждение «в том числе в
libcameracustom.so ровно эти пять» — неверно; там их нет вовсе. Вывод дорожки
ориентации про статик-метаданные при этом остаётся в силе.

INFERENCE: блобы m5c разделены по происхождению. `libcameracustom.so` — родная
для m5c (тюнинг ISP/3A/шейдинг/cam_cal, знает все восемь модулей).
`libcam.halsensor.so` и `libcam.metadataprovider.so` — донорские, generic
(знают только GC/IMX), поэтому для наших сенсоров статик-характеристики
(ориентация, размеры, физический размер матрицы) берутся из generic-заглушки.

### 8.2 Чем ключуется тюнинг: числовым sensor id, и это ровно то, что мы правим

FACT: в `libcameracustom.so` есть инстанциации шаблона
`NSFeature::RAWSensorInfo<N>` (методы `impGetDefaultData`, `impGetFlickerPara`)
ровно для восьми N:

```
16520 = 0x4088   16521 = 0x4089   16522 = 0x408A   16523 = 0x408B
24192 = 0x5E80   24193 = 0x5E81   24194 = 0x5E82   24195 = 0x5E83
```

То есть пер-сенсорные данные по умолчанию (ISP/3A/shading NVRAM, flicker)
адресуются **числовым id варианта модуля** — тем самым, который ядро теперь и
отдаёт (§2.4). Это более прямое обоснование правки, чем рассуждение про имена.

FACT: cam_cal в этом же блобе разрешается через `dlsym` по искалеченным именам,
лежащим в `.dynstr`: `_Z21S5K4H8_ST_CAM_CALInitv`,
`_Z27S5K4H8_ST_CAM_CALDeviceNamePc`, `_Z27S5K4H8_ST_CAM_CALGetCalDataPj` и так
для всех восьми вариантов, плюс generic `CAM_CALInit`/`CAM_CALDeviceName`/
`_Z17CAM_CALGetCalDataPj`. Сами `*_CAM_CALDeviceName(char *buf)` — это
`strcat(buf, "S5K4H8_ST_OTP")` и т.п. (проверено дизассемблированием
`0x141e90` → константа `0xdd9d90` = `"S5K4H8_ST_OTP"`), а generic-вариант
приклеивает `"CAM_CAL_DRV"` (`0x14f8e0` → `0xde1370`).

### 8.3 Что из §2.5 надо поправить

CORRECTION к §2.5: FACT'ы (блоб адресует драйверы ядра индексом в
`kdSensorList`; `adopt_CAMERA_HW_CheckIsAlive` не сверяет id с записью списка;
стоковый порядок списка — сначала четыре S5K5E8) остаются в силе. А INFERENCE
«главная камера получала статик-инфо S5K5E8 (5 МП)» **неверна**: у S5K5E8
статик-таблицы в блобах тоже нет, и список `picture-size-values` до `2560x1920`
— это generic-заглушка из донорских `libcam.halsensor`/`libcam.metadataprovider`
(§8.1), а не таблица фронтального сенсора.

Реальное следствие путаницы индексов — именно выбор cam_cal и тюнинга: HAL
считал, что на индексе 0 сидит `s5k5e8st`, и полез в `/dev/S5K5E8_ST_OTP` для
камеры 0, тогда как ядро на том же индексе держало S5K4H8.

INFERENCE (механика починки, полезно понимать): раньше индекс 0 на главном
сокете **ошибочно отвечал «жив»** (наш S5K4H8 отдавал 0x4088, а `CheckIsAlive`
принимает любой ненулевой id). Теперь на индексах 0..3 стоит драйвер S5K5E8,
который на главном сокете сенсор не найдёт и вернёт `0xFFFFFFFF`, поиск пойдёт
дальше и остановится на индексе 4..7 — драйвере S5K4H8 с правильным именем.
То есть фикс работает за счёт того, что неверные записи теперь корректно
**не отвечают**, ровно как в стоке.

### 8.4 Насколько это меняет прогноз по цвету

Тезис дорожки ориентации «если статик-таблицы для S5K4H8 нет, то и
shading/AWB/CCM могут оказаться generic» — по замерам выше **не подтверждается**
для тюнинга: `RAWSensorInfo<0x4088..0x408B>` и восемь наборов `*_CAM_CAL*` в
`libcameracustom.so` есть, и ключ у них — числовой id варианта. Generic только
слой статик-метаданных, а он в конвейер ISP не входит.

HYPOTHESIS (остаётся): даже с правильным cam_cal цвет может оказаться не
идеальным, если `GetCameraDefaultPara()` не найдёт NVRAM камеры. FACT:
`/data/nvram/APCFG/APRDEB` на устройстве содержит только `BT_Addr`, `GPS`,
`OMADM_USB`, `WIFI`, `WIFI_CUSTOM` — файлов `CAMERA_*` нет вовсе. Falsify:
после прошивки посмотреть, появились ли `CAMERA_ISP`/`CAMERA_3A`/
`CAMERA_SHADING` в этом каталоге; если нет — следующая нить именно там, а не в
статик-метаданных.

### 8.5 Предупреждение по сборке образа

Если boot собирается заново из `Image.gz-dtb` с **штатным** ramdisk дерева, то
правка `init.mt6735.rc` из §4.1 в образ не попадёт, узлы останутся
`root:root 0600`, и `can't open CAM_CAL` сохранится при полностью исправном
ядре. Либо вносить §4.1 в дерево до сборки ramdisk, либо брать готовый
`boot_camotp.img` (§4), в ramdisk которого правка уже есть.
