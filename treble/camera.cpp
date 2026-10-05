// libm5cshim_camera — what the N-era MediaTek camera closure of m5c imports
// from platform libraries and Android 13 no longer exports.
//

// sonames in place the camera provider still could not load camera.mt6737m.so
// because of these imports (both ABIs):
//   libcam_utils             PropertyMap (9), GraphicBuffer(w,h,f,usage),
//                            GraphicBuffer(w,h,f,usage,stride,handle,own),
//                            GraphicBuffer::lock(usage, void**)
//   libmtk_mmutils           GraphicBuffer(w,h,f,usage)
//   libmmsdkservice.feature  GraphicBuffer(ANativeWindowBuffer*, bool), lock,
//                            BufferQueue::createBufferQueue(N), N
//                            BufferItemConsumer ctor + setName, Surface(N)
//   libcam.utils.sensorlistener
//                            SensorManager(String16 const&),
//                            SensorEventQueue::getFd(),
//                            IPermissionController::asInterface()
// The rest of the N sensor API comes from LineageOS libsensor_vendor
// (hardware/lineage/compat), wired to the same consumers.  Wiring: DT_NEEDED
// edits in vendor/meizu/m5c treble-elf-wiring.txt (blob-elf-wire.py).
//
// Most bodies are m95's (device/meizu/m95/shims/gui.cpp, ui.cpp,
// propertymap.cpp, sensor.cpp), proven there on the same mtkcam code base.
// Only manual declarations of the Android 13 entry points are used (as on
// m95); the targets live in libui / libgui_vendor / libsensor_vendor, which
// this library NEEDs.
//
// Object sizes (FACT, 32-bit): the blobs allocate the N sizes themselves —
// GraphicBuffer 136 B (A13: 160), BufferItemConsumer 1064 B (A13: 1080),
// Surface 1776 B (A13: several KiB).  The first two are covered by
// libm5cshim_newpad (newpad.cpp), the camera HAL's operator new with slack;
// Surface is refused below, as on m95.
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>

#include <string>

#include <log/log.h>
#include <utils/KeyedVector.h>
#include <utils/String8.h>

// ---- PropertyMap (m95 propertymap.cpp; N system/core/libutils) ------------
// Android 13 moved the class to libinput, which a vendor process cannot load.
// The blob allocates the object; its only member stays N's KeyedVector.
namespace android {

class PropertyMap {
  public:
    PropertyMap();
    ~PropertyMap();
    void clear();
    void addProperty(const String8& key, const String8& value);
    bool hasProperty(const String8& key) const;
    bool tryGetProperty(const String8& key, String8& outValue) const;
    bool tryGetProperty(const String8& key, bool& outValue) const;
    bool tryGetProperty(const String8& key, int32_t& outValue) const;
    bool tryGetProperty(const String8& key, float& outValue) const;

  private:
    KeyedVector<String8, String8> mProperties;
};

PropertyMap::PropertyMap() {}

PropertyMap::~PropertyMap() {}

void PropertyMap::clear() {
    mProperties.clear();
}

void PropertyMap::addProperty(const String8& key, const String8& value) {
    mProperties.add(key, value);
}

bool PropertyMap::hasProperty(const String8& key) const {
    return mProperties.indexOfKey(key) >= 0;
}

bool PropertyMap::tryGetProperty(const String8& key, String8& outValue) const {
    ssize_t index = mProperties.indexOfKey(key);
    if (index < 0) {
        return false;
    }
    outValue = mProperties.valueAt(index);
    return true;
}

bool PropertyMap::tryGetProperty(const String8& key, bool& outValue) const {
    int32_t intValue;
    if (!tryGetProperty(key, intValue)) {
        return false;
    }
    outValue = intValue;
    return true;
}

bool PropertyMap::tryGetProperty(const String8& key, int32_t& outValue) const {
    String8 stringValue;
    if (!tryGetProperty(key, stringValue) || stringValue.length() == 0) {
        return false;
    }
    char* end;
    int value = strtol(stringValue.c_str(), &end, 10);
    if (*end != '\0') {
        return false;
    }
    outValue = value;
    return true;
}

bool PropertyMap::tryGetProperty(const String8& key, float& outValue) const {
    String8 stringValue;
    if (!tryGetProperty(key, stringValue) || stringValue.length() == 0) {
        return false;
    }
    char* end;
    float value = strtof(stringValue.c_str(), &end);
    if (*end != '\0') {
        return false;
    }
    outValue = value;
    return true;
}

}  // namespace android

