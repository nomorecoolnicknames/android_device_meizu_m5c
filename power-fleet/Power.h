/*
 * Power HAL (AIDL V3) shared by the Meizu MediaTek device trees.
 */
#pragma once

#include <aidl/android/hardware/power/BnPower.h>

#include <memory>
#include <mutex>
#include <set>
#include <string>

#include "Adpf.h"
#include "Config.h"
#include "Engine.h"

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

class Power : public BnPower {
  public:
    Power(Config config, std::shared_ptr<Engine> engine);

    ndk::ScopedAStatus setMode(Mode type, bool enabled) override;
    ndk::ScopedAStatus isModeSupported(Mode type, bool* _aidl_return) override;
    ndk::ScopedAStatus setBoost(Boost type, int32_t durationMs) override;
    ndk::ScopedAStatus isBoostSupported(Boost type, bool* _aidl_return) override;
    ndk::ScopedAStatus createHintSession(int32_t tgid, int32_t uid,
                                         const std::vector<int32_t>& threadIds,
                                         int64_t durationNanos,
                                         std::shared_ptr<IPowerHintSession>* _aidl_return) override;
    ndk::ScopedAStatus getHintSessionPreferredRate(int64_t* outNanoseconds) override;
    binder_status_t dump(int fd, const char** args, uint32_t numArgs) override;

  private:
    void updateAdpfSuppression();

    const Config mConfig;
    const std::shared_ptr<Engine> mEngine;
    const std::shared_ptr<Adpf> mAdpf;

    std::mutex mLock;
    bool mScreenOff = false;
    bool mLowPower = false;
};

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
