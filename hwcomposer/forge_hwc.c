/*
 * forge_hwc — hwcomposer.mt6737m for the Meizu m5c on the forge 4.9 kernel.
 *
 * HWC1 (HWC_DEVICE_API_VERSION_1_1) facade over the NATIVE 4.9 mtk_disp_mgr
 * session ABI.  The vendor 3.18-built blob is broken against this kernel
 * (frames stall inside its internal queues, root cause never established);
 * this module replaces it with the minimal correct pipeline:
 *
 *   prepare(): every layer -> HWC_FRAMEBUFFER (SurfaceFlinger composes
 *              everything with GLES into the framebuffer target).
 *   set():     wait FBT acquire fence (the kernel does not consume
 *              src_fence_fd, verified: no reader outside compat conversion)
 *              -> PREPARE_INPUT_BUFFER(204)  ion_fd -> buff idx + release fence
 *              -> GET_PRESENT_FENCE(217)     -> retire fence + idx
 *              -> SET_INPUT_BUFFER(206)      native 12-layer struct, L0 only
 *              -> TRIGGER_SESSION(203)       with present_fence_idx
 *   vsync:     dedicated thread blocking in WAIT_FOR_VSYNC(213).
 *   blank():   FBIOBLANK on fb0 (mtkfb_blank -> primary_display_suspend/resume).
 *
 * Design note: everything version-specific to Android N lives in the thin
 * HWC1 facade at the bottom of this file; the engine (open/session/frame/
 * vsync/power) talks only to the kernel UAPI in disp_session_uapi.h and is
 * meant to be reused behind an HWC2 facade (or hwc2on1adapter) on the
 * LOS 15.1 -> 16 -> 18.1 ladder with this same 4.9 kernel.
 *
 * Buffer handles: ion fd and stride are queried through the vendor
 * libgralloc_extra.so (dlopen, plain C symbol, present in /system/lib{,64}).
 * Fallback when unavailable: fd = handle->data[0], stride = display width
 * (FACT p61: gralloc buffers for the 720-wide panel have pitch 2880 = 720*4).
 */

#define LOG_TAG "forge-hwc"

#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>	/* disp_session_uapi.h (kernel copy) uses bool */
#include <malloc.h>
#include <poll.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <dlfcn.h>
#include <sys/ioctl.h>
#include <sys/system_properties.h>
#include <linux/fb.h>

#include <hardware/hardware.h>
#include <hardware/hwcomposer.h>

#include "disp_session_uapi.h"

/* liblog, declared by hand so the module links against libc+liblog+libdl only */
int __android_log_print(int prio, const char *tag, const char *fmt, ...);
#define FLOGI(...) __android_log_print(4 /* INFO */, LOG_TAG, __VA_ARGS__)
#define FLOGW(...) __android_log_print(5 /* WARN */, LOG_TAG, __VA_ARGS__)
#define FLOGE(...) __android_log_print(6 /* ERROR */, LOG_TAG, __VA_ARGS__)

#define DISP_DEV_PATH "/dev/mtk_disp_mgr"
#define FB_DEV_PATH "/dev/graphics/fb0"

/* gralloc_extra_query attribute ids (device/meizu/m5c/libgem/inc/gralloc_extra.h) */
#define GE_GET_ION_FD 1
#define GE_GET_WIDTH 10
#define GE_GET_HEIGHT 11
#define GE_GET_STRIDE 12
#define GE_GET_FORMAT 15

struct forge_hwc {
	hwc_composer_device_1_t base;	/* must stay first */
	const hwc_procs_t *procs;

	int disp_fd;
	int fb_fd;
	unsigned int session;
	int session_ok;

	unsigned int width, height;
	unsigned int vsync_period_ns;
	unsigned int xdpi_1000, ydpi_1000;	/* dpi * 1000, HWC1 convention */

	int (*ge_query)(buffer_handle_t handle, int attribute, void *out);
	void *ge_lib;

	pthread_t vsync_thread;
	pthread_mutex_t lock;
	pthread_cond_t cond;
	volatile int vsync_on;
	volatile int stop;

	/* stats for dump() */
	unsigned int frames;
	unsigned int prepare_fail;
	unsigned int trigger_fail;
	unsigned int acquire_timeouts;
	unsigned int last_buff_idx;
	unsigned int last_pf_idx;
	int fmt_override;	/* debug.forgehwc.fmt, 0 = RGBA8888 */

	/* overlay stats */
	unsigned int ovl_frames;	/* frames with >=1 promoted layer */
	unsigned int gles_frames;	/* frames composed via FBT only */
	unsigned int promoted_total;	/* cumulative promoted layers */
	unsigned int last_novl;		/* planes in last frame */
	int last_fbt_used;
};

