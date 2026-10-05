// libm5cshim_region — android::Region with the Nougat object layout, for the
// m5c (MT6737M) Mali EGL driver, lib{,64}/egl/libGLES_mali.so.
//
// Code: device/meizu/m95/shims/region.cpp (los20 device/meizu/m95 0420a7d),
// unchanged but for the export macro and the helper header's name. The m95
// header comment is the full story; in short, an N/M-era Mali reads Region's
// fields itself with the old layout (Vector<Rect>: array at +8, count at +16,
// 32 bytes), while Android 10+ libui keeps a FatVector, so the platform libui
// crashed every HWUI process on m95.
//

// Mali imports from libui.so exactly the same seven Region symbols as m95's
// (ctor, dtor, set(int,int), clear, orSelf(Rect), subtractSelf(Rect),
// getArray(size_t*)) and nothing else. libui.so is not linked into sphal on
// purpose (system/linkerconfig meizu-legacy-vendor 0dcdd17), so Mali's
// DT_NEEDED libui.so is rewritten to this library at build time
// (vendor/meizu/m5c treble-elf-wiring.txt); nothing else loads it.

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <sys/types.h>

#define M5C_EXPORT __attribute__((visibility("default")))

namespace android {

// android::Rect, the subset the region algebra needs. Same name, same layout
// (four int32) as libui's, so the mangled signatures match the blob's imports
// without pulling libui headers (whose Rect.h wants libarect/libutils).
class Rect {
public:
    typedef int32_t value_type;   // region_operator<RECT>::TYPE
    static const Rect EMPTY_RECT; // region_operator's initial span rect

    int32_t left;
    int32_t top;
    int32_t right;
    int32_t bottom;

    inline Rect() : left(0), top(0), right(0), bottom(0) {}
    inline Rect(int32_t w, int32_t h) : left(0), top(0), right(w), bottom(h) {}
    inline Rect(int32_t l, int32_t t, int32_t r, int32_t b) : left(l), top(t), right(r), bottom(b) {}

    inline bool isValid() const { return (getWidth() >= 0) && (getHeight() >= 0); }
    inline bool isEmpty() const { return (getWidth() <= 0) || (getHeight() <= 0); }
    inline int32_t getWidth() const { return right - left; }
    inline int32_t getHeight() const { return bottom - top; }
    inline bool operator==(const Rect& rhs) const {
        return left == rhs.left && top == rhs.top && right == rhs.right && bottom == rhs.bottom;
    }
    inline bool operator!=(const Rect& rhs) const { return !operator==(rhs); }
};

static_assert(sizeof(Rect) == 16, "Rect must be four int32");

const Rect Rect::EMPTY_RECT(0, 0, 0, 0);

}  // namespace android

#include "m5c_RegionHelper.h"  // copy of libui include_private/ui/RegionHelper.h (R), not exported by libui_headers

namespace android {

// ---------------------------------------------------------------------------
// N-layout Vector<Rect>: 32 bytes, array pointer at +8, element count at +16.
// The vptr slot is never dereferenced by the driver; it holds the capacity.
// ---------------------------------------------------------------------------
class NRectVector {
public:
    size_t   mCapacity;   // +0  (VectorImpl vptr slot in N)
    Rect*    mArr;        // +8  (VectorImpl::mStorage)
    size_t   mCount;      // +16 (VectorImpl::mCount)
    uint32_t mFlags;      // +24
    uint32_t mItemSize;   // +28

    NRectVector() : mCapacity(0), mArr(nullptr), mCount(0), mFlags(0), mItemSize(sizeof(Rect)) {}
    ~NRectVector() { free(mArr); }
    NRectVector(const NRectVector&) = delete;
    NRectVector& operator=(const NRectVector&) = delete;

    size_t size() const { return mCount; }
    bool empty() const { return mCount == 0; }
    Rect* data() { return mArr; }
    const Rect* data() const { return mArr; }
    Rect* begin() { return mArr; }
    Rect* end() { return mArr + mCount; }
    const Rect* begin() const { return mArr; }
    const Rect* end() const { return mArr + mCount; }
    Rect& front() { return mArr[0]; }
    Rect& back() { return mArr[mCount - 1]; }
    const Rect& front() const { return mArr[0]; }
    const Rect& back() const { return mArr[mCount - 1]; }
    Rect& operator[](size_t i) { return mArr[i]; }
    const Rect& operator[](size_t i) const { return mArr[i]; }

    void clear() { mCount = 0; }

