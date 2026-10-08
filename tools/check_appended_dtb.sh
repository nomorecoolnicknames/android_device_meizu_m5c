#!/bin/bash
# Check that a built Image.gz-dtb carries the stock DTB before flashing it.
#
# The 4.9 kernel must run with the stock DTB appended to Image.gz. The
# `make Image.gz-dtb` target appends the DTB built from the kernel tree,
# which uses different I2C sensor addresses and lacks the eMMC compatible
# string "mediatek,mt6735m-mmc", so the device would not find its storage.
#
#   ./check_appended_dtb.sh <Image.gz-dtb> [expected-dtb-md5]
#
# Without the second argument the stock m5c DTB md5 is used.
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

# The input must be the gzip image: on a raw Image the driver's own strings
# would give a false result. Exit code 2 means wrong input.
if data[:2] != b'\x1f\x8b':
    print("WRONG INPUT: %s does not start with the gzip magic 1f 8b." % img)
    print("Pass an Image.gz-dtb, not a raw Image or a boot.img.")
    print("For a boot.img, extract the kernel first (abootimg -x).")
    sys.exit(2)

found = []
i = data.find(MAGIC)
while i != -1:
    # FDT header: magic, totalsize, off_dt_struct, off_dt_strings, ...
    total = int.from_bytes(data[i + 4:i + 8], 'big')
    version = int.from_bytes(data[i + 20:i + 24], 'big')
    if 1000 < total <= len(data) - i and 1 <= version <= 17:
        found.append((i, total))
    i = data.find(MAGIC, i + 1)

if not found:
    print("ERROR: no appended DTB in %s (magic d00dfeed not found)" % img)
    sys.exit(1)

if len(found) > 1:
    print("WARNING: %d DTB candidates found, checking the first one" % len(found))

off, total = found[0]
got = hashlib.md5(data[off:off + total]).hexdigest()
print("image  : %s (%d bytes)" % (img, len(data)))
print("dtb    : off=%d size=%d" % (off, total))
print("md5    : %s" % got)
print("expect : %s" % want)

# Structural check, in case the stock DTB changes legitimately: the eMMC
# driver matches "mediatek,mt6735m-mmc", the tree-built DTB has
# "mediatek,msdc" instead.
blob = data[off:off + total]
stock_key = blob.count(b"mt6735m-mmc")
built_key = blob.count(b"mediatek,msdc\x00")
print("keys   : mt6735m-mmc=%d  mediatek,msdc=%d" % (stock_key, built_key))
structural_ok = stock_key > 0 and built_key == 0

if got == want and structural_ok:
    print("OK - the expected DTB is appended, safe to flash")
    sys.exit(0)

if got == want and not structural_ok:
    print("FAIL - md5 matches, but the DTB lacks the eMMC compatible the driver needs.")
    print("Either the reference md5 is outdated or the image is not for m5c.")
    sys.exit(1)

if got != want and structural_ok:
    print("WARNING - md5 differs, but the DTB looks like the stock one:")
    print("the stock DTB may have changed. Verify manually before flashing.")
    sys.exit(1)

print("FAIL - wrong DTB appended, do not flash")
print()
print("Fix without rebuilding the kernel:")
print("  cat <kernel-out>/arch/arm64/boot/Image.gz \\")
print("      <stock DTB from boot.img, 69427 bytes> \\")
print("      > %s.STOCKDTB" % img)
print("and run this check again on the .STOCKDTB file")
sys.exit(1)
PY
