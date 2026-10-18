# CRT XR 0.1.0-beta.6 — public beta

A little CRT room for your XR glasses: retro games, an anchored television, a tunable CRT picture and your music in the background.

**This is an early public beta. Please try it, report problems, and contribute ideas, compatibility reports or code reviews.** Built with substantial AI coding assistance; additional eyes on the code and setup are welcome.

## Downloads

- **Windows:** CRT-XR-0.1.0-beta.6-windows.zip. Extract everything; keep CRT-XR.pck beside the EXE. Native Xbox-compatible controls. VITURE tracking needs the separately obtained Windows SDK copied into sdk/ beside the app; proprietary SDK DLLs are not included. Read WINDOWS-SETUP.md. Close SpaceWalker, put glasses in SBS first, launch on a normal monitor, select their display, then Open glasses view. Monitor-only play needs no SDK.
- **Steam Deck/Linux:** CRT-XR-0.1.0-beta.6-linux.tar.gz. In Desktop Mode, extract and open Install CRT XR.desktop. Tracked Deck use needs Decky Loader and XR Gaming already installed; Pro 2 currently needs its testing version and a supported driver. On Deck, launch in mono, press A at the prompt, then switch SBS. This flow differs from Windows.
- **Corresponding source:** CRT-XR-0.1.0-beta.6-corresponding-source.tar.gz. Exact application/build inputs and pinned emulator source materials. Keep available alongside the binaries. GitHub's automatic source ZIP is not the app download.
- SHA256SUMS.txt verifies archive integrity; binaries are unsigned and checksums do not authenticate the publisher.

## Included

SNES, NES, Mega Drive/Genesis, Master System and Game Gear; adjustable CRT/signal effects and screen fitting; 3DoF head tracking; room lighting, baked contact shadows and stereo audio; save states and auto resume; ROM-root/SD library indexing, Recent and Favourites; screenshots; MP3 albums/direct MP3 radio, seeking, optional game-volume dip and silent restoration of the last music position.

This candidate adds Windows VITURE tracking and corrected axes, explicit display selection, mixed-DPI resolution handling, local/mapped-drive and UNC folder access, and independent desktop/XR FOV calibration. The public Windows package uses the user's own SDK rather than bundling vendor DLLs.

## Tested and still to test

VITURE Pro 2 is the only tested glasses model. Core Windows tracking/SBS/Xbox operation and the DPI correction have user confirmation; Deck tracking/SBS/controller operation and real installer upgrade/.desktop launch have prior user acceptance. The latest FOV/browser refinements have automated coverage and need broader user feedback. Clean-user SDK setup, fresh Steam accounts, other glasses/controllers, unplug/replug, suspend/resume and long gameplay/music sessions remain beta test requests. Windows and Deck SDK/driver requirements differ; SBS plus 3DoF hardware alone does not guarantee tracking support.

ROMs must be uncompressed. No ROMs, BIOS files or music are included. Radio is direct MP3 only, not HLS/AAC/DRM/station webpages. Large music/album loads can briefly stall the UI. No automatic updater or crash uploader is included.

## Feedback

Use https://github.com/blackalice/CRT-XR/issues and include General → Copy diagnostics, platform/OS, glasses, controller, mono/SBS, display scaling/resolution and reproduction steps. Review logs for private paths/URLs before sharing. Suggestions and pull requests are welcome.

Original code is MIT; bundled cores/assets retain their own terms. The complete collection is not wholly MIT or commercially unrestricted. Retain all notices and the companion corresponding-source download.
