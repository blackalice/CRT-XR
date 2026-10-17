# Gaming Mode SBS resolution investigation

Reviewed 17 October 2026. Source inspection and upstream research; no live Deck validation (SSH reported No route to host). No display settings changed.

## Diagnosis

Three dimensions must agree: the physical connector mode, Gamescope's game-facing virtual screen, and the application window. SBS optical mode is separate again. Switching the glasses does not prove all three resolutions changed.

If the app gets 1920x1080 and splits it horizontally, each eye only receives a 960x1080 region rather than the intended 1920x1080. Depending on compositor scaling this can look narrow, pillarboxed or cropped. The symptom alone cannot distinguish a physical output problem from a virtual-screen cap.

Current code findings:

- scripts/steam-session.py deliberately leaves Gaming Mode outputs to Gamescope, uses X11/fullscreen and starts the prompt at 1280x720.
- scripts/main.gd requests 3840x1080 in both SBS startup paths, after requesting fullscreen. This is an app-window request, not a physical display-mode switch; it cannot override the compositor's output policy.
- scripts/ui/sbs_prompt.gd auto-continues only for exactly 3840x1080; manual Continue permits an unresolved mismatch.
- scripts/glasses-session.py selects only 3840x1080 and validates that exact size. The Desktop path genuinely changes output mode through KDE; the Gaming Mode path does not.
- Automatic glasses detection in the Steam launcher currently recognises VITURE only. Other brands need explicit selection/detection, beyond just removing the resolution constants. Display compatibility and tracking compatibility are separate.

## First workaround to test

1. Exit CRT XR. Switch glasses to SBS first and leave them connected.
2. In Gaming Mode Settings > Display, inspect the external display resolution. If automatic selection remains at the mono mode, turn off automatic resolution and choose the advertised SBS mode at a supported refresh rate (initially 60 Hz where available).
3. In CRT XR's Steam Properties > General, set Game Resolution to Native. Check the global Maximum Game Resolution setting as well if present in that SteamOS version. Native applies to the selected external mode; it is not a guarantee of physical mode selection.
4. Launch CRT XR only after the external mode has settled. If Steam retained the old virtual resolution across a hotplug, exit/relaunch with SBS already active.
5. Record physical output, game-facing screen and actual window dimensions together. If the physical output is correct but the game screen remains capped, test an explicit per-game SBS resolution where Steam offers it.

This is a candidate workaround, not a confirmed fix on this Deck. Steam UI wording and available mode choices vary by version and attached display. Desktop Mode launched through Steam remains the already-proven fallback.

## Automation options

Prefer Steam's own external-mode and per-game resolution settings. The existing shortcut is already set to Native, so simply setting that again is not a complete fix.

Do not add a nested gamescope invocation as the default fix: its virtual-screen arguments can change what the child app sees, but do not guarantee that the outer Gaming Mode compositor changes the glasses' physical signal. Likewise KScreen/xrandr in the game cannot take over Gamescope's DRM output.

A version-specific integration with Steam/Gamescope's mode controls may be possible, but should be an experimental adapter with capability checks, original-state backup, timeout and restoration. The upstream gamescope-control Wayland protocol explicitly calls itself private and does not expose a general output-resolution setter. Treat mode-save-file recipes and private Steam APIs as version-specific until tested on the installed build; do not ship a blanket modes.cfg edit as a universal fix.

## Recommended app design

- Introduce a display profile identified by EDID make/model/serial when available, with connector only a fallback. Never identify XR solely from an ultrawide resolution.
- Store mono mode, SBS mode, refresh rate and per-eye aspect independently. Choose only modes actually advertised by the selected display. Full SBS, half SBS and unusual layouts need explicit profiles; width/height heuristics alone are insufficient.
- Read physical advertised modes separately from the game-facing screen and actual drawable window. /sys/class/drm/.../modes lists available modes, not proof of the active scanout mode. Capture the active mode through compositor/DRM diagnostics where supported.
- Match the validated profile, then size the two eye viewports from the actual drawable dimensions. Do not replace every constant with the current screen size: in Gaming Mode that may be the stale 1920x1080 virtual screen that caused this issue.
- Keep the black startup curtain while modes settle. If the physical and game-facing sizes do not agree with the profile, show a readable setup/retry explanation rather than silently starting malformed SBS.
- Include a small diagnostics page with expected SBS mode, advertised modes, physical mode when known, app screen/window sizes and session type. Keep unknown values explicitly unknown.
- Retain manual output/mode override for unidentified glasses and remember it per display. Tracking-provider support is a separate task.

## Hardware verification

With the Deck in Gaming Mode and glasses attached: collect Gamescope version/command line, external EDID + advertised modes before/after SBS, selected Steam display mode, shortcut resolution override, game-facing XRandR screen and CRT XR drawable size. Test switch-before-launch, switch-in-prompt, relaunch, unplug/reconnect and cancellation/restoration. Repeat with a synthetic non-3840 profile in local tests and at least one second physical display before claiming multi-display support.

## Upstream references

- https://github.com/ValveSoftware/gamescope — virtual screen/output distinction and nested command-line options.
- https://github.com/ValveSoftware/gamescope/blob/master/protocol/gamescope-control.xml — private protocol and available requests.
- https://github.com/ValveSoftware/gamescope/blob/master/src/Backends/DRMBackend.cpp — physical DRM mode selection requires an advertised matching mode.

The upstream master branch is research evidence, not proof of the installed SteamOS/Gamescope implementation.
