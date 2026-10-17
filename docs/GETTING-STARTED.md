# Getting started with CRT XR

Public beta candidate: 0.1.0-beta.4. This is an early beta; testing so far has been on Steam Deck with VITURE Pro 2. No games or music are included.

## Before you start

**Install Decky Loader and its XR Gaming plugin before using CRT XR with head tracking.** **VITURE Pro 2 currently requires the testing version of XR Gaming, rather than the stable release.** Most XR users will already have Decky and XR Gaming, but Pro 2 users should check which version they have. Confirm XR Gaming recognises your glasses and its driver is enabled. CRT XR setup assumes the plugin is installed; it does not install Decky Loader or XR Gaming for you. Keep XR Gaming's display effects disabled when CRT XR is managing the stereo view.

## Install on Steam Deck

1. Switch to **Desktop Mode** from the Deck's Power menu. Sign in to Steam at least once before setup.
2. Download the complete Linux package and extract it with the Deck's archive manager. Keep the extracted files together until installation finishes.
3. Open **Install-CRT-XR.sh** in the extracted folder and choose **Execute / Run**. If the file manager opens it as text, right-click → Properties → Permissions → enable executable, then run it. Alternatively, open a terminal in the extracted folder and run `bash ./Install-CRT-XR.sh`.
4. Choose **VITURE Full SBS** for our tested glasses setup, or **Deck / monitor only**. The VITURE profile supports playing without glasses as well. Other glasses need manual display/profile setup during this beta.
5. Finish any running game, then allow setup to close Steam. If there are several Steam accounts, choose the account you use. Setup verifies the files, installs CRT XR in your home folder, backs up configuration and adds or updates its Steam shortcut. It needs no administrator password and does not enable SSH or Steam debugging.
6. Steam restarts after setup. Choose **Return to Gaming Mode**, then open **Library → Non-Steam → CRT XR**. Keep compatibility/Proton disabled: this is a native Linux application.

Fresh-device installer and controller-layout acceptance are still pending. If Steam's controller layout is not a gamepad, select the **Gamepad With Joystick Trackpad** template for CRT XR. The installer preserves an existing CRT XR shortcut's app ID and controller settings.

## First play

**Without glasses:** launch CRT XR normally. It starts in mono on the Deck. No SBS prompt should appear.

**With the tested VITURE setup:** connect the glasses directly in mono, then launch CRT XR. Read the instructions, release the launch button, press A, then switch the glasses to SBS using their button. The app stays black during the switch and reveals the room once the mode and app dimensions settle. There is no need to navigate Steam's flat interface through SBS during this normal flow.

If it stays black, X retries. To leave, return the glasses to mono and press B / Escape. First-install Steam/display behaviour still needs a clean-device test. The tested resolution override for this profile is 3840×1080; Native alone did not work on our Deck.

Open **Game library → Library locations** and choose your main ROM folder, including an SD card. Relevant supported systems appear automatically. Open a game; bring your own uncompressed SNES, NES, Mega Drive, Master System or Game Gear ROMs.

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
└── gamegear/
    └── Game.gg
```

CRT XR discovers supported games in subfolders and presents them by system; you do not need to move ROMs into the app folder. Common folder aliases such as `genesis`, `superfamicom`, `sms` and `gg` are recognised. Folder names help discovery, while the supported file type/content chooses the emulator core. You can also select a single supported system folder or browse to a game directly.

Known unsupported system folders and artwork/BIOS/save folders are skipped when scanning the main library, so a larger multi-system collection is fine. Only supported, recognised cartridges appear. ROMs must be **uncompressed**; ZIP archives are not scanned as games. No ROMs are supplied.

In folder and game lists, **left/right jumps ten entries** and holding a direction continues scrolling. Jumps stop at the ends and cross game-list pages. **LB/RB** still changes whole game pages. To change the saved folder later, use **Library locations**.

## Head tracking prerequisite

**XR Gaming for Decky Loader must already be installed and enabled.** It provides the XR driver used for tracking. **Pro 2 users need its testing version.** Confirm it recognises your glasses before testing CRT XR. The project is [XR Gaming](https://github.com/wheaney/decky-XRGaming).

CRT XR setup checks for the supported driver binary. Other SBS/3DoF glasses are expected to work when their tracking is exposed through a compatible driver, but only Pro 2 has been tested. Automatic detection currently recognises VITURE; other models may need an explicit display profile. Plugin installation alone does not prove that its driver version is compatible with this beta. If the check fails, CRT XR can use fixed view; record the message so we can check the plugin/driver version. Setup does not install or update Decky, replace drivers, modify USB rules or change the driver's settings. Do not remove an already working XR Gaming installation just to run CRT XR setup.

## Updates and recovery

Run the installer from the next complete package. It updates the existing entry instead of deliberately creating another shortcut, preserves settings/saves, and retains previous program versions. Re-running an older package reinstalls that version. Close CRT XR before updating. Steam must close while its configuration is changed.

Steam artwork is installed automatically: portrait/landscape covers, hero, logo and shortcut icon. Updates refresh artwork installed by CRT XR while preserving later custom artwork. Steam must restart before the library reflects changes.

Programs: `~/Applications/CRT-XR/releases/`, with a stable `current` link. Install receipts/backups: `~/Applications/CRT-XR/`. Backups can contain Steam-local account/configuration details; do not share them. Settings/saves: `~/.local/share/godot/app_userdata/CRT XR/`; these are separate from the app and never removed by setup. Old RetroCRT XR data is copied on first app launch without deleting originals.

If setup reports an unsupported Steam configuration, it stops rather than guessing. Keep the error text and use the existing working build; report your SteamOS version and whether Steam was fully closed. The installer is tested with synthetic Steam configuration and the observed current Steam resolution field; broader Steam-version acceptance remains pending.

## Windows preview

Extract the complete Windows package and run **CRT-XR.exe**. Keep its neighbouring folders/files together. This is an unsigned portable preview; the Steam Deck setup script is for Linux only. Windows offers mono/SBS simulation, not the Linux tracking driver.

## Report a problem

Use **General → Copy diagnostics**. Include your device, Desktop/Gaming Mode, mono/SBS, the steps and what happened. Review logs before sharing: local paths or stream URLs can appear. Settings, games and music need not be sent.
