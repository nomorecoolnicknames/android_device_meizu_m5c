/*
 * Copyright (C) 2018 The Android Open Source Project
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

#define LOG_TAG "android.hardware.thermal@2.0-service.m5c"

#include <algorithm>
#include <chrono>
#include <cmath>

#include <unistd.h>

#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/parseint.h>
#include <android-base/strings.h>
#include <hidl/HidlTransportSupport.h>

#include "Thermal.h"

namespace android {
namespace hardware {
namespace thermal {
namespace V2_0 {
namespace implementation {

using ::android::sp;
using ::android::base::ReadFileToString;
using ::android::base::Trim;
using ::android::hardware::interfacesEqual;
using ::android::hardware::thermal::V1_0::ThermalStatus;
using ::android::hardware::thermal::V1_0::ThermalStatusCode;

namespace {

constexpr int kSeverities = 7;  // ThrottlingSeverity NONE .. SHUTDOWN
constexpr auto kPollInterval = std::chrono::seconds(5);

// Hot thresholds come from the stock Flyme thermal policy (vendor .tp/thermal.conf,

// 100 C, system reset at 117 C; tzbattery - reset at 60 C; tzbts (mtktsAP, the board
// thermistor) - charging current limit from 45 C, reset at 95 C.  The reset trips are
// reported as EMERGENCY, never as SHUTDOWN: the kernel thermal driver resets the phone
// itself there, and a false reading must not make the framework power Android off.
const std::vector<Sensor> kSensors = {
        {"mtktscpu", "cpu", TemperatureType::CPU, {NAN, NAN, NAN, 85.0, 100.0, NAN, NAN},
         "", ThrottlingSeverity::NONE},
        {"mtktsbattery", "battery", TemperatureType::BATTERY, {NAN, NAN, NAN, NAN, NAN, 60.0, NAN},
         "", ThrottlingSeverity::NONE},
        {"mtktsAP", "skin", TemperatureType::SKIN, {NAN, NAN, 45.0, NAN, NAN, 95.0, NAN},
         "", ThrottlingSeverity::NONE},
};

ThrottlingSeverity severityOf(const Sensor& sensor, float celsius) {
    for (int i = kSeverities - 1; i > 0; --i) {
        if (!std::isnan(sensor.hot[i]) && celsius >= sensor.hot[i]) {
            return static_cast<ThrottlingSeverity>(i);
        }
    }
    return ThrottlingSeverity::NONE;
}

float firstHot(const Sensor& sensor) {
    for (int i = 1; i < kSeverities; ++i) {
        if (!std::isnan(sensor.hot[i])) return sensor.hot[i];
    }
    return NAN;
}

}  // namespace

// Caller holds sensors_mutex_.  Some zones appear only after the HAL started: the MTK
// driver registers mtktsAP (tzbts) when thermal_manager loads the policy

void Thermal::resolveZones(bool logMissing) {
    for (int zone = 0; zone < 32; ++zone) {
        std::string dir = "/sys/class/thermal/thermal_zone" + std::to_string(zone) + "/";
        std::string type;
        if (!ReadFileToString(dir + "type", &type)) continue;
        type = Trim(type);
        for (Sensor& sensor : sensors_) {
            if (sensor.tempPath.empty() && type == sensor.zoneType) {
                sensor.tempPath = dir + "temp";
                LOG(INFO) << sensor.name << " <- " << dir << " (" << type << ")";
            }
        }
    }
    if (!logMissing) return;
    for (const Sensor& sensor : sensors_) {
        if (sensor.tempPath.empty()) LOG(WARNING) << "no thermal zone " << sensor.zoneType << " yet";
    }
}

Thermal::Thermal() : sensors_(kSensors) {
    resolveZones(true);
    poller_ = std::thread(&Thermal::pollLoop, this);
}

// Millidegrees; the MTK zones without a sensor read -127000 (mtktspa on this board).
bool Thermal::readSensor(const Sensor& sensor, float* celsius) {
    std::string text;
    int milli;
    if (sensor.tempPath.empty() || !ReadFileToString(sensor.tempPath, &text) ||
        !::android::base::ParseInt(Trim(text), &milli) || milli < -40000 || milli > 200000) {
        return false;
    }
    *celsius = milli / 1000.0f;
    return true;
}

void Thermal::pollLoop() {
    for (;;) {
        std::vector<Temperature_2_0> changed;
        {
            std::lock_guard<std::mutex> _lock(sensors_mutex_);
            if (std::any_of(sensors_.begin(), sensors_.end(),
                            [](const Sensor& s) { return s.tempPath.empty(); })) {
                resolveZones(false);
            }
            for (Sensor& sensor : sensors_) {
                float celsius;
                if (!readSensor(sensor, &celsius)) continue;
                ThrottlingSeverity severity = severityOf(sensor, celsius);
                if (severity != sensor.lastSeverity) {
                    LOG(INFO) << sensor.name << " " << celsius << " C: "
                              << toString(sensor.lastSeverity) << " -> " << toString(severity);
                    sensor.lastSeverity = severity;
                    changed.push_back({sensor.type, sensor.name, celsius, severity});
                }
            }
        }
        if (!changed.empty()) {
            std::vector<CallbackSetting> callbacks;
            {
                std::lock_guard<std::mutex> _lock(thermal_callback_mutex_);
                callbacks = callbacks_;
            }
            for (const Temperature_2_0& t : changed) {
                for (const CallbackSetting& c : callbacks) {
                    if (c.is_filter_type && c.type != t.type) continue;
                    if (!c.callback->notifyThrottling(t).isOk()) {
                        LOG(ERROR) << "notifyThrottling failed for " << t.name;
                    }
                }
            }
        }
        std::this_thread::sleep_for(kPollInterval);
    }
}

// Methods from ::android::hardware::thermal::V1_0::IThermal follow.
Return<void> Thermal::getTemperatures(getTemperatures_cb _hidl_cb) {
    ThermalStatus status;
    status.code = ThermalStatusCode::SUCCESS;
    std::vector<Temperature_1_0> temperatures;
    std::lock_guard<std::mutex> _lock(sensors_mutex_);
    for (const Sensor& sensor : sensors_) {
        float celsius;
        if (!readSensor(sensor, &celsius)) continue;
        temperatures.push_back({
                .type = static_cast<::android::hardware::thermal::V1_0::TemperatureType>(
                        sensor.type),
                .name = sensor.name,
                .currentValue = celsius,
                .throttlingThreshold = firstHot(sensor),
                .shutdownThreshold = NAN,
                .vrThrottlingThreshold = NAN,
        });
    }
    _hidl_cb(status, temperatures);
    return Void();
}

// /proc/stat lines of the online CPUs; offline ones are reported with zero counters.
Return<void> Thermal::getCpuUsages(getCpuUsages_cb _hidl_cb) {
    ThermalStatus status;
    status.code = ThermalStatusCode::SUCCESS;
    std::vector<CpuUsage> cpu_usages;
    std::string stat;
    if (!ReadFileToString("/proc/stat", &stat)) {
        status.code = ThermalStatusCode::FAILURE;
        status.debugMessage = "Failed to read /proc/stat";
        _hidl_cb(status, cpu_usages);
        return Void();
    }
    std::vector<std::string> lines = ::android::base::Split(stat, "\n");
    for (int cpu = 0; cpu < 16; ++cpu) {
        std::string dir = "/sys/devices/system/cpu/cpu" + std::to_string(cpu);
        std::string online = "1";
        if (access(dir.c_str(), F_OK) != 0) break;
        if (cpu > 0) ReadFileToString(dir + "/online", &online);
        CpuUsage usage = {.name = "cpu" + std::to_string(cpu), .active = 0, .total = 0,
                          .isOnline = Trim(online) == "1"};
        std::string prefix = "cpu" + std::to_string(cpu) + " ";
        for (const std::string& line : lines) {
            if (!::android::base::StartsWith(line, prefix)) continue;
            std::vector<std::string> f = ::android::base::Split(Trim(line), " ");
            uint64_t v[7] = {};
            for (int i = 0; i < 7 && i + 1 < static_cast<int>(f.size()); ++i) {
                ::android::base::ParseUint(f[i + 1], &v[i]);
            }
            // user nice system idle iowait irq softirq
            usage.active = v[0] + v[1] + v[2] + v[5] + v[6];
            usage.total = usage.active + v[3] + v[4];
            break;
        }
        cpu_usages.push_back(usage);
    }
    _hidl_cb(status, cpu_usages);
    return Void();
}

// The MTK coolers are policy objects of thermal_manager, not devices with a state the
// framework could use; none is reported.
Return<void> Thermal::getCoolingDevices(getCoolingDevices_cb _hidl_cb) {
    ThermalStatus status;
    status.code = ThermalStatusCode::SUCCESS;
    _hidl_cb(status, {});
    return Void();
}

// Methods from ::android::hardware::thermal::V2_0::IThermal follow.
Return<void> Thermal::getCurrentTemperatures(bool filterType, TemperatureType type,
                                             getCurrentTemperatures_cb _hidl_cb) {
    ThermalStatus status;
    status.code = ThermalStatusCode::SUCCESS;
    std::vector<Temperature_2_0> temperatures;
    std::lock_guard<std::mutex> _lock(sensors_mutex_);
    for (const Sensor& sensor : sensors_) {
        float celsius;
        if (filterType && sensor.type != type) continue;
        if (!readSensor(sensor, &celsius)) continue;
        temperatures.push_back({sensor.type, sensor.name, celsius, severityOf(sensor, celsius)});
    }
    _hidl_cb(status, temperatures);
    return Void();
}

Return<void> Thermal::getTemperatureThresholds(bool filterType, TemperatureType type,
                                               getTemperatureThresholds_cb _hidl_cb) {
    ThermalStatus status;
    status.code = ThermalStatusCode::SUCCESS;
    std::vector<TemperatureThreshold> temperature_thresholds;
    std::lock_guard<std::mutex> _lock(sensors_mutex_);
    for (const Sensor& sensor : sensors_) {
        if (filterType && sensor.type != type) continue;
        if (sensor.tempPath.empty()) continue;
        TemperatureThreshold threshold = {
                .type = sensor.type,
                .name = sensor.name,
                .hotThrottlingThresholds = {{NAN, NAN, NAN, NAN, NAN, NAN, NAN}},
                .coldThrottlingThresholds = {{NAN, NAN, NAN, NAN, NAN, NAN, NAN}},
                .vrThrottlingThreshold = NAN,
        };
        for (int i = 0; i < kSeverities; ++i) threshold.hotThrottlingThresholds[i] = sensor.hot[i];
        temperature_thresholds.push_back(threshold);
    }
    _hidl_cb(status, temperature_thresholds);
    return Void();
}

Return<void> Thermal::getCurrentCoolingDevices(bool /* filterType */, CoolingType /* type */,
                                               getCurrentCoolingDevices_cb _hidl_cb) {
    ThermalStatus status;
    status.code = ThermalStatusCode::SUCCESS;
    _hidl_cb(status, {});
    return Void();
}

