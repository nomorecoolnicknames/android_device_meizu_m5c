#!/system/bin/sh
# One-shot at boot_completed: reconcile the Settings.Secure cached
# Bluetooth address with the factory one exported by btaddr_mtk.
#
# BluetoothManagerService loads bluetooth_address once at startup and
# refreshes it only while it is empty (isNameAndAddressSet), so a
# 22:22:xx:xx:xx:xx autogen address stored by an earlier build sticks
# forever (dumpsys, and getAddress while BT is off). A change made
# here is picked up on the next boot.

new="$(cat /data/misc/bluetooth/bdaddr 2>/dev/null)"
case "$new" in
    [0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]) ;;
    *) exit 0 ;;
esac

cur="$(settings get secure bluetooth_address 2>/dev/null)"
if [ "$cur" != "$new" ]; then
    settings put secure bluetooth_address "$new"
    settings put secure bluetooth_addr_valid 1
    log -t btaddr_mtk "settings cache updated: ${cur} -> ${new}"
fi