// ---- GraphicBuffer ---------------------------------------------------------
namespace android {
class GraphicBuffer;
class BufferItemConsumer;
class ConsumerBase;
struct native_handle;
template <typename T>
class sp;
class IGraphicBufferProducer;
class IGraphicBufferConsumer;
}  // namespace android

// system/window.h ANativeWindowBuffer, A13 layout (handle offset identical
// to N; N's reserved[2] became layerCount + reserved[1]) — m95 gui.cpp.
struct m5c_native_base {
    int magic;
    int version;
    void* reserved[4];
    void (*incRef)(struct m5c_native_base*);
    void (*decRef)(struct m5c_native_base*);
};
struct m5c_anwb {
    struct m5c_native_base common;
    int width;
    int height;
    int stride;
    int format;
    int usage_deprecated;
    uintptr_t layerCount;
    void* reserved[1];
    const android::native_handle* handle;
    uint64_t usage;
    void* reserved_proc[8 - (sizeof(uint64_t) / sizeof(void*))];
};

#ifdef __LP64__
#define M5C_U64 "m"
#else
#define M5C_U64 "y"
#endif

// A13 entry points (libui, libgui_vendor).
extern "C" {
// GraphicBuffer(w, h, format, layerCount, uint64_t usage, std::string requestorName)
void m5c_gb_ctor_alloc(android::GraphicBuffer*, uint32_t, uint32_t, int, uint32_t, uint64_t,
                       std::string) __asm__("_ZN7android13GraphicBufferC1Ejjij" M5C_U64
                                            "NSt3__112basic_stringIcNS1_11char_traitsIcEENS1_"
                                            "9allocatorIcEEEE");
// GraphicBuffer(const native_handle_t*, HandleWrapMethod, w, h, format,
//               layerCount, uint64_t usage, stride)
void m5c_gb_ctor_wrap(android::GraphicBuffer*, const android::native_handle*, uint8_t, uint32_t,
                      uint32_t, int, uint32_t, uint64_t, uint32_t)
        __asm__("_ZN7android13GraphicBufferC1EPK13native_handleNS0_16HandleWrapMethodEjjij" M5C_U64
                "j");
// GraphicBuffer::lock(uint32_t usage, void** vaddr, int32_t* bpp, int32_t* bps)
int m5c_gb_lock(android::GraphicBuffer*, uint32_t, void**, int32_t*, int32_t*)
        __asm__("_ZN7android13GraphicBuffer4lockEjPPvPiS3_");
// BufferQueue::createBufferQueue(sp<IGBP>*, sp<IGBC>*, bool consumerIsSurfaceFlinger)
void m5c_bq_create(android::sp<android::IGraphicBufferProducer>*,
                   android::sp<android::IGraphicBufferConsumer>*, bool)
        __asm__("_ZN7android11BufferQueue17createBufferQueueEPNS_2spINS_"
                "22IGraphicBufferProducerEEEPNS1_INS_22IGraphicBufferConsumerEEEb");
// BufferItemConsumer(const sp<IGBC>&, uint64_t usage, int bufferCount, bool controlledByApp)
void m5c_bic_ctor(android::BufferItemConsumer*, const void*, uint64_t, int, bool)
        __asm__("_ZN7android18BufferItemConsumerC1ERKNS_2spINS_22IGraphicBufferConsumerEEE" M5C_U64
                "ib");
void m5c_cb_setname(android::ConsumerBase*, const android::String8&)
        __asm__("_ZN7android12ConsumerBase7setNameERKNS_7String8E");
}  // extern "C"

// GraphicBuffer::HandleWrapMethod, an enum : uint8_t in Android 13
// (frameworks/native/libs/ui/include/ui/GraphicBuffer.h:98-126).  NOTE: m95's
// gui.cpp passes 1 as CLONE_HANDLE, but 1 is TAKE_HANDLE there.
enum : uint8_t {
    M5C_WRAP_HANDLE = 0,
    M5C_TAKE_HANDLE = 1,
    M5C_TAKE_UNREGISTERED_HANDLE = 2,
    M5C_CLONE_HANDLE = 3,
};

