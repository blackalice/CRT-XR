# Pre-launch checklist

Updated 17 October 2026. Candidate 0.1.0-beta.2 is for private review. The installer and guide are prepared; public release is not yet cleared.

| Area | State | Next acceptance step |
|---|---|---|
| App naming and existing-data migration | Implemented and automated | Verify a real upgrade and save restore |
| Gaming Mode SBS handoff | User confirmed mono → black → SBS works | Repeat after installer on a fresh Steam account/device |
| Prompt readability | Scaled logical canvas implemented | Confirm larger instructions through glasses |
| No-glasses launch | Forced test flags removed; Deck mono sizing added | Human test with glasses unplugged |
| Deck installer | Offline per-user installer and Linux transaction tests prepared | Run GUI against a real Steam account with Steam closed; verify correct settings branch, shortcut and controller layout |
| Updates/recovery | Existing app ID retained, prior builds and configuration backups retained; disk-failure rollback tested | Real upgrade followed by reinstall of prior package |
| Tracking prerequisite | Installer detects verified driver binary | Documented prerequisite: Decky Loader + XR Gaming already installed/enabled. Validate supported plugin/driver versions and clean-device calibration; CRT XR installer does not install the plugin |
| Getting-started guide | Written, included in Linux package | Have a tester follow it without developer assistance |
| Original source licence | MIT proposal written for owner review | Owner approval/copyright name; then add LICENSE |
| Bundled core distribution | Actual notices/source snapshots available | Resolve host/core licence obligations and provenance before public release |
| Reproducible emulator binaries | Pinned revisions and build script exist | Validate local builds for both platforms and record actual source/toolchain hashes |
| Model/source backup | Local verified model archive exists | Owner supplies off-machine destination; verify restore from clean checkout + asset bundle |
| Device reliability | Previous gameplay/audio/controller checks exist | Suspend/resume, glasses unplug/replug, missing SD, longer gameplay/music session |
| Package privacy/integrity | Payload hashes, no private media/save formats in package; installer installs listed payload only | Verify final archive hashes; checksums detect corruption, not publisher authenticity |
| Windows preview | Portable build route exists | Export current candidate and smoke-test the delivered folder |

## Installer scope

Setup runs in Desktop Mode, under the current user. It verifies the local package, asks before closing Steam, chooses the Steam account, installs immutable versioned payloads and updates a stable link. It writes Steam shortcuts plus the observed per-game ResolutionOverride2 setting only while Steam is closed; no live VDF edits, SSH, developer console, root or network downloads. Other configuration values are retained, although text formatting/comments are normalised by the strict parser. Unknown syntax stops installation before configuration changes.

The installer supports the tested VITURE 3840×1080 profile and a mono/monitor Native profile. This is not universal XR support or universal Steam-version compatibility. Other displays can use the lower-level explicit profile options documented in SBS-HANDOFF-TEST.md; a friendly persistent cross-device profile selector is a follow-up.

## Local validation records

Python tests cover shortcut binary round-trip, unrelated entries, app-ID/tag/launch-option preservation, resolution insertion, escaped text values, malformed formats, package corruption/traversal, Steam-running refusal, dry-run, multiple accounts, fresh install/update/save preservation, and rollback on a simulated configuration write failure. Linux transaction tests use temporary fixture homes, not the real Steam account. The Deck went offline during preparation, so actual installer acceptance remains outstanding.

## Release sequence

1. Finish clean-device installer + no-glasses/readability checks.
2. Resolve tracking setup, original-source licence choice and bundled-core distribution/provenance.
3. Verify external backup/rebuild and complete hardware soak checks.
4. Produce the reviewed package/source/checksum set, then explicitly approve publication. No public upload or repository publication is performed by this work.
