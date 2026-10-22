# CRT XR — Windows beta setup

Version: 0.1.0-beta.8. Tested with VITURE Pro 2 and an Xbox-compatible controller.

## Extract the app

Download `CRT-XR-<version>-Windows.zip` from https://github.com/blackalice/CRT-XR/releases and extract it to a folder. Double-click **CRT-XR.exe**; it is unsigned, so if Windows warns, choose **More info → Run anyway**. There is nothing to install and Steam is optional. Keep the EXE with the files and folders next to it (`CRT-XR.pck`, the extension DLL, `cores`, `assets`, `tracking`, `docs`, `licenses`).

Without glasses, choose **Play on this screen without glasses**. No VITURE SDK is needed for this path.

## Set up VITURE tracking

The proprietary VITURE SDK is **not bundled**. Obtain the Windows x86_64 glasses SDK from the official developer page: https://www.viture.com/developer . Follow its terms and Windows driver prerequisites. SpaceWalker installation alone does not put the SDK in CRT XR's folder.

Create a folder named **sdk** beside CRT-XR.exe, then copy the **contents of the SDK's x86_64 directory** into it. Keep all its dependency DLLs together, including glasses.dll and libusb-1.0.dll. You do not need to copy headers, demo programs or the original ZIP. CRT XR does not download these files, alter USB drivers or enable SDK telemetry.

Close SpaceWalker before tracking so it does not compete for the same USB device. Connect glasses directly to the PC. **Switch glasses into SBS before launching CRT XR.** Use your normal monitor for setup, choose the glasses display and select **Open glasses view**. CRT XR keeps the view black while moving to that display and waits for a stable, plausible full-SBS mode; its resolution is read from the selected display. The SBS button remains manual.

If the view stays black, return the glasses to mono and press B / Escape to retry. Recheck the selected display and Windows' active display mode. If tracking is unavailable, check the USB connection, SDK files and whether SpaceWalker is closed; **Controls & XR → Tracking** has a retry and fixed-view option. Other brands of glasses are not supported by this VITURE backend. Reconnect/suspend reliability on other computers is not yet established.

## Controls and games

Xbox/XInput-compatible controllers work directly, without Steam desktop mappings. LB + RB + Start opens settings; R3 recentres. Up/down selects; left/right adjusts; A activates, B returns, Y resets the selected option, X opens compact preview. LB/RB changes categories and LT/RT changes subsections. The right stick adjusts TV distance when enabled.

Choose **Game library → Library locations** and your main ROM folder containing the console subfolders (snes, nes, megadrive, gb, gba and so on). Select **Use this folder for my library**. The browser's **Computer drives** lists local/removable/mapped drives; **Open folder or network path…** accepts D:/roms or \\server\share\roms. Sign in to protected shares in Windows File Explorer first. Music uses the same path entry. No games or music are supplied. ROMs must be uncompressed; ZIP games are not supported.

Desktop and XR calibration are stored independently. Older Windows preview settings using a 50-degree field of view migrate to 24 degrees for glasses. Distance limits remain 1.2–5 metres; if a formerly small picture becomes very large, move the TV back with the right stick.

## Updates, data and feedback

Close the old app before running a new version. Extract updates into a new complete folder. Settings, music bookmarks and saves normally live in **%APPDATA%/Godot/app_userdata/CRT XR/**, separate from the app. Keep a backup and the previous release while testing.

Report issues at https://github.com/blackalice/CRT-XR/issues with General → Copy diagnostics, Windows version, glasses model, display modes/scaling, controller and steps to reproduce. Review logs before sharing because they can contain local paths or radio URLs. The project is a public beta; code reviews, ideas and compatibility reports are welcome.
