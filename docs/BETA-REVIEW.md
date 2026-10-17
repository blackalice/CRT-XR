# CRT XR â€” first beta review

Review updated: 17 October 2026. Candidate: 0.1.0-beta.4. Target: early public beta; private testers are not assumed. Publication has not been performed; the open distribution decisions below remain. No public upload, Git commit or release tag was made.

## Fixed during this pass

- Recent/Favourites returned no games for an empty search because String.contains("") is false in Godot. Empty search now returns the stored list; continuation and favourite actions work again.
- App/menu names, Windows/Linux executables, native extension/bridge names, launchers, logs and documentation now use CRT XR / crt-xr / crt_xr. Local Git description is CRT XR; no remote repository exists to rename. The active checkout path remains XR-CRT.
- One-time data migration copies old preferences, saves, favourites and music bookmarks without deleting originals or replacing newer data. Old logs/caches are skipped. The legacy core environment override remains accepted.
- Added application version/icon and General â†’ Copy diagnostics. Replaced stale prototype/menu instructions with the current quickstart.
- Added official Godot engine licence/copyright notices to exports, model provenance hashes, asset preflight and a verified local model recovery archive. Ignored files remain excluded from Git and exported packages.
- Short/truncated save files are rejected before variant decoding. Existing failed-save/menu recovery paths remain intact.
- Updated outdated regression expectations for the new home menu, category count, alphabetical jump row, picture pipeline and per-game preference default. These were test-maintenance issues, not additional application defects.

## Validation evidence

24 Windows automated suites pass: emulation/core switching; controller and stereo menus; picture controls/pipeline; preferences; ROM locations/index/library; automatic/manual saves; screenshots/defaults; music albums/resume; TV audio/power-on; console placement; room contacts; migration; pose prediction. Reports: build/beta-review/results.json and per-suite logs. Real rendering is used where readback is necessary; each test has isolated user data. Native Linux IPC-reader tests also pass. Windows and Steam Deck exported-package checks pass, including Deck GPU startup, renamed native extension, diagnostic ROM load, pause menu and prepared room assets. The shortcut remains CRT XR; subsequent Gaming Mode testing confirmed an explicit 3840×1080 override is needed on our Deck; original preferences/saves were backed up and verified unchanged. Device testing caught and fixed CRLF launcher line endings; export now normalises them and packaging rejects them. Through-glasses SBS, real-data migration on first normal launch and longer hardware testing still need human validation.

## Public-release gates

1. **Choose the licence for the app's own source and confirm combined distribution terms.** No app LICENSE file is present; LICENCE-PROPOSAL.md recommends MIT for original contributions, pending owner review. Nestopia is GPL-2.0; Snes9x and Genesis Plus GX contain non-commercial restrictions. Copies of core licences and upstream source snapshots are included, but that does not decide the host application's licence or combined-work obligations. The beta must not be presented as wholly permissive/commercially reusable. See THIRD_PARTY.md and the actual bundled licences.
2. **Finish reproducible core provenance.** Current Nestopia/Genesis binaries came from the official buildbot, with pinned archive hashes/source revisions recorded. Linux/Windows source builds from those revisions should be validated before broad distribution so corresponding-source/toolchain provenance is clear. Source snapshots and a build script exist, but are not yet independently reproduced for both platforms.
3. **Back up source/model assets off this machine and establish the release-source route.** Models are intentionally ignored by Git. archive/CRT-XR-model-assets-0.1.0-beta.1.zip is a verified local recovery copy, not an off-machine backup. A clean checkout needs that asset bundle (or the original downloads and documented preparation). The local Git repo is not published yet.
4. **Public-beta hardware validation.** Test clean install/upgrade, Desktop Mode SBS switching/restoration, Gaming Mode explicit SBS resolution, head tracking/recenter, unplug/replug, suspend/resume, SD-card removal and a longer gameplay/music session. Automated results do not establish through-glasses comfort, sound quality or every driver/firmware combination. Broader-device acceptance will come from public-beta feedback; no private tester group is assumed. Document unverified combinations instead of presenting them as guaranteed.

## Known beta limitations / follow-ups

- Tracking currently accepts one verified XRLinuxDriver binary hash. Other driver builds fall back safely to fixed view; widen compatibility only after ABI checks, not by deleting the guard.
- Gaming Mode mono-to-SBS handoff is user-confirmed with an explicit 3840×1080 per-game override. The installer prepares that profile; clean-account configuration, no-glasses mode and enlarged prompt readability still need hardware acceptance. See PRE-LAUNCH-CHECKLIST.md.
- Large MP3 opening and ID3 album scans are synchronous. A 256 MiB file or a slow/large SD-card album can briefly stall the UI; background loading is the next music-performance improvement. Memory is bounded to the current compressed track plus decoder/mixer working memory, not a whole album.
- Internet radio is direct MP3 only; URL entry needs a keyboard. Stream reconnect is manual after an error. No rewind/time-shift buffer exists for live radio.
- Music bookmarks checkpoint every five seconds; abrupt termination can lose up to five seconds. Desktop file paths and radio URLs can occur in preferences; review diagnostic files before sharing.
- Windows binaries are unsigned. A Desktop Mode Steam Deck installer is prepared and tested with isolated Linux fixtures; actual Steam-account acceptance is pending. There is no automatic updater or crash-report uploader. Windows remains a portable folder.
- Some headless renderer tests emit engine/test-teardown RID warnings; these are not evidence of a measured gameplay leak. A long device soak test remains required.

## Suggested first-beta scope

Free public beta, with feedback gathered from users rather than a separate private tester group. Steam Deck + VITURE Pro 2 is the tested XR combination; Windows is a local preview. Pro 2 currently requires the testing version of XR Gaming. Other SBS/3DoF glasses are intended to work through compatible tracking and display profiles but are untested. Ship a complete versioned package, quickstart, known limitations, credits, source/licensing materials and checksums. Use 0.1.0-beta.1 for review, then increment beta revisions for fixes. Public licensing/distribution decisions remain with the project owner.


## Installer preparation, 17 October

See PRE-LAUNCH-CHECKLIST.md for current states and GETTING-STARTED.md for the packaged user guide. The installer verifies listed payload hashes, keeps prior versions, backs up Steam configuration, updates the same shortcut ID, and sets the observed ResolutionOverride2 field while Steam is closed. No SSH/developer debugging/root is required for app installation. The tracking-driver dependency is detected but not automatically installed. The Deck went offline during preparation, so no claim of clean-device installer acceptance is made.

Current preparation checks: 24/24 application suites pass; the picture-fit readback test now explicitly disables the separately tested power-on reveal so it measures geometry rather than racing the startup animation. Installer checks: 31 passing Python checks on Windows plus 5 Linux-only transaction checks skipped there; all 9 installer checks pass in WSL/Linux, including those 5 transactions.

Launch scope: console and cables are parked, omitted from rendering and exported model assets. Table and carpet contact AO were rebaked in Blender against the console-free layout; contact registration and geometry smoke checks pass. Original console sources/preparation remain available locally.

Artwork: supplied portrait, landscape, hero, logo and icon are packaged. Setup installs grid assets using the actual shortcut ID and points the shortcut icon to its stable installed path. Managed artwork updates only if unchanged since its previous install; custom artwork is preserved. Artwork changes participate in configuration-failure rollback. Logos appear in the SBS instructions and controlled mono/stereo loading UI; engine boot and the SBS switching curtain remain black. Linux artwork tests pass; real Steam library appearance after installer setup still needs acceptance.