/* one plane handed to the kernel OVL */
struct fhwc_plane {
	buffer_handle_t handle;
	int acquire;		/* fence fd, consumed by submit */
	int fmt;		/* DISP_FORMAT_* */
	int32_t blending;	/* HWC_BLENDING_*, 0 for the FBT */
	uint16_t sx, sy, sw, sh;	/* source crop, pixels */
	uint16_t tx, ty;	/* dest offset */
	int release_fd;		/* out: per-plane release fence */
};

static int prop_int(const char *name, int def)
{
	char v[PROP_VALUE_MAX];

	if (__system_property_get(name, v) > 0)
		return atoi(v);
	return def;
}

/*
 * Duplicate the load-bearing markers into dmesg: logcat gets rotated and
 * restarted with the framework, dmesg is what every capture script here
 * already collects.
 */
static void kmsg_log(const char *fmt, ...)
{
	char line[256];
	va_list ap;
	int fd, n;

	fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
	if (fd < 0)
		return;
	va_start(ap, fmt);
	n = vsnprintf(line, sizeof(line), fmt, ap);
	va_end(ap);
	if (n > 0)
		write(fd, line, (size_t)(n < (int)sizeof(line) ? n : (int)sizeof(line)));
	close(fd);
}

/* ============================ engine ============================ */

static int engine_wait_fence(struct forge_hwc *hwc, int fd, int timeout_ms)
{
	struct pollfd p;
	int ret;

	if (fd < 0)
		return 0;
	p.fd = fd;
	p.events = POLLIN | POLLERR;
	do {
		ret = poll(&p, 1, timeout_ms);
	} while (ret == -1 && (errno == EINTR || errno == EAGAIN));
	if (ret == 0) {
		hwc->acquire_timeouts++;
		FLOGW("acquire fence %d timed out after %d ms", fd, timeout_ms);
	}
	return ret;
}

static int engine_open_session(struct forge_hwc *hwc)
{
	struct disp_session_config cfg;
	struct disp_session_info info;

	memset(&cfg, 0, sizeof(cfg));
	cfg.type = DISP_SESSION_PRIMARY;
	cfg.device_id = 0;
	cfg.mode = DISP_SESSION_DIRECT_LINK_MODE;
	cfg.user = SESSION_USER_HWC;

	if (ioctl(hwc->disp_fd, DISP_IOCTL_CREATE_SESSION, &cfg) < 0) {
		FLOGE("CREATE_SESSION failed: %s", strerror(errno));
		return -errno;
	}
	hwc->session = cfg.session_id;

	memset(&info, 0, sizeof(info));
	info.session_id = hwc->session;
	if (ioctl(hwc->disp_fd, DISP_IOCTL_GET_SESSION_INFO, &info) < 0) {
		FLOGE("GET_SESSION_INFO failed: %s", strerror(errno));
		return -errno;
	}

	hwc->width = info.displayWidth;
	hwc->height = info.displayHeight;
	/*
	 * MTK convention (measured on device, not guessed): vsyncFPS comes
	 * back as fps*100 — 5850 here, i.e. 58.50 Hz.  Values <= 1000 are
	 * treated as plain Hz just in case another kernel returns those.
	 */
	if (info.vsyncFPS > 1000)
		hwc->vsync_period_ns =
		    (unsigned int)(100000000000ULL / info.vsyncFPS);
	else if (info.vsyncFPS)
		hwc->vsync_period_ns = 1000000000u / info.vsyncFPS;
	else
		hwc->vsync_period_ns = 16666666u;
	if (info.physicalWidthUm && info.physicalHeightUm) {
		hwc->xdpi_1000 = (unsigned int)
		    ((uint64_t)info.displayWidth * 25400000ULL / info.physicalWidthUm);
		hwc->ydpi_1000 = (unsigned int)
		    ((uint64_t)info.displayHeight * 25400000ULL / info.physicalHeightUm);
	}
	if (!hwc->xdpi_1000)
		hwc->xdpi_1000 = hwc->ydpi_1000 =
		    (unsigned int)prop_int("ro.sf.lcd_density", 320) * 1000u;

	/* be explicit about the mode; the vendor HAL did the same (12x mode=1) */
	memset(&cfg, 0, sizeof(cfg));
	cfg.type = DISP_SESSION_PRIMARY;
	cfg.mode = DISP_SESSION_DIRECT_LINK_MODE;
	cfg.session_id = hwc->session;
	cfg.user = SESSION_USER_HWC;
	cfg.present_fence_idx = (unsigned int)-1;
	if (ioctl(hwc->disp_fd, DISP_IOCTL_SET_SESSION_MODE, &cfg) < 0)
		FLOGW("SET_SESSION_MODE failed: %s (continuing)", strerror(errno));

	hwc->session_ok = 1;
	FLOGI("session 0x%x: %ux%u vsyncFPS=%u period=%uns maxLayer=%u vsync=%u dpi=%u.%03u",
	      hwc->session, hwc->width, hwc->height, info.vsyncFPS,
	      hwc->vsync_period_ns, info.maxLayerNum,
	      info.isHwVsyncAvailable, hwc->xdpi_1000 / 1000, hwc->xdpi_1000 % 1000);
	kmsg_log("forge-hwc: session 0x%x %ux%u vsyncFPS=%u period=%uns maxLayer=%u",
		 hwc->session, hwc->width, hwc->height, info.vsyncFPS,
		 hwc->vsync_period_ns, info.maxLayerNum);
	return 0;
}

