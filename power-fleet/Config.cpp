#include "Config.h"

#include <fstream>
#include <sstream>

#include <json/reader.h>
#include <json/value.h>

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

namespace {

bool Fail(std::string* error, const std::string& what) {
    if (error) *error = what;
    return false;
}

ValueMap ParseValueMap(const Json::Value& v) {
    ValueMap out;
    if (!v.isObject()) return out;
    for (const auto& key : v.getMemberNames()) out[key] = v[key].asString();
    return out;
}

std::set<std::string> ParseNames(const Json::Value& v) {
    std::set<std::string> out;
    if (!v.isArray()) return out;
    for (const auto& name : v) out.insert(name.asString());
    return out;
}

bool ParseNode(const std::string& name, const Json::Value& v, NodeConfig* node,
               std::string* error) {
    node->name = name;
    const std::string type = v["Type"].asString();
    if (type == "cpufreq_floor") {
        const std::string policy = v["Policy"].asString();
        if (policy.empty()) return Fail(error, "node " + name + ": cpufreq_floor needs Policy");
        node->type = NodeConfig::Type::CpufreqFloor;
        node->path = policy + "/scaling_min_freq";
        node->maxPath = policy + "/scaling_max_freq";
        node->minInfoPath = policy + "/cpuinfo_min_freq";
    } else if (type == "ppm_floor") {
        if (!v["Cluster"].isInt()) return Fail(error, "node " + name + ": ppm_floor needs Cluster");
        node->type = NodeConfig::Type::PpmFloor;
        node->path = v.get("Path", "/proc/ppm/policy/userlimit_min_cpu_freq").asString();
        node->maxPath = v["MaxPath"].asString();
        node->cluster = v["Cluster"].asInt();
    } else if (type == "value") {
        node->type = NodeConfig::Type::Value;
        node->path = v["Path"].asString();
        node->defaultValue = v["Default"].asString();
        const std::string aggregate = v.get("Aggregate", "max_int").asString();
        if (aggregate == "max_int") {
            node->aggregate = NodeConfig::Aggregate::MaxInt;
        } else if (aggregate == "max_fields") {
            node->aggregate = NodeConfig::Aggregate::MaxFields;
        } else {
            return Fail(error, "node " + name + ": unknown Aggregate " + aggregate);
        }
    } else if (type == "pulse") {
        node->type = NodeConfig::Type::Pulse;
        node->path = v["Path"].asString();
        node->durationPath = v["DurationPath"].asString();
    } else {
        return Fail(error, "node " + name + ": unknown Type '" + type + "'");
    }
    if (node->path.empty()) return Fail(error, "node " + name + ": no path");
    node->order = v.get("Order", 0).asInt();
    const std::string release = v.get("Release", "default").asString();
    if (release == "default") {
        node->release = NodeConfig::Release::Default;
    } else if (release == "none") {
        node->release = NodeConfig::Release::None;
    } else if (release == "capture") {
        node->release = NodeConfig::Release::Capture;
    } else {
        return Fail(error, "node " + name + ": unknown Release " + release);
    }
    if (node->release != NodeConfig::Release::Default && node->type != NodeConfig::Type::Value) {
        return Fail(error, "node " + name + ": Release none/capture is for value nodes");
    }
    return true;
}

// Every name in `set` must be a non-pulse node.
bool CheckSet(const std::map<std::string, NodeConfig::Type>& types, const ValueMap& set,
              const std::string& where, std::string* error) {
    for (const auto& [node, value] : set) {
        auto it = types.find(node);
        if (it == types.end()) return Fail(error, where + ": unknown node " + node);
        if (it->second == NodeConfig::Type::Pulse) {
            return Fail(error, where + ": pulse node " + node + " in Set");
        }
    }
    return true;
}

}  // namespace

bool ParseConfig(const std::string& json, Config* out, std::string* error) {
    Json::Value root;
#ifdef JSONCPP_VERSION_STRING  // jsoncpp 1.x (A13 trees)
    Json::CharReaderBuilder builder;
    std::string errs;
    std::istringstream in(json);
    if (!Json::parseFromStream(builder, in, &root, &errs)) return Fail(error, "json: " + errs);
#else  // jsoncpp 0.x (Android 9): no CharReaderBuilder yet
    Json::Reader reader;
    if (!reader.parse(json, root, false)) {
        return Fail(error, "json: " + reader.getFormattedErrorMessages());
    }
#endif
    if (!root.isObject()) return Fail(error, "json: root is not an object");

    Config config;
    std::map<std::string, NodeConfig::Type> types;
    const Json::Value& nodes = root["Nodes"];
    for (const auto& name : nodes.getMemberNames()) {
        NodeConfig node;
        if (!ParseNode(name, nodes[name], &node, error)) return false;
        types[name] = node.type;
        config.nodes.push_back(node);
    }

    const Json::Value& requests = root["Requests"];
    for (const auto& source : requests.getMemberNames()) {
        if (source != "interaction" && source != "fling" && source != "launch") {
            return Fail(error, "unknown request " + source);
        }
        const Json::Value& r = requests[source];
        RequestConfig rc;
        rc.holdMs = r.get("HoldMs", 0).asInt();
        rc.pulseMs = r.get("PulseMs", 0).asInt();
        rc.pulseMaxMs = r.get("PulseMaxMs", 1000).asInt();
        rc.flingMinMs = r.get("FlingMinMs", 0).asInt();
        rc.maxMs = r.get("MaxMs", 0).asInt();
        rc.ignoreZeroDuration = r.get("IgnoreZeroDuration", false).asBool();
        for (const auto& p : r["Pulse"]) {
            const std::string name = p.asString();
            auto it = types.find(name);
            if (it == types.end() || it->second != NodeConfig::Type::Pulse) {
                return Fail(error, source + ": " + name + " is not a pulse node");
            }
            rc.pulse.push_back(name);
        }
        rc.set = ParseValueMap(r["Set"]);
        if (!CheckSet(types, rc.set, source, error)) return false;
        if (source == "launch" && rc.maxMs <= 0) return Fail(error, "launch needs MaxMs > 0");
        config.requests[source] = rc;
    }

    const Json::Value& adpf = root["Adpf"];
    if (adpf.isObject()) {
        config.adpf.enabled = adpf.get("Enabled", false).asBool();
        config.adpf.reportRateMs = adpf.get("ReportRateMs", 100).asInt64();
        config.adpf.staleMs = adpf.get("StaleMs", 150).asInt64();
        config.adpf.lowWater = adpf.get("LowWater", 0.8).asDouble();
        for (const auto& level : adpf["Levels"]) {
            ValueMap set = ParseValueMap(level);
            if (!CheckSet(types, set, "Adpf level", error)) return false;
            config.adpf.levels.push_back(set);
        }
        if (config.adpf.enabled && config.adpf.levels.empty()) {
            return Fail(error, "Adpf enabled without Levels");
        }
    }

    config.boosts = ParseNames(root["Supported"]["Boosts"]);
    config.modes = ParseNames(root["Supported"]["Modes"]);
    *out = std::move(config);
    return true;
}

bool LoadConfig(const std::string& path, Config* out, std::string* error) {
    std::ifstream in(path);
    if (!in) return Fail(error, "cannot open " + path);
    std::stringstream buf;
    buf << in.rdbuf();
    return ParseConfig(buf.str(), out, error);
}

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