extern "C" {

// N: GraphicBuffer(w, h, format, uint32_t usage)
void _ZN7android13GraphicBufferC1Ejjij(android::GraphicBuffer* self, uint32_t w, uint32_t h,
                                       int format, uint32_t usage) {
    m5c_gb_ctor_alloc(self, w, h, format, 1u, usage, std::string("<m5c N camera>"));
}

// N: GraphicBuffer(w, h, format, usage, stride, handle, keepOwnership) — the
// mapping Android 13's own deprecated inline constructor uses.
void _ZN7android13GraphicBufferC1EjjijjP13native_handleb(android::GraphicBuffer* self,
                                                          uint32_t w, uint32_t h, int format,
                                                          uint32_t usage, uint32_t stride,
                                                          android::native_handle* handle,
                                                          bool keepOwnership) {
    m5c_gb_ctor_wrap(self, handle, keepOwnership ? M5C_TAKE_HANDLE : M5C_WRAP_HANDLE, w, h,
                     format, 1u, usage, stride);
}

// N: GraphicBuffer(ANativeWindowBuffer*, bool keepOwnership).  N tied the
// lifetime to the source buffer; without that tie CLONE_HANDLE owns a dup,
// WRAP_HANDLE borrows; TAKE_HANDLE would double-free (m95 gui.cpp).
void _ZN7android13GraphicBufferC1EP19ANativeWindowBufferb(android::GraphicBuffer* self,
                                                          struct m5c_anwb* buffer,
                                                          bool keepOwnership) {
    uint64_t usage = buffer->usage ? buffer->usage : (uint64_t)(uint32_t)buffer->usage_deprecated;
    m5c_gb_ctor_wrap(self, buffer->handle, keepOwnership ? M5C_CLONE_HANDLE : M5C_WRAP_HANDLE,
                     (uint32_t)buffer->width, (uint32_t)buffer->height, buffer->format, 1u, usage,
                     (uint32_t)buffer->stride);
}

// N: GraphicBuffer::lock(uint32_t usage, void** vaddr)
int _ZN7android13GraphicBuffer4lockEjPPv(android::GraphicBuffer* self, uint32_t usage,
                                         void** vaddr) {
    return m5c_gb_lock(self, usage, vaddr, nullptr, nullptr);
}

// N: BufferQueue::createBufferQueue(sp<IGBP>*, sp<IGBC>*, sp<IGraphicBufferAlloc> const&);
// the allocator is gone, Android 13 allocates internally.
void _ZN7android11BufferQueue17createBufferQueueEPNS_2spINS_22IGraphicBufferProducerEEEPNS1_INS_22IGraphicBufferConsumerEEERKNS1_INS_19IGraphicBufferAllocEEE(
        android::sp<android::IGraphicBufferProducer>* outProducer,
        android::sp<android::IGraphicBufferConsumer>* outConsumer, const void* /*allocator*/) {
    m5c_bq_create(outProducer, outConsumer, false);
}

// N: BufferItemConsumer(const sp<IGBC>&, uint32_t usage, int bufferCount, bool controlledByApp)
void _ZN7android18BufferItemConsumerC1ERKNS_2spINS_22IGraphicBufferConsumerEEEjib(
        android::BufferItemConsumer* self, const void* consumer, uint32_t usage, int bufferCount,
        bool controlledByApp) {
    m5c_bic_ctor(self, consumer, (uint64_t)usage, bufferCount, controlledByApp);
}

// N: BufferItemConsumer::setName; Android 13 keeps ConsumerBase::setName
// (first, non-virtual base: same pointer).
void _ZN7android18BufferItemConsumer7setNameERKNS_7String8E(android::BufferItemConsumer* self,
                                                            const android::String8& name) {
    m5c_cb_setname(reinterpret_cast<android::ConsumerBase*>(self), name);
}

// N: Surface(const sp<IGraphicBufferProducer>&, bool).  Not forwarded on
// purpose (m95): the blob allocates 1776 bytes, an Android 13 Surface needs
// several KiB — constructing into that block would overrun the heap.  Only
// the effect/SDK paths of libmmsdkservice.feature reach it.
void _ZN7android7SurfaceC1ERKNS_2spINS_22IGraphicBufferProducerEEEb(void* /*self*/,
                                                                     const void* /*producer*/,
                                                                     bool /*controlledByApp*/) {
    LOG_ALWAYS_FATAL("m5c: legacy Surface(sp<IGraphicBufferProducer>, bool) called; the N-sized "
                     "allocation cannot hold an Android 13 Surface");
}

}  // extern "C"

// ---- Sensors ---------------------------------------------------------------
// LineageOS libsensor_vendor: SensorManager() only (no package argument).
extern "C" void m5c_sm_ctor(void*) __asm__("_ZN7android13SensorManagerC1Ev");

