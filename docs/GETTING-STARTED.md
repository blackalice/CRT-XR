# Getting started with CRT XR

Public beta: 0.1.0-beta.10. VITURE Pro 2 has been tested on Steam Deck and Windows; other hardware remains unverified. No games or music are included.

## Before you start

**Install Decky Loader and its XR Gaming plugin before using CRT XR with head tracking.** **VITURE Pro 2 requires an XR Gaming version with Pro 2 support, rather than the stable release.** Most XR users will already have Decky and XR Gaming, but Pro 2 users should check which version they have. Confirm XR Gaming recognises your glasses and its driver is enabled. CRT XR setup assumes the plugin is installed; it does not install Decky Loader or XR Gaming for you. Keep XR Gaming's display effects disabled when CRT XR is managing the stereo view.

The download contains just **Install CRT XR**, **HOW TO INSTALL.txt** and a **CRT XR files** folder. Keep them together: the launcher installs from that folder and does not download anything. KDE may ask you to **Trust and Launch**. `CRT XR files/Install-CRT-XR.sh` remains available as a fallback.

## Install on Steam Deck

1. Switch to **Desktop Mode** from the Deck's Power menu. Sign in to Steam at least once before setup.
2. Download `CRT-XR-<version>-SteamDeck.tar.gz` and extract it (right-click → Extract). Keep the extracted folder together until installation finishes.
3. Double-click **Install CRT XR** in the extracted folder. Choose **Trust and Launch** if prompted; if needed, right-click → Properties → Permissions → allow execution.
4. Choose **VITURE Full SBS** for our tested glasses setup, or **Deck / monitor only**. The VITURE profile supports playing without glasses as well. Other glasses need manual display/profile setup during this beta.
5. Finish any running game, then allow setup to close Steam. If there are several Steam accounts, choose the account you use. Setup verifies the files, installs CRT XR in your home folder, backs up configuration and adds or updates its Steam shortcut. It needs no administrator password and does not enable SSH or Steam debugging.
6. Restart Steam yourself, or choose **Return to Gaming Mode**, then open **Library -> Non-Steam -> CRT XR**. Setup does not start a detached Steam process. Keep compatibility/Proton disabled: this is a native Linux application.

The real-account upgrade was tested on 17 October 2026: the original shortcut ID, controller values, artwork and preferences were preserved. Fresh-device controller-layout acceptance remains pending. If Steam's controller layout is not a gamepad, select the **Gamepad With Joystick Trackpad** template for CRT XR. The installer preserves an existing CRT XR shortcut's app ID and controller settings.

## First play

**Without glasses:** launch CRT XR normally. It starts in mono on the Deck. No SBS prompt should appear.

**With the tested VITURE setup:** connect the glasses directly in mono, then launch CRT XR. Read the instructions, release the launch button, press A, then switch the glasses to SBS using their button. The app stays black during the switch and reveals the room once the mode and app dimensions settle. There is no need to navigate Steam's flat interface through SBS during this normal flow.

If it stays black, X retries. To leave, return the glasses to mono and press B / Escape. First-install Steam/display behaviour still needs a clean-device test. The tested resolution override for this profile is 3840×1080; Native alone did not work on our Deck.

Open **Game library → Library locations** and choose your main ROM folder, including an SD card. Relevant supported systems appear automatically. Open a game; bring your own uncompressed games for any supported console (see the README list).

L1 + R1 + Start opens the menu. Up/down selects, left/right adjusts, A activates and B returns. R3 recentres. Music controls sit above the normal menu actions without taking the default selection.

## ROM folders

On first use, choose **Game library → Set up your ROM library**. Existing libraries in common EmuDeck, RetroDECK and SD-card locations are suggested when found. Open your **main ROM folder**, then choose **Use this folder for my library**—the folder containing the console folders. An existing EmuDeck-style layout can stay where it is, including on an SD card:

```text
roms/
├── snes/
│   ├── Game.sfc
│   └── RPGs/
│       └── Another game.smc
├── nes/
│   └── Game.nes
├── megadrive/       # genesis/ also works
│   └── Game.md
├── mastersystem/
│   └── Game.sms
├── gamegear/
│   └── Game.gg
├── gb/              # gbc/ gameboy/ also work
│   └── Game.gb
├── gba/
│   └── Game.gba
├── pcengine/        # tg16/ turbografx16/ also work
│   └── Game.pce
├── segacd/          # megacd/ also works; needs the CD BIOS files
│   ├── Game.cue
│   └── Game.bin
├── atari2600/       # atari/ atarivcs/ also work
│   └── Game.a26
├── atarilynx/       # needs lynxboot.img
│   └── Game.lynx
├── ngpc/            # ngp/ neogeopocket/ also work
│   └── Game.ngpc
└── vectrex/
    └── Game.vec
```

