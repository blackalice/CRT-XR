#pragma once
#include <cstdint>

namespace crt_xr {
// Application contract, NOT the driver's shared-memory layout.
enum class TrackingStatus { ready, unavailable, abi_unverified, stale, invalid, lock_timeout };
struct TrackingSample {
    float x = 0, y = 0, z = 0, w = 1; // normalized Godot local-to-world quaternion
    std::uint64_t received_monotonic_us = 0;
    std::uint64_t sequence = 0;
    TrackingStatus status = TrackingStatus::unavailable;
};
class TrackingSource {
public:
    virtual ~TrackingSource() = default;
    // Never create, remove, initialize or repair driver-owned resources.
    virtual TrackingStatus attach_existing() = 0;
    // Nonblocking/bounded mutex wait; invalid samples must not reach the renderer.
    virtual TrackingSample poll() = 0;
    virtual void detach() = 0;
};
} // namespace crt_xr