/* HAL pixel format -> DISP_FORMAT for the overlay path; 0 = not supported */
static int map_hal_format(int hal_fmt)
{
	switch (hal_fmt) {
	case 1:		/* HAL_PIXEL_FORMAT_RGBA_8888 */
		return DISP_FORMAT_RGBA8888;
	case 2:		/* HAL_PIXEL_FORMAT_RGBX_8888 */
		return DISP_FORMAT_RGBX8888;
	case 4:		/* HAL_PIXEL_FORMAT_RGB_565 */
		return DISP_FORMAT_RGB565;
	case 5:		/* HAL_PIXEL_FORMAT_BGRA_8888 */
		return DISP_FORMAT_BGRA8888;
	default:
		return 0;
	}
}

/*
 * Blending -> OVL alpha controls.  Verified against the kernel encoding
 * (mt6735m/ddp_ovl.c: sur_aen -> SURFL_EN bit 15, src/dst_alpha -> the
 * 2-bit blend factor selectors).  PREMULT: out = src + (1-a_s)*dst ->
 * factors ONE / SRC_INVERT; COVERAGE: SRC / SRC_INVERT.
 */
static void fill_blending(struct disp_input_config *c, int32_t blending)
{
	if (blending == 0x0105 /* HWC_BLENDING_PREMULT */) {
		c->alpha_enable = 1;
		c->sur_aen = 1;
		c->src_alpha = DISP_ALPHA_ONE;
		c->dst_alpha = DISP_ALPHA_SRC_INVERT;
	} else if (blending == 0x0405 /* HWC_BLENDING_COVERAGE */) {
		c->alpha_enable = 1;
		c->sur_aen = 1;
		c->src_alpha = DISP_ALPHA_SRC;
		c->dst_alpha = DISP_ALPHA_SRC_INVERT;
	} else {	/* HWC_BLENDING_NONE / FBT: opaque */
		c->alpha_enable = 0;
		c->sur_aen = 0;
		c->src_alpha = DISP_ALPHA_ONE;
		c->dst_alpha = DISP_ALPHA_ONE;
	}
	c->alpha = 0xff;
}

/*
 * Hand n planes (bottom -> top == OVL layer 0 -> n-1) to the kernel in one
 * SET_INPUT + TRIGGER.  Consumes every plane's acquire fence; fills each
 * plane's release_fd and *retire_fence (all owned by the caller).
 */
