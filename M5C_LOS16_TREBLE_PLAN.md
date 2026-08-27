# M5C_LOS16_TREBLE_PLAN — LOS 16.0 (Android 9, arm64) с Treble на Meizu m5c

Дата разведки: 2026-08-27. Статус: **исследование и план — ничего не прошито,
ничего не собрано, устройство не трогалось.** Все сетевые находки помечены
«(сеть)» и требуют перепроверки при выполнении; всё остальное снято с деревьев
на диске. Метки по CLAUDE.md §2.

Контекст решений владельца (2026-08-17, BRINGUP_STATE.md): конечная цель —
Android 13, только arm64, vendor-раздел размещаем на `custom`. LOS 16 — это
ступень B2 лестницы Фронта B (`M5C_K49_ROADMAP.md`): 15.1 → **16.0** → 17.1 →
(18.1). Настоящий план покрывает ступень 16.0 и закладывает Treble-механику,
которая нужна всем ступеням выше.

---

## 0. Резюме выполнимости

**INFERENCE (высокая уверенность): LOS 16 arm64 на нашем ядре 4.9.188 —
реалистичная цель.** Опоры:

- ядро уже arm64 (`arch/arm64/configs/m5c_defconfig`, FACT) и уже несёт
  binder/hwbinder/vndbinder, SELinux, configfs, sdcardfs, SYNC_FILE, BPF —
  диф до `kernel/configs/android-base.config` составляет ~10 опций (§3, FACT);
- наш `forge_hwc` (HWC 1.1 с retire/release-фенсами, FACT) ложится под
  штатный `hwc2on1adapter`, который в lineage-16.0 есть (сеть, FACT);
- vendor-RIL-библиотека `mtk-ril.so` (32/64) в блобах есть (FACT) — путь
  «AOSP rild + shim» открыт;
- прецедент существует: LOS 16 на MT6737 (Moto E4 `woods`, arm32, ядро 3.18,
  M/N-блобы) — дерево `iykex/PIE9.0_device_motorola_woods` (сеть) даёт
  готовый рецепт HIDL-обвязки;
- 14.1 остаётся reference и не трогается (правило Фронта B).

Главные препятствия (по природе): **телефония** (в LOS 16 механизм
`BOARD_RIL_CLASS` мёртв — наши java-правки не переносятся, §4.6),
**sepolicy/first-stage mount** (в стоковом DTB нет fstab-узла, §1.4),
**возраст блобов** (134 ELF тянут framework-библиотеки — VNDK недостижим,
медиакодеки под угрозой, §6.2), **дисковое место под дерево P** (§6.6).

---

## 1. Разметка и её ограничения

### 1.1 Что есть (FACT)

- Отдельного vendor-раздела нет: `rootdir/root/fstab.mt6735` монтирует только
  system/data/cache/protect1,2/nvdata (+emmc-узлы), vendor не упоминается.
- Карта разделов — BRINGUP_STATE.md p86 (сверена по двум опорам boot=p7,
  expdb=p10): system=p23, cache=p24, userdata=p25, **custom=p17**.
- Размеры (BoardConfig/`board/filesystem.mk` + getvar):
  boot 16 МиБ, recovery 32 МиБ по getvar (BoardConfig говорит 20 МиБ —
  противоречие, ground truth getvar), **system 1 610 612 736 Б = 1.5 ГиБ**,
  cache 400 МиБ, userdata ~12.8 ГБ (eMMC 16 ГБ).
- `custom` = mmcblk0p17, **512 МиБ ext4**, в LOS 14.1 не монтируется вообще,
  занято ~73 МиБ стоковых данных Flyme; дамп снят
  (sha256 `ad8f6a88…`, лежит на девбоксе в `/tmp/m5c-backup-20260817/` —
  **волатильное место, пересохранить до любых записей**). Стоковый образ
  раздела есть и локально: `/home/n8n/Flyme5.1.6.0A/custom.img` (FACT).
- fastboot не пишет ни одного раздела (p87, FACT) — вся прошивка через
  TWRP/dd по by-name.

