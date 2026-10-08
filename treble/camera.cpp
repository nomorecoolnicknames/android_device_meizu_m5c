// Shims for the symbols the Nougat-era camera blobs import from platform
// libraries that Android 13 no longer exports.
//
// The blobs allocate N-sized objects themselves: GraphicBuffer and
// BufferItemConsumer are covered by the operator new slack of newpad.cpp,
// Surface (too small for the Android 13 layout) is refused below.
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>

#include <string>

#include <log/log.h>
#include <utils/KeyedVector.h>
#include <utils/String8.h>

// PropertyMap moved to libinput, which a vendor process cannot load.
// The blob allocates the object; its only member is a KeyedVector.
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
// to N; N's reserved[2] became layerCount + reserved[1]).
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

// GraphicBuffer::HandleWrapMethod, an enum : uint8_t in Android 13.
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
// WRAP_HANDLE borrows; TAKE_HANDLE would double-free.
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

// N: Surface(const sp<IGraphicBufferProducer>&, bool). Not forwarded: the
// blob allocates 1776 bytes, an Android 13 Surface needs several KiB. Only
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

// N: SensorManager(String16 const& opPackageName). The blob allocates 40
// bytes; the compat object is four words, no vtable.
void _ZN7android13SensorManagerC1ERKNS_8String16E(void* self, const void* /*opPackageName*/) {
    m5c_sm_ctor(self);
}

// N: SensorEventQueue::getFd() const.  The compat queue wraps an NDK
// ASensorEventQueue and has no descriptor of its own; a valid descriptor that
// never becomes readable keeps the listener's Looper happy (-1 crashes it).
// Gyro-assisted camera features get no events.
int _ZNK7android16SensorEventQueue5getFdEv(const void* /*self*/) {
    static const int fd = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    ALOGW("m5c: SensorEventQueue::getFd() has no real descriptor on the compat libsensor, "
          "returning a silent eventfd (%d)", fd);
    return fd;
}

}  // extern "C"

// N: IPermissionController::asInterface(sp<IBinder> const&). Only reached when
// a "permission" service exists, which vndservicemanager does not have.
// sp<> is returned indirectly; a one-pointer struct with a user-provided
// destructor is returned the same way.
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

// HAL3 static metadata for the S5K4H8 main sensor.
// The blobs only define the per-sensor metadata for MTK reference sensors,
// so the S5K4H8 uses the IMX219 tables (8 Mpix Bayer RAW). Crop, field of
// view and lens data are therefore approximate. The lookup is
// dlsym(RTLD_DEFAULT) from the camera closure, which includes this library.
#include <dlfcn.h>

