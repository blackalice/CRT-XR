"""Check that menu paths in the user guides match the app's settings menu.

Reads the category names from scripts/ui/menu_controller.gd (CATEGORIES) and the
tab titles from page("…") calls in scripts/ui/menu_catalog.gd, then looks for
bold menu paths such as **Picture → Looks** in the guides. A path that starts
with a settings category must name one of its tabs (any tab title is accepted:
the tab list per category is built at run time), and names the menu no longer
uses are reported wherever they appear. No network, no writes.
"""
from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]
GUIDES = ["README.md", "WHATS-NEW.md", "docs/GETTING-STARTED.md", "docs/WINDOWS-SETUP.md", "docs/USING-CRT-XR.md",
          "docs/emulation.md", "docs/picture-controls.md", "docs/music-visualiser.md", "docs/gaming-mode.md",
          "docs/display-setup.md", "docs/head-tracking.md", "docs/audio.md", "docs/room-and-view.md",
          "scripts/installer/HOW TO INSTALL.txt", "scripts/installer/HOW TO START.txt"] + \
         [str(p.relative_to(ROOT)) for p in sorted((ROOT / "docs/glasses").glob("*.md"))]
# Names the menu used to have. Each is reported with what replaced it.
STALE = {
    "Setups & help": "Scenes & help", "Help & system": "Scenes & help", "About & Help": "Scenes & help → Help",
    "General → Copy": "Scenes & help → System → Copy", "Games & controls": "Games", "Controls & XR": "View & glasses",
    "TV & picture →": "Picture", "Saved setups": "Scenes", "Layout & placement": "Layout",
    "View → Tracking": "View & glasses → Tracking", "View → Advanced": "View & glasses → Calibration",
    "Emulation →": "Games", "Audio & vibration": "Sound → Menu sounds / Menu & access → Vibration",
}

def categories() -> list:
    text = (ROOT / "scripts/ui/menu_controller.gd").read_text(encoding="utf-8")
    found = re.search(r"const CATEGORIES := \[(.*?)\]", text)
    return re.findall(r'"([^"]+)"', found.group(1)) if found else []

def tabs() -> set:
    text = (ROOT / "scripts/ui/menu_catalog.gd").read_text(encoding="utf-8")
    return set(re.findall(r'page\("([^"]+)"', text)) | set(re.findall(r'open_settings_section\(\d+, *"([^"]+)"\)', text))

def main() -> int:
    known_categories = set(categories())
    known_tabs = tabs()
    problems = []
    for name in GUIDES:
        path = ROOT / name
        if not path.is_file(): continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for old, new in STALE.items():
                if old in line and not (old == "Saved setups" and "Scenes" in line):
                    problems.append(f"{name}:{number}: '{old}' is now '{new}'")
            for path_text in re.findall(r"\*\*([^*]+?→[^*]+?)\*\*", line):
                parts = [part.strip() for part in path_text.replace("Settings →", "").split("→")]
                if parts[0] in known_categories and len(parts) > 1 and parts[1] not in known_tabs:
                    problems.append(f"{name}:{number}: '{parts[1]}' is not a tab of {parts[0]}")
    for problem in problems: print("FAIL:", problem)
    print(f"Checked menu paths in {len(GUIDES)} guides against {len(known_categories)} categories and {len(known_tabs)} tabs.")
    return 1 if problems else 0

if __name__ == "__main__":
    sys.exit(main())