CRT XR discovers supported games in subfolders and presents them by system; you do not need to move ROMs into the app folder. Common folder aliases such as `genesis`, `superfamicom`, `sms` and `gg` are recognised. Folder names help discovery, while the supported file type/content chooses the emulator core. You can also select a single supported system folder or browse to a game directly.

Known unsupported system folders and artwork/BIOS/save folders are skipped when scanning the main library, so a larger multi-system collection is fine. Only supported, recognised cartridges appear. ROMs must be **uncompressed**; ZIP archives are not scanned as games. Sega CD and Atari Lynx are the two exceptions that need hardware files: put the Sega CD BIOS (`bios_CD_U.bin`, `bios_CD_E.bin`, `bios_CD_J.bin` as your discs require) and the Lynx boot ROM (`lynxboot.img`) in a `bios` folder next to the CRT XR application — the library tells you what is missing and never rewrites your ROMs. No ROMs are supplied.

In folder and game lists, **left/right jumps ten entries** and holding a direction continues scrolling. Jumps stop at the ends and cross game-list pages. **L1/R1** still changes whole game pages. To change the saved folder later, use **Library locations**.

## Head tracking prerequisite

**XR Gaming for Decky Loader must already be installed and enabled.** It provides the XR driver used for tracking. **Use an XR Gaming release with Pro 2 support; older stable installations may need the testing channel.** Confirm it recognises your glasses before testing CRT XR. The project is [XR Gaming](https://github.com/wheaney/decky-XRGaming).

CRT XR setup checks for the supported driver binary. Other SBS/3DoF glasses are expected to work when their tracking is exposed through a compatible driver, but only Pro 2 has been tested. Automatic detection currently recognises VITURE; other models may need an explicit display profile. Plugin installation alone does not prove that its driver version is compatible with this beta. If the check fails, CRT XR can use fixed view; record the message so we can check the plugin/driver version. Setup does not install or update Decky, replace drivers, modify USB rules or change the driver's settings. Do not remove an already working XR Gaming installation just to run CRT XR setup.

## Updates and recovery

Run the installer from the next complete package. It updates the existing entry instead of deliberately creating another shortcut, preserves settings/saves, and retains previous program versions. Re-running an older package reinstalls that version. Close CRT XR before updating. Steam must close while its configuration is changed.

Steam artwork is installed automatically: portrait/landscape covers, hero, logo and shortcut icon. Updates refresh artwork installed by CRT XR while preserving later custom artwork. Steam must restart before the library reflects changes.

Programs: `~/Applications/CRT-XR/releases/`, with a stable `current` link. Install receipts/backups: `~/Applications/CRT-XR/`. Backups can contain Steam-local account/configuration details; do not share them. Settings/saves: `~/.local/share/godot/app_userdata/CRT XR/`; these are separate from the app and never removed by setup. Old RetroCRT XR data is copied on first app launch without deleting originals.

If setup reports an unsupported Steam configuration, it stops rather than guessing. Keep the error text and use the existing working build; report your SteamOS version and whether Steam was fully closed. The installer is tested with synthetic Steam configuration and the observed current Steam resolution field; broader Steam-version acceptance remains pending.

## Windows preview

Extract `CRT-XR-<version>-Windows.zip` to a folder and double-click **CRT-XR.exe** (if Windows warns about an unrecognised app, choose **More info → Run anyway**). Keep the files and folders next to it together. This is an unsigned portable preview; the Steam Deck setup script is for Linux only. Native Windows VITURE tracking is being validated with Pro 2 and a separately supplied SDK. See [Windows setup](WINDOWS-SETUP.md). Use Play without glasses for a fixed mono view.

## Report a problem

Use **General → Copy diagnostics**. Include your device, Desktop/Gaming Mode, mono/SBS, the steps and what happened. Review logs before sharing: local paths or stream URLs can appear. Settings, games and music need not be sent.

## Gaming Mode tracking without a virtual display

Leave XR Gaming’s virtual display off for CRT XR. With connected glasses, the Steam launcher temporarily enables driver tracking in external-only/none mode and disables the Gamescope XR effect. Previous driver settings restore on normal exit. A recovery record restores owned settings on the next CRT XR launch after an interrupted session; changes made through XR Gaming while the app runs are preserved. No plugin or driver binary is replaced.

Motion prediction now defaults to 0 ms. Existing preferences are retained: if head movement feels ahead of you, set Controls & XR → Advanced calibration → Motion prediction to 0 ms before changing FOV.
