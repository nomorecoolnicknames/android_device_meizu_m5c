# Patches for repo-managed projects

These changes apply to projects outside this repository that are managed by
`repo`. Keep them here so a `repo sync` does not lose them.

| Patch | Project |
|---|---|
| vendor_mediatek_FULL.patch | vendor/mediatek |
| vendor_meizu_m5c_FULL.patch | vendor/meizu/m5c |
| vendor_mediatek/0001-android11-integration.patch | vendor/mediatek |
| vendor_meizu_m5c/0001-android11-integration.patch | vendor/meizu/m5c |
| vendor_mediatek_a11_contract.patch | vendor/mediatek |

## Contents

vendor_mediatek_FULL.patch touches Android.mk, include/telephony/ril.h and
ril/libril/{Android.mk, mtk_ril_unsol_commands.h, ril.cpp, ril_service.cpp,
ril_service.h}. It carries three RIL fixes needed for the SIM to work:
1. iccIOForApp passes the MF path as NULL instead of an empty string,
   otherwise EF_ICCID cannot be read and no subscription is created;
2. RIL_InitialAttachApn without roamingProtocol for m5c
   (MTK_RIL_IAA_NO_ROAMING_PROTOCOL, set in ril/libril/Android.mk by
   TARGET_DEVICE), otherwise rild crashes in strlen after registration;
3. dataCallListChangedInd accepts an empty list, otherwise the framework does
   not notice a dropped PDP context.

vendor_meizu_m5c_FULL.patch touches Android.mk (prebuilt librilmtk and
mtk-ril modules) and m5c-vendor-blobs.mk.

The 0001-android11-integration.patch files apply on top of the FULL patches
for Android 11: among other changes, the ICU shim links libandroidicu and the
power HAL blob is installed as power.mt6737m.so.
vendor_mediatek_a11_contract.patch is described in A11_CONTRACT.md.

## Applying

    cd vendor/mediatek && git apply /path/to/vendor_mediatek_FULL.patch
    cd vendor/meizu/m5c && git apply /path/to/vendor_meizu_m5c_FULL.patch

Then apply the Android 11 patches the same way, with `git apply --unidiff-zero`
(they have no context lines).

If the base has moved, use `git apply -3` and resolve the conflicts.
