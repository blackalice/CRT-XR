# Steam Deck installer acceptance

Use the exact release archive, not a developer export folder. Keep the old builds for rollback until this passes.

## Upgrade test (preferred first)

1. Exit CRT XR and finish other games. In Desktop Mode, close Steam completely before offline configuration writes. SSH remains available in Desktop Mode.
2. Before closing, record CRT XR's app ID, target, start directory, launch options, controller configuration and resolution. Back up shortcuts.vdf, localconfig.vdf, affected grid artwork and the complete Godot `CRT XR` preferences/save directory. Record hashes so unchanged user data can be verified.
3. Extract the release archive outside the install folder. Run Install-CRT-XR.sh, choose VITURE 3840x1080, select the existing account if prompted, and allow Steam to close. The installer updates the existing CRT XR entry; do not remove that entry first.
4. Verify exactly one CRT XR shortcut, same app ID/tags/launch options/controller configuration, resolution 3840x1080, target `~/Applications/CRT-XR/current/launch-steam.sh`, current link to the new immutable release, and a successful install receipt with backups. Verify every installed payload hash.
5. Restart Steam. Check portrait, recent-game landscape, hero, logo and icon. Existing custom artwork is intentionally preserved. The installer does not replace unmanaged developer-installed PNGs just because they share an app ID.
6. In Gaming Mode with glasses unplugged, launch and check a correctly proportioned mono scene. Then connect glasses in mono, launch again, confirm prompt proportions/readability, press A, switch SBS and check the scene. Check ROM setup, controller settings, saves, music pause/resume and suspend/reconnect.

## Clean-install test (after upgrade)

A separate Steam user is the least disruptive way to exercise first-time setup. To use the same account, close Steam and make a second full backup first; temporarily remove only the CRT XR shortcut, its per-app resolution entry and its matching artwork. Move the app's user-data directory to a timestamped backup if testing first-run ROM setup. Never delete the data, Steam account configuration, other shortcuts or old build directories.

Run the installer and verify the fresh shortcut/controller behaviour. A fresh app ID may differ; do not assume the old ID. Restore user data only with CRT XR closed. Undo clean-test Steam changes with Steam closed, restoring the saved configuration/artwork snapshot; restore any previous current symlink from its receipt. Do not overwrite configuration while Steam is running.

## Cleanup once accepted

Keep `current`, `releases/`, the active release and install receipts/backups. Old developer folders under `~/Applications/CRT-XR/` can be moved to an archive after checking that no Steam target/start directory, launch script or symlink references them. Old versions are small compared with ROM/music libraries, and there is no need to remove them for launch. Preferences/saves are outside these directories and must be retained. Do not remove XR Gaming or its driver.

## Observed upgrade result - 17 October 2026

The first real run exposed Steam's AppName/Exe field casing, which the original fixture tests did not cover. The installer was fixed to read/update keys case-insensitively while preserving their spelling, with regression coverage. The trial-created duplicate was removed with Steam closed; the original shortcut remained intact.

The corrected real-account upgrade passed: original app ID retained, no duplicate, unrelated shortcuts unchanged, existing per-app/controller values retained, 3840x1080 resolution, installed manifest hashes verified, all four library artwork files matched, all 42 checked preference/save files unchanged, backups available. Steam was restarted using the active desktop environment. This validates upgrade behaviour, not a fresh user's controller template or through-glasses perception. Detached automatic Steam restart was removed to avoid stale display/session connections.
