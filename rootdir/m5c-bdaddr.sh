#!/vendor/bin/sh
# Publish the factory Bluetooth address from MTK NVRAM for the Bluetooth HAL.
#
# The AOSP HAL aborts without an address. Write the factory address from
# NVRAM (BT_Addr, first 6 bytes) as ASCII to the file named by
# ro.bt.bdaddr_path. Started once NVRAM is ready (service.nvram_init=Ready).

set -u

NV=/data/nvram/APCFG/APRDEB/BT_Addr

[ -r "$NV" ] || exit 0

OUT=/data/vendor/bluetooth/bdaddr

addr=$(od -An -tx1 -N6 "$NV" 2>/dev/null | tr -d ' \n' | tr 'a-f' 'A-F')

# Six bytes, twelve hex digits, and not one of the two degenerate addresses
# NVRAM shows when it has never been provisioned.
case "$addr" in
    ????????????) ;;
    *) exit 0 ;;
esac
[ "$addr" = "000000000000" ] && exit 0
[ "$addr" = "FFFFFFFFFFFF" ] && exit 0

formatted=$(echo "$addr" | sed 's/../&:/g; s/:$//')
# Rewritten on every boot, atomically, readable by the HAL (user bluetooth).
printf '%s' "$formatted" > "$OUT.tmp" || exit 0
chmod 0644 "$OUT.tmp"
mv -f "$OUT.tmp" "$OUT"

exit 0
