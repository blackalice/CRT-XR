# SBS handoff test

This is groundwork, not an automatic Gaming Mode resolution fix. The normal launch path and Desktop recovery supervisor are unchanged.

## First Deck session

1. Install the separate `dist/sbs-probe-linux` build alongside the working version. Keep the current Steam entry available for rollback.
2. Test in Gaming Mode, with the glasses initially in mono and the per-game resolution still Native. Use launch options `--sbs-probe --glasses` for VITURE's known 3840x1080 profile.
3. Read the prompt while still in mono. Press A to black out, then press the glasses' SBS button. Do not adjust Steam's display settings yet: the first test measures what happens automatically.
4. The app waits for the selected display to advertise the target mode and for both its game-facing screen and window to match for four readings. It stays black on a mismatch or after a 90-second timeout. B/Escape exits; switching back to mono before cancelling avoids seeing Steam's flat UI in SBS. The app curtain cannot cover Steam overlays or the shell after exit.
5. Collect diagnostics while it is black. Under `~/.local/state/crt_xr/display-probe-*/`, `display.json` holds the latest DRM inventory; `display.jsonl` records connection/mode changes; `display.json.app.json` holds the latest expected/screen/window sizes and wait reason. The normal `godot-steam.log` records phase changes. Each launch has a unique directory, so stale files cannot unlock the curtain.
6. Compare with Gamescope's active output mode, process command line/version and Steam's selected external resolution. Advertised sysfs modes are not the current scanout mode: the probe explicitly reports physical mode verification as false. Matching the app sizes is a candidate handoff, not proof of the physical signal or optical correctness.
7. Repeat with SBS already active before launch. If automatic switching fails, make the external-mode change once for diagnosis and repeat. This separates a physical-mode selection failure from Steam retaining the old virtual screen. Only then implement the appropriate Gaming Mode adapter.

## Other display profiles

Use `--sbs-probe --glasses --sbs-resolution 5120x1440 --xr-connector card1-DP-1` as an example, replacing dimensions and connector with those of the actual device. This is an explicit full-SBS profile, not automatic optical-layout inference or a claim that a particular headset uses that mode. The helper discovers newly advertised modes after switching; it does not require the target mode to exist at initial launch. Unknown devices require the connector override. It refuses ambiguous automatic identity matches.

VITURE identification remains the existing EDID-name heuristic. EDID hashes and connectors are captured to investigate identity changes before adding persisted profiles; automatic cross-brand detection, half-SBS layouts and tracking adapters are not implemented here.

## Safety and validation

The helper reads sysfs and writes its own diagnostics only. It does not edit Steam settings, modes.cfg, KScreen layouts or DRM modes. The launcher supervises and cleans up the probe process. Normal launches do not start it. No extra 3D rendering pass is added.

Local checks cover alternate target dimensions, target appearing after hotplug, disconnects, ambiguous identity, stale data, mismatched screen/window dimensions and repeated A not bypassing the gate. The original 3840x1080 fallback remains in non-experimental paths until hardware validation justifies migrating the working setup.

## Deck session, 17 October 2026

Installed Gamescope: 3.16.23.6. The physical DP-1 output switches to 3840x1080@60 automatically after the VITURE button switch (confirmed in the Gamescope user journal). Xwayland server #0 initially follows it, then Steam requests 1920x1080. CRT XR runs on DISPLAY=:1, whose advertised/current game-facing mode remains 1920x1080. App diagnostics agree. This separates physical output switching from the game-facing resolution failure.

The test prompt initially hid on its first resize. Fixed: experimental prompt stays visible until explicitly armed; the Steam launch A press must be released before a new press can arm it. Added regression assertions and transferred corrected PCK.

A guarded SteamClient.Apps.SetAppResolutionOverride test changed only CRT XR from Native to 3840x1080. Steam readback confirms the new value. It did not change the already-running virtual screen immediately; relaunch validation is next. Original setting for restoration: Native. No modes.cfg edits were made. The existing CRT XR shortcut currently points to sbs-test-20261017/launch-sbs-test.sh; production target remains 0.1.0-beta.1/launch-steam.sh. Keep experimental changes separate until optical acceptance.

On relaunch with the explicit per-app override, DISPLAY=:1 and CRT XR's actual window both became 3840x1080. The physical output remained 3840x1080@60. This confirms the override is effective on launch, but it was not applied live to the prior session. The diagnostic gate had an additional bug: JSON numbers decode as floats, while the target dimensions were integers, causing whole-array equality to fail. Reproduced with a JSON round-trip regression assertion, fixed by numeric component comparison with shape/type checks, and re-exported/transferred. Optical acceptance and mono-to-SBS launch with this override are still pending.

## Polished automatic launcher

The user confirmed both SBS-already-active and mono-to-SBS startup work with the explicit Steam per-game override. Keep that override on this Deck while validating the mono path.

The normal Gaming Mode launcher now automatically runs the supervised handoff when identified glasses are connected. It no longer needs the test wrapper's forced --glasses/connector flags. With no glasses (or --mono), it bypasses the prompt and watcher and requests a 1280x800 mono window. Gamescope presents that window; it avoids fullscreen inheriting a wide game-facing screen. Added --deck-mono to retain the Deck aspect when initialising the app. Physical no-glasses acceptance remains pending.

The setup panel uses charcoal/cream styling, numbered steps, A Begin, B Cancel and X Retry while waiting. It waits for the launch A press to be released. Its layout scales from a 1280x720 logical canvas, independently along both axes, so the wide SBS game canvas being squeezed into the physical mono image does not make the text tiny. This applies to the setup prompt only, not the stereo scene or menus. Prompt-only visual inspection excludes all licensed models. Through-glasses readability acceptance remains pending.

Installed alongside prior builds as ~/Applications/CRT-XR/gaming-handoff-20261017; the existing Steam entry now points to its launch-steam.sh. Settings/shortcut backups are in that directory. This is not automatic Steam configuration for arbitrary headsets: the confirmed 3840x1080 Steam override remains a per-device setup step until profile-aware prelaunch configuration is implemented.
