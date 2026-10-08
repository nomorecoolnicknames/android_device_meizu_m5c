#!/vendor/bin/sh
# Start gsm0710muxd once the modem has passed its second handshake
# (md_hs2_msg_notify in the kernel log): the mux gives the modem 10 s to
# answer "+EIND: 128", and a late modem gets reset. Runs in the gsm0710muxd
# domain (gsm0710muxd_exec).
i=0
while [ "$i" -lt 30 ]; do
    dmesg | grep -q md_hs2_msg_notify && break
    sleep 1
    i=$((i + 1))
done
exec /vendor/bin/gsm0710muxd -s /dev/ttyC0 -f 512 -n 8 -m basic
