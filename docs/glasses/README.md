# Setting up your glasses

CRT XR needs two things from XR glasses: a **full side-by-side (SBS) 3D mode**, so each eye gets its own picture, and **head tracking** (3DoF), so the TV stays put when you turn your head. Without tracking you still get a fixed 3D view.

Pick your setup:

| You play on | Glasses | Guide |
|---|---|---|
| Steam Deck | Any glasses XR Gaming supports (VITURE, XREAL, Rokid, RayNeo…) | [Steam Deck](STEAM-DECK.md) |
| Windows | VITURE | [Windows with VITURE](WINDOWS-VITURE.md) |
| Windows | XREAL, Rokid, RayNeo and others | [Windows with OpenTrack](WINDOWS-OPENTRACK.md) |
| Anything | No glasses | Choose **This screen** in first-run setup, or press **Y** on Home for **Flat view**: the game fills your screen with the CRT picture, without the room. |

## What's been tested

VITURE Pro 2 is tested on Steam Deck and Windows. Other glasses are expected to work through the same routes but haven't been confirmed on hardware yet. If you try them, please [report how it went](https://github.com/blackalice/CRT-XR/issues): the glasses model, Deck or Windows, and whether SBS and tracking worked.

## If something's wrong

- **The view stays black after switching to SBS**: switch the glasses back to 2D, press B / Escape, and try again. On the Deck, check CRT XR's Steam game resolution is 3840 × 1080 (the installer sets it).
- **The TV slides as you turn your head**: adjust **View & glasses → Calibration → Vertical field of view** (turn on **Show advanced settings** in **Menu & access → Accessibility** first).
- **Turning goes the wrong way**: **View & glasses → Tracking → Invert yaw / pitch / roll**.
- **The view drifts**: press **R3** (or R) to recentre.
