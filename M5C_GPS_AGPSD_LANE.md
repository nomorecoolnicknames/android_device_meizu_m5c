# M5C GPS lane — mtk_agpsd ICU55 crash-loop (2026-08-27)

## Симптом

FACT (logcat, живое устройство): `mtk_agpsd` падает каждые ~5 с:

```
F libc: CANNOT LINK EXECUTABLE "/system/bin/mtk_agpsd":
        cannot locate symbol "UCNV_FROM_U_CALLBACK_STOP_55" referenced by "/system/bin/mtk_agpsd"
```

Ядерная часть GPS исправна (`/dev/stpgps` 191:0, `mnld` в epoll, CONSYS жив —
Wi-Fi/BT работают). Фикса нет: `Location[0,0 acc=3.4e38]`.

## Причина

FACT (readelf по блобам, toolchain arm-linux-androideabi-4.9):

- m5c-блоб `mtk_agpsd` (Flyme, Android 6, md5 `c84a4c567a6d7892b3b3c34cfd52e6d4`)
  требует 7 UND-символов ICU **55**:
  `ucnv_open_55, ucnv_close_55, ucnv_convertEx_55, ucnv_setFromUCallBack_55,
  ucnv_setToUCallBack_55, UCNV_FROM_U_CALLBACK_STOP_55, UCNV_TO_U_CALLBACK_STOP_55`
- LOS 14.1 несёт ICU **56.1** (FACT: `external/icu/icu4c/source/common/unicode/uvernum.h`
  → `U_ICU_VERSION "56.1"`, суффикс `_56`) — символов `*_55` в `libicuuc.so` нет.

## Решение: замена блоба на m681-версию (ICU 56)

Выбрано вместо shim'а (`libshim_icu` + `TARGET_LD_SHIM_LIBS`), потому что:

- FACT: m681-блоб `vendor/meizu/m681/proprietary/vendor/bin/mtk_agpsd`
  (md5 `904f35cbdbdeeb4cc88209adafb36fd9`) слинкован ровно под ICU 56
  (`ucnv_*_56`), DT_NEEDED-список идентичен m5c-блобу, ELF32 ARM.
- FACT: строки интерфейса MNL↔AGPS (`Agps2FrameworkInterface_*`, `AGPS2MNL_PMTK`,
  `agps_ver=%d mnl_ver=%d`, сокеты `/data/agps_supl/*`) в обоих блобах совпадают;
  версия согласуется в рантайме (`agps_ver/mnl_ver`).
- FACT: пути конфига одинаковы (`/etc/agps_profiles_conf2.xml`, `/vendor/etc/...`,
  `/data/agps_supl/...`); ROM ставит конфиг в `system/etc/` (m5c-vendor-blobs.mk:109).
- FACT: прецедент — модемный `ccci_fsd` из m681 уже работает на m5c.
- FACT: механика shim'ов в этом дереве фантомная — `libshim_asc/...` из
  `product/hardware.mk` НЕ определены нигде в дереве (модулей нет, PRODUCT_PACKAGES
  инертны); bionic linker поддерживает `LD_SHIM_LIBS`/`LINKER_FORCED_SHIM_LIBS`,
  но ни один shim не собирается. Замена блоба — ноль нового кода.

INFERENCE: m681-блоб — из Flyme на Android 7 (ICU 56 ↔ N), поэтому его
окружение (libc++ locale-символы с версией `LIBC_N`) совпадает с LOS 14.1 лучше,
чем у родного m5c-блоба.

## Что изменено

- `vendor/meizu/m5c/proprietary/bin/mtk_agpsd` → m681-версия (`904f35cb…`);
  бэкап рядом: `mtk_agpsd.flyme-icu55` (`c84a4c56…`).
- То же в `android_vendor_meizu_m5c/proprietary/bin/` (бэкап там уже был).
- Makefile-правки не нужны: `m5c-vendor-blobs.mk:101` уже копирует
  `vendor/meizu/m5c/proprietary/bin/mtk_agpsd → system/bin/mtk_agpsd`.

## Проверка (живой тест без пересборки)

