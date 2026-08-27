# Bluetooth
# Factory BD address: btaddr_mtk exports it from MTK NVRAM
# (APCFG/APRDEB/BT_Addr) to /data/misc/bluetooth/bdaddr; the stack
# reads that file via ro.bt.bdaddr_path (btif_fetch_local_bdaddr).
PRODUCT_PACKAGES += \
    btaddr_mtk

PRODUCT_PROPERTY_OVERRIDES += \
    ro.bt.bdaddr_path=/data/misc/bluetooth/bdaddr
