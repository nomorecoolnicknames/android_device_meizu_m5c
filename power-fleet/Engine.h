/*
 * Node engine of the Power HAL.
 *
 * Sources ("interaction", "fling", "launch", "adpf") hold requests: node ->
 * value token, valid until a deadline.  For every node the engine writes the
 * aggregate (max) of the live requests, or the released value when none is
 * left, and only when that differs from what it last wrote.  Floors are
 * clamped to the live ceiling at write time: on 4.9 a scaling_min_freq above
 * scaling_max_freq is refused whole (cpufreq.c cpufreq_set_policy, -EINVAL),
 * and the ceilings move at run time (thermal, user limits).
 *
 * The engine does no I/O of its own (Fs), so tests/engine_host_test.cpp runs
 * it against a fake sysfs on the host.
 */
#pragma once

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <map>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

#include "Config.h"

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

class Engine {
  public:
    using Clock = std::chrono::steady_clock;
    static constexpr std::chrono::milliseconds kRetryPeriod{500};
    static constexpr std::chrono::seconds kRetryWindow{60};

    struct Fs {
        // Reads the whole node; false if it does not exist or cannot be read.
        std::function<bool(const std::string& path, std::string* out)> read;
        // Writes the value; false with errno in *err on failure.
        std::function<bool(const std::string& path, const std::string& value, int* err)> write;
    };
    static Fs RealFs();

    explicit Engine(std::vector<NodeConfig> nodes, Fs fs = RealFs());
    ~Engine();

    // Worker thread that releases requests when they expire.  Tests do not
    // start it and call apply() with their own clock instead.
    void start();

    // Drops every request and writes the released value of every node that
    // exists: a restarted HAL must not leave a floor behind.  A node that is
    // not writable yet (init gives it to group system a little later, or it
    // is created later) is retried every kRetryPeriod for kRetryWindow; those
    // early refusals count as `deferred`, not as failures.
    void reset(Clock::time_point now = Clock::now());

    // Replaces the request of `source` (extend: keep the later deadline of the
    // live request and this one), then applies at once.
    void setRequest(const std::string& source, const ValueMap& values, Clock::time_point until,
                    bool extend = false, Clock::time_point now = Clock::now());
    void clearRequest(const std::string& source, Clock::time_point now = Clock::now());
    void clearAll(Clock::time_point now = Clock::now());

    // Pulse node: duration (only when it changed), then "1".
    void pulse(const std::string& node, int32_t durationMs);

    // Drops expired requests and writes what changed; returns the next deadline
    // (Clock::time_point::max() if no request is left).
    Clock::time_point apply(Clock::time_point now);

    bool hasRequest(const std::string& source) const;
    std::string dump(Clock::time_point now = Clock::now()) const;

  private:
    struct NodeState {
        NodeConfig cfg;
        std::optional<std::string> written;  // nullopt: unknown, write next time
        std::optional<int64_t> releasedKhz;  // cpufreq floors: cpuinfo_min_freq
        std::optional<int64_t> pulseUs;
        std::optional<std::string> captured;  // Release::Capture: value before the hold
        uint64_t writes = 0;
        uint64_t failures = 0;
        uint64_t deferred = 0;  // EACCES/ENOENT before the first good write
        int lastError = 0;
    };
    struct Request {
        ValueMap values;
        Clock::time_point until;
    };

    Clock::time_point applyLocked(Clock::time_point now);
    std::optional<std::string> targetLocked(NodeState& node) const;
    std::optional<int64_t> readKhz(const std::string& path) const;
    bool writeLocked(NodeState& node, const std::string& value);
    void loop();

    Fs mFs;
    std::vector<NodeState> mNodes;  // sorted by (order, name): the write order
    NodeState* findLocked(const std::string& name);
    std::map<std::string, Request> mRequests;

    mutable std::mutex mLock;
    std::condition_variable mCv;
    bool mDirty = false;
    bool mStop = false;
    Clock::time_point mRetryUntil;  // end of the start-up retry window
    std::thread mWorker;
};

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