### 1.2 Решение по vendor (FACT-решение владельца + INFERENCE по размерам)

**Vendor-раздел = `custom` (512 МиБ).** Решение владельца от 2026-08-17
задокументировано в BRINGUP_STATE.md. Проверка вместимости: содержимое
`vendor/meizu/m5c` = 293 МиБ (FACT, du), причём туда входит и то, что уедет
в system (framework-джарники и пр.) — реальный vendor-набор будет меньше.
**Вердикт: влезает с запасом (INFERENCE).**

### 1.3 Влезет ли Android 9 в system 1.5 ГиБ

- phh GSI AOSP 9 v119 `system-arm64-aonly-vanilla` = 448 МБ в xz (сеть,
  FACT); при типичном ratio xz ~2.5–3× содержимое ~1.1–1.4 ГБ.
  **INFERENCE: vanilla-вариант и собственная сборка LOS 16 без GApps в
  1.5 ГиБ помещаются, впритык; GApps-варианты — нет.** Проверка на этапе:
  `resize2fs -M` распакованного образа перед прошивкой.
- Перекройка GPT не нужна и не предлагается: доступного custom и текущего
  system достаточно; резать userdata — отдельный необратимый риск без выгоды.

### 1.4 First-stage mount и sepolicy split (ключевое ограничение)

FACT: стоковый DTB (`captures/20260817-los-first-boot/dtb_stock.dtb`,
декомпилирован dtc) **не содержит узла `firmware/android/fstab`** — вообще ни
одного вхождения «fstab». Ядро 4.9 у нас летает со стоковым DTB байт-в-байт
(проектное правило), т.е. first-stage mount по DT-fstab недоступен без правки
DTB.

INFERENCE (по архитектуре init Android 9; тот же вывод — в прецеденте
`/srv/forge/android/meizu_mx6_m95/TREBLE_VENDOR_PARTITION_PLAN.md` §7a):
без first-stage mount split-sepolicy (`PRODUCT_SEPOLICY_SPLIT`) не взлетит —
plat/vendor-части политики лежат на ещё не смонтированных разделах. Поэтому:

- **База плана: монолитная sepolicy в ramdisk** (без `PRODUCT_SEPOLICY_SPLIT`),
  vendor монтируется в `mount_all` из fstab рамдиска. Для собственной сборки
  LOS 16 этого достаточно; старт вообще с `androidboot.selinux=permissive`,
  как сейчас на 14.1 (FACT: `board/kernel.mk:14`) и как у woods (сеть).
- Правка DTB (добавить fstab-узел через dtc decompile/recompile) — отдельная
  опциональная полоса с собственным гейтом (проект живёт на правиле
  «сток-DTB байт-в-байт»; трогать только ради GSI-стадии, если понадобится).

---

## 2. Что берём готовым, что пишем сами

Готовое:

- **lineage-16.0** — ветки живы у LineageOS (FACT, сеть: branch существует).
- **HIDL-обвязка AOSP/LOS**: passthrough-имплементации
  `audio@2.0-impl`, `camera.provider@2.4-impl` + `camera.device@1.0-impl`,
  `bluetooth@1.0-impl`, `sensors@1.0-impl`, `gnss@1.0-impl`,
  `graphics.composer@2.1-impl` (внутри — `hwc2on1adapter`),
  `mapper@2.0-impl`/`allocator@2.0-impl` (умеют gralloc0),
  `memtrack/power/light/vibrator/health/keymaster@3.0(soft)/gatekeeper` —
  весь список подтверждён рабочим рецептом woods (сеть: `device_woods.mk`,
  `hidl/manifest.xml`).
- **Рецепт-референс**: `iykex/PIE9.0_device_motorola_woods` (MT6737, LOS 16,
  сеть) — карта HIDL-манифеста, shims (`libshim_ril`, `libshim_camera`),
  sepolicy-подход (permissive). Не drop-in: у них arm32 и ядро 3.18.
- **phh GSI v119** (AOSP 9, arm64-aonly, сеть) — для Treble-валидации на
  этапе 6.