static int engine_submit(struct forge_hwc *hwc, struct fhwc_plane *planes,
			 int n, int *retire_fence)
{
	struct disp_buffer_info buf;
	struct disp_present_fence pf;
	struct disp_session_input_config *in;
	struct disp_session_config trig;
	int i, k, ret;

	*retire_fence = -1;
	if (n > 4)
		return -EINVAL;

	/* the kernel does not wait src_fence_fd: wait here, then submit */
	for (k = 0; k < n; k++) {
		engine_wait_fence(hwc, planes[k].acquire, 1200);
		if (planes[k].acquire >= 0)
			close(planes[k].acquire);
		planes[k].acquire = -1;
		planes[k].release_fd = -1;
	}

	in = calloc(1, sizeof(*in));
	if (!in)
		return -ENOMEM;
	in->session_id = hwc->session;
	in->config_layer_num = 4;
	for (i = 0; i < 4; i++) {
		in->config[i].layer_id = (uint8_t)i;
		in->config[i].layer_enable = 0;
		in->config[i].src_fence_fd = -1;
		in->config[i].ext_sel_layer = -1;
	}

	for (k = 0; k < n; k++) {
		struct disp_input_config *c = &in->config[k];
		struct fhwc_plane *p = &planes[k];
		int ion_fd = -1;
		int stride_px = (int)hwc->width;

		if (hwc->ge_query) {
			if (hwc->ge_query(p->handle, GE_GET_ION_FD, &ion_fd) != 0)
				ion_fd = -1;
			hwc->ge_query(p->handle, GE_GET_STRIDE, &stride_px);
		}
		if (ion_fd < 0 && p->handle->numFds > 0)
			ion_fd = p->handle->data[0];
		if (ion_fd < 0) {
			FLOGE("plane %d: no ion fd (numFds=%d)", k, p->handle->numFds);
			continue;	/* leave the plane disabled */
		}

		memset(&buf, 0, sizeof(buf));
		buf.session_id = hwc->session;
		buf.layer_id = (unsigned int)k;
		buf.layer_en = 1;
		buf.ion_fd = ion_fd;
		buf.cache_sync = 0;
		buf.fence_fd = -1;
		buf.interface_fence_fd = -1;
		if (ioctl(hwc->disp_fd, DISP_IOCTL_PREPARE_INPUT_BUFFER, &buf) < 0) {
			hwc->prepare_fail++;
			FLOGE("PREPARE(l%d) failed: %s (ion=%d)", k,
			      strerror(errno), ion_fd);
			continue;
		}
		hwc->last_buff_idx = buf.index;
		p->release_fd = buf.fence_fd;

		c->layer_enable = 1;
		c->buffer_source = DISP_BUFFER_ION;
		c->security = DISP_NORMAL_BUFFER;
		c->src_fmt = (enum DISP_FORMAT)p->fmt;
		c->next_buff_idx = buf.index;
		c->src_pitch = (uint16_t)stride_px;
		c->src_offset_x = p->sx;
		c->src_offset_y = p->sy;
		c->src_width = p->sw;
		c->src_height = p->sh;
		c->tgt_offset_x = p->tx;
		c->tgt_offset_y = p->ty;
		c->tgt_width = p->sw;
		c->tgt_height = p->sh;
		c->frm_sequence = hwc->frames;
		fill_blending(c, p->blending);
	}

	memset(&pf, 0, sizeof(pf));
	pf.session_id = hwc->session;
	pf.present_fence_fd = -1;
	if (ioctl(hwc->disp_fd, DISP_IOCTL_GET_PRESENT_FENCE, &pf) < 0) {
		FLOGW("GET_PRESENT_FENCE failed: %s", strerror(errno));
		pf.present_fence_fd = -1;
		pf.present_fence_index = (unsigned int)-1;
	}
	hwc->last_pf_idx = pf.present_fence_index;

	ret = ioctl(hwc->disp_fd, DISP_IOCTL_SET_INPUT_BUFFER, in);
	free(in);
	if (ret < 0) {
		FLOGE("SET_INPUT_BUFFER failed: %s", strerror(errno));
		goto fail;
	}

	memset(&trig, 0, sizeof(trig));
	trig.type = DISP_SESSION_PRIMARY;
	trig.mode = DISP_SESSION_DIRECT_LINK_MODE;
	trig.session_id = hwc->session;
	trig.user = SESSION_USER_HWC;
	trig.present_fence_idx = pf.present_fence_index;
	trig.tigger_mode = TRIGGER_NORMAL;
	if (ioctl(hwc->disp_fd, DISP_IOCTL_TRIGGER_SESSION, &trig) < 0) {
		hwc->trigger_fail++;
		FLOGE("TRIGGER_SESSION failed: %s", strerror(errno));
		goto fail;
	}

	hwc->frames++;
	hwc->last_novl = (unsigned int)n;
	if (hwc->frames <= 8 || (hwc->frames % 600) == 0)
		FLOGI("frame #%u: planes=%d pf_idx=%u", hwc->frames, n,
		      pf.present_fence_index);

	*retire_fence = pf.present_fence_fd;
	return 0;

fail:
	if (pf.present_fence_fd >= 0)
		close(pf.present_fence_fd);
	for (k = 0; k < n; k++) {
		if (planes[k].release_fd >= 0) {
			close(planes[k].release_fd);
			planes[k].release_fd = -1;
		}
	}
	return -errno;
}

static void *vsync_thread_fn(void *arg)
{
	struct forge_hwc *hwc = arg;
	struct disp_session_vsync_config vs;
	struct timespec ts_now;
	int64_t ts, last_ts = 0;

	while (1) {
		pthread_mutex_lock(&hwc->lock);
		while (!hwc->vsync_on && !hwc->stop)
			pthread_cond_wait(&hwc->cond, &hwc->lock);
		pthread_mutex_unlock(&hwc->lock);
		if (hwc->stop)
			break;

		memset(&vs, 0, sizeof(vs));
		vs.session_id = hwc->session;
		if (ioctl(hwc->disp_fd, DISP_IOCTL_WAIT_FOR_VSYNC, &vs) < 0) {
			usleep(16666);
			continue;
		}
		ts = (int64_t)vs.vsync_ts;
		if (ts == 0) {
			/* DISP_SLEPT / lcm-disconnected path returns immediately */
			clock_gettime(CLOCK_MONOTONIC, &ts_now);
			ts = (int64_t)ts_now.tv_sec * 1000000000LL + ts_now.tv_nsec;
			usleep(16666);
		}
		if (ts == last_ts) {	/* did not advance: don't spin */
			usleep(16666);
			continue;
		}
		last_ts = ts;
		if (hwc->vsync_on && hwc->procs && hwc->procs->vsync)
			hwc->procs->vsync(hwc->procs, 0, ts);
	}
	return NULL;
}

