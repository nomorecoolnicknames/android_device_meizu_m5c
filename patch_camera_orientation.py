#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Fix the per-camera orientation this MTK HAL1 stack reports to Android.

Chain (all of it read out of the prebuilts, see M5C_CAMERA_ORIENTATION_LANE.md):

    CameraService::getCameraInfo()            frameworks/av, no hardcode
      -> camera.mt6737m.so
         CamDeviceManagerBase::getDeviceInfo(int, camera_info&)
             camera_info.orientation <- EnumInfo+20
         CamDeviceManagerImp::enumDeviceLocked()
             EnumInfo+20 <- IMetadataProvider vtable slot +40
      -> libcam.metadataprovider.so
         MetadataProvider::getDeviceWantedOrientation()   (vaddr 0x00016de8)

and that function is:

    entry = staticMeta.entryFor(MTK_SENSOR_INFO_WANTED_ORIENTATION /* 0x000F0012 */)
    if (entry.isEmpty())
        return (this->mOpenId == 0) ? 90 : 270;      <-- hardcoded fallback
    return entry.itemAt(0);

The fallback is what runs on the m5c: the per-sensor static metadata tables
compiled into these blobs only cover the MediaTek reference sensors
(GC0310, GC2145, GC2355, IMX135, IMX219). There is no
constructCustStaticMetadata_*_SENSOR_DRVNAME_S5K4H8_* / _S5K5E8_* symbol in any
blob, so for our sensors MTK_SENSOR_INFO_WANTED_ORIENTATION is never set and
camera 0 is reported as 90.

The main sensor driver (S5K4H8) applies IMAGE_HV_MIRROR (reg 0x0101 = 0x03) in
every mode, i.e. the delivered stream is already rotated 180 degrees, and it
declares the matching RAW_Gb Bayer order.  CameraInfo.orientation is defined in
terms of the delivered image, so the truthful value for camera 0 is 270 — hence
preview and stills come out upside down while the HAL claims 90.

The patch NOPs the condition so the fallback yields 270 for both branches:

    0x00016e02  ldr   r5, [r6, #8]        (left alone, result unused)
    0x00016e04  cmp   r5, #0              (left alone)
    0x00016e06  ite   eq          bf 0c \
    0x00016e08  moveq r0, #90     20 5a  / -> nop; nop   (00 bf 00 bf)
    0x00016e0a  movne r0, #270    f4 4f 87 70  -> now unconditional mov.w #270

The front branch already returned 270, so this changes camera 0 only — and it
only ever runs for sensors that have no metadata table, i.e. both of ours.
The non-empty path (a sensor that does carry MTK_SENSOR_INFO_WANTED_ORIENTATION)
is untouched.

NOT the lever, kept here only so nobody burns a day on it again:
NSCamCustomSensor::getSensorOrientation() in libcameracustom.so returns
{ main=90, sub=270, main2=90 } at file offset 0x00d8f718 (arm) / 0x00dbf058
(arm64), but its only consumer is ImgSensorDrv::sendCommand() in
libcam.halsensor.so — it goes down to the kernel driver, not into camera_info.
Patching it to 270 was tried on hardware and dumpsys media.camera still said 90.
`--check` prints it for reference and refuses to write it.

Usage:
    ./patch_camera_orientation.py --check  <libs...>
    ./patch_camera_orientation.py --apply  <path to libcam.metadataprovider.so>
    ./patch_camera_orientation.py --revert <path to libcam.metadataprovider.so>
"""

import argparse
import hashlib
import struct
import sys

# --- libcam.metadataprovider.so, arm 32-bit (the copy mediaserver loads) ------
MDP_ARM_SIZE = 222828
MDP_ARM_OFF = 0x00015E06          # vaddr 0x00016e06, .text Addr 0x7a20 / Off 0x6a20
MDP_PRISTINE = bytes.fromhex("0cbf5a20")   # ite eq ; moveq r0, #90
MDP_PATCHED = bytes.fromhex("00bf00bf")    # nop ; nop
MDP_TAIL = bytes.fromhex("4ff48770")       # mov(ne).w r0, #270 — must follow both

# --- libcameracustom.so orientation quad: informational only -----------------
CUSTOM_QUAD = {
    16866932: ("libcameracustom.so arm", 0x00D8F718),
    17138288: ("libcameracustom.so arm64", 0x00DBF058),
}


def report_quad(path, fh, size):
    label, off = CUSTOM_QUAD[size]
    fh.seek(off)
    quad = struct.unpack("<4I", fh.read(16))
    print("%s\n  %s — NOT the lever (feeds ImgSensorDrv::sendCommand, not "
          "camera_info)\n  offset 0x%08x  { main=%d, sub=%d, main2=%d, unused=%d }"
          % (path, label, off, *quad))


def handle_mdp(path, fh, args):
    fh.seek(MDP_ARM_OFF)
    cur = fh.read(4)
    tail = fh.read(4)
    if tail != MDP_TAIL:
        print("%s: SKIP, no mov.w r0,#270 at 0x%08x — wrong offset or different "
              "blob revision" % (path, MDP_ARM_OFF + 4))
        return 1
    state = {MDP_PRISTINE: "pristine (main=90)", MDP_PATCHED: "patched (main=270)"}.get(cur)
    if state is None:
        print("%s: SKIP, bytes at 0x%08x are %s, expected %s or %s"
              % (path, MDP_ARM_OFF, cur.hex(), MDP_PRISTINE.hex(), MDP_PATCHED.hex()))
        return 1
    print("%s\n  libcam.metadataprovider.so arm — getDeviceWantedOrientation "
          "fallback\n  offset 0x%08x  %s" % (path, MDP_ARM_OFF, state))
    if args.check:
        return 0
    want = MDP_PATCHED if args.apply else MDP_PRISTINE
    if cur == want:
        print("  already there — nothing to do")
        return 0
    fh.seek(MDP_ARM_OFF)
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
    g.add_argument("--revert", action="store_true", help="back to stock 90/270")
    args = ap.parse_args()
    if not (args.apply or args.revert):
        args.check = True

    rc = 0
    for path in args.libs:
        mode = "r+b" if not args.check else "rb"
        with open(path, mode) as fh:
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
