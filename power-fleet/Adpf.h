/*
 * ADPF without uclamp.
 *
 * The kernels (3.18, 4.9) have no uclamp, so a hint session cannot
 * clamp its own threads the way the Pixel HAL does.  Instead every session
 * keeps a level 0..N: frames over the target raise it, a batch well under
 * the target lowers it.  The highest level of the running sessions becomes
 * the "adpf" request of the engine (Adpf.Levels[L - 1]) with a short deadline,
 * so the floor goes away by itself once HWUI stops drawing and reporting.
 */
#pragma once

#include <chrono>
#include <cstdint>
#include <map>
#include <mutex>
#include <string>
#include <vector>

#include "Config.h"
#include "Engine.h"

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

// One batch of reports -> the next level of a session.  A frame over the
// target: +1; over 1.5 x target: +2; every frame under lowWater x target: -1.
int AdpfNextLevel(int level, int maxLevel, int64_t targetNs, const std::vector<int64_t>& actualNs,
                  double lowWater);

class Adpf {
  public:
    using Clock = Engine::Clock;

    Adpf(AdpfConfig config, Engine* engine);

    int open(int64_t targetNs, Clock::time_point now = Clock::now());
    void setTarget(int id, int64_t targetNs);
    void report(int id, const std::vector<int64_t>& actualNs, Clock::time_point now = Clock::now());
    void setPaused(int id, bool paused, Clock::time_point now = Clock::now());
    void close(int id, Clock::time_point now = Clock::now());

    // Screen off, battery saver or "adpf" in the off list: no floor at all.
    void setSuppressed(bool suppressed, Clock::time_point now = Clock::now());

    int globalLevel() const;
    std::string dump() const;

  private:
    struct Session {
        int64_t targetNs = 0;
        int level = 0;
        bool paused = false;
        Clock::time_point lastReport;
    };

    void recomputeLocked(Clock::time_point now);

    const AdpfConfig mConfig;
    Engine* const mEngine;

    mutable std::mutex mLock;
    std::map<int, Session> mSessions;
    int mNextId = 1;
    bool mSuppressed = false;
    int mApplied = 0;
    std::vector<uint64_t> mLevelHits;  // how often each global level was applied
};

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
