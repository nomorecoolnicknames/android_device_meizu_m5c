// libnativehelper.so (vendor): the three JNIHelp calls imported by
// libem_bt_jni and libmeizucamera. A vendor process has no JavaVM, so they
// fail as they would without a valid env.
struct _JNIEnv;
class _jobject;

extern "C" {

int jniThrowException(_JNIEnv*, const char*, const char*) {
    return -1;
}

int jniThrowRuntimeException(_JNIEnv*, const char*) {
    return -1;
}

int jniGetFDFromFileDescriptor(_JNIEnv*, _jobject*) {
    return -1;
}

}  // extern "C"
