# dmgbuild settings for the Possum installer window.
# Usage: dmgbuild -s Support/dmg-settings.py -D app=build/Possum.app -D resources=Resources Possum out.dmg
# Icon positions must match scripts/make-dmg-background.swift.
import os.path

application = defines["app"]  # noqa: F821 (injected by dmgbuild)
app_name = os.path.basename(application)
resources = defines["resources"]  # noqa: F821

format = "UDZO"
filesystem = "HFS+"
files = [application]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(resources, "AppIcon.icns")  # mounted volume icon

background = os.path.join(resources, "DMG", "background.tiff")
# Height = 400 pt background + title bar, so nothing is clipped or scrolls.
window_rect = ((200, 120), (640, 432))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

icon_size = 128
text_size = 13
arrange_by = None
icon_locations = {
    app_name: (170, 215),
    "Applications": (470, 215),
}