- Наши активы: ядро 4.9.188 arm64 (все драйверы уже доведены на 14.1),
  device-дерево 14.1, vendor-блобы (в т.ч. `mtk-ril.so`, `libGLES_mali.so`
  32/64), `forge_hwc`, `btaddr_mtk`, ecc-опыт, expdb-evidence-канал
  (OS-независим — FACT roadmap).

Пишем/портируем сами:

- device-дерево `lineage-16.0` для m5c (BoardConfig, fstab с vendor=custom,
  HIDL-манифест, sepolicy-дельта, init.rc-переработка под P);
- vendor-side телефонию: форк libril/rild с MTK-нюансами (перенос знаний из
  `MT6735.java`/`MtkEccList.java` — §4.6);
- shims по мере обнаружения (по образцу woods);
- ramdisk P (init 9.0) — свой, не стоковый (роадмап B1: ограничение «рамдиск
  общий со стоком» на 15.1+ умирает).

---

## 3. Требования к ядру — конкретный диф

FACT: полный `.config`, сгенерированный из `m5c_defconfig` (make …
m5c_defconfig), сверен построчно с `kernel/configs/android-base.config` этого
же дерева (4.9.188). Расхождения — исчерпывающий список:

| CONFIG | статус | действие / примечание |
|---|---|---|
| `CONFIG_ANDROID_LOW_MEMORY_KILLER` | нет | включить; драйвер в дереве есть (`drivers/staging/android/lowmemorykiller.c`, FACT) |
| `CONFIG_SYNC` | нет | **не существует в 4.9.188** — строка эталона устарела; функционал = `CONFIG_SYNC_FILE=y` + `CONFIG_SW_SYNC=y`, оба уже включены (FACT) |
| `CONFIG_NETFILTER_XT_MATCH_QTAGUID` | нет | **исходника xt_qtaguid в дереве нет вообще** (FACT). P умеет учёт трафика через eBPF: `CONFIG_BPF_SYSCALL=y`, `CONFIG_CGROUP_BPF=y` уже есть (FACT). Рекомендую добавить `CONFIG_BPF_JIT=y`. Верификация на этапе 2: netd стартует, `/sys/fs/bpf` живой. Запасной путь — портировать xt_qtaguid из 4.9-android common (сеть) |
| `CONFIG_PM_AUTOSLEEP` | выключен | включить (suspend-механика P/healthd) |
| `CONFIG_RANDOMIZE_BASE` (KASLR) | выключен | **не включать на этапах бринг-апа**: наша evidence-инфраструктура (DRAM-маркеры, rc49-ринг, FLOG) живёт на фиксированных адресах; VTS для нас не гейт. Отметить как долг |
| `CONFIG_USB_CONFIGFS_F_FS` | выключен | включить — adb на P ходит через f_fs |
| `CONFIG_USB_CONFIGFS_F_MTP` / `F_PTP` | выключен/нет | включить |
| `CONFIG_USB_CONFIGFS_F_ACC` / `F_AUDIO_SRC` | выключен/нет | включить |
| `CONFIG_USB_CONFIGFS_F_MIDI` | выключен | включить (или вырезать midi из USB-конфигов) |

Остальное из android-base уже удовлетворено, в т.ч. критичное для Treble:
`CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"` (FACT — уже в
конфиге). Отдельные ремарки:

- configfs-гаджет на 4.9 доказан живьём (p30) и включается одним свитчем —
  p38-гарды возвращают configfs-путь при выключении `CONFIG_USB_G_ANDROID`
  (FACT, roadmap B0).
- zram/zswap: `CONFIG_ZRAM=y`, `CONFIG_ZSMALLOC=y` уже есть (FACT) — на P с
  2 ГиБ RAM включить zram в fstab обязательно (INFERENCE).
- binderfs не нужен (это Android 11+), ashmem есть.
- INFERENCE (справочно, перепроверить): минимум ядра для P-launch — 4.9.84+;
  наш 4.9.188 проходит с запасом, как upgrade-девайс — тем более.

**Итог по ядру: доработки тривиальны (один defconfig-патч).** Ядро — самый
готовый компонент всей затеи.

---

