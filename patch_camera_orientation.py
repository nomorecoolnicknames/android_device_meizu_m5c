#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Patch the per-camera orientation table inside the prebuilt libcameracustom.so.

Background
----------
On this MTK HAL1 stack the value that ends up in Camera1
``CameraInfo.orientation`` (and therefore in the viewfinder rotation and in the
JPEG rotation the app asks the HAL for) comes from

    NSCamCustomSensor::getSensorOrientation()

inside the Flyme prebuilt ``libcameracustom.so``.  There is no source for that
blob and no Android property that overrides it: ``libcam.halsensor.so`` is the
only consumer of the symbol and it just reads the returned const struct.

The function is a two-instruction stub that returns the address of a const
``SensorOrientation_T`` in ``.rodata``:

    arm   getSensorOrientation:  ldr r0,[pc,#4]; add r0,pc; bx lr
          literal 0x00c9379e + pc(0x101f7a) -> vaddr 0x00d95718
          .rodata Addr 0x001046f0 / Off 0x000fe6f0  -> file offset 0x00d8f718
    arm64 getSensorOrientation:  adrp x0,0xde1000; add x0,x0,#88; ret
          -> vaddr 0x00de1058
          .rodata Addr 0x0014f930 / Off 0x0012d930 -> file offset 0x00dbf058

The struct is four little-endian u32 degrees:
``{ main, sub, main2, unused }`` and ships as ``{90, 270, 90, 0}`` — the plain
MediaTek reference default, not something Meizu tuned for the m5c.

Why we change it
----------------
The kernel driver for the main sensor (S5K4H8) applies ``IMAGE_HV_MIRROR``
(reg 0x0101 = 0x03) in every mode, i.e. the readout is already rotated 180
degrees, and it declares the matching Bayer order ``SENSOR_OUTPUT_FORMAT_RAW_Gb``.
So the stream the HAL actually delivers for camera 0 needs 270, not 90.
``CameraInfo.orientation`` is defined in terms of the delivered image, so 270 is
the truthful value for this stack.  See M5C_CAMERA_ORIENTATION_LANE.md.

Usage
-----
    ./patch_camera_orientation.py --check  <path to libcameracustom.so> ...
    ./patch_camera_orientation.py --main 270 <path to libcameracustom.so> ...

Idempotent: re-running with the same value is a no-op.  Refuses to touch a file
whose size does not match a known blob, or whose table does not hold one of the
values we know about.
"""

import argparse
import hashlib
import struct
import sys

# size -> (arch label, file offset of SensorOrientation_T)
KNOWN = {
    16866932: ("arm (32-bit, the one mediaserver actually loads)", 0x00D8F718),
    17138288: ("arm64 (shipped, not loaded by mediaserver on LOS 14.1)", 0x00DBF058),
}

PRISTINE = (90, 270, 90, 0)
FIELDS = ("main", "sub", "main2", "unused")
SANE = {0, 90, 180, 270}


def read_table(fh, off):
    fh.seek(off)
    return struct.unpack("<4I", fh.read(16))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("libs", nargs="+", help="path(s) to libcameracustom.so")
    ap.add_argument("--check", action="store_true", help="only report the table")
    for f in FIELDS[:3]:
        ap.add_argument("--" + f, type=int, help="new %s orientation in degrees" % f)
    args = ap.parse_args()

    wanted = {i: getattr(args, f) for i, f in enumerate(FIELDS[:3])
              if getattr(args, f) is not None}
    for deg in wanted.values():
        if deg not in SANE:
            sys.exit("refusing: %d is not one of %s" % (deg, sorted(SANE)))

    rc = 0
    for path in args.libs:
        with open(path, "r+b") as fh:
            fh.seek(0, 2)
            size = fh.tell()
            if size not in KNOWN:
                print("%s: SKIP, size %d is not a known libcameracustom.so" % (path, size))
                rc = 1
                continue
            arch, off = KNOWN[size]
            cur = read_table(fh, off)
            if any(d not in SANE for d in cur):
                print("%s: SKIP, table at 0x%x is %s, not degrees — wrong offset?"
                      % (path, off, cur))
                rc = 1
                continue
            print("%s\n  %s\n  offset 0x%08x  current { %s }"
                  % (path, arch, off,
                     ", ".join("%s=%d" % (n, v) for n, v in zip(FIELDS, cur))))
            if args.check or not wanted:
                continue
            new = list(cur)
            for i, deg in wanted.items():
                new[i] = deg
            if tuple(new) == cur:
                print("  already { %s } — nothing to do"
                      % ", ".join("%s=%d" % (n, v) for n, v in zip(FIELDS, new)))
                continue
            fh.seek(off)
            fh.write(struct.pack("<4I", *new))
            fh.flush()
            fh.seek(0)
            md5 = hashlib.md5(fh.read()).hexdigest()
            print("  wrote  { %s }\n  new md5 %s"
                  % (", ".join("%s=%d" % (n, v) for n, v in zip(FIELDS, new)), md5))
    return rc


if __name__ == "__main__":
    sys.exit(main())
