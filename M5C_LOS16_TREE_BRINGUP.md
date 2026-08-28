# M5C_LOS16_TREE_BRINGUP — скелет дерева LOS 16.0 для m5c на gunwest

Дата: 2026-08-28. Лейн: `los16-m5c`. Это исполнение этапа 0 из
`M5C_LOS16_TREBLE_PLAN.md` §5 («скелет device-дерева, критерий —
`lunch lineage_m5c-userdebug` конфигурируется»). Метки по CLAUDE.md §2.

## 1. Итог этапа (FACT)

**Гейт пройден.** На gunwest (`/home/gun/m6rom16/rom`, ветка lineage-16.0):

```
$ export OUT_DIR=out-m5c16
$ source build/envsetup.sh && lunch lineage_m5c-userdebug
PLATFORM_VERSION=9
LINEAGE_VERSION=16.0-20260828-UNOFFICIAL-m5c
TARGET_PRODUCT=lineage_m5c
TARGET_BUILD_VARIANT=userdebug
TARGET_ARCH=arm64  TARGET_ARCH_VARIANT=armv8-a
TARGET_2ND_ARCH=arm  TARGET_2ND_ARCH_VARIANT=armv8-a
OUT_DIR=/home/gun/m6rom16/rom/out-m5c16
```

`mka`/`brunch` НЕ запускались (запрет владельца: на диске gunwest 80 ГБ
свободно, полную сборку решает владелец).

**Грабля хоста (FACT):** общий `out/` в этом дереве принадлежит root
(остатки сборки `lineage_meizu_m6` от 2026-08-06); без `OUT_DIR` lunch
падает на `rm out/.soong_ui.trace: Permission denied`, после чего roomservice
идёт искать «device m5c» на GitHub и морочит голову ложным
«Don't have a product spec». **Правило: для m5c всегда
`export OUT_DIR=out-m5c16`** (соседи так же живут в `out-m681-treble` и
`m95-out16`). Сообщение lunch «Trying dependencies-only mode on a
non-existing device tree?» — это roomservice не нашёл `lineage.dependencies`;
безвредно.

## 2. Что создано

### device/meizu/m5c (новое, написано с нуля по образцам m95/m681)

| файл | происхождение |
|---|---|
| `BoardConfig.mk` | standalone по модели m95 + vendor-блок m681; значения из 14.1 `board/*.mk`/`PlatformConfig.mk` |
| `device.mk` | новый; inherit vendor, dalvik-heap 2048 явно, ramdisk-копии, keylayout, permission-xml по матрице 2026-08-28 |
| `lineage_m5c.mk` | по m95: core_64_bit ДО phone-стека, `LINEAGE_BUILD := m5c`, SHIPPING_API 25, FULL_TREBLE_OVERRIDE false |
| `AndroidProducts.mk`, `vendorsetup.sh` | COMMON_LUNCH_CHOICES + add_lunch_combo |
| `Android.mk` | guard `ifeq ($(TARGET_DEVICE),m5c)` |
| `rootdir/fstab.mt6735` | **новый**: `custom` (by-name) → `/vendor` ext4 ro wait; zram 512 МиБ; forceencrypt снят |
| `rootdir/init*.rc, ueventd, enableswap.sh` | копии из 14.1 `rootdir/root/` — N-эра, НЕ портированы под Pie-init (этап 2) |
| `keylayout/{mtk-kpd,mtk-tpd,mtk-tpd-kpd,ACCDET}.kl` | копии 14.1 `configs/keylayout` |
| `seccomp/mediacodec.policy` | 14.1 `mediacodec-seccomp.policy`, Pie-имя; ставится в `/vendor/etc/seccomp_policy/` (урок m681: без него omx ловит SIGSYS → бутлуп) |
| `system.prop` | 14.1 минус `ro.telephony.ril_class=MT6735` (механизм мёртв в P, §4.6 плана) |
| `overlay/.../config.xml` | пустой `<resources/>` — намеренно: N-овые имена ресурсов в Pie ломают сборку молча, портируем по этапам |
| `prebuilt-kernel/Image.gz-dtb` | см. §3 |

### vendor/meizu/m5c (перенос)

Полная копия 14.1-дерева (293 МБ, tar+push, md5 сверен:
`86e59ead562112631e78d090462cf0d9`). `m5c-vendor-blobs.mk` не тронут —
его защитные комментарии (md_ctrl и hwcomposer-блобы НАМЕРЕННО отсутствуют,
оба затирали собранные из исходников модули и ломали загрузку) сохранены.
**Единственная правка: `Android.mk` обёрнут в `ifeq ($(TARGET_DEVICE),m5c)`** —
иначе его BUILD_PREBUILT-модули (`libnvram`, `libdpframework`, …) начали бы
определяться и в сборках соседей m681/m95 в том же дереве и коллидировать
по именам (INFERENCE по устройству make-скана; не проверял на живой сборке
соседа и проверять не хочу).

