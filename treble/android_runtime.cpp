// libandroid_runtime.so (vendor, empty but for two JNI helpers) — NEEDed by
// libmeizucamera.so, a Meizu camera-app library that sits in the HAL closure
// (camera.mt6737m.so NEEDs it directly).  It imports
// AndroidRuntime::getJNIEnv() and registerNativeMethods(); the native HAL
// process has no JavaVM, so null / -1 are the honest answers.  Bodies as m95
// (device/meizu/m95/shims/android_runtime.cpp); the signatures reproduce the
// real class so the mangled names match.  The platform library is
// system-only, so the real name cannot shadow anything in a vendor process.
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
