#include "ipc_reader.h"
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <thread>

namespace { volatile std::sig_atomic_t running = 1; void stop(int) { running = 0; } }
int main(int argc, char** argv) {
    if (argc != 3) {
        std::fputs("Usage: retrocrt-tracking-bridge LOOPBACK_UDP_PORT PARENT_PID\n", stderr);
        return 2;
    }
    char* end = nullptr;
    const long port = std::strtol(argv[1], &end, 10);
    if (*end || port < 1024 || port > 65535) return 2;
    const long parent = std::strtol(argv[2], &end, 10);
    if (*end || parent <= 1) return 2;
    const int socket_fd = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, 0);
    if (socket_fd == -1) { std::perror("tracking UDP socket"); return 1; }
    sockaddr_in destination{};
    destination.sin_family = AF_INET;
    destination.sin_port = htons(static_cast<unsigned short>(port));
    destination.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    std::signal(SIGTERM, stop);
    std::signal(SIGINT, stop);
    retrocrt::IpcReader reader;
    unsigned long long sequence = 0;
    auto next_report = std::chrono::steady_clock::now();
    while (running && kill(static_cast<pid_t>(parent), 0) == 0) {
        const auto sample = reader.poll();
        const auto now = std::chrono::steady_clock::now();
        if ((sample.valid && sample.changed) || now >= next_report) {
            if (sample.valid && sample.changed) ++sequence;
            char packet[512];
            const auto& q = sample.quaternion;
            const int size = std::snprintf(packet, sizeof(packet),
                "{\"v\":1,\"valid\":%s,\"status\":\"%s\",\"sequence\":%llu,\"driver_ms\":%.0f,\"q\":[%.9g,%.9g,%.9g,%.9g]}",
                sample.valid ? "true" : "false", sample.status, sequence, sample.driver_ms, q[0], q[1], q[2], q[3]);
            if (size < 0 || static_cast<std::size_t>(size) >= sizeof(packet) ||
                sendto(socket_fd, packet, static_cast<std::size_t>(size), MSG_DONTWAIT,
                       reinterpret_cast<sockaddr*>(&destination), sizeof(destination)) < 0) {
                std::perror("tracking send"); close(socket_fd); return 1;
            }
            next_report = now + std::chrono::milliseconds(100);
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
    close(socket_fd);
    return 0;
}
