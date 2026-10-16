/*
 * IPowerHintSession of the fleet Power HAL: a thin handle on one Adpf
 * session (Adpf.h holds the logic, so the host test covers it).
 */
#pragma once

#include <aidl/android/hardware/power/BnPowerHintSession.h>
#include <aidl/android/hardware/power/WorkDuration.h>

#include <atomic>
#include <memory>
#include <vector>

#include "Adpf.h"

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

class HintSession : public BnPowerHintSession {
  public:
    HintSession(std::shared_ptr<Adpf> adpf, int64_t targetNs);
    ~HintSession();

    ndk::ScopedAStatus updateTargetWorkDuration(int64_t targetDurationNanos) override;
    ndk::ScopedAStatus reportActualWorkDuration(
            const std::vector<WorkDuration>& actualDurations) override;
    ndk::ScopedAStatus pause() override;
    ndk::ScopedAStatus resume() override;
    ndk::ScopedAStatus close() override;

  private:
    const std::shared_ptr<Adpf> mAdpf;
    const int mId;
    std::atomic<bool> mClosed{false};
};

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
