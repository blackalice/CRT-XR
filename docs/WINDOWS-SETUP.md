# CRT XR — Windows beta setup

Tested with VITURE Pro 2 and an Xbox-compatible controller. Short guides: [VITURE](glasses/WINDOWS-VITURE.md) · [XREAL, Rokid, RayNeo and others](glasses/WINDOWS-OPENTRACK.md).

## Extract the app

Download `CRT-XR-<version>-Windows.zip` from https://github.com/blackalice/CRT-XR/releases and extract it to a folder. Double-click **CRT-XR.exe**; it is unsigned, so if Windows warns, choose **More info → Run anyway**. There is nothing to install and Steam is optional. Keep the EXE with the files and folders next to it (`CRT-XR.pck`, the extension DLL, `cores`, `assets`, `tracking`, `docs`, `licenses`).

Without glasses, choose **Play on this screen without glasses**. No VITURE SDK is needed for this path.

## Other glasses: OpenTrack tracking

The built-in tracking reads VITURE glasses. For other glasses, CRT XR can follow any tool that sends **OpenTrack UDP** (six doubles: x, y, z, yaw, pitch, roll in degrees) to `127.0.0.1` port **4242**:

- [opentrack](https://github.com/opentrack/opentrack) itself, set to output **UDP over network** with IP `127.0.0.1` and port `4242`;
- [PhoenixHeadTracker](https://github.com/iVideoGameBoss/PhoenixHeadTracker) for XREAL Air glasses;
- VertoXR, which supports Rokid and RayNeo glasses.

Start the tool, then in CRT XR choose **View & glasses → Tracking → Tracking source → OpenTrack**. The status reads *OpenTrack UDP / LIVE 3DoF* once poses arrive, and the first pose centres the view. Only this computer can send: CRT XR listens on 127.0.0.1. This path has been tested with simulated packets, not yet with real non-VITURE glasses. OpenTrack has no documented sign convention, so if turning or tilting goes the wrong way, use **Invert yaw/pitch/roll** on the same page. Field of view differs between models; adjust **View & glasses → Calibration → Vertical field of view** (shown with **Show advanced settings** on) if the TV seems to slide as you turn. SBS works as with VITURE: switch the glasses to their full side-by-side mode and choose their display.

## Video playback (optional)

Windows has no built-in FFmpeg. To watch videos, open **Video Library** and choose **Set up video playback**. CRT XR downloads only FFmpeg's five LGPL video libraries (about 55 MB) from https://github.com/BtbN/FFmpeg-Builds, checks each one and keeps them in its own user-data folder (`%APPDATA%/Godot/app_userdata/CRT XR/ffmpeg`, with a `source.cfg` recording where they came from). Nothing else on the computer changes, and videos play straight away. Then use **Choose a video folder** in the same place.

## Set up VITURE tracking

The proprietary VITURE SDK is **not bundled**. Download the Windows SDK from https://www.viture.com/developer and follow its terms; keep the ZIP.

On CRT XR's start-up screen choose **Set up VITURE head tracking…** (or later, **View & glasses → Tracking → Set up VITURE SDK**) and pick the ZIP, its folder, or `glasses.dll` inside it. CRT XR copies the x86_64 DLLs into its own settings folder (`%APPDATA%/Godot/app_userdata/CRT XR/viture-sdk`), so the setup survives updates to a new app folder. An `sdk` folder beside CRT-XR.exe, as older versions used, still works. CRT XR does not download these files, alter USB drivers or enable SDK telemetry.

Close SpaceWalker before tracking so it does not compete for the same USB device; CRT XR warns while it is running. Connect glasses directly to the PC. Use your normal monitor for setup: choose the glasses display (usually picked for you) and select **Open glasses view**, then switch the glasses to SBS when asked. Switching to SBS first also works. CRT XR keeps the view black while moving to that display and waits for a stable full-SBS mode, following the display if it reconnects as the mode changes.

If the view stays black, return the glasses to 2D and press B / Escape to return to the start-up screen. Recheck the selected display. If tracking is unavailable, the Tracking page says why (SDK not set up, SpaceWalker running, glasses not found) and has a retry and fixed-view option. Reconnect/suspend reliability on other computers is not yet established.

## Controls and games

Xbox/XInput-compatible controllers work directly, without Steam desktop mappings. LB + RB + Start opens settings; R3 recentres. Up/down selects; left/right adjusts; A activates, B returns, Y resets the selected option, X opens compact preview. LB/RB changes categories and LT/RT changes subsections. The right stick adjusts TV distance when enabled.

Choose **Game Library → Library locations** and your main ROM folder containing the console subfolders (snes, nes, megadrive, gb, gba and so on). Select **Use this folder for my library**. The browser's **Computer drives** lists local/removable/mapped drives; **Open folder or network path…** accepts D:/roms or \\server\share\roms. Sign in to protected shares in Windows File Explorer first. Music uses the same path entry. No games or music are supplied. Games can be plain files or ZIPs; Sega CD CHDs go in a `segacd` folder.

Desktop and XR calibration are stored independently. Older Windows preview settings using a 50-degree field of view migrate to 24 degrees for glasses. Distance limits remain 1.2–5 metres; if a formerly small picture becomes very large, move the TV back with the right stick.

## Updates, data and feedback

Close the old app before running a new version. Extract updates into a new complete folder. Settings, music bookmarks and saves normally live in **%APPDATA%/Godot/app_userdata/CRT XR/**, separate from the app. Keep a backup and the previous release while testing.

Report issues at https://github.com/blackalice/CRT-XR/issues with Scenes & help → System → Copy diagnostics, Windows version, glasses model, display modes/scaling, controller and steps to reproduce. Review logs before sharing because they can contain local paths or radio URLs. The project is a public beta; code reviews, ideas and compatibility reports are welcome.