```sh
adb push vendor/meizu/m5c/proprietary/bin/mtk_agpsd /data/local/tmp/mtk_agpsd.56
adb shell su -c 'mount -o remount,rw /system && cp /system/bin/mtk_agpsd /data/local/tmp/mtk_agpsd.55.bak && cp /data/local/tmp/mtk_agpsd.56 /system/bin/mtk_agpsd && chmod 755 /system/bin/mtk_agpsd && chcon u:object_r:agpsd_exec:s0 /system/bin/mtk_agpsd; mount -o remount,ro /system'   # контекст из sepolicy/file_contexts:13
adb shell su -c 'stop agpsd; start agpsd'
adb logcat -s libc agpsd mtk_agpsd AGPSD MNLD | head -50   # НЕ должно быть CANNOT LINK
adb shell 'ps | grep agpsd'                                 # pid стабилен >30 с
# затем на открытом небе: adb shell dumpsys location | grep -A2 "last location"
```

Откат: `cp /data/local/tmp/mtk_agpsd.55.bak /system/bin/mtk_agpsd`.

## Рубеж 2 (2026-08-27, после замены agpsd): mnld не знает SETTINGS_SYNC + ENOENT-цикл

FACT (устройство): agpsd запущен (`ver=4.151.0`), но:
`E agps: ERR: [MNL2AGPS] agps2mnl unknown type=252`, `agps2_gnss_ack_timeout`,
`E MNLD: main: process data error: 2 (No such file or directory)` циклом, фикса нет.

Расшифровка по исходникам `gps/mtk_mnld/mnl_agps_interface/inc/mnl_agps_interface.h`:
- FACT: 252 = `MNL_AGPS_TYPE_SETTINGS_SYNC` (AGPS→MNL), ACK на него — 154
  (`SETTINGS_ACK`). Строку `agps2mnl unknown type=%d` печатает mnld-сторона
  (парсер agps→mnl, LOG_TAG "agps") — т.е. СТАРЫЙ m5c mnld-блоб (Flyme M, 2016)
  не знает сообщение 252 от нового agpsd.
- FACT: в GPS-стеке два поколения. Gen-M (Flyme 2016): blob-HAL + blob-mnld,
  транспорт HAL↔mnld — файловые dgram-сокеты `/data/gps_mnl/{hal2mnld,mnld2hal}`.
  Gen-N (MTK 2017): source-HAL `gps.mt6737m` (в PRODUCT_PACKAGES) + исходники
  mnld в `gps/mtk_mnld/` (в образ НЕ попадали — `mnld` нет в PRODUCT_PACKAGES,
  а его `LOCAL_SHARED_LIBRARIES libcurl` не собирается: `external/curl` даёт
  только static, `curl/libs/Android.mk` — обрезанный стаб), транспорт —
  абстрактные сокеты `mtk_hal2mnl`/`mtk_mnl2hal`.
- INFERENCE (сильная): в образе HAL — source-сборка (Gen-N) ⇒ blob-mnld шлёт в
  несуществующий `/data/gps_mnl/mnld2hal` ⇒ `sendto`=ENOENT ⇒ тот самый цикл
  «process data error: 2»; команды HAL (gps_start) до Gen-M mnld вообще не
  доходят. Проверка: `md5sum /system/lib*/hw/gps.mt6737m.so` vs блобы
  (`f35bfca6…`/32, `4f45ae89…`/64) — совпадение = blob-HAL, иначе source.

### Решение рубежа 2: mnld → Gen-N (пара из m681 + libmnl нашего чипа)

- FACT: `vendor/meizu/m681/.../bin/mnld` (Gen-N) использует те же
  `mtk_hal2mnl`/`mtk_mnl2hal` и знает SETTINGS_SYNC-эпоху протокола agps.
- FACT: его 27 mnl/mtk-импортов полностью покрываются tree-`libmnl.so`
  (`gps/mtk_mnld/mnl/libs/libmnl.so`, 67cfe376…, сборка ДЛЯ MT6735-семейства,
  экспорт-API из 199 функций ИДЕНТИЧЕН m681-libmnl); старый m5c-libmnl
  (160 экспортов) не покрывает 13 символов (qepo/mpe/flp/gnss_measurement).