Return<void> Thermal::registerThermalChangedCallback(const sp<IThermalChangedCallback>& callback,
                                                     bool filterType, TemperatureType type,
                                                     registerThermalChangedCallback_cb _hidl_cb) {
    ThermalStatus status;
    if (callback == nullptr) {
        status.code = ThermalStatusCode::FAILURE;
        status.debugMessage = "Invalid nullptr callback";
        LOG(ERROR) << status.debugMessage;
        _hidl_cb(status);
        return Void();
    } else {
        status.code = ThermalStatusCode::SUCCESS;
    }
    std::lock_guard<std::mutex> _lock(thermal_callback_mutex_);
    if (std::any_of(callbacks_.begin(), callbacks_.end(), [&](const CallbackSetting& c) {
            return interfacesEqual(c.callback, callback);
        })) {
        status.code = ThermalStatusCode::FAILURE;
        status.debugMessage = "Same callback interface registered already";
        LOG(ERROR) << status.debugMessage;
    } else {
        callbacks_.emplace_back(callback, filterType, type);
        LOG(INFO) << "A callback has been registered to ThermalHAL, isFilter: " << filterType
                  << " Type: " << android::hardware::thermal::V2_0::toString(type);
    }
    _hidl_cb(status);
    return Void();
}

Return<void> Thermal::unregisterThermalChangedCallback(
    const sp<IThermalChangedCallback>& callback, unregisterThermalChangedCallback_cb _hidl_cb) {
    ThermalStatus status;
    if (callback == nullptr) {
        status.code = ThermalStatusCode::FAILURE;
        status.debugMessage = "Invalid nullptr callback";
        LOG(ERROR) << status.debugMessage;
        _hidl_cb(status);
        return Void();
    } else {
        status.code = ThermalStatusCode::SUCCESS;
    }
    bool removed = false;
    std::lock_guard<std::mutex> _lock(thermal_callback_mutex_);
    callbacks_.erase(
        std::remove_if(callbacks_.begin(), callbacks_.end(),
                       [&](const CallbackSetting& c) {
                           if (interfacesEqual(c.callback, callback)) {
                               LOG(INFO)
                                   << "A callback has been unregistered from ThermalHAL, isFilter: "
                                   << c.is_filter_type << " Type: "
                                   << android::hardware::thermal::V2_0::toString(c.type);
                               removed = true;
                               return true;
                           }
                           return false;
                       }),
        callbacks_.end());
    if (!removed) {
        status.code = ThermalStatusCode::FAILURE;
        status.debugMessage = "The callback was not registered before";
        LOG(ERROR) << status.debugMessage;
    }
    _hidl_cb(status);
    return Void();
}

}  // namespace implementation
}  // namespace V2_0
}  // namespace thermal
}  // namespace hardware
}  // namespace android
