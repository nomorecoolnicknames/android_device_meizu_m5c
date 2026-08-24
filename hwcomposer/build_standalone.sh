#!/bin/sh
# Standalone build of hwcomposer.mt6737m.so without a full ROM checkout
# build.  Uses the ROM tree's own prebuilts: gcc 4.9 (the same toolchain
# the kernels are built with) and the NDK android-24 platform libs, so the
# result links only against libc/liblog/libdl/libm that exist on the
# device.  The Android.mk next to this script is the canonical in-tree
# build; this script exists so a devbox session can produce a testable
# binary in seconds.
set -e

TREE=$(cd "$(dirname "$0")/../../../.." && pwd)
SRC=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$SRC/out}
mkdir -p "$OUT/lib64" "$OUT/lib"

CFLAGS="-O2 -fPIC -Wall -Wno-unused-parameter -fno-exceptions
  -I$SRC
  -I$TREE/hardware/libhardware/include
  -I$TREE/system/core/include"

# arm64
GCC64=$TREE/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-gcc
SYS64=$TREE/prebuilts/ndk/current/platforms/android-24/arch-arm64
$GCC64 $CFLAGS --sysroot="$SYS64" -shared -nostdlib \
  -Wl,-soname,hwcomposer.mt6737m.so \
  "$SYS64/usr/lib/crtbegin_so.o" "$SRC/forge_hwc.c" "$SYS64/usr/lib/crtend_so.o" \
  -L"$SYS64/usr/lib" -lc -llog -ldl -lm \
  -o "$OUT/lib64/hwcomposer.mt6737m.so"

# arm32
GCC32=$TREE/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-gcc
SYS32=$TREE/prebuilts/ndk/current/platforms/android-24/arch-arm
$GCC32 $CFLAGS --sysroot="$SYS32" -shared -nostdlib \
  -Wl,-soname,hwcomposer.mt6737m.so \
  "$SYS32/usr/lib/crtbegin_so.o" "$SRC/forge_hwc.c" "$SYS32/usr/lib/crtend_so.o" \
  -L"$SYS32/usr/lib" -lc -llog -ldl -lm \
  -o "$OUT/lib/hwcomposer.mt6737m.so"

md5sum "$OUT/lib64/hwcomposer.mt6737m.so" "$OUT/lib/hwcomposer.mt6737m.so"
