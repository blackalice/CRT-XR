# CRT XR 0.1.0-beta.14.1 — beta.14 hotfix

A small update to beta.14, fixing screen-glow rendering, view shifts after
temporary tracking interruptions, and a crash when opening NES games.

## Downloads

| Platform | Download |
|---|---|
| Steam Deck | `CRT-XR-0.1.0-beta.14.1-SteamDeck.tar.gz` |
| Windows | `CRT-XR-0.1.0-beta.14.1-Windows.zip` |

On Steam Deck, extract the archive in Desktop Mode and run **Install CRT XR**.
On Windows, extract to a new folder and run **CRT-XR.exe**. Existing settings,
ROM locations, battery saves and save states carry over.

The `…-source-code.tar.gz` download is the corresponding source and build
inputs, including the NES core patch; it is not an app package.

## Fixed

- **Screen glow washing out the picture and clock digits.** After sustained
  Steam Deck play, looking in certain directions could abruptly turn the
  picture white/cyan. Any nonzero Screen glow brought it back; zero cleared it.
  The screen lights now run without their live cube-shadow passes, retaining
  coloured room lighting. The owner reports that this resolves the effect.
  More light may reach beneath the table. Screen bloom is unchanged.
- **View shifts after a temporary tracking gap.** Stale tracking now preserves
  the room anchor when samples return, including interruptions around save-state
  loading. Reported driver disconnects retain the existing recovery behaviour;
  R3 still recentres. Loading a save can still briefly pause the app.
- **NES startup/reopen crash.** Nestopia could pass an uninitialized background
  colour into its NTSC filter and crash on the first frame after opening a game.
  Both platform cores now initialize the value on construction/reset and bound
  its filter lookup index. This preserves the core identity and save-state layout.
- **Avoidable lighting work.** Paused pictures reuse their last lighting sample,
  and screen-light range is updated only when TV scale changes.

## Validation

The original NES crash was reproduced on Steam Deck with Mega Man 3 (US),
without room rendering or input preview. The rebuilt Linux core passed ten
open/run/save-state-restore/reset cycles with preview off and ten with it on.
Lighting and tracking-recovery checks also passed on the Deck. Windows package
and core checks are included in the release build record; real Windows glasses
and other glasses models still need hardware testing.

All beta.14 features and requirements remain. See the
[beta.14 release notes](https://github.com/blackalice/CRT-XR/releases/tag/v0.1.0-beta.14)
for setup, supported glasses and known limitations. No games, BIOS files or media
are included. Upstream licences, notices and corresponding source accompany the
downloads. Windows binaries remain unsigned.
