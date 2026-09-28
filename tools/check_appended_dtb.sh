#!/bin/bash
# check_appended_dtb.sh — проверка ЧУЖОГО, уже собранного образа перед
# прошивкой. Третий инструмент в паре к двум существующим, а не замена им:
#
#   tools/los16_repack_boot_kernel.sh — СОБИРАЕТ правильно: gzip -n -9 от
#       raw Image + байт-в-байт стоковый dtb + гейты + abootimg -u с
#       сохранением заголовка. Это основной путь, им и надо пользоваться.
#   tools/check_prebuilt_kernel.sh    — гейт свежести prebuilt из
#       BoardConfig.mk: сверяет md5 положенного в дерево ядра с EXPECTED.txt.
#       Про то, КАКОЙ dtb приклеен, он не знает ничего: если в EXPECTED.txt
#       вписать md5 негодного образа, гейт его узаконит.
#   этот скрипт                       — отвечает на другой вопрос: «мне дали
#       готовый образ, собранный неизвестно чем, — можно его шить?».
#       Не зависит ни от EXPECTED.txt, ни от того, кто собирал.
#       Ровно эта ситуация и случилась 2026-09-03: соседняя полоса собрала
#       ядро штатной целью `make Image.gz-dtb` вместо repack-скрипта.
#
# Ядро 4.9 этого аппарата работает со СТОКОВЫМ DTB, приклеенным к Image.gz.
# Штатная цель `make Image.gz-dtb` (arch/arm64/boot/Makefile:52) клеит DTB,
# СОБРАННЫЙ из дерева, и образ при этом выглядит совершенно нормально:
# правильное имя, правдоподобный размер, никакой ошибки.
#
# ВАЖНО про сырой Image: гейт msdc осмыслен ТОЛЬКО на хвосте-DTB. На сыром
# arch/arm64/boot/Image любое ядро этого дерева читается как
# mt6735m-mmc=1 / mediatek,msdc=2 (имена msdc0_top/msdc1_top живут в самом
# драйвере), и вывод «DTB собранный» был бы ложным. Здесь этой ошибки нет
# по построению: строки считаются ВНУТРИ вырезанного блоба, а не по файлу,
# и на сыром Image скрипт отказывается судить вовсе ("нет приклеенного
# DTB", код 1). Оговорка записана в шапке los16_repack_boot_kernel.sh.
#
# Разница не косметическая. Дети i2c@11009000 расходятся:
#   сток      gsensor@18  msensor@0c  gyro@68  alsps@48  nfc@28
#   собранный gsensor@4c  msensor@0d  gyro@68  alsps@60  nfc@28
# То есть на собранном DTB отваливаются РАБОТАЮЩИЕ акселерометр MC3XXX и
# магнитометр AKM09912, а ALS/PS ищется по адресу, где клиента нет вовсе.
#
#   ./check_appended_dtb.sh <Image.gz-dtb> [ожидаемый-md5-dtb]
#
# Без второго аргумента сверяет со стоковым DTB m5c.
set -u

STOCK_MD5=e17a091033c1e9188df898186be2761f

IMG=${1:-}
WANT=${2:-$STOCK_MD5}

if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "usage: $0 <Image.gz-dtb> [expected-dtb-md5]" >&2
    exit 2
fi

python3 - "$IMG" "$WANT" <<'PY'
import hashlib, sys

img, want = sys.argv[1], sys.argv[2]
data = open(img, 'rb').read()
MAGIC = bytes.fromhex('d00dfeed')

# Вход обязан быть СЖАТЫМ образом. На сыром arch/arm64/boot/Image гейт msdc
# бессмыслен: strings читает там строки самого драйвера и любое исправное
# ядро этого дерева даёт mt6735m-mmc=1 / mediatek,msdc=2, то есть уверенный
# ложный отказ. Отдельный код возврата 2, чтобы «не тот вход» не читался как
# «плохой образ». Замечание bt-stp, 2026-09-03.
if data[:2] != b'\x1f\x8b':
    print("НЕ ТОТ ВХОД: %s не начинается с gzip-сигнатуры 1f 8b." % img)
    print("Гейт применяется к Image.gz-dtb, а не к сырому Image и не к boot.img.")
    print("Для boot.img сначала достаньте ядро (abootimg -x), потом проверяйте его.")
    sys.exit(2)

found = []
i = data.find(MAGIC)
while i != -1:
    # заголовок FDT: magic, totalsize, off_dt_struct, off_dt_strings, ...
    total = int.from_bytes(data[i + 4:i + 8], 'big')
    version = int.from_bytes(data[i + 20:i + 24], 'big')
    if 1000 < total <= len(data) - i and 1 <= version <= 17:
        found.append((i, total))
    i = data.find(MAGIC, i + 1)

if not found:
    print("ОШИБКА: в %s нет приклеенного DTB (магии d00dfeed не найдено)" % img)
    sys.exit(1)

if len(found) > 1:
    print("ВНИМАНИЕ: найдено %d кандидатов DTB, проверяю первый" % len(found))

off, total = found[0]
got = hashlib.md5(data[off:off + total]).hexdigest()
print("образ  : %s (%d байт)" % (img, len(data)))
print("dtb    : off=%d size=%d" % (off, total))
print("md5    : %s" % got)
print("ожидаю : %s" % want)

# Вторая, структурная проверка — на случай, когда сток законно поменяется и
# md5 перестанет быть эталоном. Ключ выбран не косметический: драйвер eMMC
# этого ядра ищет "mediatek,mt6735m-mmc" (msdc_cust.h:46, там же комментарий,
# что имени "mediatek,msdc" в стоковом DTB нет и eMMC тогда не пробится).
# Собранный из дерева DTB несёт ровно обратную пару, то есть на нём аппарат
# не нашёл бы корневую ФС и не загрузился бы вовсе.
blob = data[off:off + total]
stock_key = blob.count(b"mt6735m-mmc")
built_key = blob.count(b"mediatek,msdc\x00")
print("ключ   : mt6735m-mmc=%d  mediatek,msdc=%d" % (stock_key, built_key))
structural_ok = stock_key > 0 and built_key == 0

if got == want and structural_ok:
    print("OK — приклеен ожидаемый DTB, прошивать можно")
    sys.exit(0)

if got == want and not structural_ok:
    print("ОТКАЗ — md5 совпал, но в DTB нет имени eMMC, которое ищет драйвер.")
    print("Либо эталонный md5 в скрипте устарел, либо образ собран не для m5c.")
    sys.exit(1)

if got != want and structural_ok:
    print("ВНИМАНИЕ — md5 не совпал, но структурно DTB стоковый:")
    print("сток мог законно смениться. Прошивать только после сверки вручную.")
    sys.exit(1)

print("ОТКАЗ — приклеен НЕ тот DTB, прошивать НЕЛЬЗЯ")
print()
print("Починить, не пересобирая ядро:")
print("  cat <дерево>/arch/arm64/boot/Image.gz \\")
print("      device/meizu/m5c/captures/20260817-los-first-boot/dtb_stock.dtb \\")
print("      > %s.STOCKDTB" % img)
print("и прогнать этот же гейт по .STOCKDTB")
sys.exit(1)
PY
