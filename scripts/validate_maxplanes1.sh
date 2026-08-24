#!/system/bin/sh
# validate_maxplanes1.sh — bit-map sanity check for the underflow counters,
# to run BEFORE trusting any forge-uflow numbers (timlid's p80 0xe03 trap).
#
# With exactly ONE overlay plane, only OVL internal RDMA0 should be fetching.
# By the register spec (p88) bits 9-12 = RDMA0..3 FIFO_UNDERFLOW, bits 5-8 =
# RDMA0..3 EOF_ABNORMAL. So with one plane:
#   - rdma_eof_abnormal[1..3] and rdma_fifo_underflow[1..3] SHOULD stay ~0
#     (those engines aren't feeding a layer).
#   - if [1]/[2]/[3] climb with one plane -> the map is still wrong OR the
#     bits latch and are not per-frame -> do NOT trust absolute numbers,
#     treat only [0] and rdma0_uflow, normalised on ovl0_frames.
#
# Push to /data/local/tmp and run: sh /data/local/tmp/validate_maxplanes1.sh
echo "======== maxplanes=1 bit-map check @ $(date) ========"
setprop debug.forgehwc.maxplanes 1
setprop debug.forgehwc.overlays 1
echo "-- restarting SurfaceFlinger (kill; init respawns it) ..."
kill $(pidof surfaceflinger) 2>/dev/null
sleep 20
echo "-- SF back: $(pidof surfaceflinger)"
echo "-- plane count now (expect 1 promoted): $(dumpsys SurfaceFlinger 2>/dev/null | grep -o 'forge-hwc: .*last: planes=[0-9]*' | head -1)"
echo "-- SRC_CON (expect 0x1 = one layer):"
printf forgedump > /sys/kernel/debug/dispsys 2>/dev/null
dmesg | grep 'OVL0 SRC_CON' | tail -1
echo "-- baseline counters:"
printf forgedump > /sys/kernel/debug/dispsys 2>/dev/null
B=$(dmesg | grep 'forge-uflow:' | tail -2)
echo "$B"
echo "-- drive redraws 10s ..."
i=0; while [ $i -lt 20 ]; do input swipe 360 900 360 400 150 >/dev/null 2>&1; i=$((i+1)); done
sleep 1
printf forgedump > /sys/kernel/debug/dispsys 2>/dev/null
echo "-- after-load counters:"
dmesg | grep 'forge-uflow:' | tail -2
echo "VERDICT: if rdma_eof_abnormal[1..3]/rdma_fifo_underflow[1..3] grew with"
echo "one plane, absolute per-engine numbers are NOT trustworthy — use [0] +"
echo "rdma0_uflow only, normalised on ovl0_frames delta. If only [0] grew,"
echo "the map is confirmed and all four engines are readable."
echo "======== end maxplanes=1 check ========"