- FACT: m681-mnld дополнительно требует `libcurl.so` (в LOS его нет —
  external/curl собирает только static; `libcurl` в PRODUCT_PACKAGES инертен);
  взят блоб `libcurl.so` из m681 (deps: libcrypto/libssl/libz — есть в ROM).
- Риск (HYPOTHESIS): m681-mnld ищет NVRAM-калибровку `ML4A_000` (m5c-блоб искал
  `EL6N_000`) — возможна деградация до работы без калибровки; смотреть лог
  «Get nvram restore ready». SELinux permissive (cmdline) — денialы не блокер.

Изменено (оба vendor-дерева, бэкапы `*.flyme-m2016`):
- `proprietary/xbin/mnld` ← m681 Gen-N (84b49bcf…), старый d4bdef56….
- `proprietary/lib/libmnl.so` ← tree MT6735-сборка (67cfe376…), старый 1ee654c8….
- `proprietary/lib/libcurl.so` ← m681 (edf930d0…), НОВЫЙ файл; строка установки
  добавлена в оба `m5c-vendor-blobs.mk` (после строки xbin/mnld).
- В blobs.mk замечен дубликат строки libmnl (две одинаковые копии) — не трогал.

## Известный хвост (не GPS)

FACT: те же 7 символов `*_55` не находят `lib/libdrmmtkutil.so` и
`lib64/libdrmmtkutil.so` (MTK OMA DRM) — они тоже не загружаются на ICU 56.
m681-версии есть, но их экспорт НЕ совпадает (нет `Cta5CommonMultimediaFile`,
`DrmInfoType::KEY_DRM_*_CLOCK` и др. — ~20 символов), слепая замена может сломать
потребителей (`libdrmmtkplugin`). Если DRM понадобится — либо кросс-чек импортов
потребителей, либо здесь уже честный кандидат на `libshim_icu`
(7 обёрток `*_55` → `*_56`, wiring через `LINKER_FORCED_SHIM_LIBS` в BoardConfig).

## Рубеж 3 (2026-08-27, вечер): Gen-N стек целиком — тракт зашевелился до NMEA

Живой разбор «process data error: 2» / «unknown type=252» после замены agpsd.

### Опровержение и уточнение картины рубежа 2

- REJECTED (частично): инференс «в образе source-HAL (Gen-N)». FACT: и на
  устройстве, и в staging свежей сборки (`out/.../system/lib/hw/`) лежал
  **blob-HAL** `f35bfca6…` (32) / `4f45ae89…` (64) — Gen-M, файловые сокеты
  `/data/gps_mnl/{hal2mnld,mnld2hal}` (strings по бинарю). Причина: строки 104–105
  `m5c-vendor-blobs.mk` копируют блоб ПОВЕРХ собранного из исходников модуля.
- FACT: source-HAL при этом собирается: `out/.../obj/SHARED_LIBRARIES/
  gps.mt6737m_intermediates/PACKED/gps.mt6737m.so` = `6d999c3b…` (64),
  `obj_arm/...` = `79deae0f…` (32), оба Gen-N (`mtk_hal2mnl`/`mtk_mnl2hal`).
- FACT: сокет `/data/gps_mnl/mnld2hal` на живом устройстве отсутствовал
  (был только `hal2mnld` от Gen-M mnld) — blob-HAL Gen-M (ABI Android M,
  gps.h M) в N-фреймворке свой приёмный сокет не поднимал.
- INFERENCE (механизм ENOENT): Gen-M mnld слал ответы в несуществующий
  `/data/gps_mnl/mnld2hal` → sendto = ENOENT → цикл `main: process data
  error: 2`. `type=252` — SETTINGS_SYNC от нового agpsd, неизвестный Gen-M
  mnld (FACT по inc/mnl_agps_interface.h, см. рубеж 2).

### Гипотезы рубежа и их проверка

1. Пара mnld/agpsd разных поколений — ПОДТВЕРЖДЕНО (unknown type=252;
   исчез после замены mnld на Gen-N).
