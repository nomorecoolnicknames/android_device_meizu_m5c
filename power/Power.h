/*
 * Copyright (C) 2020 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#pragma once

#include <aidl/android/hardware/power/BnPower.h>

#include <chrono>
#include <condition_variable>
#include <mutex>
#include <thread>

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace m5c {

class Power : public BnPower {
    ndk::ScopedAStatus setMode(Mode type, bool enabled) override;
    ndk::ScopedAStatus isModeSupported(Mode type, bool* _aidl_return) override;
    ndk::ScopedAStatus setBoost(Boost type, int32_t durationMs) override;
    ndk::ScopedAStatus isBoostSupported(Boost type, bool* _aidl_return) override;
    ndk::ScopedAStatus createHintSession(int32_t tgid, int32_t uid,
                                         const std::vector<int32_t>& threadIds,
                                         int64_t durationNanos,
                                         std::shared_ptr<IPowerHintSession>* _aidl_return) override;
    ndk::ScopedAStatus getHintSessionPreferredRate(int64_t* outNanoseconds) override;

  public:
    Power();

  private:
    void interactionHold(int32_t durationMs);
    void releaseLoop();

    std::mutex mLock;
    int32_t mPulseUs = -1;  // last value written to boostpulse_duration
    // Interaction hold of the experiment boosts (HPS cores, GPU floor), see Power.cpp.
    std::condition_variable mCv;
    std::chrono::steady_clock::time_point mHoldUntil;
    int mApplied = 0;  // kBoostHps | kBoostGpu currently written
    std::thread mReleaser;
};

}  // namespace m5c
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
