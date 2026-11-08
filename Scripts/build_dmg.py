#!/usr/bin/env python3
"""Build the drag-to-Applications DMG with a branded background, headless.

Writes the Finder layout via .DS_Store directly (dmgbuild), so no Finder
automation is needed. Usage:

    Scripts/build_dmg.py <EchoTune.app> <output.dmg>
"""

import os
import sys

import dmgbuild

APP = sys.argv[1]
OUT = sys.argv[2]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

settings = {
    "volume_name": "EchoTune",
    "format": "UDBZ",
    "files": [APP],
    "symlinks": {"Applications": "/Applications"},
    "background": os.path.join(ROOT, "Scripts", "dmg-assets", "background.png"),
    "show_status_bar": False,
    "show_tab_view": False,
    "show_toolbar": False,
    "show_pathbar": False,
    "show_sidebar": False,
    "window_rect": ((0, 0), (660, 400)),
    "default_view": "icon-view",
    "icon_size": 128,
    "icon_locations": {
        "EchoTune.app": (180, 170),
        "Applications": (480, 170),
    },
    "include_icon_view_settings": True,
    "include_list_view_settings": False,
    "arrange_by": None,
}

if __name__ == "__main__":
    dmgbuild.build_dmg(filename=OUT, volume_name="EchoTune", settings=settings)
    print(f"==> DMG built: {OUT}")
