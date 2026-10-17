# CRT XR — beta quickstart

Version: 0.1.0-beta.1. Keep the complete extracted folder together; run CRT-XR.exe on Windows or launch-steam.sh from Steam on Linux. Windows may show an unsigned-application warning; code signing is not configured yet.

## Steam Deck

Use Desktop Mode for the first setup. Connect the glasses directly, enable their SBS mode when prompted, and launch through Steam using the normal Gamepad layout. Do not hold the three-lines button to switch Desktop/gamepad mappings. Live tracking requires the supported XRLinuxDriver installation; the app offers a fixed view if tracking is unavailable. Follow DISPLAY-SETUP.md and GAMING-MODE.md for details.

Gaming Mode cannot always negotiate the external 3840×1080 mode automatically. Set the shortcut's external resolution to Native in Steam; Desktop Mode remains the recommended first beta route. The glasses may still need their physical SBS switch. Recenter with R3; the view has rotational tracking (3DoF), not walking/positional tracking.

## Games

Open Game library → Library locations and choose the main ROM folder, including SD cards. Supported console folders appear automatically; unrelated systems stay hidden. Supported files are uncompressed SNES (.sfc/.smc), NES (.nes/.unf/.unif), Mega Drive (.md/.gen/.smd or recognised Sega .bin), Master System (.sms) and Game Gear (.gg). ZIPs, disc systems and BIOS-based consoles are not supported in this beta.

L1+R1+Start opens the pause menu. A activates, B goes back, up/down selects and left/right adjusts. L1/R1 changes settings category and L2/R2 changes subsection. Y resets the selected setting. Exit saves preferences, SRAM and an automatic resume point. Reconnect a missing SD card rather than deleting its library settings.

## Music

Browse albums from the main menu or Audio. MP3s up to 256 MiB are supported; only the current track is loaded. Folders play in disc/track order, then natural filename order. Press Play to start a restored song: its last timestamp is prepared silently on launch. Use left/right on the timeline to seek by ten seconds, or drag/click it with a pointer. Down exits the horizontal icon controls.

Audio → TV sound includes optional automatic game-volume dipping. Audio → Music & radio accepts direct MP3 stream URLs (keyboard entry). AAC, HLS, playlists, DRM and station webpages are not supported; live radio reconnects rather than time-shifts. No music is supplied.

## Reporting problems

General → Copy diagnostics copies version/platform details without ROM or music paths. Include those, Desktop/Gaming Mode, mono/SBS, steps to reproduce and what you expected. Settings/logs may contain local file paths or stream URLs; review them before sharing. A screenshot can be taken from the menu or F6. Some automatic checks use synthetic images; through-glasses comfort and sound still need human review.

Keep the previous build as a fallback. First launch migrates old RetroCRT XR data by copying it; original settings/saves remain intact. Do not run old and new versions simultaneously while migrating. This beta candidate has not been signed or published automatically.
