// libnativehelper.so (vendor) — see Android.bp: 35 of its 39 consumers import
// nothing from it.  The other four (libem_bt_jni and libmeizucamera, both
// ABIs) import three JNIHelp calls; a vendor process has no JavaVM, so they
// fail as they would without a valid env.  libmeizucamera is in the camera

// jniThrowRuntimeException, jniGetFDFromFileDescriptor unresolved there).
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