/* ============================ HWC1 facade ============================ */

static struct forge_hwc *to_hwc(hwc_composer_device_1_t *dev)
{
	return (struct forge_hwc *)dev;
}

/*
 * Can this layer go to a hardware overlay as-is?  Conservative: the OVL has
 * no scaler and no rotator, so any doubt means GLES (always correct).
 * Returns the DISP_FORMAT, or 0 for "compose with GLES".
 */
static int layer_fits_overlay(struct forge_hwc *hwc, hwc_layer_1_t *l)
{
	int hal_fmt = 0, fmt;
	int sw, sh, dw, dh;

	if (l->flags & HWC_SKIP_LAYER)
		return 0;
	if (!l->handle)
		return 0;	/* dim layers / sideband / not yet latched */
	if (l->transform != 0)
		return 0;	/* no rotator */
	if (l->blending != HWC_BLENDING_NONE &&
	    l->blending != HWC_BLENDING_PREMULT &&
	    l->blending != HWC_BLENDING_COVERAGE)
		return 0;

	/* integer, unscaled, fully on-screen */
	sw = l->sourceCropi.right - l->sourceCropi.left;
	sh = l->sourceCropi.bottom - l->sourceCropi.top;
	dw = l->displayFrame.right - l->displayFrame.left;
	dh = l->displayFrame.bottom - l->displayFrame.top;
	if (sw <= 0 || sh <= 0 || sw != dw || sh != dh)
		return 0;	/* scaled (or empty) */
	if (l->sourceCropi.left < 0 || l->sourceCropi.top < 0)
		return 0;
	if (l->displayFrame.left < 0 || l->displayFrame.top < 0 ||
	    l->displayFrame.right > (int)hwc->width ||
	    l->displayFrame.bottom > (int)hwc->height)
		return 0;	/* would need clipping */

	if (!hwc->ge_query)
		return 0;
	if (hwc->ge_query(l->handle, GE_GET_FORMAT, &hal_fmt) != 0)
		return 0;
	fmt = map_hal_format(hal_fmt);
	return fmt;
}

/*
 * Promotion rule: overlays are taken only as a contiguous run from the TOP
 * of the z-ordered list, so the GLES-composed remainder (bottom of the
 * stack) is exactly what the single FBT plane at OVL 0 can represent.
 * If everything fits and there are at most 4 layers, no FBT is used at all.
 */
static int fhwc_prepare(hwc_composer_device_1_t *dev, size_t numDisplays,
			hwc_display_contents_1_t **displays)
{
	struct forge_hwc *hwc = to_hwc(dev);
	hwc_display_contents_1_t *d;
	int i, nlayers, top_run, budget, first_ovl;
	int overlays_on = prop_int("debug.forgehwc.overlays", 1);

	if (!numDisplays || !displays || !displays[0])
		return 0;
	d = displays[0];

	/* indexes of real layers (the FBT is not a candidate) */
	nlayers = 0;
	for (i = 0; i < (int)d->numHwLayers; i++)
		if (d->hwLayers[i].compositionType != HWC_FRAMEBUFFER_TARGET)
			nlayers++;

	/* how many contiguous layers from the top fit an overlay */
	top_run = 0;
	if (overlays_on) {
		for (i = (int)d->numHwLayers - 1; i >= 0; i--) {
			hwc_layer_1_t *l = &d->hwLayers[i];

			if (l->compositionType == HWC_FRAMEBUFFER_TARGET)
				continue;
			if (!layer_fits_overlay(hwc, l))
				break;
			top_run++;
		}
	}

	if (top_run == nlayers && nlayers > 0 && nlayers <= 4)
		budget = nlayers;	/* everything on OVL, no FBT */
	else
		budget = top_run < 3 ? top_run : 3;	/* OVL 0 = FBT */

	/*
	 * forge: cap the number of planes fetched concurrently.
	 *
	 * Each overlay plane has its own fetch FIFO, and with three
	 * full-screen planes live all three underflow: OVL0_INTSTA came back
	 * 0xe03 under a fast animation, bits 9/10/11 being the per-layer
	 * RDMA FIFO underflow of layers 0, 1 and 2. On a single plane the
	 * same register reads 0x3. The picture breaks up toward the bottom
	 * of the frame, where the accumulated fetch deficit shows.
	 *
	 * Demoting a layer does not save the bytes it read — the GLES
	 * remainder arrives as a full-screen FBT plane instead — so what is
	 * being bought here is fewer concurrent fetch streams, not less
	 * traffic. debug.forgehwc.maxplanes exists to find the point where
	 * the underflow bits stop appearing without a rebuild.
	 */
	{
		int maxp = prop_int("debug.forgehwc.maxplanes", 4);

		if (maxp < 0)
			maxp = 0;
		if (budget > maxp)
			budget = maxp;
	}

	/* first (lowest-z) real layer that gets an overlay */
	first_ovl = nlayers - budget;

	nlayers = 0;
	for (i = 0; i < (int)d->numHwLayers; i++) {
		hwc_layer_1_t *l = &d->hwLayers[i];

		if (l->compositionType == HWC_FRAMEBUFFER_TARGET)
			continue;
		if (nlayers >= first_ovl && budget > 0)
			l->compositionType = HWC_OVERLAY;
		else
			l->compositionType = HWC_FRAMEBUFFER;
		nlayers++;
	}
	return 0;
}

