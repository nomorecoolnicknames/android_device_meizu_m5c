# M5C: BT-адрес из NVRAM (lane)

Статус: **ЗАКРЫТО 2026-08-27** — на живом 710HVBR923RYK
`dumpsys bluetooth_manager` показывает `D8:6C:02:AB:6F:3F`, state ON.

## Дефект

Адрес адаптера был `22:22:AF:F6:76:58` — автоген LOS-стека, а не
заводской адрес из калибровки.

## Архитектура (все — FACT, по коду ветки)

Два независимых потребителя адреса, между ними НЕТ моста:

1. **Чип**: vendor-либа libbluetooth_mtk читает первые 6 байт записи
   `AP_CFG_RDEB_FILE_BT_ADDR_LID` = `/data/nvram/APCFG/APRDEB/BT_Addr`
   (симлинк `/data/nvram -> /nvdata`, `rootdir/root/init.mt6735.rc:125`;
   путь зашит в блобе libcustom_nvram.so) и программирует контроллер
   vendor-HCI 0xFC1A (`bluetooth-mtk/driver/bluedroid/radiomod.c:291`).
   Адрес, переданный стеком, либа игнорирует (`bt_drv.c:45`).
   Лог прошлых загрузок подтверждает: `mtk_fw_cfg: [BDAddr d8-6c-02-ab-6f-3f]`.
2. **Хост-стек**: `system/bt/btif/src/btif_core.c:397`
   `btif_fetch_local_bdaddr()`, приоритет: файл `ro.bt.bdaddr_path` →
   bt_config "Adapter/Address" → `persist.service.bdroid.bdaddr` →
   `ro.boot.btmacaddr` → QC-файл → **автоген 22:22:xx** (строки 474-479).
   Кода чтения MTK NVRAM в стеке НЕТ (grep по system/bt на
   APRDEB/BT_Addr/libnvram — ноль).
3. **Фреймворк**: `dumpsys bluetooth_manager` печатает `mAddress` —
   кэш `Settings.Secure.bluetooth_address`
   (`BluetoothManagerService.java:2041`), который обновляется ТОЛЬКО
   пока пуст (`isNameAndAddressSet`, вызовы `storeNameAndAddress`
   только из `MESSAGE_GET_NAME_AND_ADDRESS`, очередь — строки 941,
   1436). Живой `getAddress()` при BT=ON идёт мимо кэша (строка 1176).

## Причины (две, обе подтверждены на устройстве)

- NVRAM жив и содержит заводской **D8:6C:02:AB:6F:3F** (= Wi-Fi MAC −1
  в младшем байте; файл 66 байт = 64-байтная запись + 2 хвостовых), но
  моста NVRAM→стек не существовало: `ro.bt.bdaddr_path` не был задан,
  стек дошёл до автогена и закэшировал 22:22 в bt_config.
- После установки моста dumpsys ОСТАВАЛСЯ 22:22: третья точка кэша —
  `Settings.Secure.bluetooth_address` (застрявший автоген, никогда не
  перечитывается). REJECTED-версии этой итерации: права/EACCES (стек
  файл NVRAM вообще не открывает), путь (единственный настраиваемый —
  `ro.bt.bdaddr_path`), фиксированный адрес в bdroid_buildcfg.h (там
  только имя устройства).

## Фикс (в дереве, `bluetooth/` + `product/bluetooth.mk`)

- `bluetooth/btaddr_mtk.c` (+`.rc`, oneshot по
  `service.nvram_init=Ready`): NVRAM → ASCII 17 байт →
  `/data/misc/bluetooth/bdaddr` (bluetooth:net_bt_stack). Fallback при
  пустом/дефолтном NVRAM (00…, FF…, дефолты 6735/6735m из
  CFG_BT_Default.h): FNV-1a(ro.serialno), префикс 0x02 (locally
  administered) + write-back первых 6 байт в NVRAM, чтобы чип совпал.
- `product/bluetooth.mk`: `ro.bt.bdaddr_path=/data/misc/bluetooth/bdaddr`
  (приоритет №1 в btif — перебивает застрявший bt_config).
- `bluetooth/btaddr_settings.sh` (+сервис в том же `.rc`, oneshot по
  `sys.boot_completed=1`): сверяет `Settings.Secure.bluetooth_address`
  с файлом bdaddr, при расхождении пишет правильный (эффект — со
  следующей загрузки; нужен для dirty-flash поверх /data со старым
  автогеном). На 710HVBR923RYK кэш поправлен вручную 2026-08-27
  (`settings put secure bluetooth_address D8:6C:02:AB:6F:3F` + reboot),
  проверка после перезагрузки прошла.

## Проверка (выполнена 2026-08-27)

- `logcat -d -s btaddr_mtk` → `BD address D8:6C:02:AB:6F:3F exported`
- `dumpsys bluetooth_manager | head -5` → `address: D8:6C:02:AB:6F:3F`
- `settings get secure bluetooth_address` → `D8:6C:02:AB:6F:3F`
- bt_config.conf `Address = d8:6c:02:ab:6f:3f`
- Открыто (некритично): подтвердить адрес в эфире сканом со второго
  телефона (ожидание: D8:6C:02:AB:6F:3F, чип программируется им же).

## Что пересобрать

Для `btaddr_settings.sh`-миграции: пересборка ROM подхватит
`bluetooth/Android.mk` (модуль `btaddr_settings.sh` → /system/etc) и
обновлённый `btaddr_mtk.rc`. Быстрая ручная накатка без пересборки:
скопировать скрипт в /system/etc, rc — в /system/etc/init, ребут.