## 4. HAL-и: что есть → что нужно → путь

| HAL | сейчас (14.1) | нужно на P | путь | оценка риска |
|---|---|---|---|---|
| **Композитор** | `forge_hwc` HWC 1.1, свой код (FACT: `HWC_DEVICE_API_VERSION_1_1`, retire/release-фенсы реализованы — forge_hwc.c:1015,1093,1317) | composer@2.1 HIDL | `composer@2.1-impl` passthrough: загрузчик сам оборачивает HWC1-модуль в `hwc2on1adapter` (FACT, сеть: адаптер в lineage-16.0 есть, ветвится по minor-версии 1.x — 1.1 поддержана; без 1.3+ нет virtual display — нам не нужно) | **низкий-средний**: контракт фенсов/prepare-set у адаптера строже, чем у SF N-эры; дальний план — переписать forge_hwc сразу как HWC2 (наш код, 1349 строк) |
| Gralloc | `gralloc.mt6737m.so` blob (gralloc0, M-эра) | mapper@2.0 + allocator@2.0 | passthrough-имплементации умеют gralloc0 (сеть/AOSP) | низкий |
| GPU | `libGLES_mali.so` 32+64 (FACT) | то же, EGL loader P | как есть; проверить DT_NEEDED под P-неймспейсы | средний |
| **Audio** | MTK HAL **из исходников 2016 в device-дереве** (FACT: `audio/Android.mk` MTK (C) 2016) | audio@2.0 HIDL | пересборка исходников под P + `audio@2.0-impl` поверх; audio_policy → configurable XML | средний: API audio_hw между N и P менялось умеренно |
| **Camera** | blob `camera.mt6737m.so` HAL1 + ~26 libcam-блобов с DT_NEEDED на `libcamera_client` M-эры (FACT, скан §6.2) | camera.provider@2.4 | `provider@2.4-impl` + `camera.device@1.0-impl` (HAL1-путь жив в P) + `libshim_camera` по образцу woods; прецедент в хозяйстве: m6 provider@2.4 поверх legacy (memory) | **высокий**: длинный хвост M-зависимостей; возможно потребуется пачка shim-либ |
| **RIL** | blob-демон `mtkrild` + `gsm0710muxd` + **java-класс `MT6735` через `BOARD_RIL_CLASS`** (FACT: board/telephony.mk) | radio@1.0 HIDL | AOSP `rild` (в P он же хостит IRadio HIDL) + dlopen `mtk-ril.so` (блоб есть, 32+64 — FACT) + `libshim_ril`; `gsm0710muxd`/автозапуск цепочки переносятся как есть (vendor-демоны) | **высокий** — см. §4.6 |
| Wi-Fi | ядро gen2, `CONFIG_CFG80211=y` (FACT), wpa_supplicant N | wifi@1.0 HIDL | `wifi@1.0-service` + libwifi-hal (fallback), wpa_supplicant_8 из P; nvram-путь и `wlan.driver.status`-логика из 14.1 | средний |
| BT | bluedroid + `bluetooth-mtk`/`combo_loader` в дереве, `btaddr_mtk` наш | bluetooth@1.0 HIDL | `bluetooth@1.0-impl` поверх libbt-vendor (MTK /dev/stpbt); btaddr-логику сохранить (три точки кэша адреса — известны) | средний |
| GPS | `gps/gps_hal` исходники + `mtk_mnld`, agpsd 4.151 (Gen-N) | gnss@1.0 HIDL | `gnss@1.0-impl` поверх legacy gps.h HAL | средний; фикс позиции сломан и на 14.1 — переносим как есть, полоса gps-fix независима |
| Sensors | `sensors.mt6737m.so` blob + libhwm | sensors@1.0 | `sensors@1.0-impl` passthrough | низкий |
| Медиа (OMX) | `libMtkOmxVdecEx` и др. — DT_NEEDED на `libstagefright.so` M-эры (FACT, скан) | omx@1.0 | ВЕРОЯТНО НЕ ПЕРЕЖИВУТ; fallback — SW-кодеки P | **высокий**: HW-декод видео скорее всего теряем (см. §6.3) |
| Прочее (light, vibrator, power, memtrack, health, keymaster, gatekeeper, usb, configstore, drm-clearkey) | mix blob/source | HIDL 1.0/2.0/3.0 | стандартные AOSP-имплементации (рецепт woods, сеть) | низкий |

