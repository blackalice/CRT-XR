# CRT XR — UX review (15 Nov 2026)

Scope: download → install → first run → everyday use → settings → new features. Based on the repo at `d60aab6` (dev build after beta.15), README and docs, installer scripts, menu code and the first-run captures in `build/welcome-review/`. Not tested on hardware.

Priority key: **P1** fix before the next public release · **P2** high value, next few builds · **P3** later / nice to have.

---

## 1. Download and install

The Deck installer is in good shape: it handles Steam's config, artwork and the 3840×1080 profile, keeps settings, and needs no SSH or sudo. The friction is in what happens **around** it.

| # | Issue | Suggestion | Pri |
|---|---|---|---|
| 1.1 | **XR Gaming prerequisite is the biggest drop-off.** Users need Decky + XR Gaming *on the testing channel* for Pro 2. The installer assumes it's there. | Have the installer check for Decky and XR Gaming and report one of: "Ready for head tracking", "XR Gaming not found (link)", "XR Gaming found but too old for Pro 2: switch to the testing channel". Show the same status on the first-run **Your view** step. | P1 |
| 1.2 | Setup ends with "restart Steam yourself". | End with a **Return to Gaming Mode** button (`steam://` / `qdbus` session switch) so the last step is one press. | P2 |
| 1.3 | **Windows VITURE SDK is a manual copy** of DLLs into a `sdk` folder beside the EXE. Easy to get wrong (wrong subfolder, or copying the ZIP). | Add **Locate VITURE SDK…** to the Windows launch screen and View & glasses → Tracking. Let users pick the SDK folder or ZIP, find `x86_64/glasses.dll` and copy what's needed into user data. Also warn if SpaceWalker is running. | P1 |
| 1.4 | On Windows the glasses must be in SBS **before** launch. The Deck already watches for the SBS switch live. | Let the Windows launch screen watch the chosen display and continue when it changes to full SBS, so the order doesn't matter. | P2 |
| 1.5 | **No update check.** Updating means downloading again and re-extracting (Windows leaves a new folder each time). | Add an opt-in **Check for updates** on the Help page (GitHub Releases API, version compare, link to the page), and show "What's new" once after an update. Later, consider itch.io + butler, or Scoop/winget for Windows. | P2 |
| 1.6 | Windows binaries are unsigned (SmartScreen warning). | Keep the clear instructions. If downloads grow, an OV certificate or SignPath (free for OSS) removes the warning. | P3 |
| 1.7 | **README is ~26 KB.** Before anyone sees Install, it covers features, a dev-build table and the dev-build feature list. | Split it: hero image → 3-step quick start per platform → features → links. Move dev-build notes to `docs/DEVELOPMENT-BUILDS.md`. | P2 |

## 2. Documentation drift (concrete, quick wins) — P1

These are what a new tester hits first, and several no longer match the app.

- **Out-of-date menu paths.** The sidebar is now *View & glasses, Picture, Room, Sound, Games, Videos, Menu & access, Setups & help* (`menu_controller.gd CATEGORIES`), but the docs say:
  - README: "Help & system → Copy diagnostics", "Games & controls → …" (×3)
  - GETTING-STARTED / WINDOWS-SETUP: "General → Copy diagnostics", "View → Advanced calibration → Motion prediction", "View → Tracking"
  - `menu_welcome.gd` line 5 comment: "Help & system"
- **Version labels are stale.** GETTING-STARTED, WINDOWS-SETUP and PRE-LAUNCH-CHECKLIST say beta.14.
- **The README hero screenshot is out of date.** It shows the old sidebar (Audio, Controls, Emulation, Saved setups, About & Help) and the *Deck Showcase* preset, which has been removed.
- **GETTING-STARTED's ROM tree has no `psx/` or `n64/`.** Its BIOS location ("next to the CRT XR application") also differs from the README (`bios` beside `roms`, or `~/Applications/CRT-XR/bios`).
- **Prevent it happening again.** Add a check to `scripts/check-repository.py` that pulls `A → B` menu paths from the docs and compares them with `CATEGORIES` and the tab names in `menu_catalog.gd`.

## 3. First run

The welcome flow is strong: the boot logo lands on the page, Next is pinned, there's auto-detection of EmuDeck/RetroDECK, and a This screen / Glasses choice. Improvements:

