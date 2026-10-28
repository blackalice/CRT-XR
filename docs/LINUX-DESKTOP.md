# General Linux installer preview

This is a native **x86-64 Linux** desktop build, based on beta.14.1. It can be
installed and played without Steam, Decky Loader or XR software. The existing
Steam Deck installer and Gaming Mode launcher remain available separately.

## Install or update

Extract the Linux desktop archive and run **Install CRT XR**. If your file
manager asks, allow execution or choose **Trust and Launch**. The installer
uses KDialog or Zenity when available and otherwise prints its result in the
terminal opened by the launcher. Find **CRT XR** in your application menu.

Terminal alternative, from the extracted folder:

```sh
bash "CRT XR files/Install-CRT-XR-Linux.sh" --no-gui
```

Close CRT XR before updating. The app is installed under
`~/Applications/CRT-XR/releases/`, with a `current` link selecting the active
build. A menu shortcut is written under `$XDG_DATA_HOME/applications/` (normally
`~/.local/share/applications/`). Previous builds and shortcut backups are kept
under the installation directory. Settings and saves stay in Godot's existing
`CRT XR` user-data directory. No system packages or XR drivers are installed.

The current binaries require **glibc 2.38+**, **GLIBCXX_3.4.32** support from
libstdc++, **Python 3.9+**, and working OpenGL 3.3/GPU drivers. The installer
checks architecture, libc and binary dependencies before copying. This is not
an ARM or musl build. Older distributions need a future build against an older
runtime baseline. Video playback additionally needs the system FFmpeg libraries
supported by CRT XR; emulation does not require FFmpeg.

## Play on a normal screen

Open **CRT XR** from your application menu. This uses a mono fixed/simulated
view without changing your display layout or driver configuration. Keyboard and
gamepad controls are the same as the other builds. Choose your ROM folder under
**Game library → Library locations**; games and BIOS files are not supplied.

## Play with XR glasses

Install and enable a compatible **XR Linux Driver**, for example through Breezy
Desktop. Decky Loader is not needed on other Linux desktops. Do not install a
second competing driver setup over an existing XR Gaming installation.

Use the installed launcher's **Play with XR glasses** action, or run:

```sh
~/Applications/CRT-XR/current/launch-linux.sh --glasses
```

On KDE with `kscreen-doctor`, the existing display-session helper can select the
glasses, handle SBS and restore the display layout. On other desktops the
launcher uses manual SBS: first switch the glasses to SBS and select their
display/primary output using your desktop's display settings. It does not
automatically rearrange GNOME or other desktops' displays. To force manual
setup, including on KDE:

```sh
~/Applications/CRT-XR/current/launch-linux.sh --manual-sbs
# Optional Godot display index, starting at 0:
~/Applications/CRT-XR/current/launch-linux.sh --manual-sbs --screen 1
```

For both glasses paths, the launcher temporarily requests tracking-only output
from the existing XR driver; CRT XR supplies its own stereo room and head
tracking. The prior driver settings are restored when the app exits or crashes.
If the launcher itself is forcibly killed, the existing recovery journal is
processed at the next glasses launch. User changes to driver settings during a
session are retained where they differ from CRT XR's temporary values.

Logs are in `$XDG_STATE_HOME/crt_xr/` (normally `~/.local/state/crt_xr/`), notably
`godot-linux.log` for ordinary/manual launches or `godot.log` for managed KDE
display sessions. Different distributions, compositor versions and glasses still
need hardware acceptance; installing successfully is not a guarantee of XR
compatibility.

## Optional Steam integration

Steam integration is opt-in and needs a native Steam installation with an
existing account. Close Steam first, then run:

```sh
bash "CRT XR files/Install-CRT-XR-Linux.sh" --integration steam
```

This uses the existing Steam installer, including account/display-profile
selection, shortcut/artwork preservation and Steam configuration backups.
Command-line setup is also available with `--no-gui --account <Steam user ID>`.
The standalone desktop installer does not close Steam or change its files.