2. Отсутствующий конфиг/NVRAM — ОТПАЛО как блокер. FACT: `mnl.prop` в
   `/data/misc/gps/` нет, mnld честно пишет «[setting] load default value»
   и работает; NVRAM-запись читается через `/data/nvram/APCFG/APRDEB/GPS`
   (LID 50, 52 байта, «nvram_init_val Ready»); `ML4A_000` (путь в m681-mnld)
   на m5c отсутствует (есть `EL6N_000` от старого стека), эффект — только
   «customer didn't set clock drift value, use default value».
3. SELinux — ОТПАЛО. FACT: permissive (avc denied … permissive=1), денаи
   только от toolbox/ps, функциональных нет.
4. Сокет/узел init — ОТПАЛО как первопричина: отсутствующий `mnld2hal`
   создаёт не init, а HAL; сокеты init (`/dev/socket/{mnld,agpsd*}`) на месте.

### Что сделано (устройство + дерево)

Полный перевод стека на Gen-N (все четыре звена одного поколения):

| звено | было (Gen-M/микс) | стало (Gen-N) |
|---|---|---|
| HAL 32 | blob `f35bfca6` | source-build `79deae0f` |
| HAL 64 | blob `4f45ae89` | source-build `6d999c3b` |
| mnld | blob `d4bdef56` | m681 `84b49bcf` |
| libmnl | m5c `1ee654c8` | tree MT6735 `67cfe376` |
| libcurl | (случайный `8777ba53`) | m681 `edf930d0` |
| mtk_agpsd | — | m681 `904f35cb` (рубеж 1) |

- На устройстве файлы подменены живьём (бэкапы: `/data/local/tmp/gpsback/`),
  контексты сохранены (`system_file`, `mnld_exec`).
- В дереве: из ОБОИХ `m5c-vendor-blobs.mk` (vendor/meizu/m5c и
  android_vendor_meizu_m5c) удалены строки установки блобного HAL
  `gps.mt6737m.so` (32+64) — теперь в образ ставится source-модуль
  `gps.mt6737m` из `PRODUCT_PACKAGES` (product/gps.mk:10). Блобы
  переименованы в `*.flyme-m2016` рядом. **Требуется пересборка ROM** —
  текущая сборка стартовала до правки и унесёт блобный HAL.

### Результат на живом устройстве (в помещении, на девбоксе)

- FACT: оба демона стабильны; `@mtk_hal2mnl` (mnld) и `@mtk_mnl2hal`
  (HAL в system_server) связаны (/proc/net/unix).
- FACT: `mEngineCapabilities=0x41 (SCHEDULING MEASUREMENTS)` в dumpsys
  location — фреймворк проинициализировал HAL.
- FACT: цепочка команд работает: `hal_set_server` (SUPL supl.google.com)
  и `hal_gps_start` доходят из фреймворка в mnld; FSM IDLE→START,
  `mtk_gps_sys_init() success`; PMTK-обмен mnld↔agpsd в обе стороны
  ($PMTK764/$PMTK680), `unknown type` и `process data error` исчезли.
- FACT: NMEA идёт 1 Гц конец-в-конец (GPGGA/GPGSV/GPRMC через
  `mnl2hal_nmea` в HAL). Сессия запускалась broadcast'ом
  `com.android.internal.location.ALARM_WAKEUP` → `startNavigating`
  (GnssLocationProvider.java:502) — трюк для теста без UI-клиента.
- Спутники: `$GPGSV,1,1,0` — 0 SV за сессию в помещении. Фикса нет.
  «Enabled Providers» без gps в dumpsys — норма (это список test-provider'ов).

### Статус и хвосты

- Тракт framework→HAL→mnld→MNL-движок→чип→NMEA→HAL исправен (FACT).
- Фикс позиции НЕ подтверждён: 0 спутников в помещении не отличает
  «нет неба» от «мёртвый RF-фронтенд» (LNA/антенна). HYPOTHESIS: у окна /
  на улице SV появятся; проверить первым же выносом аппарата.
- Клок-дрейф не калиброван (нет `ML4A_000`) — возможен долгий холодный
  старт; лечится записью калибровки, если станет проблемой.
- EPO/QEPO качаются только при сети на аппарате (`is_network_connected=0`).
