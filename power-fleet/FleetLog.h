/*
 * Logging for the parts of the fleet Power HAL that also build on the host
 * (Config, Engine, Adpf; tests/run-host-test.sh).  On Android this is
 * android-base logging; on the host a minimal stream to stderr that drops
 * VERBOSE, so the test output only shows warnings and errors.
 */
#pragma once

#ifdef __ANDROID__
#include <android-base/logging.h>
#define FLEET_LOG(severity) LOG(severity)
#else
#include <cstring>
#include <iostream>

namespace fleetlog {

struct Line {
    bool on;
    ~Line() {
        if (on) std::cerr << std::endl;
    }
    template <typename T>
    Line& operator<<(const T& v) {
        if (on) std::cerr << v;
        return *this;
    }
};

}  // namespace fleetlog

#define FLEET_LOG(severity) \
    ::fleetlog::Line{std::strcmp(#severity, "VERBOSE") != 0} << #severity << ": "
#endif
