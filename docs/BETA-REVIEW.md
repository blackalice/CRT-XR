# Beta.7 update — 21 October 2026

Removed exact XR driver and plugin-API fingerprints. Runtime shared-memory layout/ownership, pose validity and freshness checks remain. Installer detection and SBS control accept updated compatible builds. Deployed on Steam Deck with the updated driver; the user confirmed tracking works again. The prior installation remains available and 53 preference/save files were preserved.

# CRT XR public beta review — 0.1.0-beta.6

Reviewed 18 October 2026. See PRE-LAUNCH-CHECKLIST.md for current acceptance and the release BUILD-RECORD.json for executed candidate checks. Old development deployments are not evidence that a new user's install works.

## Changes since beta.5 preparation

- Native Windows VITURE pose helper, corrected orientation mapping tested on Pro 2, and Xbox-compatible controls.
- Windows launch screen with explicit display choice, desktop fallback and black fullscreen handoff. Recommended sequence is glasses in SBS before launching, then choose their display.
- Per-monitor Windows DPI manifest fixes wrong dimensions on mixed-scale desktops. CRT-XR.pck stays beside the EXE so resource changes cannot corrupt embedded data.
- Browser links to local/removable/mapped drives, explicit drive roots, and folder/UNC entry for ROMs and music.
- Independent desktop/XR field-of-view calibration prevents the former 50-degree desktop preview from shrinking the XR picture. Legacy default migrates to 24 degrees for XR; explicit XR choices persist.

## Release scope and obligations

Free public beta, seeking testers, issues, ideas and code review. Windows and Steam Deck Pro 2 XR have user-confirmed basics; remaining acceptance is listed openly. The Windows package does not include the proprietary VITURE SDK. Windows users supply it under its own terms. SpaceWalker drivers alone do not configure CRT XR's SDK directory.

Original code is MIT. The Nestopia in-process combination follows conservative GPL distribution treatment. Retain custom Snes9x/Genesis Plus GX restrictions, full notices and matching source/build materials; the complete collection is not wholly permissive or commercially unrestricted. All six core binaries are locally built from pinned source with recorded hashes; they are not described as reproduced upstream buildbot binaries. See CORE-DISTRIBUTION.md.

TV historical CC BY 4.0 licence evidence, creator credit, model revision and modification notices are retained. Artistic source originals are not in the corresponding application-source archive; processed runtime model data and credits remain in app downloads. A verified local artistic backup exists; off-machine recovery remains outstanding.

## Test evidence and limits

The regression runner isolates preferences and uses synthetic cartridges. Real Deck GUI upgrade and .desktop installation passed; original app ID/user data and artwork integrity were checked. User confirmed corrected prompt readability and SBS on Deck. Windows hardware feedback corrected the SDK axes and established SBS-before-launch as the preferred sequence. The final new package still needs broader clean-user acceptance, updated FOV/browser feedback and longer unplug/replug/suspend/gameplay/music sessions.

Known limitations: runtime-validated Linux IPC layout; separately supplied Windows SDK; unsigned Windows binaries; synchronous large MP3/album loads; direct MP3 radio only with manual reconnect; five-second music bookmark checkpoint interval; no automatic updater/crash uploader. Logs can include private paths/URLs. Do not promise support for every SBS/3DoF display.
