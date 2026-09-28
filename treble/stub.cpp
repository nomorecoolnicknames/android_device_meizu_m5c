// Empty library: its only job is to exist under a soname that N-era vendor
// blobs NEED (see Android.bp in this directory for which and why).
extern "C" void __m5c_treble_stub_marker(void) {}
