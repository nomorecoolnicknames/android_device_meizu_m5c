#include "Power.h"

#include <unistd.h>

#include <algorithm>
#include <sstream>

#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/properties.h>
#include <android-base/strings.h>

#include "HintSession.h"

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

namespace {

using Clock = Engine::Clock;

// Comma-separated sources (interaction, fling, launch, adpf) and node names
// that stay off, read on every call. debug.vendor.* overrides the ro.vendor.*
// default from vendor.prop; "none" clears the default.
std::set<std::string> OffList() {
    std::string v = ::android::base::GetProperty("debug.vendor.power.fleet.off", "");
    if (v.empty()) v = ::android::base::GetProperty("ro.vendor.power.fleet.off", "");
    std::set<std::string> off;
    if (v == "none") return off;
    for (auto& s : ::android::base::Split(v, ",")) {
        s = ::android::base::Trim(s);
        if (!s.empty()) off.insert(s);
    }
    return off;
}

ValueMap Without(const ValueMap& set, const std::set<std::string>& off) {
    ValueMap out;
    for (const auto& [node, value] : set) {
        if (!off.count(node)) out[node] = value;
    }
    return out;
}

}  // namespace

Power::Power(Config config, std::shared_ptr<Engine> engine)
    : mConfig(std::move(config)),
      mEngine(std::move(engine)),
      mAdpf(std::make_shared<Adpf>(mConfig.adpf, mEngine.get())) {}

ndk::ScopedAStatus Power::setMode(Mode type, bool enabled) {
    LOG(VERBOSE) << "setMode " << toString(type) << " " << enabled;
    if (!mConfig.modes.count(toString(type))) return ndk::ScopedAStatus::ok();
    std::lock_guard<std::mutex> lock(mLock);
    switch (type) {
        case Mode::LAUNCH: {
            auto it = mConfig.requests.find("launch");
            if (it == mConfig.requests.end()) break;
            std::set<std::string> off = OffList();
            if (!enabled || mScreenOff || off.count("launch")) {
                mEngine->clearRequest("launch");
                break;
            }
            const RequestConfig& rc = it->second;
            for (const auto& p : rc.pulse) {
                if (!off.count(p)) mEngine->pulse(p, std::min(rc.pulseMs, rc.pulseMaxMs));
            }
            // MaxMs: a lost LAUNCH=false must not hold the floor.
            Clock::time_point now = Clock::now();
            mEngine->setRequest("launch", Without(rc.set, off),
                                now + std::chrono::milliseconds(rc.maxMs), false, now);
            break;
        }
        case Mode::INTERACTIVE:
        case Mode::DISPLAY_INACTIVE:
            mScreenOff = (type == Mode::INTERACTIVE) ? !enabled : enabled;
            if (mScreenOff) mEngine->clearAll();
            updateAdpfSuppression();
            break;
        case Mode::LOW_POWER:
            mLowPower = enabled;
            if (mLowPower) {
                mEngine->clearRequest("interaction");
                mEngine->clearRequest("fling");
            }
            updateAdpfSuppression();
            break;
        default:
            break;
    }
    return ndk::ScopedAStatus::ok();
}

void Power::updateAdpfSuppression() {
    mAdpf->setSuppressed(mScreenOff || mLowPower);
}

ndk::ScopedAStatus Power::isModeSupported(Mode type, bool* _aidl_return) {
    *_aidl_return = mConfig.modes.count(toString(type)) != 0;
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::setBoost(Boost type, int32_t durationMs) {
    LOG(VERBOSE) << "setBoost " << toString(type) << " " << durationMs;
    if (type != Boost::INTERACTION || !mConfig.boosts.count(toString(type))) {
        return ndk::ScopedAStatus::ok();
    }
    std::lock_guard<std::mutex> lock(mLock);
    if (mScreenOff || mLowPower) return ndk::ScopedAStatus::ok();

    // A fling (duration > 0) uses its own request when the device has one,
    // otherwise it is an interaction held at least that long.
    const bool fling = durationMs > 0 && mConfig.requests.count("fling");
    const std::string source = fling ? "fling" : "interaction";
    auto it = mConfig.requests.find(source);
    std::set<std::string> off = OffList();
    if (it == mConfig.requests.end() || off.count(source)) return ndk::ScopedAStatus::ok();
    const RequestConfig& rc = it->second;
    if (durationMs <= 0 && rc.ignoreZeroDuration) return ndk::ScopedAStatus::ok();

    if (!rc.pulse.empty()) {
        int32_t pulseMs = std::clamp(durationMs > 0 ? durationMs : rc.pulseMs, 1, rc.pulseMaxMs);
        for (const auto& p : rc.pulse) {
            if (!off.count(p)) mEngine->pulse(p, pulseMs);
        }
    }
    ValueMap set = Without(rc.set, off);
    if (!set.empty()) {
        int32_t holdMs = fling ? std::max(durationMs, rc.flingMinMs)
                               : std::max(rc.holdMs, durationMs);
        Clock::time_point now = Clock::now();
        // extend: a short touch right after a long fling keeps the fling's end.
        mEngine->setRequest(source, set, now + std::chrono::milliseconds(holdMs), true, now);
    }
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::isBoostSupported(Boost type, bool* _aidl_return) {
    *_aidl_return = mConfig.boosts.count(toString(type)) != 0;
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::createHintSession(int32_t, int32_t, const std::vector<int32_t>&,
                                            int64_t durationNanos,
                                            std::shared_ptr<IPowerHintSession>* _aidl_return) {
    if (!mConfig.adpf.enabled) {
        *_aidl_return = nullptr;
        return ndk::ScopedAStatus::fromExceptionCode(EX_UNSUPPORTED_OPERATION);
    }
    *_aidl_return = ndk::SharedRefBase::make<HintSession>(mAdpf, durationNanos);
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::getHintSessionPreferredRate(int64_t* outNanoseconds) {
    // -1 tells HintManagerService that sessions are unsupported (it then never
    // calls createHintSession).
    if (!mConfig.adpf.enabled) {
        *outNanoseconds = -1;
        return ndk::ScopedAStatus::fromExceptionCode(EX_UNSUPPORTED_OPERATION);
    }
    *outNanoseconds = mConfig.adpf.reportRateMs * 1000000;
    return ndk::ScopedAStatus::ok();
}

binder_status_t Power::dump(int fd, const char**, uint32_t) {
    std::ostringstream out;
    {
        std::lock_guard<std::mutex> lock(mLock);
        std::set<std::string> off = OffList();
        out << "fleet Power HAL: screen " << (mScreenOff ? "off" : "on") << ", low power "
            << mLowPower << ", off list '" << ::android::base::Join(off, ",") << "'\n";
    }
    out << mEngine->dump() << mAdpf->dump();
    std::string s = out.str();
    if (!::android::base::WriteStringToFd(s, fd)) return STATUS_UNKNOWN_ERROR;
    fsync(fd);
    return STATUS_OK;
}

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
