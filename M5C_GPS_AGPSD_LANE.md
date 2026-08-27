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

## Известный хвост (не GPS)

FACT: те же 7 символов `*_55` не находят `lib/libdrmmtkutil.so` и
`lib64/libdrmmtkutil.so` (MTK OMA DRM) — они тоже не загружаются на ICU 56.
m681-версии есть, но их экспорт НЕ совпадает (нет `Cta5CommonMultimediaFile`,
`DrmInfoType::KEY_DRM_*_CLOCK` и др. — ~20 символов), слепая замена может сломать
потребителей (`libdrmmtkplugin`). Если DRM понадобится — либо кросс-чек импортов
потребителей, либо здесь уже честный кандидат на `libshim_icu`
(7 обёрток `*_55` → `*_56`, wiring через `LINKER_FORCED_SHIM_LIBS` в BoardConfig).