| # | Issue | Suggestion | Pri |
|---|---|---|---|
| 3.1 | **Nothing to play without ROMs.** Reviewers and curious users see a test signal, not the experience. | Bundle 2–3 freely licensed homebrew games and/or a short CC-licensed video clip as a **Demo** shelf. Hide it once a library is found. This is probably the biggest single improvement to first impressions and to press or YouTube coverage. | P1 |
| 3.2 | Six steps is a lot before the first game. | Merge **Console region** into **Comfort** (it's already guessed from the locale). Make **Videos & music** skippable from the library step ("Add videos & music later"). That gives four steps. | P2 |
| 3.3 | **Your view** packs in a lot: Playing with, tracking buttons, TV for games, TV for videos and a fitting guide. | Ask only **Glasses / This screen** and **TV for games**. Default TV for videos to Wide and leave the guide in Settings. In the Nov 6 capture, *Connect glasses / Use fixed view* still show under "Playing on this screen", so check this is now hidden. | P2 |
| 3.4 | All set page: in the capture, **Go to Home** sits below the fold. | Make the final action **Play [first game found]** or **Continue**, with Home beside it. Shorten the summary table. | P3 |

## 4. Everyday use

- **Menu chord (L1+R1+Start).** It's safe in games, but it's a three-finger action users do constantly. Offer an alternative: **hold Select/View for 0.5 s**, or Guide/Home on Windows. Make it configurable under Menu & access. **P2**
- **Fast-forward and rewind in games.** The save-state and second-core machinery already exist. Hold-to-rewind plus a fast-forward toggle are the most-requested emulator conveniences. **P2**
- **Box art.** It currently only reuses scraped media. Add an optional **Fetch box art** using libretro-thumbnails, which needs no account (match by No-Intro name or CRC, cache in user data). It also feeds the box-on-table prop. **P2**
- **Library at scale.** It pages by 50 with Jump to letter. Add **sort/filter** (Most played already exists → also *Recently added*, *Unplayed*) and a **random game** button, which suits the "flicking channels" theme. **P3**
- **Controllers.** Check and document two-player local play and PlayStation/Switch pads on Windows (only "Xbox-compatible" is stated). **P2**

## 5. Settings: where to simplify

The settings are very complete, and that's now the main risk. There are 8 categories × up to 5 tabs. There's a 3-level scope strip (This game · Console · Defaults), separate game/video pictures per TV model, and **five overlapping "save my state" ideas**: Picture looks, My looks, Room presets, My rooms and Saved setups.

| # | Suggestion | Pri |
|---|---|---|
| 5.1 | **Basic / Advanced toggle** (Menu & access). Basic hides signal-level rows (chroma phase noise, moving artifacts, beam, interlacing, separate preview core, EE cycle rate…) and the scope strip, and edits only defaults. Most users never need more. | P1 |
| 5.2 | **Show the scope strip only when it matters.** Show it when the game or console already has an override, or when the user presses View/Select. A small "This game has its own picture" badge on the Picture tile does the rest. | P2 |
| 5.3 | **Merge the save concepts.** Keep *Looks* (picture) and *Rooms* (environment), and make *Saved setups* = "a look + a room + view". Better still, call setups **Scenes** and list them alongside Looks and Rooms in Quick settings, so there's one place to "pick a vibe". | P2 |
| 5.4 | **Explain changes in plain words.** Rows already show From console / Changed here. Add a one-line "Why does this game look different?" in the pause menu when overrides exist, with "Clear this game's changes". | P3 |
| 5.5 | **Remove the hidden alias categories** (4, 5, 7) and their mappings once tests no longer need them. That's less code to keep consistent. | P3 |

## 6. New features worth considering

The first three come from `dist/FUTURE-PLANS.md`; the order reflects my suggested priority for an XR nostalgia product.

1. **Saturday-morning channel.** Shuffle the video folder as a live "broadcast" with bumpers, and leave it running when you open the menu. It's the most on-brand feature and builds on what exists. *(medium)*
2. **15-second clip capture** of the TV in the room. It's the best word-of-mouth tool, and it helps bug reports. *(medium)*
3. **RetroAchievements.** It has a big retro audience and leaderboards fit the "bedroom TV" fantasy. *(high)*
4. **Share looks and rooms.** Export/import a look as a small `.cfg` or a short code, which feeds a community "looks" thread. *(low)*
5. **projectM preset import.** Drop `.milk` files in a folder. *(low; already noted as unsupported)*
6. **Sleep timer and ambient mode.** For music, visualiser or the channel: the TV powers down with the CRT collapse effect. Idle can show static or a channel instead of the logo screensaver. *(low)*
7. **The console matches the game, and more rooms** (arcade corner, 90s living room). *(medium–high, asset-bound)*
8. **Android handhelds.** Already well scoped in FUTURE-PLANS. Keep it gated on demand.

## 7. Suggested next release (beta.16)

1. Doc pass and doc-path lint (section 2) and a new README screenshot.
2. Installer/first-run prerequisite check for XR Gaming (1.1) and Windows SDK picker (1.3).
3. Demo shelf (3.1).
4. Basic/Advanced settings toggle (5.1).
5. Update check (1.5).