namespace {
int m5cForwardStatic(const char* target, void* metadata, void* info) {
    using Fn = int (*)(void*, void*);
    Fn fn = reinterpret_cast<Fn>(dlsym(RTLD_DEFAULT, target));
    if (fn == nullptr) {
        ALOGE("m5c: %s not found for the forwarded static metadata", target);
        return 0;
    }
    ALOGI("m5c: forwarded static metadata from %s", target);
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

// The front S5K5E8 (5 Mpix Bayer RAW) uses the GC2355 tables, for each of
// the four module variants (ST, QH, HOLITECH, SUNWIN).
#define M5C_S5K5E8_FROM_GC2355(VARIANT, CATEGORY)                                             \
    extern "C" int                                                                            \
            constructCustStaticMetadata_DEVICE_##CATEGORY##_SENSOR_DRVNAME_S5K5E8_##VARIANT##_MIPI_RAW( \
                    void* metadata, void* info) {                                             \
        return m5cForwardStatic(                                                              \
                "constructCustStaticMetadata_DEVICE_" #CATEGORY "_SENSOR_DRVNAME_GC2355_MIPI_RAW", \
                metadata, info);                                                              \
    }
// SENSOR: the GC2355 table with the S5K5E8 geometry on top: modes 1296x972
// (preview) and 2592x1944 (capture, video) at 30 fps, 1.12 um pixels
// (2.903 x 2.177 mm). The tag numbers mirror the Android ones; 0xf000c is
// the MTK per-scenario table. The LENS table stays the GC2355's.
namespace {
struct M5cMSize { int w, h; };
struct M5cMRect { int x, y, w, h; };
template <typename T> struct M5cT2T {};
struct M5cObj { void* vptr; void* imp; void* spare[2]; };

struct M5cMetaApi {
    void (*entryCtor)(M5cObj*, unsigned);
    void (*entryDtor)(M5cObj*);
    void (*metaCtor)(M5cObj*);
    void (*metaDtor)(M5cObj*);
    int (*update)(void*, unsigned, const M5cObj*);
    void (*pushInt)(M5cObj*, const int&, M5cT2T<int>);
    void (*pushFloat)(M5cObj*, const float&, M5cT2T<float>);
    void (*pushI64)(M5cObj*, const int64_t&, M5cT2T<int64_t>);
    void (*pushRect)(M5cObj*, const M5cMRect&, M5cT2T<M5cMRect>);
    void (*pushSize)(M5cObj*, const M5cMSize&, M5cT2T<M5cMSize>);
    void (*pushMeta)(M5cObj*, const M5cObj&, M5cT2T<M5cObj>);
};

template <typename F> bool m5cSym(F& f, const char* name) {
    f = reinterpret_cast<F>(dlsym(RTLD_DEFAULT, name));
    if (f == nullptr) ALOGE("m5c: %s not found", name);
    return f != nullptr;
}

bool m5cMetaApi(M5cMetaApi& a) {
    return m5cSym(a.entryCtor, "_ZN5NSCam9IMetadata6IEntryC1Ej") &&
           m5cSym(a.entryDtor, "_ZN5NSCam9IMetadata6IEntryD1Ev") &&
           m5cSym(a.metaCtor, "_ZN5NSCam9IMetadataC1Ev") &&
           m5cSym(a.metaDtor, "_ZN5NSCam9IMetadataD1Ev") &&
           m5cSym(a.update, "_ZN5NSCam9IMetadata6updateEjRKNS0_6IEntryE") &&
           m5cSym(a.pushInt, "_ZN5NSCam9IMetadata6IEntry9push_backERKiNS_9Type2TypeIiEE") &&
           m5cSym(a.pushFloat, "_ZN5NSCam9IMetadata6IEntry9push_backERKfNS_9Type2TypeIfEE") &&
#ifdef __LP64__
           m5cSym(a.pushI64, "_ZN5NSCam9IMetadata6IEntry9push_backERKlNS_9Type2TypeIlEE") &&
#else
           m5cSym(a.pushI64, "_ZN5NSCam9IMetadata6IEntry9push_backERKxNS_9Type2TypeIxEE") &&
#endif
           m5cSym(a.pushRect, "_ZN5NSCam9IMetadata6IEntry9push_backERKNS_5MRectENS_9Type2TypeIS2_EE") &&
           m5cSym(a.pushSize, "_ZN5NSCam9IMetadata6IEntry9push_backERKNS_5MSizeENS_9Type2TypeIS2_EE") &&
           m5cSym(a.pushMeta, "_ZN5NSCam9IMetadata6IEntry9push_backERKS0_NS_9Type2TypeIS0_EE");
}

void m5cPutRect(const M5cMetaApi& a, void* meta, unsigned tag, M5cMRect v) {
    M5cObj e{};
    a.entryCtor(&e, tag);
    a.pushRect(&e, v, {});
    a.update(meta, tag, &e);
    a.entryDtor(&e);
}

void m5cPutSize(const M5cMetaApi& a, void* meta, unsigned tag, M5cMSize v) {
    M5cObj e{};
    a.entryCtor(&e, tag);
    a.pushSize(&e, v, {});
    a.update(meta, tag, &e);
    a.entryDtor(&e);
}

void m5cPutInt(const M5cMetaApi& a, void* meta, unsigned tag, int v) {
    M5cObj e{};
    a.entryCtor(&e, tag);
    a.pushInt(&e, v, {});
    a.update(meta, tag, &e);
    a.entryDtor(&e);
}

void m5cPutI64(const M5cMetaApi& a, void* meta, unsigned tag, int64_t v) {
    M5cObj e{};
    a.entryCtor(&e, tag);
    a.pushI64(&e, v, {});
    a.update(meta, tag, &e);
    a.entryDtor(&e);
}

int m5cS5K5E8Sensor(void* metadata, void* info) {
    int ret = m5cForwardStatic(
            "constructCustStaticMetadata_DEVICE_SENSOR_SENSOR_DRVNAME_GC2355_MIPI_RAW", metadata,
            info);
    M5cMetaApi a;
    if (!m5cMetaApi(a)) return ret;

    m5cPutRect(a, metadata, 0xf0000, {0, 0, 2592, 1944});   // active array
    m5cPutSize(a, metadata, 0xf0006, {2592, 1944});         // pixel array
    {
        M5cObj e{};
        a.entryCtor(&e, 0xf0005);                            // physical size, mm
        a.pushFloat(&e, 2.903f, {});
        a.pushFloat(&e, 2.177f, {});
        a.update(metadata, 0xf0005, &e);
        a.entryDtor(&e);
    }

    static const struct { int id; M5cMSize out; } kModes[] = {
            {1, {1296, 972}}, {2, {2592, 1944}}, {3, {2592, 1944}}};
    M5cObj modes{};
    a.entryCtor(&modes, 0xf000c);
    for (const auto& m : kModes) {
        M5cObj mode{};
        a.metaCtor(&mode);
        m5cPutInt(a, &mode, 0xf000e, m.id);
        m5cPutInt(a, &mode, 0xf000f, 30);
        m5cPutRect(a, &mode, 0xf0011, {0, 0, 2592, 1944});
        m5cPutSize(a, &mode, 0xf0010, m.out);
        m5cPutI64(a, &mode, 0xe001a, 33000000);
        a.pushMeta(&modes, mode, {});
        a.metaDtor(&mode);
    }
    a.update(metadata, 0xf000c, &modes);
    a.entryDtor(&modes);
    ALOGI("m5c: S5K5E8 sensor geometry 2592x1944 over the GC2355 table");
    return ret;
}
}  // namespace

#define M5C_S5K5E8_SENSOR(VARIANT)                                                                   \
    extern "C" int constructCustStaticMetadata_DEVICE_SENSOR_SENSOR_DRVNAME_S5K5E8_##VARIANT##_MIPI_RAW( \
            void* metadata, void* info) {                                                            \
        return m5cS5K5E8Sensor(metadata, info);                                                      \
    }

