/*
 * pthread_mutex_destroy interposer for /vendor/bin/mnld.
 *
 * libmnl.so destroys its session mutex twice on every stop, and bionic's
 * FORTIFY aborts on that:
 *
 *   FORTIFY: pthread_mutex_destroy called on a destroyed mutex
 *
 * A no-op is safe: bionic's destroy frees nothing, and pthread_mutex_init()
 * reinitialises the mutex anyway.
 */
#include <pthread.h>

int pthread_mutex_destroy(pthread_mutex_t* mutex __attribute__((unused))) {
    return 0;
}