static int fhwc_set(hwc_composer_device_1_t *dev, size_t numDisplays,
		    hwc_display_contents_1_t **displays)
{
	struct forge_hwc *hwc = to_hwc(dev);
	hwc_display_contents_1_t *d;
	hwc_layer_1_t *fbt = NULL;
	hwc_layer_1_t *src[4];
	struct fhwc_plane planes[4];
	size_t i;
	int n = 0, gles_used = 0, ret_f = -1;

	if (!numDisplays || !displays || !displays[0])
		return 0;
	d = displays[0];
	d->retireFenceFd = -1;

	for (i = 0; i < d->numHwLayers; i++) {
		hwc_layer_1_t *l = &d->hwLayers[i];

		if (l->compositionType == HWC_FRAMEBUFFER_TARGET)
			fbt = l;
		else if (l->compositionType == HWC_FRAMEBUFFER)
			gles_used = 1;
	}

	memset(planes, 0, sizeof(planes));

	/* OVL 0 = the GLES result, when anything was left to GLES */
	if (gles_used) {
		if (!fbt || !fbt->handle) {
			/* nothing usable this frame */
			if (fbt && fbt->acquireFenceFd >= 0) {
				close(fbt->acquireFenceFd);
				fbt->acquireFenceFd = -1;
			}
			return 0;
		}
		src[n] = fbt;
		planes[n].handle = fbt->handle;
		planes[n].acquire = fbt->acquireFenceFd;
		planes[n].fmt = hwc->fmt_override ?
		    hwc->fmt_override : DISP_FORMAT_RGBA8888;
		planes[n].blending = 0;	/* opaque */
		planes[n].sw = (uint16_t)hwc->width;
		planes[n].sh = (uint16_t)hwc->height;
		n++;
	}

	/* promoted layers, in z order (list order is bottom -> top) */
	for (i = 0; i < d->numHwLayers && n < 4; i++) {
		hwc_layer_1_t *l = &d->hwLayers[i];
		int fmt;

		if (l->compositionType != HWC_OVERLAY)
			continue;
		fmt = layer_fits_overlay(hwc, l);
		if (!fmt) {
			/* changed between prepare and set: should not happen */
			FLOGW("overlay layer no longer eligible, dropping frame plane");
			if (l->acquireFenceFd >= 0) {
				close(l->acquireFenceFd);
				l->acquireFenceFd = -1;
			}
			continue;
		}
		src[n] = l;
		planes[n].handle = l->handle;
		planes[n].acquire = l->acquireFenceFd;
		planes[n].fmt = fmt;
		planes[n].blending = l->blending;
		planes[n].sx = (uint16_t)l->sourceCropi.left;
		planes[n].sy = (uint16_t)l->sourceCropi.top;
		planes[n].sw = (uint16_t)(l->sourceCropi.right - l->sourceCropi.left);
		planes[n].sh = (uint16_t)(l->sourceCropi.bottom - l->sourceCropi.top);
		planes[n].tx = (uint16_t)l->displayFrame.left;
		planes[n].ty = (uint16_t)l->displayFrame.top;
		n++;
	}

	/* FBT unused this frame: its acquire fence is still ours to close */
	if (!gles_used && fbt && fbt->acquireFenceFd >= 0) {
		close(fbt->acquireFenceFd);
		fbt->acquireFenceFd = -1;
	}

	if (n == 0)
		return 0;

	engine_submit(hwc, planes, n, &ret_f);

	for (i = 0; i < (size_t)n; i++) {
		src[i]->acquireFenceFd = -1;	/* consumed by engine_submit */
		src[i]->releaseFenceFd = planes[i].release_fd;
	}
	d->retireFenceFd = ret_f;

	hwc->last_fbt_used = gles_used;
	if (n > (gles_used ? 1 : 0)) {
		hwc->ovl_frames++;
		hwc->promoted_total += (unsigned int)(n - (gles_used ? 1 : 0));
	} else {
		hwc->gles_frames++;
	}
	return 0;
}

