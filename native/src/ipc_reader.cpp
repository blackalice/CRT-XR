#include "ipc_reader.h"
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/stat.h>
#include <unistd.h>
#include <pthread.h>
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstring>

namespace crt_xr {
IpcReader::IpcReader(std::string prefix) : prefix_(std::move(prefix)) {}
IpcReader::~IpcReader() { detach(); }
void IpcReader::detach() {
    for (auto* segment : {&pose_, &mutex_, &disabled_}) {
        if (segment->data) shmdt(segment->data);
        *segment = {};
    }
    seen_ = false;
    progressed_ = false;
}
bool IpcReader::current(const Segment& segment, const char* suffix, std::size_t size) const {
    const auto path = prefix_ + suffix;
    struct stat file {};
    if (lstat(path.c_str(), &file) != 0 || !S_ISREG(file.st_mode) || file.st_uid != getuid()) return false;
    const auto key = ftok(path.c_str(), 0);
    if (key == -1 || shmget(key, 0, 0) != segment.id) return false;
    struct shmid_ds info {};
    return shmctl(segment.id, IPC_STAT, &info) == 0 && info.shm_segsz == size &&
        info.shm_perm.uid == getuid() && !(info.shm_perm.mode & SHM_DEST);
}
bool IpcReader::attach(Segment& segment, const char* suffix, std::size_t size, bool writable) {
    const auto path = prefix_ + suffix;
    struct stat file {};
    if (lstat(path.c_str(), &file) != 0 || !S_ISREG(file.st_mode) || file.st_uid != getuid()) return false;
    const auto key = ftok(path.c_str(), 0);
    if (key == -1) return false;
    segment.id = shmget(key, 0, 0); // NEVER IPC_CREAT
    if (segment.id == -1 || !current(segment, suffix, size)) return false;
    void* mapped = shmat(segment.id, nullptr, writable ? 0 : SHM_RDONLY);
    if (mapped == reinterpret_cast<void*>(-1)) return false;
    segment.data = mapped;
    return true;
}
PoseResult IpcReader::poll() {
    PoseResult result;
    const auto now = std::chrono::steady_clock::now();
    if (sizeof(pthread_mutex_t) != 40 || sizeof(float) != 4) {
        result.status = "unsupported_libc_abi";
        return result;
    }
    if (now >= next_check_) {
        next_check_ = now + std::chrono::seconds(1);
        if (!current(pose_, "pose_orientation", 64) ||
            !current(mutex_, "pose_orientation_mutex", 40) || !current(disabled_, "disabled", 1)) detach();
    }
    if (!pose_.data) {
        if (!attach(pose_, "pose_orientation", 64, false) ||
            !attach(mutex_, "pose_orientation_mutex", 40, true) || !attach(disabled_, "disabled", 1, false)) {
            detach();
            result.status = "driver_unavailable_or_layout_mismatch";
            return result;
        }
    }
    if (*static_cast<const volatile unsigned char*>(disabled_.data) != 0) {
        seen_ = false;
        progressed_ = false;
        result.status = "driver_disabled_or_disconnected";
        return result;
    }
    auto* lock = static_cast<pthread_mutex_t*>(mutex_.data);
    const int error = pthread_mutex_trylock(lock);
    if (error == EOWNERDEAD) {
        // Do not repair or unlock an inconsistent robust lock: unlocking makes
        // it unrecoverable. Exit this helper so the kernel marks owner death
        // again, preserving the producer's opportunity to recover its lock.
        std::fputs("CRT XR: driver mutex owner died; bridge exiting without repair\n", stderr);
        _exit(75);
    }
    if (error != 0) {
        result.status = error == EBUSY ? "driver_lock_busy" : "driver_lock_error";
        return result;
    }
    std::array<float, 16> data{};
    std::memcpy(data.data(), pose_.data, sizeof(data));
    if (pthread_mutex_unlock(lock) != 0) { result.status = "driver_unlock_error"; return result; }
    float norm = 0;
    for (int i = 0; i < 4; ++i) {
        if (!std::isfinite(data[i])) { result.status = "invalid_quaternion"; return result; }
        norm += data[i] * data[i];
    }
    if (norm < 0.8f || norm > 1.2f || !std::isfinite(data[12]) || data[12] < 0) {
        result.status = "invalid_pose_or_timestamp";
        return result;
    }
    result.driver_ms = data[12];
    if (!seen_) {
        seen_ = true;
        last_timestamp_ = data[12];
        last_progress_ = now;
        result.status = "waiting_for_live_samples";
        return result;
    }
    result.changed = data[12] != last_timestamp_;
    if (result.changed) { last_timestamp_ = data[12]; last_progress_ = now; progressed_ = true; }
    if (now - last_progress_ > std::chrono::milliseconds(250)) {
        result.status = "tracking_stale";
        return result;
    }
    if (!progressed_) { result.status = "waiting_for_live_samples"; return result; }
    const float scale = 1.0f / std::sqrt(norm);
    // NWU forward +X, left +Y, up +Z -> Godot right +X, up +Y, forward -Z.
    // B(x,y,z)=(-y,z,-x) is a proper basis change, determinant +1.
    result.quaternion = {-data[1] * scale, data[2] * scale, -data[0] * scale, data[3] * scale};
    result.valid = true;
    result.status = "tracking";
    return result;
}
}
