#!/vendor/bin/sh
# m5c-muxd.sh — start gsm0710muxd once the modem has passed its second
# handshake (init.m5c.modem.rc).  This was an inline `/system/bin/sh -c`
# service; a vendor service cannot run a system shell in its own domain under
# enforcing, so the wait lives here and the file carries gsm0710muxd_exec
# (sepolicy/vendor/file_contexts): init transitions to gsm0710muxd on exec.
#
# Why wait (FACT, LOS 16 on this unit, forge-modem.rc): the mux gives the
# modem 10 s to answer "+EIND: 128"; a late modem -> ASSERT -> muxreport
# resets it.  md_hs2_msg_notify in the kernel log marks the second handshake.
i=0
while [ "$i" -lt 30 ]; do
    dmesg | grep -q md_hs2_msg_notify && break
    sleep 1
    i=$((i + 1))
done
exec /vendor/bin/gsm0710muxd -s /dev/ttyC0 -f 512 -n 8 -m basic
