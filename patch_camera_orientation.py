#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Fix the per-camera orientation this MTK HAL1 stack reports to Android.

Chain, all of it read out of the prebuilts and confirmed by the HAL's own log
line (see M5C_CAMERA_ORIENTATION_LANE.md):

    CameraService::getCameraInfo()                 frameworks/av, no hardcode
      -> camera.mt6737m.so
         CamDeviceManagerBase::getDeviceInfo @0x4c24   camera_info.orientation
                                                       <- EnumInfo+20
         CamDeviceManagerImp::enumDeviceLocked @0x437c EnumInfo+20
                                                       <- provider vtable +40
      -> libcam.metadataprovider.so
         MetadataProvider::getDeviceWantedOrientation @0x16de8
             returns IMetadata entry MTK_SENSOR_INFO_WANTED_ORIENTATION
      -> the entry is written by
         constructCustStaticMetadata_DEVICE_CAMERA_COMMON @0x7bf4

The HAL logs the result itself:

    I/MtkCam/devicemgr: [enumDeviceLocked] [0x00] DeviceVersion:0x100 \
        metadata:0x... facing:0 orientation(wanted/setup)=(90/90)

`constructCustStaticMetadata_DEVICE_CAMERA_COMMON` is the tier-2 default table.
`HalSensorList::buildStaticInfo` @0xf524 in libcam.halsensor.so builds each
symbol name per category and per sensor drvname, and on a miss retries with the
default name; the per-sensor tables in these blobs only exist for the MediaTek
reference sensors (GC0310, GC2145, GC2355, IMX135, IMX219), so an m5c sensor
always lands on the COMMON table.  There it picks by facing:

    0x7cb6  r7 = [selector]
    0x7cba  cbz r7, 0x7cc8              ; facing 0 (main) -> the 90 branch
    0x7cbe  mov.w r7, #270              ; facing 1 (front) -> 270
    0x7cc8  IEntry(MTK_SENSOR_INFO_ORIENTATION        = 0x000F000B)
    0x7cd0  mov.w sl, #90               ; <-- the value we change
    0x7ce0  IEntry::push_back(sl); IMetadata::update()
    0x7d28  IEntry(MTK_SENSOR_INFO_WANTED_ORIENTATION = 0x000F0012)
    0x7d30  str.w sl, [sp, #20]         ; same sl -> one patch fixes both tags
    0x7d3c  IEntry::push_back(sl); IMetadata::update()

The main sensor driver (S5K4H8) applies IMAGE_HV_MIRROR (reg 0x0101 = 0x03) in
every mode with the matching RAW_Gb Bayer order, i.e. the delivered stream is
already rotated 180 degrees.  CameraInfo.orientation is defined in terms of the
delivered image, so 270 is the truthful value for camera 0 — hence preview and
stills come out upside down while the HAL claims 90.

The patch rewrites that one constant, same instruction width:

    0x00006cd0 (file)   4f f0 5a 0a   mov.w sl, #90
                     -> 4f f4 87 7a   mov.w sl, #270

Only the facing-0 branch changes; the front branch already produced 270.

DEAD ENDS, kept so nobody burns another day on them — both were patched, pushed
to the device and measured, and neither moved the reported value:

  1. NSCamCustomSensor::getSensorOrientation() in libcameracustom.so returns
     { main=90, sub=270, main2=90 } at file offset 0x00d8f718 (arm) /
     0x00dbf058 (arm64).  Its only call sites are inside
     ImgSensorDrv::sendCommand() in libcam.halsensor.so — it goes down to the
     kernel driver, not into camera_info.
  2. The hardcoded fallback inside getDeviceWantedOrientation itself
     (file 0x00015e06, `ite eq / moveq r0,#90 / movne.w r0,#270`) is never
     reached: the COMMON table does set the tag, so entry.isEmpty() is false.

`--check` reports all three sites; only the COMMON constant is writable.

Usage:
    ./patch_camera_orientation.py --check  <libs...>
    ./patch_camera_orientation.py --apply  <path to libcam.metadataprovider.so>
    ./patch_camera_orientation.py --revert <path to libcam.metadataprovider.so>
"""

import argparse
import hashlib
import struct
import sys

MDP_ARM_SIZE = 222828

# the live lever: COMMON table's facing-0 orientation constant
COMMON_OFF = 0x00006CD0
COMMON_90 = bytes.fromhex("4ff05a0a")     # mov.w sl, #90
COMMON_270 = bytes.fromhex("4ff4877a")    # mov.w sl, #270

# dead end 2: the unreachable fallback inside getDeviceWantedOrientation
FALLBACK_OFF = 0x00015E06
FALLBACK_STOCK = bytes.fromhex("0cbf5a20")   # ite eq ; moveq r0, #90
FALLBACK_NOPPED = bytes.fromhex("00bf00bf")  # nop ; nop

# dead end 1: libcameracustom.so orientation quad, by file size
CUSTOM_QUAD = {
    16866932: ("libcameracustom.so arm", 0x00D8F718),
    17138288: ("libcameracustom.so arm64", 0x00DBF058),
}


def report_quad(path, fh, size):
    label, off = CUSTOM_QUAD[size]
    fh.seek(off)
    quad = struct.unpack("<4I", fh.read(16))
    print("%s\n  %s — DEAD END, feeds ImgSensorDrv::sendCommand, not camera_info"
          "\n  offset 0x%08x  { main=%d, sub=%d, main2=%d, unused=%d }"
          % (path, label, off, *quad))


def handle_mdp(path, fh, args):
    fh.seek(COMMON_OFF)
    cur = fh.read(4)
    state = {COMMON_90: "stock (main=90)", COMMON_270: "patched (main=270)"}.get(cur)
    if state is None:
        print("%s: SKIP, bytes at 0x%08x are %s, expected %s or %s"
              % (path, COMMON_OFF, cur.hex(), COMMON_90.hex(), COMMON_270.hex()))
        return 1
    fh.seek(FALLBACK_OFF)
    fb = fh.read(4)
    fb_state = {FALLBACK_STOCK: "stock", FALLBACK_NOPPED: "NOPPED — undo this, "
                "it is a dead end"}.get(fb, "unrecognised (%s)" % fb.hex())
    print("%s\n  libcam.metadataprovider.so arm\n"
          "  COMMON table orientation  offset 0x%08x  %s\n"
          "  unreachable fallback      offset 0x%08x  %s"
          % (path, COMMON_OFF, state, FALLBACK_OFF, fb_state))
    if args.check:
        return 0
    want = COMMON_270 if args.apply else COMMON_90
    if cur == want:
        print("  already there — nothing to do")
        return 0
    fh.seek(COMMON_OFF)
    fh.write(want)
    fh.flush()
    fh.seek(0)
    print("  wrote %s\n  new md5 %s" % (want.hex(), hashlib.md5(fh.read()).hexdigest()))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("libs", nargs="+")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--check", action="store_true", help="report only (default)")
    g.add_argument("--apply", action="store_true", help="main camera -> 270")
    g.add_argument("--revert", action="store_true", help="back to stock 90")
    args = ap.parse_args()
    if not (args.apply or args.revert):
        args.check = True

    rc = 0
    for path in args.libs:
        with open(path, "rb" if args.check else "r+b") as fh:
            fh.seek(0, 2)
            size = fh.tell()
            if size in CUSTOM_QUAD:
                report_quad(path, fh, size)
            elif size == MDP_ARM_SIZE:
                rc |= handle_mdp(path, fh, args)
            else:
                print("%s: SKIP, size %d is not a blob this script knows" % (path, size))
                rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
