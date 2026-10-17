# Steam Deck inspection — 14 October 2026

Connected through the user-authorized SSH session as `deck`. No password was
stored in the project. Prototype files are installed at:

```text
/home/deck/Applications/CRT-XR/prototype-20261014/
```

## Observed environment

* Linux x86-64, SteamOS 3.8.28, build 20260922.1.
* Active KDE Wayland Desktop Mode session.
* Godot used OpenGL compatibility on the AMD Custom GPU 0405 (vangogh), Mesa 26.1.2.
* Only the built-in eDP display was reported connected during inspection.
* XR Gaming package version: `1.6.1-0108128`.
* Driver process: `/home/deck/.local/bin/xrDriver`.

## Installed artifact fingerprints

| Artifact | SHA-256 |
|---|---|
| `~/.local/bin/xrDriver` | `bb14df734f6fb81fb22d584e9954a843acb4dda68c841bab176053e0371479ed` |
| `~/.local/share/breezy_vulkan/manifest` | `ad92c31275a72d0e2554cf75d65d9d918b76aecd0332daf917798d3843c40812` |
| Prototype executable | `54cc228405e5be61934192e3bc5461c91dcb4a3275578b29a869557a4322e79c` |
| Prototype PCK | `1ab2efcf5f6d408db94d76c8fcad0e6388041024242aa8be6cf7613a316e7ed4` |

The installed driver manifest contains binary checksums; it did not establish a
matching source commit. The package version and fingerprints identify the tested
artifacts but do not certify the tracking ABI.

## Existing IPC inventory

The utility queried segment metadata without mapping memory or acquiring locks.

| Segment suffix | Bytes | Owner UID | Attachments |
|---|---:|---:|---:|
| `pose_orientation` | 64 | 1000 | 1 |
| `pose_orientation_mutex` | 40 | 1000 | 1 |
| `keepalive_date` | 16 | 1000 | 1 |
| `disabled` | 1 | 1000 | 1 |

These sizes agree with the upstream allocation expectations. Fresh orientation,
coordinate conversion, timestamp semantics and robust-mutex behavior have not
been tested. Presence of segments does not establish a live headset connection.

## Prototype checks

* Local and remote package hashes matched.
* Headless startup succeeded.
* Graphical startup through `launch-deck.sh` succeeded and exited cleanly.
* Rendered capture was retrieved and inspected: `deck-preview.png`.
* All 13 scene/stereo checks passed on the actual Deck using the exported build.

XR Gaming configuration, driver files and shared-memory contents were not changed.
Glasses tracking and Full-SBS optical testing remain pending a connected device.
