#include "Adpf.h"

#include <algorithm>
#include <sstream>

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

int AdpfNextLevel(int level, int maxLevel, int64_t targetNs, const std::vector<int64_t>& actualNs,
                  double lowWater) {
    if (targetNs <= 0 || actualNs.empty()) return level;
    bool over = false;
    bool severe = false;
    bool allLow = true;
    for (int64_t a : actualNs) {
        if (a > targetNs) over = true;
        if (2 * a > 3 * targetNs) severe = true;
        if (static_cast<double>(a) >= lowWater * static_cast<double>(targetNs)) allLow = false;
    }
    if (severe) {
        level += 2;
    } else if (over) {
        level += 1;
    } else if (allLow) {
        level -= 1;
    }
    return std::clamp(level, 0, maxLevel);
}

Adpf::Adpf(AdpfConfig config, Engine* engine)
    : mConfig(std::move(config)), mEngine(engine), mLevelHits(mConfig.levels.size() + 1, 0) {}

int Adpf::open(int64_t targetNs, Clock::time_point now) {
    std::lock_guard<std::mutex> lock(mLock);
    int id = mNextId++;
    Session s;
    s.targetNs = targetNs;
    s.lastReport = now;
    mSessions[id] = s;
    return id;
}

void Adpf::setTarget(int id, int64_t targetNs) {
    std::lock_guard<std::mutex> lock(mLock);
    auto it = mSessions.find(id);
    if (it != mSessions.end() && targetNs > 0) it->second.targetNs = targetNs;
}

void Adpf::report(int id, const std::vector<int64_t>& actualNs, Clock::time_point now) {
    std::lock_guard<std::mutex> lock(mLock);
    auto it = mSessions.find(id);
    if (it == mSessions.end()) return;
    Session& s = it->second;
    // A session that was quiet longer than the floor lives starts from zero:
    // its old level described frames that are long gone.
    if (now - s.lastReport > std::chrono::milliseconds(mConfig.staleMs)) s.level = 0;
    s.lastReport = now;
    s.level = AdpfNextLevel(s.level, static_cast<int>(mConfig.levels.size()), s.targetNs, actualNs,
                            mConfig.lowWater);
    recomputeLocked(now);
}

void Adpf::setPaused(int id, bool paused, Clock::time_point now) {
    std::lock_guard<std::mutex> lock(mLock);
    auto it = mSessions.find(id);
    if (it == mSessions.end()) return;
    it->second.paused = paused;
    if (paused) it->second.level = 0;
    recomputeLocked(now);
}

void Adpf::close(int id, Clock::time_point now) {
    std::lock_guard<std::mutex> lock(mLock);
    if (mSessions.erase(id) == 0) return;
    recomputeLocked(now);
}

void Adpf::setSuppressed(bool suppressed, Clock::time_point now) {
    std::lock_guard<std::mutex> lock(mLock);
    mSuppressed = suppressed;
    recomputeLocked(now);
}

int Adpf::globalLevel() const {
    std::lock_guard<std::mutex> lock(mLock);
    return mApplied;
}

void Adpf::recomputeLocked(Clock::time_point now) {
    int level = 0;
    if (!mSuppressed) {
        for (const auto& [id, s] : mSessions) {
            if (!s.paused) level = std::max(level, s.level);
        }
    }
    if (level == 0) {
        if (mApplied != 0) mEngine->clearRequest("adpf", now);
    } else {
        // Re-armed on every report: the deadline is what drops a floor
        // nobody reports against any more.
        mEngine->setRequest("adpf", mConfig.levels[level - 1],
                            now + std::chrono::milliseconds(mConfig.staleMs), false, now);
    }
    if (level != mApplied) mLevelHits[level]++;
    mApplied = level;
}

std::string Adpf::dump() const {
    std::lock_guard<std::mutex> lock(mLock);
    std::ostringstream out;
    out << "ADPF: " << (mConfig.enabled ? "enabled" : "disabled") << ", sessions "
        << mSessions.size() << ", level " << mApplied << (mSuppressed ? " (suppressed)" : "")
        << "\n  level entries:";
    for (size_t i = 0; i < mLevelHits.size(); ++i) out << " L" << i << "=" << mLevelHits[i];
    out << "\n";
    for (const auto& [id, s] : mSessions) {
        out << "  session " << id << ": target " << s.targetNs / 1000 << " us, level " << s.level
            << (s.paused ? " paused" : "") << "\n";
    }
    return out.str();
}

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
