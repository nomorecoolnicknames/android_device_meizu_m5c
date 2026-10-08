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

#include "Power.h"

#include <algorithm>
#include <string>

#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/properties.h>

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace m5c {

namespace {

// Tunables of the interactive governor (kernel drivers/cpufreq/cpufreq_interactive.c,
// android-4.9 with the update_util hook restored in 9985d21f6).  boostpulse holds the
// CPUs at hispeed_freq (the top OPP, 1248 MHz) for boostpulse_duration microseconds;
// boost holds them there until it is written 0.  With another governor these files
// do not exist and every write is a logged no-op.
constexpr char kInteractive[] = "/sys/devices/system/cpu/cpufreq/interactive/";

// A touch gets this long unless the framework asks for more (it usually passes 0).
constexpr int32_t kDefaultPulseMs = 80;
constexpr int32_t kMaxPulseMs = 1000;


// over budget, ~30 % of it runnable with two CPUs online, GPU at 299 MHz).  Chosen per run by
// debug.vendor.m5c.power_boost (shell can set it), else ro.vendor.m5c.power_boost (vendor.prop),
// as a bit mask; 0 = only the interactive boostpulse above:
//   kBoostHps - keep 4 CPUs online through MTK hotplug (/proc/hps/num_base_perf_serv, default 1);
//   kBoostGpu - fix the GPU at 448.5 MHz (/proc/gpufreq/gpufreq_opp_freq, 0 = back to GED DVFS).
// Both are released kHoldMs after the last interaction, so an idle phone keeps neither.
constexpr int kBoostHps = 1;
constexpr int kBoostGpu = 2;
constexpr char kHpsBase[] = "/proc/hps/num_base_perf_serv";
constexpr char kGpuFix[] = "/proc/gpufreq/gpufreq_opp_freq";
constexpr char kHpsCores[] = "4";
constexpr char kHpsDefault[] = "1";
constexpr char kGpuKhz[] = "448500";
constexpr auto kHoldMs = std::chrono::milliseconds(1000);

int boostMask() {
    int mask = ::android::base::GetIntProperty("debug.vendor.m5c.power_boost", -1);
    if (mask < 0) mask = ::android::base::GetIntProperty("ro.vendor.m5c.power_boost", 0);
    return mask & (kBoostHps | kBoostGpu);
}

bool writeNode(const char* path, const char* value) {
    if (!::android::base::WriteStringToFile(value, path)) {
        PLOG(VERBOSE) << "cannot write " << value << " to " << path;
        return false;
    }
    return true;
}

bool writeTunable(const char* name, const std::string& value) {
    std::string path = std::string(kInteractive) + name;
    if (!::android::base::WriteStringToFile(value, path)) {
        PLOG(VERBOSE) << "cannot write " << value << " to " << path;
        return false;
    }
    return true;
}

}  // namespace

Power::Power() : mReleaser(&Power::releaseLoop, this) {}

// Caller holds mLock.  Applies the boosts the mask asks for and extends the hold.
void Power::interactionHold(int32_t durationMs) {
    int want = boostMask();
    if ((want & kBoostHps) && !(mApplied & kBoostHps) && writeNode(kHpsBase, kHpsCores)) {
        mApplied |= kBoostHps;
    }
    if ((want & kBoostGpu) && !(mApplied & kBoostGpu) && writeNode(kGpuFix, kGpuKhz)) {
        mApplied |= kBoostGpu;
    }
    if (mApplied == 0) return;
    auto until = std::chrono::steady_clock::now() +
                 std::max(kHoldMs, std::chrono::milliseconds(durationMs));
    if (until > mHoldUntil) mHoldUntil = until;
    mCv.notify_all();
}

void Power::releaseLoop() {
    std::unique_lock<std::mutex> lock(mLock);
    for (;;) {
        mCv.wait(lock, [this] { return mApplied != 0; });
        while (mApplied != 0 && std::chrono::steady_clock::now() < mHoldUntil) {
            mCv.wait_until(lock, mHoldUntil);
        }
        if (mApplied & kBoostHps) writeNode(kHpsBase, kHpsDefault);
        if (mApplied & kBoostGpu) writeNode(kGpuFix, "0");
        mApplied = 0;
    }
}

ndk::ScopedAStatus Power::setMode(Mode type, bool enabled) {
    LOG(VERBOSE) << "Power setMode: " << toString(type) << " to: " << enabled;
    if (type == Mode::LAUNCH) {
        writeTunable("boost", enabled ? "1" : "0");
    }
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::isModeSupported(Mode type, bool* _aidl_return) {
    *_aidl_return = type == Mode::LAUNCH;
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::setBoost(Boost type, int32_t durationMs) {
    LOG(VERBOSE) << "Power setBoost: " << toString(type) << ", duration: " << durationMs;
    if (type != Boost::INTERACTION) {
        return ndk::ScopedAStatus::ok();
    }
    int32_t pulseUs = std::clamp(durationMs > 0 ? durationMs : kDefaultPulseMs, 1, kMaxPulseMs) * 1000;
    std::lock_guard<std::mutex> lock(mLock);
    if (pulseUs != mPulseUs && writeTunable("boostpulse_duration", std::to_string(pulseUs))) {
        mPulseUs = pulseUs;
    }
    writeTunable("boostpulse", "1");
    interactionHold(durationMs);
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::isBoostSupported(Boost type, bool* _aidl_return) {
    *_aidl_return = type == Boost::INTERACTION;
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::createHintSession(int32_t, int32_t, const std::vector<int32_t>&, int64_t,
                                            std::shared_ptr<IPowerHintSession>* _aidl_return) {
    *_aidl_return = nullptr;
    return ndk::ScopedAStatus::fromExceptionCode(EX_UNSUPPORTED_OPERATION);
}

ndk::ScopedAStatus Power::getHintSessionPreferredRate(int64_t* outNanoseconds) {
    *outNanoseconds = -1;
    return ndk::ScopedAStatus::fromExceptionCode(EX_UNSUPPORTED_OPERATION);
}

}  // namespace m5c
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