### 4.6 Телефония — главный переписываемый узел

FACT (сеть, lineage-16.0 `TelephonyComponentFactory.makeRIL`): возвращается
`new RIL(...)` без какого-либо ril_class-хука — **механизм `BOARD_RIL_CLASS`
в LOS 16 отсутствует**. Наши `MT6735.java` (парсинг parcel-ов, mux-нюансы) и
`MtkEccList.java` (фикс 91-символьного лимита sysprop, стоивший дня) в P-мире
не подключить как класс.

INFERENCE (по архитектуре P): parcel-уровень уехал из java в нативный
`libril` — java RIL теперь говорит только HIDL. Значит MTK-специфика
(смещения unsol-кодов, MTK-parcel-ы, поведение при GET_SIM_STATUS) должна
жить в **форке libril/rild на vendor-стороне**. Перенос наших знаний из
MT6735.java — ручная работа с построчной сверкой. ECC-логика на P устроена
иначе (EmergencyNumber-трактов ещё нет, они в Q; ecclist-пропы живы) —
лимит 91 символ на sysprop в P ещё действует (INFERENCE, проверить).

HYPOTHESIS: `mtkrild` (blob-демон целиком) на P не поднимется полезным
образом — framework P не слушает socket-RIL. Фальсификатор: поднять его на
этапе 4 и посмотреть, регистрирует ли он HIDL-сервис (почти наверняка нет —
блоб M-эры, HIDL тогда не существовал).

---

## 5. Этапы (каждый — с проверяемой целью)

Правило всех этапов: reference-14.1 остаётся нетронутой прошивкой-откатом;
evidence-канал expdb OS-независим и обязателен; никаких прошивок без
by-name-резолва и сверки размеров (p86); каждая ступень фиксируется в
BRINGUP_STATE + коммитом.

- **Этап 0 — инфраструктура.** Место под дерево P (см. §6.6: сейчас 164 ГБ
  свободно — впритык, нужен shallow-sync и/или чистка), синк lineage-16.0
  (P возит свой prebuilt-JDK — костыль JDK8 не нужен), скелет device-дерева.
  Критерий: `lunch lineage_m5c-userdebug` конфигурируется. Риск: место.
- **Этап 1 — vendor-раздел ещё на 14.1 (де-рискинг разметки).** Прецедент —
  стадия A плана mx6. Пересохранить бэкап custom с девбокса в надёжное место;
  на 14.1 включить `TARGET_COPY_OUT_VENDOR := vendor` + fstab-строку
  custom→/vendor. Критерий: 14.1 бутается с /vendor на p17, матрица
  компонентов не регрессирует. Риск: file_contexts/лейблы, OTA-скрипт.
  Выгода: смена разметки и смена ОС никогда не совмещаются в одной прошивке.
- **Этап 2 — минимальный бут LOS 16.** Наш boot (ядро с §3-патчем конфига,
  P-ramdisk, монолитная sepolicy, permissive) + system LOS 16 + vendor c
  HIDL-обвязкой без экзотики. Критерий: **adb живой, init без crash-loop,
  netd поднялся (eBPF-учёт)**. Риск: eBPF-путь netd на 4.9 (§3), f_fs-гаджет.
- **Этап 3 — дисплей.** composer@2.1-impl + hwc2on1adapter поверх forge_hwc,
  mapper/allocator поверх gralloc0, Mali EGL. Критерий: **boot-анимация и UI
  на экране**. Риск: фенс-контракт адаптера; смотреть и на разрывы — путь SF
  меняется, поведение tearing-полосы даст новые данные.
- **Этап 4 — связь.** RIL-форк (§4.6), Wi-Fi HIDL, BT HIDL. Критерий:
  **SIM READY + регистрация LTE; wifi-скан; BT state ON с заводским
  адресом**. Риск: RIL — самый большой объём ручной работы всего плана.