#define M5C_S5K5E8_VARIANT(VARIANT)                    \
    M5C_S5K5E8_FROM_GC2355(VARIANT, CAMERA)            \
    M5C_S5K5E8_FROM_GC2355(VARIANT, LENS)              \
    M5C_S5K5E8_SENSOR(VARIANT)                         \
    M5C_S5K5E8_FROM_GC2355(VARIANT, TUNING_3A)         \
    M5C_S5K5E8_FROM_GC2355(VARIANT, FLASHLIGHT)        \
    M5C_S5K5E8_FROM_GC2355(VARIANT, SCALER)            \
    M5C_S5K5E8_FROM_GC2355(VARIANT, FEATURE)           \
    M5C_S5K5E8_FROM_GC2355(VARIANT, REQUEST)

M5C_S5K5E8_VARIANT(ST)
M5C_S5K5E8_VARIANT(QH)
M5C_S5K5E8_VARIANT(HOLITECH)
M5C_S5K5E8_VARIANT(SUNWIN)

// Symbols needed by libcam_platform.so, dlopen()ed by the device manager.
// libcam.client also constructs GraphicBufferMapper via new(8); the
// operator new slack of newpad.cpp covers it.
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

// Request templates: the blobs only have the IMX219 variant and no COMMON.
extern "C" int constructCustRequestMetadata_SENSOR_DRVNAME_S5K4H8_ST_MIPI_RAW(void* metadata,
                                                                            void* requestType) {
    return m5cForwardStatic("constructCustRequestMetadata_SENSOR_DRVNAME_IMX219_MIPI_RAW", metadata,
                            requestType);
}

extern "C" int constructCustRequestMetadata_COMMON(void* metadata, void* requestType) {
    return m5cForwardStatic("constructCustRequestMetadata_SENSOR_DRVNAME_IMX219_MIPI_RAW", metadata,
                            requestType);
}

// The Nougat camera blobs pthread_join() a thread that was already joined or
// detached. Android 13 bionic aborts on that for target SDK >= 26, so run the
// camera provider at target SDK 25. Other processes also load this library
// through the OMX closure and are left alone.
#include <unistd.h>
namespace {
__attribute__((constructor)) void m5cCameraProviderSdk() {
    const char* name = getprogname();
    if (name == nullptr || strstr(name, "camera.provider") == nullptr) return;
    using SetSdk = void (*)(int);
    SetSdk set = reinterpret_cast<SetSdk>(
            dlsym(RTLD_DEFAULT, "__loader_android_set_application_target_sdk_version"));
    if (set == nullptr) {
        ALOGE("m5c: %s: no __loader_android_set_application_target_sdk_version (%s)", name,
              dlerror());
        return;
    }
    set(25);
    ALOGW("m5c: %s: target SDK 25 for the Nougat camera blobs (pthread_join ESRCH, not abort)",
          name);
}
}  // namespace