static int fhwc_event_control(hwc_composer_device_1_t *dev, int disp,
			      int event, int enabled)
{
	struct forge_hwc *hwc = to_hwc(dev);

	if (disp != 0 || event != HWC_EVENT_VSYNC)
		return -EINVAL;
	pthread_mutex_lock(&hwc->lock);
	hwc->vsync_on = !!enabled;
	pthread_cond_signal(&hwc->cond);
	pthread_mutex_unlock(&hwc->lock);
	return 0;
}

static int fhwc_blank(hwc_composer_device_1_t *dev, int disp, int blank)
{
	struct forge_hwc *hwc = to_hwc(dev);
	int arg = blank ? FB_BLANK_POWERDOWN : FB_BLANK_UNBLANK;

	if (disp != 0)
		return -EINVAL;
	if (hwc->fb_fd < 0)
		return -ENODEV;
	FLOGI("blank(%d)", blank);
	if (ioctl(hwc->fb_fd, FBIOBLANK, arg) < 0) {
		FLOGE("FBIOBLANK(%d) failed: %s", arg, strerror(errno));
		return -errno;
	}
	return 0;
}

static int fhwc_query(hwc_composer_device_1_t *dev, int what, int *value)
{
	struct forge_hwc *hwc = to_hwc(dev);

	switch (what) {
	case HWC_BACKGROUND_LAYER_SUPPORTED:
		*value = 0;
		return 0;
	case HWC_DISPLAY_TYPES_SUPPORTED:
		*value = HWC_DISPLAY_PRIMARY_BIT;
		return 0;
	case HWC_VSYNC_PERIOD:
		*value = (int)hwc->vsync_period_ns;
		return 0;
	default:
		return -EINVAL;
	}
}

static void fhwc_register_procs(hwc_composer_device_1_t *dev,
				const hwc_procs_t *procs)
{
	to_hwc(dev)->procs = procs;
}

static void fhwc_dump(hwc_composer_device_1_t *dev, char *buff, int buff_len)
{
	struct forge_hwc *hwc = to_hwc(dev);

	snprintf(buff, buff_len,
		 "forge-hwc: session=0x%x %ux%u period=%uns frames=%u prepare_fail=%u "
		 "trigger_fail=%u acq_timeout=%u last_idx=%u last_pf=%u "
		 "vsync_on=%d ge=%s "
		 "ovl_frames=%u gles_frames=%u promoted=%u last: planes=%u fbt=%d\n",
		 hwc->session, hwc->width, hwc->height, hwc->vsync_period_ns, hwc->frames,
		 hwc->prepare_fail, hwc->trigger_fail, hwc->acquire_timeouts,
		 hwc->last_buff_idx, hwc->last_pf_idx, hwc->vsync_on,
		 hwc->ge_query ? "yes" : "no",
		 hwc->ovl_frames, hwc->gles_frames, hwc->promoted_total,
		 hwc->last_novl, hwc->last_fbt_used);
}

static int fhwc_get_display_configs(hwc_composer_device_1_t *dev, int disp,
				    uint32_t *configs, size_t *numConfigs)
{
	(void)dev;
	if (disp != 0)
		return -EINVAL;
	if (*numConfigs > 0) {
		configs[0] = 0;
		*numConfigs = 1;
	}
	return 0;
}

static int fhwc_get_display_attributes(hwc_composer_device_1_t *dev, int disp,
				       uint32_t config, const uint32_t *attributes,
				       int32_t *values)
{
	struct forge_hwc *hwc = to_hwc(dev);
	int i;

	if (disp != 0 || config != 0)
		return -EINVAL;
	for (i = 0; attributes[i] != HWC_DISPLAY_NO_ATTRIBUTE; i++) {
		switch (attributes[i]) {
		case HWC_DISPLAY_VSYNC_PERIOD:
			values[i] = (int32_t)hwc->vsync_period_ns;
			break;
		case HWC_DISPLAY_WIDTH:
			values[i] = (int32_t)hwc->width;
			break;
		case HWC_DISPLAY_HEIGHT:
			values[i] = (int32_t)hwc->height;
			break;
		case HWC_DISPLAY_DPI_X:
			values[i] = (int32_t)hwc->xdpi_1000;
			break;
		case HWC_DISPLAY_DPI_Y:
			values[i] = (int32_t)hwc->ydpi_1000;
			break;
		default:
			values[i] = 0;
			break;
		}
	}
	return 0;
}