    void reserve(size_t n) {
        if (n <= mCapacity) return;
        size_t cap = mCapacity ? mCapacity : 4;
        while (cap < n) cap *= 2;
        Rect* p = static_cast<Rect*>(realloc(mArr, cap * sizeof(Rect)));
        if (!p) abort();
        mArr = p;
        mCapacity = cap;
    }

    void push_back(const Rect& r) {
        reserve(mCount + 1);
        mArr[mCount++] = r;
    }

    // insert one element before pos (pos in [begin, end])
    void insert(Rect* pos, const Rect& r) {
        size_t idx = pos - mArr;
        reserve(mCount + 1);
        memmove(mArr + idx + 1, mArr + idx, (mCount - idx) * sizeof(Rect));
        mArr[idx] = r;
        mCount++;
    }

    // insert [first, last) before pos; ranges never alias mArr in this file.
    void insert(Rect* pos, const Rect* first, const Rect* last) {
        size_t n = last - first;
        if (!n) return;
        size_t idx = pos - mArr;
        reserve(mCount + n);
        memmove(mArr + idx + n, mArr + idx, (mCount - idx) * sizeof(Rect));
        memcpy(mArr + idx, first, n * sizeof(Rect));
        mCount += n;
    }
};

class Region {
public:
    NRectVector mStorage;   // offset 0: the blob reads +8 and +16 of *this

    typedef const Rect* const_iterator;

    M5C_EXPORT Region();
    M5C_EXPORT ~Region();
    Region(const Region& rhs);
    explicit Region(const Rect& rhs);
    // Exported: exactly what libGLES_mali imports (both ABIs, FACT readelf):
    // the ctor, dtor, clear, set(w, h), orSelf, subtractSelf and getArray.
    // operator=, set(Rect), translate and begin/end were exported for m95's
    // hwcomposer.mt6797; no m5c blob imports them (the stock HWC is not
    // shipped), so they stay internal.
    Region& operator=(const Region& rhs);

    M5C_EXPORT void clear();
    void set(const Rect& r);
    M5C_EXPORT void set(int32_t w, int32_t h);
    Region translate(int dx, int dy) const;

    M5C_EXPORT Region& orSelf(const Rect& r);
    M5C_EXPORT Region& subtractSelf(const Rect& r);
    Region& operationSelf(const Rect& r, uint32_t op);

    M5C_EXPORT Rect const* getArray(size_t* count) const;

    inline bool isEmpty() const { return getBounds().isEmpty(); }
    inline bool isRect() const { return mStorage.size() == 1; }
    inline Rect getBounds() const { return mStorage[mStorage.size() - 1]; }
    const_iterator begin() const;
    const_iterator end() const;

private:
    class rasterizer;
    static void boolean_operation(uint32_t op, Region& dst,
                                  const Region& lhs, const Rect& rhs, int dx, int dy);
};

// N VectorImpl: vptr + mStorage + mCount (pointer-sized) + mFlags + mItemSize
// (uint32 each): 32 bytes on arm64, 20 on arm32 (array at +4, count at +8).
static_assert(sizeof(NRectVector) == 3 * sizeof(void*) + 8, "N-layout Vector<Rect> size");
static_assert(sizeof(Region) == sizeof(NRectVector), "Region must be exactly its N-layout vector");

enum {
    op_nand = region_operator<Rect>::op_nand,
    op_and  = region_operator<Rect>::op_and,
    op_or   = region_operator<Rect>::op_or,
    op_xor  = region_operator<Rect>::op_xor
};

// ---------------------------------------------------------------------------

Region::Region() {
    mStorage.push_back(Rect(0, 0));
}

Region::Region(const Region& rhs) {
    mStorage.clear();
    mStorage.insert(mStorage.begin(), rhs.mStorage.begin(), rhs.mStorage.end());
}

Region::Region(const Rect& rhs) {
    mStorage.push_back(rhs);
}

Region::~Region() {
}

Region& Region::operator=(const Region& rhs) {
    if (this != &rhs) {
        mStorage.clear();
        mStorage.insert(mStorage.begin(), rhs.mStorage.begin(), rhs.mStorage.end());
    }
    return *this;
}

// R: Region::translate(dx, dy) const -> copy, then shift every rect and the
// bounds. Returned by value: 32 bytes, non-trivially destructible -> sret.
Region Region::translate(int dx, int dy) const {
    Region reg(*this);
    if ((dx || dy) && !reg.isEmpty()) {
        for (size_t i = 0; i < reg.mStorage.size(); i++) {
            Rect& r = reg.mStorage[i];
            r.left += dx; r.right += dx;
            r.top += dy; r.bottom += dy;
        }
    }
    return reg;
}

void Region::clear() {
    mStorage.clear();
    mStorage.push_back(Rect(0, 0));
}

void Region::set(const Rect& r) {
    mStorage.clear();
    mStorage.push_back(r);
}

void Region::set(int32_t w, int32_t h) {
    mStorage.clear();
    mStorage.push_back(Rect(w, h));
}

Region& Region::orSelf(const Rect& r) {
    if (isEmpty()) {
        set(r);
        return *this;
    }
    return operationSelf(r, op_or);
}

Region& Region::subtractSelf(const Rect& r) {
    return operationSelf(r, op_nand);
}

Region& Region::operationSelf(const Rect& r, uint32_t op) {
    Region lhs(*this);
    boolean_operation(op, *this, lhs, r, 0, 0);
    return *this;
}

Region::const_iterator Region::begin() const {
    return mStorage.data();
}

Region::const_iterator Region::end() const {
    if (mStorage.empty()) return mStorage.data();
    size_t numRects = isRect() ? 1 : mStorage.size() - 1;
    return mStorage.data() + numRects;
}

Rect const* Region::getArray(size_t* count) const {
    if (count) *count = static_cast<size_t>(end() - begin());
    return begin();
}

// ---------------------------------------------------------------------------
// rasterizer: ported verbatim from R Region.cpp, FatVector -> NRectVector.
// ---------------------------------------------------------------------------

class Region::rasterizer : public region_operator<Rect>::region_rasterizer {
    Rect bounds;
    NRectVector& storage;
    Rect* head;
    Rect* tail;
    NRectVector span;
    Rect* cur;
public:
    explicit rasterizer(Region& reg)
        : bounds(INT_MAX, 0, INT_MIN, 0), storage(reg.mStorage), head(), tail(), cur() {
        storage.clear();
    }

