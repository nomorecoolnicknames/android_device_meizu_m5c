#!/bin/sh
# Called from BoardConfig.mk: verify that the prebuilt kernel matches
# EXPECTED.txt. Prints nothing on success; on a mismatch prints a short
# marker on stdout (BoardConfig.mk fails the build on it) and details on
# stderr.
#
# This only checks that the image matches what the tree expects, not that
# the expected kernel is the latest one.
#
#   $1 - path to Image.gz-dtb
#   $2 - path to the expectations file (MD5 / VERSION)
set -u
IMG=$1
EXP=$2

# Details go to stderr so make prints them as is; stdout gets a short marker.
[ -f "$IMG" ] || { echo "kernel not found: $IMG" >&2; echo "prebuilt-kernel: kernel missing, see details above"; exit 0; }
[ -f "$EXP" ] || { echo "expectations file not found: $EXP" >&2; echo "prebuilt-kernel: expectations file missing, see details above"; exit 0; }

want_md5=$(awk '$1=="MD5"{print $2}' "$EXP")
have_md5=$(md5sum "$IMG" | cut -d' ' -f1)
[ "$want_md5" = "$have_md5" ] && exit 0

want_ver=$(sed -n 's/^VERSION //p' "$EXP")
have_ver=$(python3 - "$IMG" <<'PY' 2>/dev/null
import sys, zlib, re
d = open(sys.argv[1], 'rb').read()
i = d.find(b'\x1f\x8b\x08')
raw = b''
if i >= 0:
    try:
        raw = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(d[i:])
    except Exception:
        pass
m = re.search(rb'Linux version [0-9][^\x00]{0,120}', raw)
print(m.group(0).decode('utf-8', 'replace') if m else 'version not found')
PY
)

cat >&2 <<MSG
Prebuilt kernel does not match $EXP.
  file:     $IMG
  expected: $want_md5 $want_ver
  found:    $have_md5 $have_ver
Update EXPECTED.txt in the same commit as the kernel.
MSG
echo "prebuilt-kernel: kernel mismatch ($have_md5 instead of $want_md5), see details above"