extern "C" {

// N: SensorManager(String16 const& opPackageName).  The blob allocates 40
// bytes (FACT, libcam.utils.sensorlistener: _Znwj(40)); the compat object is
// four words, no vtable.
void _ZN7android13SensorManagerC1ERKNS_8String16E(void* self, const void* /*opPackageName*/) {
    m5c_sm_ctor(self);
}

// N: SensorEventQueue::getFd() const.  The compat queue wraps an NDK
// ASensorEventQueue and has no descriptor of its own; a valid descriptor that
// never becomes readable keeps the listener's Looper happy (m95 sensor.cpp:
// returning -1 crashed it).  Gyro-assisted camera features get no events.
int _ZNK7android16SensorEventQueue5getFdEv(const void* /*self*/) {
    static const int fd = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    ALOGW("m5c: SensorEventQueue::getFd() has no real descriptor on the compat libsensor, "
          "returning a silent eventfd (%d)", fd);
    return fd;
}

}  // extern "C"

// N: IPermissionController::asInterface(sp<IBinder> const&) — reached only
// from the inlined N SensorManager::getInstanceForPackage() when the
// "permission" service exists; a vendor process asks vndservicemanager, which
// has none, so the binder is null and the result unused.  The vendor libbinder
// has no IPermissionController at all.  sp<> is returned indirectly (r0 on
// arm, x8 on arm64); a one-pointer struct with a user-provided destructor is
// returned the same way (m95 gui.cpp, GLConsumer::getCurrentBuffer).
namespace {
struct M5cSpRet {
    void* p;
    ~M5cSpRet() {}
};
}  // namespace
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreturn-type-c-linkage"
extern "C" M5cSpRet _ZN7android21IPermissionController11asInterfaceERKNS_2spINS_7IBinderEEE(
        const void* /*binder*/) {
    return M5cSpRet{nullptr};
}
#pragma clang diagnostic pop

// ---- HAL3 static metadata for the S5K4H8 main sensor ------------------------
// FACT (set 15, provider log): libcam.halsensor / libcam.metadataprovider look
// the per-sensor configuration up by symbol name —
//   "constructCustStaticMetadata_DEVICE_<CATEGORY>_SENSOR_DRVNAME_S5K4H8_ST_MIPI_RAW
//    not found" (HalSensorList, impConstructStaticMetadata_by_SymbolName)
// — and the Flyme blobs define these only for MTK's reference sensors
// (IMX135/219, GC0310/2145/2355): Flyme ran this HAL as HAL1, which needs no
// static metadata.  Android 13 only takes HAL3.  TEMPORARY: the S5K4H8 gets
// MTK's IMX219 reference configuration (8 Mpix Bayer RAW, same class).  FACT
// (set 20): with it the HAL3 device opens and the preview produces frames
// before the 4.9 kernel ISP/MDP path stalls.  Risk: crop, field of view and
// lens data are the IMX219's, not this sensor's; real S5K4H8 tables are needed
// before the camera can be called working.  The lookup is dlsym(RTLD_DEFAULT)
// from the caller, i.e. its namespace's global libraries and then the camera
// closure - this library is in that closure.
// Signature (disassembly of the IMX219 functions: r0 = IMetadata& with a
// vtable, r1 = sensor info, MBOOL in r0): two pointers in, int out.
#include <dlfcn.h>

namespace {
int m5cForwardStatic(const char* target, void* metadata, void* info) {
    using Fn = int (*)(void*, void*);
    Fn fn = reinterpret_cast<Fn>(dlsym(RTLD_DEFAULT, target));
    if (fn == nullptr) {
        ALOGE("m5c: %s not found for the S5K4H8 static metadata", target);
        return 0;
    }
    ALOGI("m5c: S5K4H8 static metadata from %s", target);
    return fn(metadata, info);
}
}  // namespace

#define M5C_S5K4H8_FROM_IMX219(CATEGORY)                                                         \
    extern "C" int constructCustStaticMetadata_DEVICE_##CATEGORY##_SENSOR_DRVNAME_S5K4H8_ST_MIPI_RAW( \
            void* metadata, void* info) {                                                        \
        return m5cForwardStatic(                                                                 \
                "constructCustStaticMetadata_DEVICE_" #CATEGORY "_SENSOR_DRVNAME_IMX219_MIPI_RAW", \
                metadata, info);                                                                 \
    }