- **Этап 5 — мультимедиа и остальное.** Камера (provider@2.4 + shims), звук,
  сенсоры, GPS-стек. Критерий: **фото с основной камеры, звук в динамике,
  сенсоры в CTS-Verifier-smoke**. Риск: камера (хвост M-блобов), OMX.
- **Этап 6 — Treble-валидация GSI (опционально, это и есть «Treble готов»).**
  phh v119 arm64-aonly-vanilla вместо нашего system поверх нашего vendor.
  Критерий: **GSI бутается до UI**. Риск: GSI-ожидания к sepolicy/манифесту;
  возможно потребует DT-fstab-полосу (§1.4). Успех открывает 17.1+ по той же
  механике.

---

## 6. Риски и вероятные тупики

1. **RIL-объём.** Не тупик, но самый дорогой пункт: форк libril + перенос
   MT6735-знаний. Закладывать наибольший бюджет времени (INFERENCE).
2. **VNDK enforcement — недостижим, и это принято.** FACT (скан DT_NEEDED
   всех блобов vendor-дерева, 403 ELF): 134 имеют зависимости на
   framework-библиотеки (libbinder 78, libui 57, libcamera_client 26,
   libgui 16, libandroid_runtime 14 …). Это тот же вердикт, что на mx6:
   VNDK-граница для этих блобов невозможна. Работаем в legacy/passthrough
   Treble без `BOARD_VNDK_VERSION` — для LOS 16 и phh-GSI этого достаточно
   (INFERENCE; mx6-план демонстрирует отделимость Treble от VNDK).
3. **HW-видеодекод, вероятно, теряем** (OMX-блобы против libstagefright
   M-эры). SW-декод на 4×A53: 720p — ок, 1080p — сомнительно (INFERENCE).
   Возможный спасательный круг — пересборка MTK omx из исходников, если
   найдутся (HYPOTHESIS, не закладываться).
4. **Front-камера, GPS-фикс, tearing** — не связаны с версией ОС, переезжают
   в текущем статусе; их полосы независимы.
5. **2 ГиБ RAM.** P заметно тяжелее N; с zram и lmkd — жить можно
   (INFERENCE; woods с теми же 2 ГиБ жил). Go-конфиги — запасной рычаг.
6. **Дисковое место сборочной машины: 164 ГБ свободно (FACT df).** Полный
   синк P + out — порядка 150–200 ГБ (INFERENCE). Нужен shallow-sync
   (`repo sync -c --depth=1`), возможно чистка старых out-каталогов. Это
   реальный блокер этапа 0, решаемый хозяйственно.
7. **Цикл прошивки медленный**: fastboot мёртв (p87), всё через TWRP/dd —
   риск темпа, не техники. Recovery-раздел 32 МиБ позволяет жирный TWRP.
8. **Бэкап custom на волатильном /tmp девбокса** — пересохранить до этапа 1
   (иначе теряем стоковые 73 МиБ Meizu-данных; впрочем, стоковый custom.img
   есть и в `/home/n8n/Flyme5.1.6.0A/` — FACT).
9. **KASLR vs evidence-инфраструктура** (§3) — не включать RANDOMIZE_BASE,
   пока живём на DRAM-маркерах.

## 7. Честный вердикт

- **Реалистично**: LOS 16 arm64 до уровня «экран+adb+Wi-Fi/BT+сенсоры+звук»
  — все компоненты имеют проверенный путь (passthrough поверх того, что уже
  работает на 14.1). Ядро готово почти полностью.
- **Реалистично, но дорого**: телефония (форк libril) и камера (shim-хвост).
- **Скорее тупик**: VNDK-полный Treble (принято, не нужен), HW-видеодекод,
  GApps в 1.5 ГиБ system.
- 2 ГиБ RAM и eMMC не являются блокерами ни для одной стадии (INFERENCE).

Первый шаг: этап 1 (vendor на custom ещё на 14.1) — маленький, обратимый,
де-рискует разметку до любых игр с Pie и не мешает текущим полосам 14.1.
