/*
 * Fleet Power HAL service.  The device's nodes and requests come from
 * /vendor/etc/power/fleet_power.json; a missing or broken file leaves a HAL
 * that supports nothing, so the framework sends it nothing (the same as the
 * no-op HIDL HALs this replaces) instead of a crash loop.
 *
 * argv[1], if given, replaces the config path (for testing another json by
 * hand). The binary must run from /vendor/bin/hw to link and register.
 */
#include "Power.h"

#include <android-base/logging.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

using aidl::android::hardware::power::impl::meizu::Config;
using aidl::android::hardware::power::impl::meizu::Engine;
using aidl::android::hardware::power::impl::meizu::LoadConfig;
using aidl::android::hardware::power::impl::meizu::Power;

namespace {
constexpr char kConfigPath[] = "/vendor/etc/power/fleet_power.json";
}

int main(int argc, char** argv) {
    const char* path = argc > 1 ? argv[1] : kConfigPath;
    Config config;
    std::string error;
    if (!LoadConfig(path, &config, &error)) {
        LOG(ERROR) << path << ": " << error << " - running with nothing supported";
        config = Config();
    }

    auto engine = std::make_shared<Engine>(config.nodes);
    engine->reset();
    engine->start();

    ABinderProcess_setThreadPoolMaxThreadCount(0);
    std::shared_ptr<Power> power = ndk::SharedRefBase::make<Power>(config, engine);

    const std::string instance = std::string() + Power::descriptor + "/default";
    binder_status_t status = AServiceManager_addService(power->asBinder().get(), instance.c_str());
    CHECK_EQ(status, STATUS_OK);

    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;  // should not reach
}
