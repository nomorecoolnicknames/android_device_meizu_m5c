/*
 * Shim for the MTK video codec blobs.
 *
 * libvcodecdrv.so imports __pthread_gettid, which Pie's bionic dropped. It is
 * loaded through the 32-bit Mali driver's dlopen chain, so without the symbol
 * the 32-bit zygote finds no OpenGL ES implementation and aborts. Pie
 * provides the same value as pthread_gettid_np.
 */
#include <pthread.h>
#include <sys/types.h>

pid_t __pthread_gettid(pthread_t t);

pid_t __pthread_gettid(pthread_t t)
{
    return pthread_gettid_np(t);
}