## 3. Prebuilt-ядро (FACT)

Источник: worktree `pie49`, ветка `pie-config`, коммит `d0f794f8d`,
`vmlinux` = `Linux version 4.9.188-m5c+ #3 SMP PREEMPT Fri Aug 28 12:32:18`.

Сборка: `aarch64-linux-android-objcopy -O binary -R .note -R
.note.gnu.build-id -R .comment -S vmlinux Image` (17 717 256 Б) →
`gzip -n -9` → конкатенация со **стоковым** `dtb_stock.dtb`
(`captures/20260817-los-first-boot/`, 69 427 Б).

Итог `Image.gz-dtb` 7 808 134 Б, md5 `e8a6ab87e2b98ddc01d558bb3c8249d4`.
Гейт упаковки выдержан на самом файле: `strings | grep -c mt6735m-mmc` == 2,
`grep -c 'mediatek,msdc'` == 0, `gunzip -t` OK. Формат идентичен рабочему
14.1 `rootdir/kernel` (тот тоже gzip+DTB-хвост, 7 818 595 Б).

## 4. Что из рецепта m681 НЕ переносимо и почему

1. **`mt6755-common`/`meizu_mt675x-common` include** — семейство другое
   (MT6737M = mt6735-ветка). BoardConfig standalone, как у m95.
2. **`TARGET_LD_SHIM_LIBS` каскад (DISPLAY_SHIM_CASCADE.md)** — шимы под
   blob-hwcomposer/gui_ext mt6755. Наш композитор `forge_hwc` собирается из
   исходников; каскад не тащим, дисплейная полоса (этап 3) пойдёт через
   `composer@2.1-impl` + `hwc2on1adapter` поверх forge_hwc (план §4).
3. **RIL из vendor/mediatek/ril (`ENABLE_VENDOR_RIL_SERVICE`)** — рецепт
   правильный, но это этап 4; сокет-нюансы (`rild-mal`, `user root`) из
   `rild-mtk-hidl.rc` придётся подгонять под ccci/mux m5c (у нас
   `mtkrild`+`gsm0710muxd` авто-цепочка своя, MD1 lwg, не ulwctg).
4. **Геометрия boot**: у m681/m95 ramdisk_offset `0x04f88000`/tags
   `0x03f88000`; у m5c — ramdisk `0x03f88000`, tags `0x0df88000`, kernel
   offset `0x00080000`, `--board mt6737` (FACT, 14.1 `board/kernel.mk`,
   грузится ежедневно). Копировать чужую геометрию нельзя.
5. **Ядро из исходников** (m681) — у нас prebuilt-лейн (m95-паттерн):
   `TARGET_KERNEL_SOURCE :=` пустой + `TARGET_PREBUILT_KERNEL`.
6. **recovery 32 МиБ** — по getvar (план §1.1), а не 20 МиБ из 14.1
   BoardConfig (известное противоречие, ground truth getvar).

Перенято дословно: Treble stage A блок (vendor 512 МиБ ext4, A-only, без
VNDK, SHIPPING_API 25), `SELINUX_IGNORE_NEVERALLOWS`, отключение
boot-image-профиля (profman SIGBUS на этом хосте — свойство хоста, не
продукта), `TARGET_2ND_ARCH_VARIANT := armv8-a` (parse-гейт m95),
`androidboot.hardware=` в cmdline (у нас `mt6735` — по именам
`init.mt6735.rc`/`fstab.mt6735`, которые живое 14.1-устройство реально
использует; INFERENCE, проверится на первом боте этапа 2).

## 5. Осталось (этапы 1+)

- **Этап 1 (де-рискинг разметки)**: /vendor на custom ещё на 14.1 — не начат.
- **Этап 2**: Pie-ramdisk: rc-набор в `rootdir/` — сырые N-копии; sepolicy
  нет вообще; vendor-манифеста (`manifest.xml`) нет; USB configfs rc нет.
- `m5c-vendor-blobs.mk` кладёт всё в `system/...` — при реальном /vendor
  пути надо пересобрать список (и решить, что уезжает в vendor.img).
- HAL backbone в `device.mk` минимален (hw/vnd/servicemanager);
  per-HAL сервисы добавляются по этапам, чтобы каждый отказ был атрибутируем.
- `PRODUCT_COPY_FILES` ссылается на
  `frameworks/native/data/etc/android.hardware.camera.xml` — существование
  в этом дереве не проверено (проверится первым `mka`; остальные имена — по
  рабочему списку m681).
- Сборка `mka` не запускалась — решение владельца (место на диске).

## 6. Следы

- gunwest: `device/meizu/m5c/`, `vendor/meizu/m5c/`, `out-m5c16/` (24 МБ,
  только конфигурация lunch). Архивы из `/home/gun/incoming` удалены.
  Чужие `out-m681-treble`, `m95-out16`, root-овый `out/` не тронуты.
- Локально: этот файл; staging и ядро — в session-scratchpad (эфемерно).
