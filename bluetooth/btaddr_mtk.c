/*
 * btaddr_mtk - export the factory Bluetooth address from MTK NVRAM
 *
 * The MTK vendor library (libbluetooth_mtk) programs the controller from
 * the NVRAM calibration record (AP_CFG_RDEB_FILE_BT_ADDR_LID ->
 * /data/nvram/APCFG/APRDEB/BT_Addr, first 6 bytes of
 * ap_nvram_btradio_struct), but the Bluetooth stack itself never sees
 * that address and falls back to a random 22:22:xx:xx:xx:xx one.
 *
 * This helper runs once NVRAM is ready, reads the factory address and
 * writes it in ASCII form to /data/misc/bluetooth/bdaddr, where the
 * stack picks it up via ro.bt.bdaddr_path.
 *
 * If NVRAM holds no per-unit address (all zero / all 0xFF / MTK default
 * from CFG_BT_Default.h), a stable locally-administered address is
 * derived from ro.serialno and, when possible, written back to NVRAM so
 * the controller ends up with the same address.
 */

#define LOG_TAG "btaddr_mtk"

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <cutils/log.h>
#include <cutils/properties.h>
#include <private/android_filesystem_config.h>

#define NVRAM_BT_ADDR       "/nvdata/APCFG/APRDEB/BT_Addr"
#define NVRAM_BT_ADDR_ALT   "/data/nvram/APCFG/APRDEB/BT_Addr"
#define OUT_PATH            "/data/misc/bluetooth/bdaddr"
#define NVRAM_READY_RETRY   20 /* x 500 ms */

static const uint8_t addr_zero[6] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
static const uint8_t addr_ff[6]   = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
/* CFG_BT_Default.h: stBtDefault_6735 / stBtDefault_6735m */
static const uint8_t addr_def_6735[6]  = {0x00, 0x00, 0x46, 0x03, 0x21, 0x01};
static const uint8_t addr_def_6735m[6] = {0x00, 0x00, 0x46, 0x03, 0x35, 0x01};

static int addr_is_valid(const uint8_t *a)
{
    return memcmp(a, addr_zero, 6) && memcmp(a, addr_ff, 6) &&
           memcmp(a, addr_def_6735, 6) && memcmp(a, addr_def_6735m, 6);
}

/* FNV-1a 64-bit over the serial number, locally-administered unicast */
static void derive_addr(uint8_t *a)
{
    char serial[PROPERTY_VALUE_MAX] = {0};
    uint64_t h = 0xcbf29ce484222325ULL;
    int i;

    if (property_get("ro.serialno", serial, NULL) <= 0)
        property_get("ro.boot.serialno", serial, NULL);

    for (i = 0; serial[i]; i++) {
        h ^= (uint8_t)serial[i];
        h *= 0x100000001b3ULL;
    }

    a[0] = 0x02; /* unicast, locally administered */
    a[1] = (uint8_t)(h >> 32);
    a[2] = (uint8_t)(h >> 24);
    a[3] = (uint8_t)(h >> 16);
    a[4] = (uint8_t)(h >> 8);
    a[5] = (uint8_t)h;
}

int main(void)
{
    const char *nvram_path = NVRAM_BT_ADDR;
    uint8_t addr[6];
    char val[PROPERTY_VALUE_MAX];
    char buf[18];
    int fd, i, have_nvram = 0;

    /* Wait for nvram_daemon to finish restoring files */
    for (i = 0; i < NVRAM_READY_RETRY; i++) {
        if (property_get("service.nvram_init", val, NULL) > 0 &&
            strcmp(val, "Ready") == 0)
            break;
        usleep(500000);
    }

    fd = open(nvram_path, O_RDONLY);
    if (fd < 0) {
        nvram_path = NVRAM_BT_ADDR_ALT;
        fd = open(nvram_path, O_RDONLY);
    }
    if (fd >= 0) {
        if (read(fd, addr, 6) == 6)
            have_nvram = 1;
        close(fd);
    }

    if (!have_nvram || !addr_is_valid(addr)) {
        ALOGW("no factory BD address in %s (%s), deriving from serial",
              nvram_path, have_nvram ? "default/empty" : "unreadable");
        derive_addr(addr);
        /* Push the derived address back so the controller matches */
        if (have_nvram) {
            fd = open(nvram_path, O_WRONLY);
            if (fd >= 0) {
                if (write(fd, addr, 6) != 6)
                    ALOGW("NVRAM write-back failed: %s", strerror(errno));
                close(fd);
            }
        }
    }

    snprintf(buf, sizeof(buf), "%02X:%02X:%02X:%02X:%02X:%02X",
             addr[0], addr[1], addr[2], addr[3], addr[4], addr[5]);

    fd = open(OUT_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0640);
    if (fd < 0) {
        ALOGE("cannot write %s: %s", OUT_PATH, strerror(errno));
        return 1;
    }
    if (write(fd, buf, 17) != 17) {
        ALOGE("short write to %s", OUT_PATH);
        close(fd);
        return 1;
    }
    fchown(fd, AID_BLUETOOTH, AID_NET_BT_STACK);
    close(fd);

    ALOGI("BD address %s exported to %s", buf, OUT_PATH);
    return 0;
}