    virtual ~rasterizer();

    virtual void operator()(const Rect& rect);

private:
    template<typename T>
    static inline T min(T rhs, T lhs) { return rhs < lhs ? rhs : lhs; }
    template<typename T>
    static inline T max(T rhs, T lhs) { return rhs > lhs ? rhs : lhs; }

    void flushSpan();
};

Region::rasterizer::~rasterizer() {
    if (span.size()) {
        flushSpan();
    }
    if (storage.size()) {
        bounds.top = storage.front().top;
        bounds.bottom = storage.back().bottom;
        if (storage.size() == 1) {
            storage.clear();
        }
    } else {
        bounds.left  = 0;
        bounds.right = 0;
    }
    storage.push_back(bounds);
}

void Region::rasterizer::operator()(const Rect& rect) {
    if (span.size()) {
        if (cur->top != rect.top) {
            flushSpan();
        } else if (cur->right == rect.left) {
            cur->right = rect.right;
            return;
        }
    }
    span.push_back(rect);
    cur = span.data() + (span.size() - 1);
}

void Region::rasterizer::flushSpan() {
    bool merge = false;
    if (tail - head == ssize_t(span.size())) {
        Rect const* p = span.data();
        Rect const* q = head;
        if (p->top == q->bottom) {
            merge = true;
            while (q != tail) {
                if ((p->left != q->left) || (p->right != q->right)) {
                    merge = false;
                    break;
                }
                p++;
                q++;
            }
        }
    }
    if (merge) {
        const int bottom = span.front().bottom;
        Rect* r = head;
        while (r != tail) {
            r->bottom = bottom;
            r++;
        }
    } else {
        bounds.left = min(span.front().left, bounds.left);
        bounds.right = max(span.back().right, bounds.right);
        storage.insert(storage.end(), span.begin(), span.end());
        tail = storage.data() + storage.size();
        head = tail - span.size();
    }
    span.clear();
}

void Region::boolean_operation(uint32_t op, Region& dst,
                               const Region& lhs, const Rect& rhs, int dx, int dy) {
    if (!rhs.isValid()) {
        // R logs and returns; keep dst untouched (same observable behaviour).
        return;
    }
    size_t lhs_count;
    Rect const* const lhs_rects = lhs.getArray(&lhs_count);
    region_operator<Rect>::region lhs_region(lhs_rects, lhs_count);
    region_operator<Rect>::region rhs_region(&rhs, 1, dx, dy);
    region_operator<Rect> operation(op, lhs_region, rhs_region);
    {   // scope for rasterizer (dtor has side effects)
        rasterizer r(dst);
        operation(r);
    }
}

}  // namespace android
