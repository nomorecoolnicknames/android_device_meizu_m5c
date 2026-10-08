/* libm5cshim_jnihelp.so (vendor, 64-bit): jniRegisterNativeMethods for libwfo_jni.
 *
 * libwfo_jni needs libnativehelper.so, which is only in the ART apex, and
 * imports only jniRegisterNativeMethods from it.
 *
 * Unlike libnativehelper this does not call FatalError: a mismatching table
 * leaves the natives unregistered and the IMS app gets UnsatisfiedLinkError
 * instead of crashing. The mismatch is logged.
 */
#include <jni.h>
#include <log/log.h>

#undef LOG_TAG
#define LOG_TAG "m5cshim_jnihelp"

extern "C" __attribute__((visibility("default")))
int jniRegisterNativeMethods(JNIEnv* env, const char* className,
                             const JNINativeMethod* methods, int numMethods) {
    jclass clazz = env->FindClass(className);
    if (clazz == nullptr) {
        env->ExceptionClear();
        ALOGE("%s: class not found, %d natives not registered", className, numMethods);
        return -1;
    }
    int rc = env->RegisterNatives(clazz, methods, numMethods);
    env->DeleteLocalRef(clazz);
    if (rc < 0) {
        env->ExceptionClear();
        ALOGE("%s: RegisterNatives failed for its %d natives (class/table mismatch)",
              className, numMethods);
        return -1;
    }
    return 0;
}
