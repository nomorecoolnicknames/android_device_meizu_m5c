#!/system/bin/sh
# validate_subsys.sh <subsystem>  — one-pass on-device validation.
#
# Purpose: device time is expensive (7 flashes ahead, flashing is gated).
# After each boot: flash -> boot -> ONE run of this -> a verdict, no
# improvisation at the phone. Push to /data/local/tmp and run:
#   sh /data/local/tmp/validate_subsys.sh <conn49|sensors49|aud49|av49|cam49|base>
#
# Non-blocking by construction: no read of /proc/kmsg or any FIFO (that hung
# a capture once). dmesg is snapshotted, forgedump is pulsed and read back
# from dmesg. All redirections run inside this on-device script, never in a
# dev.sh one-liner (that trap executes redirects in the container shell).
SUB="${1:-base}"
echo "======== validate_subsys $SUB @ $(date) ========"

## --- 1. identity + alive (display / touch / adb) ---
echo "-- kernel: $(uname -r)"
echo "-- boot_completed=$(getprop sys.boot_completed) bootanim=$(getprop init.svc.bootanim)"
SF=$(dumpsys SurfaceFlinger 2>/dev/null | grep -o 'forge-hwc: session=[^ ]* [0-9x]* period=[0-9]*ns frames=[0-9]*' | head -1)
echo "-- SF: ${SF:-<no forge-hwc line>}"
echo "-- powerMode: $(dumpsys SurfaceFlinger 2>/dev/null | grep -o 'powerMode=[0-9]' | head -1)"
echo "-- input devices (expect >=4: accdet,kpd,tpd,tpd-kpd + subsystem adds): $(grep -c '^I:' /proc/bus/input/devices)"
echo "-- touch node: $(ls /dev/input/event2 2>/dev/null && echo present || echo MISSING)"
echo "-- adb: alive (this script ran)"

## --- 2. display pipeline: underflow counters, normalised on frames ---
echo "-- forgedump pulse #1 ..."
printf forgedump > /sys/kernel/debug/dispsys 2>/dev/null
sleep 3
echo "-- (drive some redraws) --"
input keyevent 224 >/dev/null 2>&1
input swipe 360 900 360 400 200 >/dev/null 2>&1
sleep 1
printf forgedump > /sys/kernel/debug/dispsys 2>/dev/null
echo "-- forge-irq / forge-uflow (last 2 of each = the two pulses):"
dmesg | grep -E "forge-irq:|forge-uflow:" | tail -6
echo "   NOTE reading uflow: reliable = rdma_eof_abnormal[] (bits5-8,IRQ-en) + rdma0_uflow;"
echo "        rdma_fifo_underflow[] (bits9-12) is best-effort. Normalise by ovl0_frames delta."

## --- 3. real MM-domain frequency ---
echo "-- MM clock (clk_summary mm/smi/disp/mmsys):"
if [ -f /sys/kernel/debug/clk/clk_summary ]; then
	grep -iE "mm_|mmsys|smi|disp|mdp" /sys/kernel/debug/clk/clk_summary 2>/dev/null | head -12
else
	echo "   clk_summary absent; mmdvfs step via smi debug if present:"
	cat /sys/module/smi_legacy/parameters/mmdvfs_debug_level 2>/dev/null
fi

## --- 4. CPU freq (context for tear-under-load) ---
echo "-- cpu0 cur/max: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)/$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)"

## --- 5. subsystem-specific criteria ---
echo "-- subsystem criteria [$SUB]:"
case "$SUB" in
  conn49)
	echo "   wlan0: $(ls /sys/class/net/wlan0 >/dev/null 2>&1 && echo YES || echo NO)"
	echo "   net ifaces: $(ls /sys/class/net | tr '\n' ' ')"
	echo "   wmt svc: $(getprop | grep -iE 'init.svc.*(wmt|p2p|wpa)' | tr '\n' ' ')"
	echo "   conn nodes: $(ls /dev/wmtWifi /dev/stpbt /dev/fm /dev/stpgps 2>/dev/null | tr '\n' ' ')"
	echo "   dmesg WMT/CONSYS: $(dmesg | grep -icE 'WMT|CONSYS|mtk_wcn') lines"
	;;
  sensors49)
	echo "   /dev/hwmsensor: $(ls /dev/hwmsensor >/dev/null 2>&1 && echo YES || echo NO)"
	echo "   input devices now: $(grep -c '^I:' /proc/bus/input/devices) (base was ~4)"
	echo "   accel/mag/als in inputs: $(grep -iE 'accel|magn|alsps|gsensor|msensor' /proc/bus/input/devices | tr '\n' ';')"
	;;
  aud49)
	echo "   /dev/snd: $(ls /dev/snd 2>/dev/null | tr '\n' ' ')"
	echo "   snd empty? $([ -z "$(ls /dev/snd 2>/dev/null)" ] && echo EMPTY-BAD || echo populated)"
	echo "   audioserver: $(getprop init.svc.audioserver)"
	;;
  av49)
	echo "   vdec/venc: $(ls /dev/mtk_vdec /dev/mtk_venc /dev/MTK_SMI 2>/dev/null | tr '\n' ' ')"
	echo "   gsm.sim.state: $(getprop gsm.sim.state)"
	echo "   ril: $(getprop init.svc.ril-daemon)"
	echo "   MD1 base (marker survival — compare vs 0x5f/0x7f/0xb0): $(dmesg | grep -iE 'ccci.*reserve|md1.*mem|reserve-memory-ccci' | tail -2)"
	;;
  cam49)
	echo "   camera nodes: $(ls /dev/camera* /dev/video* /dev/kd_camera_hw* 2>/dev/null | tr '\n' ' ')"
	echo "   flashlight: $(ls /dev/flashlight* /sys/class/leds/flashlight* 2>/dev/null | tr '\n' ' ')"
	;;
  base|*)
	echo "   (base image — display/touch/adb liveness above is the whole verdict)"
	;;
esac

## --- 6. dmesg health markers ---
echo "-- dmesg health:"
echo "   DISPERR: $(dmesg | grep -c DISPERR)  panic/Oops/BUG: $(dmesg | grep -icE 'panic|Oops|BUG:')"
echo "   forge-frame setinput last: $(dmesg | grep 'forge-frame: setinput' | tail -1)"
echo "======== end validate_subsys $SUB ========"
