/*
 * Device configuration of the Power HAL: /vendor/etc/power/fleet_power.json.
 */
#pragma once

#include <cstdint>
#include <map>
#include <set>
#include <string>
#include <vector>

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

// Node name -> value token.  Tokens of the floor nodes: kHz, "max" (the live
// ceiling) or "pct:NN" (NN % of the live ceiling); of value nodes: the string
// to write.
using ValueMap = std::map<std::string, std::string>;

struct NodeConfig {
    enum class Type {
        CpufreqFloor,  // <Policy>/scaling_min_freq, clamped to <Policy>/scaling_max_freq
        PpmFloor,      // MTK PPM user limit: "<Cluster> <kHz>", released with "<Cluster> -1"
        Value,         // a string, aggregated by Aggregate, Default when nothing asks
        Pulse,         // write "1", after DurationPath (us) when the duration changed
    };
    enum class Aggregate { MaxInt, MaxFields };
    // What a node holds when no request asks for it:
    //   Default - defaultValue (written at start too);
    //   None    - nothing is written (e.g. cpuN/online: hps takes cores down itself);
    //   Capture - the value read just before the first write of a hold is put
    //             back (e.g. /proc/hps/enabled, which a boot script may have
    //             turned off for good).
    enum class Release { Default, None, Capture };

    std::string name;
    Type type = Type::Value;
    std::string path;          // the node written
    std::string maxPath;       // live ceiling for "max"/"pct:" (floor nodes)
    std::string minInfoPath;   // released value of a cpufreq floor (cpuinfo_min_freq)
    std::string durationPath;  // pulse duration, microseconds
    int cluster = -1;          // PPM cluster id
    std::string defaultValue;  // Value nodes
    Aggregate aggregate = Aggregate::MaxInt;
    Release release = Release::Default;
    int order = 0;  // nodes are written in (order, name) order
};

struct RequestConfig {
    int32_t holdMs = 0;      // interaction: hold after the LAST call
    int32_t pulseMs = 0;     // pulse length when the framework passes 0
    int32_t pulseMaxMs = 1000;
    int32_t flingMinMs = 0;  // fling: hold at least this long
    int32_t maxMs = 0;       // launch: safety cap if LAUNCH=false never comes
    bool ignoreZeroDuration = false;
    std::vector<std::string> pulse;
    ValueMap set;
};

struct AdpfConfig {
    bool enabled = false;
    int64_t reportRateMs = 100;
    int64_t staleMs = 150;
    double lowWater = 0.8;
    std::vector<ValueMap> levels;  // level L (1..N) applies levels[L - 1]
};

struct Config {
    std::vector<NodeConfig> nodes;
    std::map<std::string, RequestConfig> requests;  // interaction, fling, launch
    AdpfConfig adpf;
    std::set<std::string> boosts;  // aidl Boost names, e.g. "INTERACTION"
    std::set<std::string> modes;   // aidl Mode names, e.g. "LAUNCH"
};

// Parses and validates (every referenced node exists and has the right type).
bool ParseConfig(const std::string& json, Config* out, std::string* error);
bool LoadConfig(const std::string& path, Config* out, std::string* error);

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
