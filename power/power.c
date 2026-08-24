/*
 * Copyright (C) 2012 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#define LOG_TAG "PowerHAL"
#include <utils/Log.h>

#include <hardware/hardware.h>
#include <hardware/power.h>

#define MT_RUSH_BOOST_PATH "/proc/hps/rush_boost_enabled"
#define MT_FPS_UPPER_BOUND_PATH "/d/ged/hal/fps_upper_bound"
#define INTERACTIVE_BOOSTPULSE_PATH \
    "/sys/devices/system/cpu/cpufreq/interactive/boostpulse"


#define POWER_HINT_POWER_SAVING 0x00000101
#define POWER_HINT_PERFORMANCE_BOOST 0x00000102
#define POWER_HINT_BALANCE  0x00000103

static void power_init(struct power_module *module)
{
}

static void power_set_interactive(struct power_module *module, int on)
{
}

static void power_fwrite(const char *path, char *s)
{
    char buf[64];
    int len;
    int fd = open(path, O_WRONLY);

    if (fd < 0) {
        strerror_r(errno, buf, sizeof(buf));
        ALOGE("Error opening %s: %s\n", path, buf);
        return;
    }

    len = write(fd, s, strlen(s));
    if (len < 0) {
        strerror_r(errno, buf, sizeof(buf));
        ALOGE("Error writing to %s: %s\n", path, buf);
    }

    close(fd);
}

static void power_hint(struct power_module *module, power_hint_t hint,
                       void *data) {
    switch (hint) {
        case POWER_HINT_LOW_POWER:
            if (data) {
                power_fwrite(MT_FPS_UPPER_BOUND_PATH, "30");
                power_fwrite(MT_RUSH_BOOST_PATH, "0");
            } else {
                power_fwrite(MT_FPS_UPPER_BOUND_PATH, "60");
                power_fwrite(MT_RUSH_BOOST_PATH, "1");
            }
            ALOGI("POWER_HINT_LOW_POWER");
            break;
        case POWER_HINT_INTERACTION:
            /*
             * forge p79: measured on device, the interactive governor never
             * ramps under UI animation on its own (bursty render load stays
             * under every reachable target_loads threshold; the multi-token
             * target_loads writes are rejected by this 4.9 parser), while a
             * boostpulse jumps 793 MHz -> hispeed_freq immediately.  Launcher
             * frame time p90 was 36 ms at 793 MHz vs 23 ms pinned high.
             * Pulse on every interaction, like every stock interactive
             * setup does; without this the hint was an empty case and
             * touches never boosted anything.
             */
            {
                static int boostpulse_fd = -2;

                if (boostpulse_fd == -2)
                    boostpulse_fd = open(INTERACTIVE_BOOSTPULSE_PATH, O_WRONLY);
                if (boostpulse_fd >= 0 && write(boostpulse_fd, "1", 1) < 0) {
                    close(boostpulse_fd);
                    boostpulse_fd = -2; /* reopen next time */
                }
            }
            break;
        case POWER_HINT_VSYNC:
        case POWER_HINT_CPU_BOOST:
        case POWER_HINT_LAUNCH:
        case POWER_HINT_SET_PROFILE:
        case POWER_HINT_VIDEO_ENCODE:
        case POWER_HINT_VIDEO_DECODE:
        break;
        case POWER_HINT_SUSTAINED_PERFORMANCE:
            ALOGI("POWER_HINT_SUSTAINED_PERFORMANCE");
            break;
        case POWER_HINT_VR_MODE:
            ALOGI("POWER_HINT_VR_MODE");
            break;
    default:
        break;
    }
}

static struct hw_module_methods_t power_module_methods = {
    .open = NULL,
};

struct power_module HAL_MODULE_INFO_SYM = {
    .common = {
        .tag = HARDWARE_MODULE_TAG,
        .module_api_version = POWER_MODULE_API_VERSION_0_2,
        .hal_api_version = HARDWARE_HAL_API_VERSION,
        .id = POWER_HARDWARE_MODULE_ID,
        .name = "Mediatek Power HAL",
        .author = "The Android Open Source Project",
        .methods = &power_module_methods,
    },

    .init = power_init,
    .setInteractive = power_set_interactive,
    .powerHint = power_hint,
};
