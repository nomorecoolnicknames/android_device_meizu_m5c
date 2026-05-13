#
# Peripheral HALs for the Meizu M5c. Included from device.mk.
# Most legacy hw modules have no unresolved symbols on Pie and only need the
# AOSP passthrough services; audio and camera also need shims.
#

# Wi-Fi
# libwifi-hal-mt66xx comes from vendor/mediatek/wlan. The supplicant service
# and /dev/wmtWifi permissions are in rootdir/forge-connectivity.rc.
PRODUCT_PACKAGES += \
    android.hardware.wifi@1.0-service \
    wpa_supplicant \
    hostapd \
    wificond \
    lib_driver_cmd_mt66xx \
    libwpa_client

# ISupplicant::addInterface copies this template into /data/vendor/wifi/wpa
# and rejects wlan0 without it.
PRODUCT_COPY_FILES += \
    external/wpa_supplicant_8/wpa_supplicant/wpa_supplicant_template.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant.conf \
    device/meizu/m5c/rootdir/forge-connectivity.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/forge-connectivity.rc

# Sensors, lights, vibrator
# Passthrough services over the legacy modules. lights.mt6737m is built from
# source and drives /sys/class/leds/{lcd-backlight,red,green,blue}.
PRODUCT_PACKAGES += \
    android.hardware.sensors@1.0-impl \
    android.hardware.sensors@1.0-service \
    android.hardware.light@2.0-impl \
    android.hardware.light@2.0-service \
    android.hardware.vibrator@1.0-impl \
    android.hardware.vibrator@1.0-service

# Camera
# camera.mt6737m.so is a HAL1 module wrapped by the provider@2.4 default impl
# through camera.device@1.0-impl; both -impl and -service are required. The
# torch also goes through the provider. libmtkshim_gui/ui provide the removed
# libgui/libui symbols (see TARGET_LD_SHIM_LIBS in BoardConfig.mk).
PRODUCT_PACKAGES += \
    android.hardware.camera.provider@2.4-impl \
    android.hardware.camera.provider@2.4-service \
    libmtkshim_gui \
    libmtkshim_ui

# Audio
# audio.primary.mt6737m.so needs libtinyxml, libtinycompress and the MTK
# AudioSystem voice-unlock symbols (no-op shim, shims/audio_voiceunlock.c).
# libtinycompress is built locally (tinycompress/Android.mk): the platform
# module needs generated kernel headers, which a prebuilt kernel lacks.
PRODUCT_PACKAGES += \
    libtinyxml \
    libtinycompress_m5c \
    libshim_audio_m5c

# Bluetooth
# 32-bit HIDL service (bluetooth_hal/Android.bp): libbt-vendor.so and
# libbluetooth_mtk.so are 32-bit only. forge-bluetooth.rc replaces the AOSP
# service and sets the BD address (m5c-bdaddr.sh); without an address the HAL
# aborts on the first enable.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-service.m5c

PRODUCT_COPY_FILES += \
    device/meizu/m5c/rootdir/forge-bluetooth.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/forge-bluetooth.rc \
    device/meizu/m5c/rootdir/m5c-bdaddr.sh:$(TARGET_COPY_OUT_VENDOR)/bin/m5c-bdaddr.sh \
    device/meizu/m5c/rootdir/m5c-stpbt-perm.sh:$(TARGET_COPY_OUT_VENDOR)/bin/m5c-stpbt-perm.sh

# Vibrator
# Built with the LED-class fallback the 4.9 kernel needs; the stock
# vibrator.default.so only supports timed_output.
PRODUCT_PACKAGES += \
    vibrator.mt6737m

# Camera app
# The camera HAL is exposed as LEGACY, which crashes the AOSP Camera2 app.
# Snap uses the Camera1 API.
PRODUCT_PACKAGES += Snap

# Media
# Codec list for the MTK OMX blobs, plus the AOSP Google codec files it
# includes from the same directory. Without it no audio or video decoders are
# available and UI sounds do not load.
PRODUCT_COPY_FILES += \
    device/meizu/m5c/configs/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    device/meizu/m5c/configs/media_codecs_mediatek_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_mediatek_audio.xml \
    device/meizu/m5c/configs/media_codecs_mediatek_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_mediatek_video.xml \
    device/meizu/m5c/configs/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml \
    device/meizu/m5c/configs/media_codecs_google_video_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video_le.xml \
    device/meizu/m5c/configs/media_codecs_performance.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_performance.xml \
    device/meizu/m5c/configs/media_profiles.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles.xml

# SoftAP (untested)
PRODUCT_COPY_FILES += \
    device/meizu/m5c/configs/hostapd/hostapd_default.conf:$(TARGET_COPY_OUT_VENDOR)/etc/hostapd/hostapd_default.conf \
    device/meizu/m5c/configs/hostapd/hostapd.accept:$(TARGET_COPY_OUT_VENDOR)/etc/hostapd/hostapd.accept \
    device/meizu/m5c/configs/hostapd/hostapd.deny:$(TARGET_COPY_OUT_VENDOR)/etc/hostapd/hostapd.deny
