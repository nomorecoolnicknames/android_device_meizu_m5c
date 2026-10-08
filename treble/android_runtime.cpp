// libandroid_runtime.so (vendor) for libmeizucamera.so in the camera HAL
// closure: AndroidRuntime::getJNIEnv() and registerNativeMethods(). The HAL
// process has no JavaVM, so they return null / -1.
struct _JNIEnv;
struct JNINativeMethod;

namespace android {
class AndroidRuntime {
  public:
    static int registerNativeMethods(_JNIEnv* env, const char* className,
                                     const JNINativeMethod* methods, int numMethods);
    static _JNIEnv* getJNIEnv();
};

int AndroidRuntime::registerNativeMethods(_JNIEnv*, const char*, const JNINativeMethod*, int) {
    return -1;
}

_JNIEnv* AndroidRuntime::getJNIEnv() {
    return nullptr;
}
}  // namespace android
