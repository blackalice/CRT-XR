#include "ipc_reader.h"
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <thread>
#include <vector>

namespace {
void check(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
    std::cout << "PASS: " << message << '\n';
}
// This producer fixture owns a private temporary namespace. It never references
// /tmp/shader_runtime_ or any actual XR driver resources.
struct Fixture {
    std::string directory, prefix;
    std::vector<int> ids;
    std::vector<void*> maps;
    std::vector<std::string> paths;
    float* pose = nullptr;
    unsigned char* disabled = nullptr;
    pthread_mutex_t* mutex = nullptr;
    Fixture(std::size_t pose_size = 64) {
        char pattern[] = "/tmp/crt_xr-ipc-test-XXXXXX";
        const auto* made = mkdtemp(pattern);
        if (!made) throw std::runtime_error("mkdtemp");
        directory = made;
        prefix = directory + "/fixture_";
        pose = static_cast<float*>(create("pose_orientation", pose_size));
        mutex = static_cast<pthread_mutex_t*>(create("pose_orientation_mutex", sizeof(pthread_mutex_t)));
        disabled = static_cast<unsigned char*>(create("disabled", 1));
        pthread_mutexattr_t attributes;
        pthread_mutexattr_init(&attributes);
        pthread_mutexattr_setpshared(&attributes, PTHREAD_PROCESS_SHARED);
        pthread_mutexattr_setrobust(&attributes, PTHREAD_MUTEX_ROBUST);
        if (pthread_mutex_init(mutex, &attributes) != 0) throw std::runtime_error("mutex init");
        pthread_mutexattr_destroy(&attributes);
        pose[3] = 1;
        pose[12] = 100;
    }
    void* create(const char* name, std::size_t size) {
        const auto path = prefix + name;
        const int file = open(path.c_str(), O_CREAT | O_EXCL | O_RDWR, 0600);
        if (file == -1) throw std::runtime_error("fixture file");
        close(file);
        paths.push_back(path);
        const int id = shmget(ftok(path.c_str(), 0), size, IPC_CREAT | IPC_EXCL | 0600);
        if (id == -1) throw std::runtime_error("fixture segment");
        ids.push_back(id);
        void* data = shmat(id, nullptr, 0);
        if (data == reinterpret_cast<void*>(-1)) throw std::runtime_error("fixture map");
        maps.push_back(data);
        return data;
    }
    ~Fixture() {
        // Only resources explicitly created by this test fixture are removed.
        if (mutex) pthread_mutex_destroy(mutex);
        for (auto* map : maps) shmdt(map);
        for (const auto id : ids) shmctl(id, IPC_RMID, nullptr);
        for (const auto& path : paths) unlink(path.c_str());
        rmdir(directory.c_str());
    }
};
}
int main() {
    try {
        {
            Fixture f;
            crt_xr::IpcReader reader(f.prefix);
            check(!reader.poll().valid && !reader.poll().valid, "Frozen initial samples are not accepted as live");
            f.pose[12] += 1;
            auto pose = reader.poll();
            check(pose.valid && pose.changed, "Advancing source timestamp enables tracking");
            f.pose[0] = std::sqrt(0.5f); f.pose[3] = std::sqrt(0.5f); f.pose[12] += 1;
            pose = reader.poll();
            check(pose.valid && std::abs(pose.quaternion[2] + std::sqrt(0.5f)) < 0.0001f, "NWU roll maps onto negative Godot Z");
            f.pose[0] = 0; f.pose[1] = std::sqrt(0.5f); f.pose[12] += 1;
            pose = reader.poll();
            check(pose.valid && pose.quaternion[0] < -0.7f, "NWU pitch maps onto negative Godot X");
            f.pose[1] = 0; f.pose[2] = std::sqrt(0.5f); f.pose[12] += 1;
            pose = reader.poll();
            check(pose.valid && pose.quaternion[1] > 0.7f, "NWU yaw maps onto positive Godot Y");
            const auto before = std::chrono::steady_clock::now();
            pthread_mutex_lock(f.mutex);
            pose = reader.poll();
            pthread_mutex_unlock(f.mutex);
            check(!pose.valid && std::chrono::steady_clock::now() - before < std::chrono::milliseconds(50), "Busy mutex never blocks rendering or helper polling");
            f.pose[0] = std::numeric_limits<float>::quiet_NaN();
            check(!reader.poll().valid, "Nonfinite quaternion rejected");
            f.pose[0] = 0;
            f.pose[3] = 0;
            f.pose[2] = 0;
            check(!reader.poll().valid, "Zero quaternion rejected");
            f.pose[3] = 1;
            f.pose[12] += 1;
            check(reader.poll().valid, "Valid data recovers after invalid samples");
            std::this_thread::sleep_for(std::chrono::milliseconds(280));
            pose = reader.poll();
            check(!pose.valid && std::strcmp(pose.status, "tracking_stale") == 0, "Stopped source timestamps expire even with valid orientation");
            f.pose[12] += 1;
            check(reader.poll().valid, "New timestamps recover stale tracking");
            *f.disabled = 1;
            check(!reader.poll().valid, "Driver disabled flag rejects samples");
            *f.disabled = 0;
            check(!reader.poll().valid, "Reconnect requires fresh timestamp progress");
            f.pose[12] += 1;
            check(reader.poll().valid, "Reconnect resumes on fresh samples");
        }
        {
            Fixture f(128);
            crt_xr::IpcReader reader(f.prefix);
            check(!reader.poll().valid, "Incorrect segment size is rejected without resetting it");
            struct shmid_ds info {};
            check(shmctl(f.ids[0], IPC_STAT, &info) == 0 && info.shm_segsz == 128, "Reader preserves mismatched producer resources");
        }
        {
            Fixture f;
            const auto child = fork();
            if (child == 0) { pthread_mutex_lock(f.mutex); _exit(0); }
            int status = 0;
            waitpid(child, &status, 0);
            const auto reader_child = fork();
            if (reader_child == 0) { crt_xr::IpcReader reader(f.prefix); reader.poll(); _exit(1); }
            waitpid(reader_child, &status, 0);
            check(WIFEXITED(status) && WEXITSTATUS(status) == 75, "Bridge exits safely on robust mutex owner death");
            check(pthread_mutex_trylock(f.mutex) == EOWNERDEAD, "Owner-dead mutex remains recoverable for its producer");
            // Fixture owns this mutex and may recover it; the production reader never does.
            pthread_mutex_consistent(f.mutex);
            pthread_mutex_unlock(f.mutex);
        }
        {
            Fixture f;
            unlink(f.paths[0].c_str());
            crt_xr::IpcReader reader(f.prefix);
            check(!reader.poll().valid && access(f.paths[0].c_str(), F_OK) == -1, "Missing resource paths are never created");
        }
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
    return 0;
}
