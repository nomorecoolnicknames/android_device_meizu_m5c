DEVICE_PATH := device/meizu/m5c
VENDOR_PATH := vendor/meizu/m5c

# Device board elements
include $(DEVICE_PATH)/board/*.mk

# Device cfg
-include $(DEVICE_PATH)/PlatformConfig.mk

#######################################################################

# Kernel
TARGET_KMODULES := true
BOARD_GLOBAL_CFLAGS += -DDISABLE_HW_ID_MATCH_CHECK

# Disable memcpy opt (for audio libraries)
TARGET_CPU_MEMCPY_OPT_DISABLE := true

# EGL
BOARD_EGL_CFG := $(DEVICE_PATH)/configs/egl.cfg
USE_OPENGL_RENDERER := true
BOARD_EGL_WORKAROUND_BUG_10194508 := true

# Flags
BOARD_GLOBAL_CFLAGS += -DNO_SECURE_DISCARD

# Fonts
EXTENDED_FONT_FOOTPRINT := true

# System.prop
TARGET_SYSTEM_PROP := $(DEVICE_PATH)/system.prop

# sepolicy
BOARD_SEPOLICY_DIRS := $(DEVICE_PATH)/sepolicy

# Seccomp filter
BOARD_SECCOMP_POLICY := $(DEVICE_PATH)/seccomp

# Hack for build
$(shell mkdir -p $(OUT)/obj/KERNEL_OBJ/usr)

# Build Station: target device identity override
TARGET_OTA_ASSERT_DEVICE := m5c
BOARD_NAME := m5c
TARGET_SYSTEM_PROP := /srv/forge/android/los14.1-m5c-patched/device/meizu/m5c/system.prop
