# Захват: kernel panic в Wi-Fi, 2026-08-27

Два подряд одинаковых крэша, снятых с `/sys/fs/pstore/` живого устройства
(образ `boot_m5c_49_20260827_modem.img`, md5 `30ec1334a99f6adb2d461e1a5beba18f`,
ядро `4.9.188-m5c+ #48`).

- `console-ramoops.txt` — последний крэш
- `console-ramoops-2.txt` — предыдущий, с тем же стеком

Суть: `Accessing user space memory outside uaccess.h routines: 96000005`,
PC в `wext_set_country` (`gl_wext.c:3328`), прямое чтение
`iwr->u.data.pointer` без `copy_from_user`. Разбор — в `BRINGUP_STATE.md`,
запись «2026-08-27 — SIM вставлена».