M5C_S5K4H8_FROM_IMX219(CAMERA)
M5C_S5K4H8_FROM_IMX219(LENS)
M5C_S5K4H8_FROM_IMX219(SENSOR)
M5C_S5K4H8_FROM_IMX219(TUNING_3A)
M5C_S5K4H8_FROM_IMX219(FLASHLIGHT)
M5C_S5K4H8_FROM_IMX219(SCALER)
M5C_S5K4H8_FROM_IMX219(FEATURE)
M5C_S5K4H8_FROM_IMX219(REQUEST)

// ---- Open-time closure (libcam_platform.so, dlopen()ed by the devicemgr) ---
// FACT (set 17, provider log): "getPlatform dlopen: libcam_platform.so
// error=... library "libjnigraphics.so" not found: needed by
// libcam.common.meizu.so" -> "No Platform", open() -38.  m5c_linkaudit with

// overlinked sonames (empty stems, Android.bp), three N entry points:
//   libcam.client    GraphicBufferMapper::lock(handle, usage, Rect, void**),
//                    String8::setPathName(const char*)
//   libvfb_render,   GLConsumer::getCurrentBuffer() const
//   libvmp_render
// Bodies as m95 (shims/ui.cpp, shims/gui.cpp).  libcam.client also builds
// GraphicBufferMapper through N's inline Singleton get() — new(8) plus the
// exported Android 13 constructor (the m681 "new(8)" trap); the camera
// closure's operator new has 64 bytes of slack (newpad.cpp), which covers it.
namespace android {
class GraphicBufferMapper;
class Rect;
class GLConsumer;
}  // namespace android

extern "C" {
int m5c_gbm_lock(android::GraphicBufferMapper*, const android::native_handle*, uint32_t,
                 const android::Rect&, void**, int32_t*, int32_t*)
        __asm__("_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPvPiS9_");
#ifdef __LP64__
int m5c_s8_setto(android::String8*, const char*, size_t) __asm__("_ZN7android7String85setToEPKcm");
#else
int m5c_s8_setto(android::String8*, const char*, size_t) __asm__("_ZN7android7String85setToEPKcj");
#endif

// N: GraphicBufferMapper::lock(handle, usage, bounds, vaddr)
int _ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPv(
        android::GraphicBufferMapper* self, const android::native_handle* handle, uint32_t usage,
        const android::Rect& bounds, void** vaddr) {
    return m5c_gbm_lock(self, handle, usage, bounds, vaddr, nullptr, nullptr);
}

// N: String8::setPathName(const char*) — copy, drop ONE trailing '/'.
void _ZN7android7String811setPathNameEPKc(android::String8* self, const char* name) {
    size_t len = strlen(name);
    if (len > 0 && name[len - 1] == '/') len--;
    m5c_s8_setto(self, name, len);
}
}  // extern "C"

// N: GLConsumer::getCurrentBuffer() const; Android 13 takes an int* outSlot.
// sp<GraphicBuffer> comes back indirectly (see M5cSpRet above), so both sides
// are declared returning that struct and the sret slot passes straight through.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreturn-type-c-linkage"
extern "C" M5cSpRet m5c_glc_current(const android::GLConsumer*, int*)
        __asm__("_ZNK7android10GLConsumer16getCurrentBufferEPi");
extern "C" M5cSpRet _ZNK7android10GLConsumer16getCurrentBufferEv(const android::GLConsumer* self) {
    return m5c_glc_current(self, nullptr);
}
#pragma clang diagnostic pop

// Request templates, same scheme.  FACT (set 19, first open in Aperture):
// "TemplateRequest: constructCustRequestMetadata_SENSOR_DRVNAME_S5K4H8_ST_MIPI_RAW
// not found" then "Fail to get constructCustRequestMetadata_COMMON" ->
// createDefaultRequest: "Template ID 1 is invalid or not supported" (-22).
// The blobs have the IMX219 variant (libcam.metadataprovider; disassembly:
// IMetadata& in r0, request type in r1, status in r0) and no COMMON at all;
// both names forward to IMX219.
extern "C" int constructCustRequestMetadata_SENSOR_DRVNAME_S5K4H8_ST_MIPI_RAW(void* metadata,
                                                                            void* requestType) {
    return m5cForwardStatic("constructCustRequestMetadata_SENSOR_DRVNAME_IMX219_MIPI_RAW", metadata,
                            requestType);
}

extern "C" int constructCustRequestMetadata_COMMON(void* metadata, void* requestType) {
    return m5cForwardStatic("constructCustRequestMetadata_SENSOR_DRVNAME_IMX219_MIPI_RAW", metadata,
                            requestType);
}
