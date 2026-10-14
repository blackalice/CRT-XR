#include "tracking_sample.h"
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/stat.h>
#include <pthread.h>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <string>

// Inventory only. Does not attach, lock, read or modify any shared memory.
// Sizes are hints from upstream, never proof of compatibility with the installed ABI.
int main() {
    std::cout << "Inventory only; tracking ABI remains unverified. Local pthread_mutex_t="
              << sizeof(pthread_mutex_t) << " bytes\n";
    bool complete = true;
    for (const auto* name : {"pose_orientation", "pose_orientation_mutex", "keepalive_date", "disabled"}) {
        const auto path = std::string("/tmp/shader_runtime_") + name;
        struct stat info {};
        if (stat(path.c_str(), &info) != 0) {
            std::cout << name << ": path unavailable: " << std::strerror(errno) << '\n';
            complete = false;
            continue;
        }
        const auto key = ftok(path.c_str(), 0);
        if (key == -1) { std::cerr << name << ": ftok: " << std::strerror(errno) << '\n'; complete = false; continue; }
        const auto id = shmget(key, 0, 0); // No IPC_CREAT, no permission changes.
        struct shmid_ds metadata {};
        if (id == -1 || shmctl(id, IPC_STAT, &metadata) == -1) {
            std::cout << name << ": segment unavailable: " << std::strerror(errno) << '\n';
            complete = false;
            continue;
        }
        std::cout << name << ": bytes=" << metadata.shm_segsz << " owner=" << metadata.shm_perm.uid
                  << " attachments=" << metadata.shm_nattch << '\n';
    }
    return complete ? 0 : 2;
}
