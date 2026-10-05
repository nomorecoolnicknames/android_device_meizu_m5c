#!/bin/bash
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