static int fhwc_close(hw_device_t *dev)
{
	struct forge_hwc *hwc = (struct forge_hwc *)dev;
	struct disp_session_config cfg;

	pthread_mutex_lock(&hwc->lock);
	hwc->stop = 1;
	pthread_cond_signal(&hwc->cond);
	pthread_mutex_unlock(&hwc->lock);
	pthread_join(hwc->vsync_thread, NULL);

	if (hwc->session_ok) {
		memset(&cfg, 0, sizeof(cfg));
		cfg.type = DISP_SESSION_PRIMARY;
		cfg.session_id = hwc->session;
		ioctl(hwc->disp_fd, DISP_IOCTL_DESTROY_SESSION, &cfg);
	}
	if (hwc->fb_fd >= 0)
		close(hwc->fb_fd);
	if (hwc->disp_fd >= 0)
		close(hwc->disp_fd);
	if (hwc->ge_lib)
		dlclose(hwc->ge_lib);
	free(hwc);
	return 0;
}

static int fhwc_open(const struct hw_module_t *module, const char *name,
		     struct hw_device_t **device)
{
	struct forge_hwc *hwc;
	int err;

	if (strcmp(name, HWC_HARDWARE_COMPOSER))
		return -EINVAL;

	hwc = calloc(1, sizeof(*hwc));
	if (!hwc)
		return -ENOMEM;

	hwc->disp_fd = open(DISP_DEV_PATH, O_RDWR);
	if (hwc->disp_fd < 0) {
		err = -errno;
		FLOGE("cannot open %s: %s", DISP_DEV_PATH, strerror(errno));
		free(hwc);
		return err;
	}
	hwc->fb_fd = open(FB_DEV_PATH, O_RDWR);
	if (hwc->fb_fd < 0)
		FLOGW("cannot open %s: %s (blank() disabled)", FB_DEV_PATH,
		      strerror(errno));

	err = engine_open_session(hwc);
	if (err) {
		/* leave the system on the fbdev fallback rather than limp */
		if (hwc->fb_fd >= 0)
			close(hwc->fb_fd);
		close(hwc->disp_fd);
		free(hwc);
		return err;
	}

	hwc->ge_lib = dlopen("libgralloc_extra.so", RTLD_LAZY | RTLD_LOCAL);
	if (hwc->ge_lib)
		hwc->ge_query = (int (*)(buffer_handle_t, int, void *))
		    dlsym(hwc->ge_lib, "gralloc_extra_query");
	FLOGI("gralloc_extra: %s", hwc->ge_query ? "loaded" : "unavailable, using fallback");

	hwc->fmt_override = prop_int("debug.forgehwc.fmt", 0);

	pthread_mutex_init(&hwc->lock, NULL);
	pthread_cond_init(&hwc->cond, NULL);
	err = pthread_create(&hwc->vsync_thread, NULL, vsync_thread_fn, hwc);
	if (err) {
		FLOGE("vsync thread: %s", strerror(err));
		close(hwc->disp_fd);
		if (hwc->fb_fd >= 0)
			close(hwc->fb_fd);
		free(hwc);
		return -err;
	}

	hwc->base.common.tag = HARDWARE_DEVICE_TAG;
	hwc->base.common.version = HWC_DEVICE_API_VERSION_1_1;
	hwc->base.common.module = (struct hw_module_t *)module;
	hwc->base.common.close = fhwc_close;
	hwc->base.prepare = fhwc_prepare;
	hwc->base.set = fhwc_set;
	hwc->base.eventControl = fhwc_event_control;
	hwc->base.blank = fhwc_blank;
	hwc->base.query = fhwc_query;
	hwc->base.registerProcs = fhwc_register_procs;
	hwc->base.dump = fhwc_dump;
	hwc->base.getDisplayConfigs = fhwc_get_display_configs;
	hwc->base.getDisplayAttributes = fhwc_get_display_attributes;

	*device = &hwc->base.common;
	FLOGI("forge-hwc up (HWC1.1, native 4.9 disp ABI)");
	return 0;
}

static struct hw_module_methods_t fhwc_module_methods = {
	.open = fhwc_open,
};

hwc_module_t HAL_MODULE_INFO_SYM = {
	.common = {
		.tag = HARDWARE_MODULE_TAG,
		.module_api_version = HWC_MODULE_API_VERSION_0_1,
		.hal_api_version = HARDWARE_HAL_API_VERSION,
		.id = HWC_HARDWARE_MODULE_ID,
		.name = "forge hwcomposer for m5c (mt6737m, 4.9 kernel)",
		.author = "forge",
		.methods = &fhwc_module_methods,
	},
};
