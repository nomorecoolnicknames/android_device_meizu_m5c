/* libbt-vendor.so (64-bit): the Bluetooth vendor interface loaded by the HIDL
 * HAL.
 *
 * Only a 32-bit libbt-vendor.so blob exists, but the 64-bit
 * libbluetooth_mtk.so exports the same symbols, so this is a 64-bit rebuild of
 * the thin stock forwarding shim. Its behaviour matches the stock 32-bit
 * library:
 *
 *   BLUETOOTH_VENDOR_LIB_INTERFACE = {size, init, op, cleanup}
 *   init(p_cb, bdaddr):  set_callbacks(p_cb), return 0; bdaddr is ignored.
 *   cleanup():           clean_resource(), clean_callbacks().
 *   op():
 *      0  POWER_CTRL            return 0 (no chip call)
 *      1  FW_CFG                return mtk_fw_cfg()
 *      2  SCO_CFG               return mtk_sco_cfg()
 *      3  USERIAL_OPEN          *(int*)param = init_uart(); return 1
 *      4  USERIAL_CLOSE         close_uart(); return 0
 *      5  GET_LPM_IDLE_TIMEOUT  *(uint32_t*)param = 5000; return 0
 *      6  LPM_SET_MODE          return 0
 *      7  LPM_WAKE_SET_STATE    return 0
 *      8  SET_AUDIO_STATE       return -1
 *      9  EPILOG                return mtk_prepare_off()
 *      10 A2DP_OFFLOAD_START    return -1
 *      11 A2DP_OFFLOAD_STOP     return -1
 *      12 (MTK) SET_FW_ASSERT   return mtk_set_fw_assert(*(uint32_t*)param)
 *      13 (MTK) SET_PSM_CONTRL  return mtk_set_psm_control(*(uint8_t*)param)
 *      default                  return -1
 *
 * The callback struct is passed through unchanged; the Pie layout only appends
 * a2dp_offload_cb after epilog_cb and is size-prefixed, so the blob reads it
 * safely.
 *
 * libbluetooth_mtk.so is installed with PRODUCT_COPY_FILES rather than as a
 * module, so it is opened with dlopen() instead of being linked.
 */
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>

#include <android/log.h>

#define LOG_TAG "bt-vendor-m95"
#define ALOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define ALOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define ALOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* bt_vendor_lib.h subset. Only the interface struct matters here: the callback
 * struct is forwarded as an opaque pointer, exactly as the stock shim does. */
typedef struct {
    size_t size;
    int (*init)(const void *p_cb, unsigned char *local_bdaddr);
    int (*op)(int opcode, void *param);
    void (*cleanup)(void);
} bt_vendor_interface_t;

/* bt_vendor_opcode_t, hardware/interfaces/bluetooth/1.0/default/bt_vendor_lib.h.
 * 12/13 are MTK-private and are not in that header. */
enum {
    BT_VND_OP_POWER_CTRL = 0,
    BT_VND_OP_FW_CFG = 1,
    BT_VND_OP_SCO_CFG = 2,
    BT_VND_OP_USERIAL_OPEN = 3,
    BT_VND_OP_USERIAL_CLOSE = 4,
    BT_VND_OP_GET_LPM_IDLE_TIMEOUT = 5,
    BT_VND_OP_LPM_SET_MODE = 6,
    BT_VND_OP_LPM_WAKE_SET_STATE = 7,
    BT_VND_OP_SET_AUDIO_STATE = 8,
    BT_VND_OP_EPILOG = 9,
    BT_VND_OP_A2DP_OFFLOAD_START = 10,
    BT_VND_OP_A2DP_OFFLOAD_STOP = 11,
    BT_VND_OP_MTK_SET_FW_ASSERT = 12,
    BT_VND_OP_MTK_SET_PSM_CONTRL = 13,
};

/* Idle timeout the stock shim hands back for BT_VND_OP_GET_LPM_IDLE_TIMEOUT
 * (movw r0,#0x1388 at 0xb36). */
#define MTK_LPM_IDLE_TIMEOUT_MS 5000

#define MTK_BT_LIBRARY "libbluetooth_mtk.so"

/* Signatures recovered from the 64-bit libbluetooth_mtk.so with
 * aarch64-linux-gnu-objdump; argument widths match how the stock 32-bit shim
 * loads them out of `param` (ldr vs ldrb). */
static void *g_mtk_handle;
static void (*p_set_callbacks)(const void *p_cb);   /* 0x1860 str x0,[x8]; ret */
static void (*p_clean_callbacks)(void);             /* 0x1870 str xzr,[x8]     */
static int (*p_init_uart)(void);                    /* 0x1880 open("/dev/stpbt")*/
static void (*p_close_uart)(void);                  /* 0x191c close(fd)        */
static int (*p_mtk_fw_cfg)(void);                   /* 0x194c                  */
static int (*p_mtk_sco_cfg)(void);                  /* 0x2ba0 BT_InitSCO       */
static int (*p_mtk_prepare_off)(void);              /* 0x2bbc epilog_cb        */
static int (*p_mtk_set_fw_assert)(uint32_t reason); /* 0x2bec                  */
static int (*p_mtk_set_psm_control)(int on);        /* 0x2c94 w0 & 1 -> ioctl  */
static void (*p_clean_resource)(void);              /* 0x2d44 b BT_Cleanup     */

struct mtk_sym {
    const char *name;
    void **slot;
};

