# CRT XR 0.1.0-beta.8 — Gaming Mode tracking fix

Fixes the Gaming Mode conflict where enabling XR Gaming's virtual display was needed for tracking but caused extra display movement and SBS glitches.

- **Leave XR Gaming's virtual display OFF.** For connected glasses in Gaming Mode, CRT XR temporarily enables raw driver output with the external display effect set to none and Gamescope XR integration disabled. CRT XR supplies the SBS view and head tracking itself.
- Previous driver settings restore on normal exit. Interrupted sessions recover on the next CRT XR launch. Changes made by the user through XR Gaming while the app runs are preserved.
- **Motion prediction defaults to 0 ms.** The previous 30 ms lead could feel oversensitive with the updated driver. Existing preferences remain unchanged: set Controls & XR → Advanced calibration → Motion prediction to 0 ms if needed.
- Includes beta.7's removal of exact driver/API fingerprint restrictions. Runtime IPC layout/ownership, pose validity and freshness checks remain.

**Hardware acceptance:** the user confirmed Gaming Mode head tracking works with virtual display off, and that 0 ms feels better. Driver configuration was verified restored after exit. Automated checks cover normal/error exits, interrupted-session recovery and preserving user changes. The beta.7 candidate was held as an unpublished draft when this issue was found; beta.8 supersedes it.

## Downloads

**Steam Deck/Linux:** extract the complete Linux archive in Desktop Mode and run Install CRT XR.desktop to update the existing Steam entry. XR Gaming must already be installed with support for your glasses. Leave its virtual display off, launch in mono, press A at the prompt and switch SBS as usual. Keep the existing shortcut and saves.

**Windows:** extract the full ZIP, keeping CRT-XR.pck and neighbouring files with the EXE. Native VITURE tracking requires a separately supplied SDK; vendor DLLs are not bundled. Put glasses in SBS before launching, choose their display, then Open glasses view. The Gaming Mode launcher change is Linux-only; the new prediction default applies to both platforms.

Matching corresponding source and SHA256SUMS.txt accompany both packages. Original source is MIT; imported cores/assets retain their own licences and restrictions. Keep notices/source available when redistributing. Windows binaries are unsigned.

This remains an early public beta. Only VITURE Pro 2 has tested native tracking; other glasses/controllers, clean-user setup, suspend/reconnect and long sessions need wider feedback. No games or music are supplied. Report issues and suggestions at https://github.com/blackalice/CRT-XR/issues with platform, glasses, XR Gaming version and reproduction steps; review logs before sharing private paths/URLs.
