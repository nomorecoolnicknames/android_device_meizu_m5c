#!/vendor/bin/sh
# Hand /dev/stpbt to the bluetooth user. The node is created only when
# wmt_loader loads the connectivity drivers, and the ramdisk ueventd rule uses
# a group that does not exist on Pie, so wait for the node and fix it here.
i=0
while [ "$i" -lt 60 ]; do
    if [ -c /dev/stpbt ]; then
        chown bluetooth:bluetooth /dev/stpbt
        chmod 0660 /dev/stpbt
        echo "forge-stpbt-perm: /dev/stpbt -> bluetooth:bluetooth 0660 after ${i}s" > /dev/kmsg
        exit 0
    fi
    sleep 1
    i=$((i + 1))
done
echo "forge-stpbt-perm: /dev/stpbt never appeared after ${i}s" > /dev/kmsg
exit 1
