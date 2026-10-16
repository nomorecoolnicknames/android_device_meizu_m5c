#include "Engine.h"

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <cstdlib>
#include <sstream>

#include "FleetLog.h"

namespace aidl {
namespace android {
namespace hardware {
namespace power {
namespace impl {
namespace meizu {

namespace {

std::string Trim(const std::string& s) {
    size_t b = s.find_first_not_of(" \t\n");
    if (b == std::string::npos) return "";
    size_t e = s.find_last_not_of(" \t\n");
    return s.substr(b, e - b + 1);
}

std::optional<int64_t> ParseInt(const std::string& s) {
    std::string t = Trim(s);
    if (t.empty()) return std::nullopt;
    char* end = nullptr;
    errno = 0;
    long long v = strtoll(t.c_str(), &end, 10);
    if (errno != 0 || end == t.c_str() || *end != '\0') return std::nullopt;
    return v;
}

std::vector<int64_t> ParseFields(const std::string& s) {
    std::vector<int64_t> out;
    std::istringstream in(s);
    std::string field;
    while (in >> field) {
        auto v = ParseInt(field);
        if (!v) return {};
        out.push_back(*v);
    }
    return out;
}

// kHz of a floor token: "max", "pct:NN" or a number; nullopt if it needs the
// ceiling and there is none.
std::optional<int64_t> ResolveKhz(const std::string& token, std::optional<int64_t> ceiling) {
    if (token == "max") return ceiling;
    if (token.rfind("pct:", 0) == 0) {
        auto pct = ParseInt(token.substr(4));
        if (!pct || !ceiling) return std::nullopt;
        return *ceiling * std::clamp<int64_t>(*pct, 0, 100) / 100;
    }
    return ParseInt(token);
}

}  // namespace

Engine::Fs Engine::RealFs() {
    Fs fs;
    fs.read = [](const std::string& path, std::string* out) {
        int fd = open(path.c_str(), O_RDONLY | O_CLOEXEC);
        if (fd < 0) return false;
        char buf[256];
        ssize_t n = read(fd, buf, sizeof(buf) - 1);
        close(fd);
        if (n < 0) return false;
        out->assign(buf, n);
        return true;
    };
    // No O_TRUNC: sysfs and procfs nodes take one write(2) of the value.
    fs.write = [](const std::string& path, const std::string& value, int* err) {
        int fd = open(path.c_str(), O_WRONLY | O_CLOEXEC);
        if (fd < 0) {
            *err = errno;
            return false;
        }
        ssize_t n = write(fd, value.data(), value.size());
        *err = n < 0 ? errno : 0;
        close(fd);
        return n == static_cast<ssize_t>(value.size());
    };
    return fs;
}

Engine::Engine(std::vector<NodeConfig> nodes, Fs fs) : mFs(std::move(fs)) {
    std::stable_sort(nodes.begin(), nodes.end(), [](const NodeConfig& a, const NodeConfig& b) {
        return a.order != b.order ? a.order < b.order : a.name < b.name;
    });
    for (auto& cfg : nodes) {
        NodeState state;
        state.cfg = cfg;
        mNodes.push_back(std::move(state));
    }
}

Engine::NodeState* Engine::findLocked(const std::string& name) {
    for (auto& node : mNodes) {
        if (node.cfg.name == name) return &node;
    }
    return nullptr;
}

Engine::~Engine() {
    {
        std::lock_guard<std::mutex> lock(mLock);
        mStop = true;
    }
    mCv.notify_all();
    if (mWorker.joinable()) mWorker.join();
}

void Engine::start() {
    mWorker = std::thread(&Engine::loop, this);
}

void Engine::loop() {
    std::unique_lock<std::mutex> lock(mLock);
    while (!mStop) {
        Clock::time_point next = applyLocked(Clock::now());
        auto wake = [this] { return mStop || mDirty; };
        if (next == Clock::time_point::max()) {
            mCv.wait(lock, wake);
        } else {
            mCv.wait_until(lock, next, wake);
        }
        mDirty = false;
    }
}

void Engine::reset(Clock::time_point now) {
    std::lock_guard<std::mutex> lock(mLock);
    mRequests.clear();
    for (auto& node : mNodes) node.written.reset();
    mRetryUntil = now + kRetryWindow;
    applyLocked(now);
}

void Engine::setRequest(const std::string& source, const ValueMap& values, Clock::time_point until,
                        bool extend, Clock::time_point now) {
    {
        std::lock_guard<std::mutex> lock(mLock);
        auto it = mRequests.find(source);
        if (extend && it != mRequests.end() && it->second.until > now) {
            until = std::max(until, it->second.until);
        }
        mRequests[source] = Request{values, until};
        applyLocked(now);
        mDirty = true;
    }
    mCv.notify_all();
}

void Engine::clearRequest(const std::string& source, Clock::time_point now) {
    {
        std::lock_guard<std::mutex> lock(mLock);
        if (mRequests.erase(source) == 0) return;
        applyLocked(now);
        mDirty = true;
    }
    mCv.notify_all();
}

void Engine::clearAll(Clock::time_point now) {
    {
        std::lock_guard<std::mutex> lock(mLock);
        if (mRequests.empty()) return;
        mRequests.clear();
        applyLocked(now);
        mDirty = true;
    }
    mCv.notify_all();
}

void Engine::pulse(const std::string& name, int32_t durationMs) {
    std::lock_guard<std::mutex> lock(mLock);
    NodeState* found = findLocked(name);
    if (!found || found->cfg.type != NodeConfig::Type::Pulse) return;
    NodeState& node = *found;
    int64_t us = static_cast<int64_t>(durationMs) * 1000;
    if (!node.cfg.durationPath.empty() && node.pulseUs != us) {
        int err = 0;
        if (mFs.write(node.cfg.durationPath, std::to_string(us), &err)) {
            node.pulseUs = us;
        } else {
            node.failures++;
            node.lastError = err;
        }
    }
    writeLocked(node, "1");
}

Engine::Clock::time_point Engine::apply(Clock::time_point now) {
    std::lock_guard<std::mutex> lock(mLock);
    return applyLocked(now);
}

bool Engine::hasRequest(const std::string& source) const {
    std::lock_guard<std::mutex> lock(mLock);
    return mRequests.count(source) != 0;
}

std::optional<int64_t> Engine::readKhz(const std::string& path) const {
    if (path.empty()) return std::nullopt;
    std::string s;
    if (!mFs.read(path, &s)) return std::nullopt;
    return ParseInt(s);
}

Engine::Clock::time_point Engine::applyLocked(Clock::time_point now) {
    Clock::time_point next = Clock::time_point::max();
    for (auto it = mRequests.begin(); it != mRequests.end();) {
        if (it->second.until <= now) {
            it = mRequests.erase(it);
        } else {
            next = std::min(next, it->second.until);
            ++it;
        }
    }
    bool pending = false;
    for (auto& node : mNodes) {
        if (node.cfg.type == NodeConfig::Type::Pulse) continue;
        std::optional<std::string> target = targetLocked(node);
        if (!target) continue;  // node absent right now (M3 Note cpufreq before it is armed)
        if (node.written == *target) continue;
        if (!writeLocked(node, *target) && node.writes == 0) pending = true;
    }
    // Start-up: a node init has not handed over yet is tried again shortly,
    // so the reset lands without waiting for the first touch.
    if (pending && now < mRetryUntil) next = std::min(next, now + kRetryPeriod);
    return next;
}

// The string the node should hold now, or nullopt if it cannot be computed.
std::optional<std::string> Engine::targetLocked(NodeState& node) const {
    std::vector<std::string> tokens;
    for (const auto& [source, request] : mRequests) {
        auto it = request.values.find(node.cfg.name);
        if (it != request.values.end()) tokens.push_back(it->second);
    }

    switch (node.cfg.type) {
        case NodeConfig::Type::CpufreqFloor: {
            std::optional<int64_t> ceiling = readKhz(node.cfg.maxPath);
            if (!ceiling) return std::nullopt;
            if (!node.releasedKhz) node.releasedKhz = readKhz(node.cfg.minInfoPath);
            if (!node.releasedKhz) return std::nullopt;
            int64_t khz = *node.releasedKhz;
            for (const auto& t : tokens) {
                if (auto v = ResolveKhz(t, ceiling)) khz = std::max(khz, *v);
            }
            return std::to_string(std::min(khz, *ceiling));
        }
        case NodeConfig::Type::PpmFloor: {
            std::optional<int64_t> ceiling = readKhz(node.cfg.maxPath);
            std::optional<int64_t> khz;
            for (const auto& t : tokens) {
                if (auto v = ResolveKhz(t, ceiling)) khz = khz ? std::max(*khz, *v) : *v;
            }
            if (khz && ceiling) khz = std::min(*khz, *ceiling);
            return std::to_string(node.cfg.cluster) + " " + (khz ? std::to_string(*khz) : "-1");
        }
        case NodeConfig::Type::Value: {
            if (tokens.empty()) {
                switch (node.cfg.release) {
                    case NodeConfig::Release::Default:
                        return node.cfg.defaultValue;
                    case NodeConfig::Release::None:
                        node.written.reset();  // the next hold writes again
                        return std::nullopt;
                    case NodeConfig::Release::Capture:
                        if (!node.captured) return std::nullopt;
                        if (node.written == node.captured) {  // put back already
                            node.captured.reset();
                            return std::nullopt;
                        }
                        return node.captured;
                }
            }
            if (node.cfg.release == NodeConfig::Release::Capture && !node.captured) {
                std::string current;
                if (!mFs.read(node.cfg.path, &current)) return std::nullopt;
                node.captured = Trim(current);
            }
            if (node.cfg.aggregate == NodeConfig::Aggregate::MaxInt) {
                std::optional<int64_t> best;
                for (const auto& t : tokens) {
                    if (auto v = ParseInt(t)) best = best ? std::max(*best, *v) : *v;
                }
                return best ? std::to_string(*best) : node.cfg.defaultValue;
            }
            std::vector<int64_t> best;
            for (const auto& t : tokens) {
                std::vector<int64_t> f = ParseFields(t);
                if (f.size() > best.size()) best.resize(f.size(), INT64_MIN);
                for (size_t i = 0; i < f.size(); ++i) best[i] = std::max(best[i], f[i]);
            }
            if (best.empty()) return node.cfg.defaultValue;
            std::string out;
            for (size_t i = 0; i < best.size(); ++i) {
                if (i) out += ' ';
                out += std::to_string(best[i]);
            }
            return out;
        }
        case NodeConfig::Type::Pulse:
            break;
    }
    return std::nullopt;
}

bool Engine::writeLocked(NodeState& node, const std::string& value) {
    int err = 0;
    if (mFs.write(node.cfg.path, value, &err)) {
        node.writes++;
        if (node.cfg.type != NodeConfig::Type::Pulse) node.written = value;
        FLEET_LOG(VERBOSE) << node.cfg.name << " <- " << value;
        return true;
    }
    node.lastError = err;
    node.written.reset();
    // Not ours yet: init chowns the node a little after the HAL starts, or the
    // kernel creates it later.  Not a failure until the node has been written once.
    if (node.writes == 0 && (err == EACCES || err == ENOENT)) {
        node.deferred++;
        FLEET_LOG(VERBOSE) << "deferred '" << value << "' to " << node.cfg.path << ": errno " << err;
        return false;
    }
    node.failures++;
    // First failure and then every 100th: a missing node would flood the log.
    if (node.failures % 100 == 1) {
        FLEET_LOG(WARNING) << "cannot write '" << value << "' to " << node.cfg.path << ": errno "
                           << err << " (" << node.failures << " failures)";
    }
    return false;
}

std::string Engine::dump(Clock::time_point now) const {
    std::lock_guard<std::mutex> lock(mLock);
    std::ostringstream out;
    out << "Requests:\n";
    for (const auto& [source, request] : mRequests) {
        auto left = std::chrono::duration_cast<std::chrono::milliseconds>(request.until - now);
        out << "  " << source << " (" << left.count() << " ms left):";
        for (const auto& [node, value] : request.values) out << " " << node << "=" << value;
        out << "\n";
    }
    out << "Nodes:\n";
    for (const auto& node : mNodes) {
        out << "  " << node.cfg.name << " " << node.cfg.path << " written="
            << (node.written ? "'" + *node.written + "'" : std::string("?"))
            << (node.captured ? " captured='" + *node.captured + "'" : std::string())
            << " writes=" << node.writes << " deferred=" << node.deferred
            << " failures=" << node.failures
            << " last_errno=" << node.lastError << "\n";
    }
    return out.str();
}

}  // namespace meizu
}  // namespace impl
}  // namespace power
}  // namespace hardware
}  // namespace android
}  // namespace aidl
