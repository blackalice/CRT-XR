#pragma once
#include <array>
#include <chrono>
#include <string>

namespace crt_xr {
struct PoseResult {
    bool valid = false;
    bool changed = false;
    const char* status = "waiting";
    std::array<float, 4> quaternion{0, 0, 0, 1};
    float driver_ms = 0;
};
class IpcReader {
public:
    explicit IpcReader(std::string prefix = "/tmp/shader_runtime_");
    ~IpcReader();
    IpcReader(const IpcReader&) = delete;
    IpcReader& operator=(const IpcReader&) = delete;
    PoseResult poll();
    void detach();
private:
    struct Segment { int id = -1; void* data = nullptr; };
    std::string prefix_;
    Segment pose_, mutex_, disabled_;
    bool attach(Segment&, const char* suffix, std::size_t size, bool writable);
    bool current(const Segment&, const char* suffix, std::size_t size) const;
    bool seen_ = false;
    bool progressed_ = false;
    float last_timestamp_ = 0;
    std::chrono::steady_clock::time_point last_progress_{};
    std::chrono::steady_clock::time_point next_check_{};
};
}
