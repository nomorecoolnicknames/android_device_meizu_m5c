#include "HintSession.h"

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

HintSession::HintSession(std::shared_ptr<Adpf> adpf, int64_t targetNs)
    : mAdpf(std::move(adpf)), mId(mAdpf->open(targetNs)) {}

HintSession::~HintSession() {
    close();
}

ndk::ScopedAStatus HintSession::updateTargetWorkDuration(int64_t targetDurationNanos) {
    mAdpf->setTarget(mId, targetDurationNanos);
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus HintSession::reportActualWorkDuration(
        const std::vector<WorkDuration>& actualDurations) {
    std::vector<int64_t> ns;
    ns.reserve(actualDurations.size());
    for (const auto& d : actualDurations) ns.push_back(d.durationNanos);
    mAdpf->report(mId, ns);
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus HintSession::pause() {
    mAdpf->setPaused(mId, true);
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus HintSession::resume() {
    mAdpf->setPaused(mId, false);
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus HintSession::close() {
    if (!mClosed.exchange(true)) mAdpf->close(mId);
    return ndk::ScopedAStatus::ok();
}

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