static const struct mtk_sym kMtkSyms[] = {
    {"set_callbacks", (void **)&p_set_callbacks},
    {"clean_callbacks", (void **)&p_clean_callbacks},
    {"init_uart", (void **)&p_init_uart},
    {"close_uart", (void **)&p_close_uart},
    {"mtk_fw_cfg", (void **)&p_mtk_fw_cfg},
    {"mtk_sco_cfg", (void **)&p_mtk_sco_cfg},
    {"mtk_prepare_off", (void **)&p_mtk_prepare_off},
    {"mtk_set_fw_assert", (void **)&p_mtk_set_fw_assert},
    {"mtk_set_psm_control", (void **)&p_mtk_set_psm_control},
    {"clean_resource", (void **)&p_clean_resource},
};

/* Resolve every symbol or none. A partially-bound shim would fail later, deep
 * inside an op(), where the log says nothing useful. */
static int mtk_bind(void) {
    size_t i;

    if (g_mtk_handle != NULL)
        return 0;

    g_mtk_handle = dlopen(MTK_BT_LIBRARY, RTLD_NOW);
    if (g_mtk_handle == NULL) {
        ALOGE("dlopen %s failed: %s", MTK_BT_LIBRARY, dlerror());
        return -1;
    }

    for (i = 0; i < sizeof(kMtkSyms) / sizeof(kMtkSyms[0]); i++) {
        void *sym = dlsym(g_mtk_handle, kMtkSyms[i].name);
        if (sym == NULL) {
            ALOGE("%s has no symbol %s: %s", MTK_BT_LIBRARY, kMtkSyms[i].name,
                  dlerror());
            dlclose(g_mtk_handle);
            g_mtk_handle = NULL;
            return -1;
        }
        *kMtkSyms[i].slot = sym;
    }
    return 0;
}

static int mtk_bt_init(const void *p_cb, unsigned char *local_bdaddr) {
    (void)local_bdaddr; /* stock ignores it; the BD address comes from NVRAM
                         * inside libbluetooth_mtk (bt_read_nvram /
                         * ap_nvram_btradio_struct, see its .rodata). */
    ALOGI("mtk_bt_init");

    if (mtk_bind() != 0)
        return -1; /* stock cannot fail here; we can, and must say so. */

    p_set_callbacks(p_cb);
    return 0;
}

static int mtk_bt_op(int opcode, void *param) {
    if (mtk_bind() != 0)
        return -1;

    switch (opcode) {
    case BT_VND_OP_POWER_CTRL:
        /* No chip call in stock: the WMT driver powers the combo chip up when
         * /dev/stpbt is opened, so USERIAL_OPEN is the real power-on. */
        ALOGD("BT_VND_OP_POWER_CTRL %d", param ? *(int *)param : -1);
        return 0;

    case BT_VND_OP_FW_CFG:
        ALOGD("BT_VND_OP_FW_CFG");
        return p_mtk_fw_cfg();

    case BT_VND_OP_SCO_CFG:
        ALOGD("BT_VND_OP_SCO_CFG");
        return p_mtk_sco_cfg();

    case BT_VND_OP_USERIAL_OPEN:
        ALOGD("BT_VND_OP_USERIAL_OPEN");
        /* One H4 fd. VendorInterface::Open() reads fd_list[0] and takes the
         * fd_count == 1 branch (H4Protocol). */
        *(int *)param = p_init_uart();
        return 1;

    case BT_VND_OP_USERIAL_CLOSE:
        ALOGD("BT_VND_OP_USERIAL_CLOSE");
        p_close_uart();
        return 0;

    case BT_VND_OP_GET_LPM_IDLE_TIMEOUT:
        ALOGD("BT_VND_OP_GET_LPM_IDLE_TIMEOUT");
        *(uint32_t *)param = MTK_LPM_IDLE_TIMEOUT_MS;
        return 0;

    case BT_VND_OP_LPM_SET_MODE:
        ALOGD("BT_VND_OP_LPM_SET_MODE %d", *(uint8_t *)param);
        return 0;

    case BT_VND_OP_LPM_WAKE_SET_STATE:
        ALOGD("BT_VND_OP_LPM_WAKE_SET_STATE");
        return 0;

    case BT_VND_OP_EPILOG:
        ALOGD("BT_VND_OP_EPILOG");
        return p_mtk_prepare_off();

    case BT_VND_OP_MTK_SET_FW_ASSERT:
        ALOGD("BT_VND_OP_SET_FW_ASSERT 0x%08x", *(uint32_t *)param);
        return p_mtk_set_fw_assert(*(uint32_t *)param);

    case BT_VND_OP_MTK_SET_PSM_CONTRL:
        ALOGD("BT_VND_OP_SET_PSM_CONTRL, setting: %d", *(uint8_t *)param);
        return p_mtk_set_psm_control(*(uint8_t *)param);

    default:
        /* BT_VND_OP_SET_AUDIO_STATE and both A2DP_OFFLOAD opcodes land here in
         * stock too — MTK offloads neither on this chip. */
        ALOGD("Unknown operation %d", opcode);
        return -1;
    }
}

static void mtk_bt_cleanup(void) {
    ALOGI("mtk_bt_cleanup");
    if (g_mtk_handle == NULL)
        return;
    p_clean_resource();
    p_clean_callbacks();
}

__attribute__((visibility("default")))
const bt_vendor_interface_t BLUETOOTH_VENDOR_LIB_INTERFACE = {
    sizeof(bt_vendor_interface_t),
    mtk_bt_init,
    mtk_bt_op,
    mtk_bt_cleanup,
};
