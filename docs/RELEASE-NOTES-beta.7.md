# CRT XR 0.1.0-beta.7 — XR Gaming driver compatibility fix

This beta fixes head tracking being rejected after updating XR Gaming, including the newer driver with VITURE Pro 2 support.

- Removed exact driver-binary and plugin-API hash restrictions from Linux tracking, the installer and the SBS control helper.
- Kept runtime shared-memory layout/ownership checks, valid quaternion checks and stale-pose handling. Compatible driver updates can work without a new app allowlist; incompatible or missing tracking still reports an error/fixed view.
- Added regression coverage for changed driver/API builds and actionable missing-driver errors.
- Updated setup guidance to require an XR Gaming version supporting your glasses, rather than a single pinned binary.

**Verified on Steam Deck:** installed beta.7 with the updated XR Gaming driver; the user confirmed tracking works again. Existing settings and saves were preserved. Windows is rebuilt at the same version for consistency; its tracking backend is unchanged.

## Downloads and updating

- **Steam Deck/Linux:** download the complete Linux archive. In Desktop Mode, extract it and run **Install CRT XR.desktop** to update the existing Steam entry. Keep XR Gaming installed and enabled; this app update does not replace your driver. Do not delete your existing shortcut or saves.
- **Windows:** extract the complete ZIP and keep CRT-XR.pck beside the EXE. VITURE tracking still needs the separately supplied SDK; vendor DLLs are not bundled. See WINDOWS-SETUP.md.
- **Corresponding source:** provided alongside both packages, with exact pinned core sources/build evidence and the application source snapshot. Retain it and the third-party notices when redistributing. SHA256SUMS.txt covers release assets.

This remains an early public beta. Only VITURE Pro 2 has tested native tracking. Other glasses, clean-device setup, suspend/reconnect and extended sessions need wider feedback. ROMs/music are not included. Windows binaries are unsigned. Original code is MIT; cores/assets retain their own terms, and the complete collection is not wholly permissive or commercially unrestricted.

Report bugs, compatibility results and suggestions at https://github.com/blackalice/CRT-XR/issues . Include platform, glasses, XR Gaming version, mono/SBS and reproduction steps. Review logs before sharing private paths or URLs.
