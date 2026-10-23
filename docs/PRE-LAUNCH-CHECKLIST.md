# Public beta release checklist

Updated 23 October 2026 for **0.1.0-beta.12**. These are observed checks and remaining beta limitations; they are not a claim of universal compatibility. Release files are prepared locally; publication is a separate action.

| Area | Verified | Remaining beta coverage |
|---|---|---|
| Steam Deck / VITURE Pro 2 | User confirmed tracking, SBS, controller operation, corrected prompt proportions and A → SBS handoff | Fresh Steam account/device, other plugin versions and glasses |
| Real Deck installer upgrade | GUI and .desktop launcher succeeded; original shortcut ID, controller settings and 42 user-data files preserved; payload/artwork hashes checked | Clean-account first install and broader Steam versions |
| Windows / VITURE Pro 2 | User confirmed SBS, head tracking after axis correction and Xbox navigation; per-monitor DPI fix matched all four Windows display modes | Updated FOV migration and browser changes need user acceptance; clean-user SDK setup, longer play, unplug/replug, suspend |
| Windows startup | User found SBS-before-launch more reliable; docs now recommend choosing the already-SBS glasses display | Wider display arrangements; desktop fallback has automated coverage |
| Video playback | Deck: system FFmpeg 7.1 with VA-API, release smoke test on a real episode and a 1080p clip (GPU and software); user-tested VCR text, tape look, sounds and menus on the Deck. Windows: clean first run downloaded FFmpeg 8.1.3 (8.5 s) and played on D3D11VA without a restart. Native decoder suite passes on FFmpeg 7.1 and 8.1 | 30-minute A/V drift and resume-across-restart acceptance in the glasses (owner testing); DVD/Blu-ray picture subtitles from real rips; other Linux distributions' FFmpeg builds |
| Other glasses | OpenTrack UDP source tested with loopback packets (48- and 52-byte, invalid and stale input, axis mapping, inversion, source switching); Deck EDID matching tested for VITURE, XREAL, Nreal, Rokid and RayNeo names and against a 32:9 monitor | Real XREAL, Rokid and RayNeo glasses: OpenTrack axis signs, field of view, Deck display names and SBS handoff |
| Windows SDK | Vendor files excluded from Git, exports and public archives; explicit user-supplied SDK setup documented | No claim of vendor redistribution permission; do not bundle proprietary DLLs |
| App regression checks | Automated suites with isolated preferences, multicore synthetic probes and source provenance for all twenty platform/core builds | See release BUILD-RECORD.json for the candidate's actual executed results |
| Source and licences | MIT original code; conservative GPL host/core treatment; exact core sources/build records; asset attributions and TV historical CC BY evidence retained | Keep corresponding-source archive and notices alongside binaries; no claim that the whole collection is MIT or commercially unrestricted |
| Local artistic assets | Prepared models, source hashes and contact bakes validated | Off-machine recovery backup remains the owner's responsibility |
| Privacy and integrity | Packages exclude ROMs, music, saves, credentials and local SDK; manifests/checksums generated | Checksums are integrity checks, not code signing; Windows binaries remain unsigned |

## Known limits to disclose

Only VITURE Pro 2 has been tested. Steam Deck tracking needs Decky Loader and XR Gaming with support for the connected glasses and compatible tracking IPC. Updated driver binaries are no longer blocked by file hashes; beta.7 was installed on the real Deck and the user confirmed tracking works again. Windows tracking needs a separately supplied VITURE SDK; other brands require a different backend. No automatic updater or crash uploader is present.

Thirteen systems are supported; see [emulation](emulation.md) for extensions and BIOS requirements. Cartridges may be zipped and Sega CD discs may be CHD (identified by their Sega CD folder); 7z/RAR, discs inside ZIPs and PC Engine CD are unsupported. PC Engine, Atari 2600, Lynx and Vectrex still need real-game testing. Sega CD requires the BIOS for the disc's region; having only another region's BIOS can still produce a generic core rejection. Videos: MP4, M4V and MKV through the system FFmpeg (7.1 or 8) or the optional Windows download; no DVD folders, ISOs, menus or streaming; codecs follow the FFmpeg in use. MP3 files up to 256 MiB and direct MP3 radio are supported. Large/slow album loads are synchronous and can briefly stall the menu. AAC/HLS/DRM/station webpages and radio time-shifting are unsupported. Long sessions, suspend/reconnect, missing network storage and broader hardware remain beta test requests.

## Publish the prepared candidate

1. Read the release folder's START-HERE.md and BUILD-RECORD.json, including any failed or skipped checks.
2. Commit the reviewed source and tag the matching snapshot as v0.1.0-beta.12. The corresponding-source archive identifies the exact supplied files even while this checkout is uncommitted. Regenerate the candidate if source changes after packaging.
3. Create a GitHub **prerelease**, paste RELEASE-NOTES.md and upload every file from upload/, including corresponding source and SHA256SUMS.txt. Keep third-party notices inside both app packages.
4. Confirm public download links work, then post the launch video and beta invitation. No upload or social post is sent automatically.
