# CRT XR — beta quickstart

Version: 0.1.0-beta.6. Keep the complete extracted folder together; run CRT-XR.exe on Windows or launch-steam.sh from Steam on Linux. Windows may show an unsigned-application warning; code signing is not configured yet.

## Steam Deck

**Prerequisite for tracked XR: Decky Loader with XR Gaming installed and enabled. VITURE Pro 2 currently needs XR Gaming’s testing version.** CRT XR setup assumes this is already present and does not install the plugin.

Use Desktop Mode for installation. Extract the complete Linux package and open **Install CRT XR.desktop**, choose the tested VITURE SBS profile or mono/monitor profile, and allow Steam to close so setup can safely register CRT XR. Restart Steam and return to Gaming Mode. See **GETTING-STARTED.md** for the full walkthrough, tracking prerequisite and recovery information.

With glasses connected in mono, launch CRT XR, press A at the prompt, then switch the glasses to SBS. The view stays black until the app dimensions settle. The VITURE profile sets Steam's per-game resolution explicitly to 3840×1080; Native alone did not work on our test Deck. Without glasses the automatic launcher uses mono. Live tracking uses XR Gaming’s supported driver; the installer currently reports that dependency rather than installing it. Real-account upgrade and prompt/SBS acceptance passed; fresh-account and no-glasses hardware coverage remain pending.

Other SBS/3DoF glasses are intended to work through a compatible driver/display profile, but only Pro 2 has been tested.

## Windows

See **WINDOWS-SETUP.md**. Extract the entire ZIP; keep CRT-XR.pck beside the EXE. For native VITURE tracking, supply the Windows SDK separately in sdk/ beside the app; vendor DLLs are not bundled. Close SpaceWalker, switch the glasses to SBS **before launching**, choose their display, then Open glasses view. Xbox controllers work directly. Choose Play on this screen without glasses for a fixed mono view.

## Games

Open Game library → Library locations and choose the main ROM folder containing `snes/`, `nes/`, `megadrive/` (or `genesis/`), `mastersystem/` and `gamegear/`, including on SD cards. Subfolders are scanned; an existing multi-system/EmuDeck-style layout can stay in place. See GETTING-STARTED.md for an example tree. Supported console folders appear automatically; unrelated systems stay hidden. Supported files are uncompressed SNES (.sfc/.smc), NES (.nes/.unf/.unif), Mega Drive (.md/.gen/.smd or recognised Sega .bin), Master System (.sms) and Game Gear (.gg). ZIPs, disc systems and BIOS-based consoles are not supported in this beta.

L1+R1+Start opens the pause menu. A activates, B goes back, up/down selects and left/right adjusts. L1/R1 changes settings category and L2/R2 changes subsection. Y resets the selected setting. Exit saves preferences, SRAM and an automatic resume point. Reconnect a missing SD card rather than deleting its library settings.

## Music

Browse albums from the main menu or Audio. MP3s up to 256 MiB are supported; only the current track is loaded. Folders play in disc/track order, then natural filename order. Press Play to start a restored song: its last timestamp is prepared silently on launch. Use left/right on the timeline to seek by ten seconds, or drag/click it with a pointer. Down exits the horizontal icon controls.

Audio → TV sound includes optional automatic game-volume dipping. Audio → Music & radio accepts direct MP3 stream URLs (keyboard entry). AAC, HLS, playlists, DRM and station webpages are not supported; live radio reconnects rather than time-shifts. No music is supplied.

## Reporting problems

General → Copy diagnostics copies version/platform details without ROM or music paths. Include those, Desktop/Gaming Mode, mono/SBS, steps to reproduce and what you expected. Settings/logs may contain local file paths or stream URLs; review them before sharing. A screenshot can be taken from the menu or F6. Some automatic checks use synthetic images; through-glasses comfort and sound still need human review.

Keep the previous build as a fallback. First launch migrates old RetroCRT XR data by copying it; original settings/saves remain intact. Do not run old and new versions simultaneously while migrating. This beta candidate has not been signed or published automatically.
