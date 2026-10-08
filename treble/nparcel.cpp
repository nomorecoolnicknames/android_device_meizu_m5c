// Box for the Marshmallow android::Parcel the 64-bit librilmtk keeps by value.
//
// sizeof(android::Parcel) is 120 on arm64 with the Android 13 headers, but
// librilmtk reserves 104 bytes. Its android::Parcel imports are renamed to
// android::Pbrcel: the first 8 bytes of the storage hold a pointer to a real
// heap-allocated Parcel and every method is forwarded to it.
#include <cstddef>
#include <cstdint>

#include <binder/Parcel.h>
#include <utils/Errors.h>

#define M5C_EXPORT __attribute__((visibility("default")))

namespace android {

class Pbrcel {
public:
    M5C_EXPORT Pbrcel();
    M5C_EXPORT ~Pbrcel();

    M5C_EXPORT status_t writeInt32(int32_t val);
    M5C_EXPORT status_t writeInt64(int64_t val);
    M5C_EXPORT status_t writeString16(const char16_t* str, size_t len);
    M5C_EXPORT status_t write(const void* data, size_t len);
    M5C_EXPORT status_t setData(const uint8_t* buffer, size_t len);

    M5C_EXPORT const void* readInplace(size_t len) const;
    M5C_EXPORT size_t dataPosition() const;
    M5C_EXPORT void setDataPosition(size_t pos) const;
    M5C_EXPORT const char16_t* readString16Inplace(size_t* outLen) const;
    M5C_EXPORT const uint8_t* data() const;
    M5C_EXPORT status_t read(void* outData, size_t len) const;
    M5C_EXPORT size_t dataSize() const;
    M5C_EXPORT status_t readInt32(int32_t* pArg) const;
    M5C_EXPORT int32_t readInt32() const;

private:
    Parcel* mReal;
};

static inline Parcel* real(const Pbrcel* self) {
    return *reinterpret_cast<Parcel* const*>(self);
}

Pbrcel::Pbrcel() : mReal(new Parcel()) {}

Pbrcel::~Pbrcel() {
    delete real(this);
}

status_t Pbrcel::writeInt32(int32_t val) {
    return real(this)->writeInt32(val);
}

status_t Pbrcel::writeInt64(int64_t val) {
    return real(this)->writeInt64(val);
}

status_t Pbrcel::writeString16(const char16_t* str, size_t len) {
    return real(this)->writeString16(str, len);
}

status_t Pbrcel::write(const void* data, size_t len) {
    return real(this)->write(data, len);
}

status_t Pbrcel::setData(const uint8_t* buffer, size_t len) {
    return real(this)->setData(buffer, len);
}

const void* Pbrcel::readInplace(size_t len) const {
    return real(this)->readInplace(len);
}

size_t Pbrcel::dataPosition() const {
    return real(this)->dataPosition();
}

void Pbrcel::setDataPosition(size_t pos) const {
    real(this)->setDataPosition(pos);
}

const char16_t* Pbrcel::readString16Inplace(size_t* outLen) const {
    return real(this)->readString16Inplace(outLen);
}

const uint8_t* Pbrcel::data() const {
    return real(this)->data();
}

status_t Pbrcel::read(void* outData, size_t len) const {
    return real(this)->read(outData, len);
}

size_t Pbrcel::dataSize() const {
    return real(this)->dataSize();
}

status_t Pbrcel::readInt32(int32_t* pArg) const {
    return real(this)->readInt32(pArg);
}

int32_t Pbrcel::readInt32() const {
    return real(this)->readInt32();
}

}  // namespace android
