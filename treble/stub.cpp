// Empty library: its only job is to exist under a soname that N-era vendor
// blobs NEED but import nothing from (Android.bp in this directory says which
// and why; libgui_m5c_fwd adds a DT_NEEDED on the real implementation).
extern "C" void __m5c_treble_stub_marker(void) {}
