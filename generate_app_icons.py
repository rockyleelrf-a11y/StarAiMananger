import os
import json
import subprocess

DIR = os.path.dirname(os.path.abspath(__file__))
LOGO = os.path.join(DIR, "logo.png")
ICONSET = os.path.join(DIR, "StarButlerCompanion/Assets.xcassets/AppIcon.appiconset")
os.makedirs(ICONSET, exist_ok=True)

icons_spec = [
    # iPhone Notification
    {"size": "20x20", "idiom": "iphone", "scale": "2x", "pixels": 40, "filename": "icon_20x20@2x.png"},
    {"size": "20x20", "idiom": "iphone", "scale": "3x", "pixels": 60, "filename": "icon_20x20@3x.png"},
    # iPhone Settings
    {"size": "29x29", "idiom": "iphone", "scale": "2x", "pixels": 58, "filename": "icon_29x29@2x.png"},
    {"size": "29x29", "idiom": "iphone", "scale": "3x", "pixels": 87, "filename": "icon_29x29@3x.png"},
    # iPhone Spotlight
    {"size": "40x40", "idiom": "iphone", "scale": "2x", "pixels": 80, "filename": "icon_40x40@2x.png"},
    {"size": "40x40", "idiom": "iphone", "scale": "3x", "pixels": 120, "filename": "icon_40x40@3x.png"},
    # iPhone App
    {"size": "60x60", "idiom": "iphone", "scale": "2x", "pixels": 120, "filename": "icon_60x60@2x.png"},
    {"size": "60x60", "idiom": "iphone", "scale": "3x", "pixels": 180, "filename": "icon_60x60@3x.png"},
    # iPad Notifications
    {"size": "20x20", "idiom": "ipad", "scale": "1x", "pixels": 20, "filename": "icon_20x20@1x~ipad.png"},
    {"size": "20x20", "idiom": "ipad", "scale": "2x", "pixels": 40, "filename": "icon_20x20@2x~ipad.png"},
    # iPad Settings
    {"size": "29x29", "idiom": "ipad", "scale": "1x", "pixels": 29, "filename": "icon_29x29@1x~ipad.png"},
    {"size": "29x29", "idiom": "ipad", "scale": "2x", "pixels": 58, "filename": "icon_29x29@2x~ipad.png"},
    # iPad Spotlight
    {"size": "40x40", "idiom": "ipad", "scale": "1x", "pixels": 40, "filename": "icon_40x40@1x~ipad.png"},
    {"size": "40x40", "idiom": "ipad", "scale": "2x", "pixels": 80, "filename": "icon_40x40@2x~ipad.png"},
    # iPad App
    {"size": "76x76", "idiom": "ipad", "scale": "1x", "pixels": 76, "filename": "icon_76x76@1x~ipad.png"},
    {"size": "76x76", "idiom": "ipad", "scale": "2x", "pixels": 152, "filename": "icon_76x76@2x~ipad.png"},
    # iPad Pro App
    {"size": "83.5x83.5", "idiom": "ipad", "scale": "2x", "pixels": 167, "filename": "icon_83.5x83.5@2x~ipad.png"},
    # App Store
    {"size": "1024x1024", "idiom": "ios-marketing", "scale": "1x", "pixels": 1024, "filename": "icon_1024x1024.png"},
]

contents_images = []
for item in icons_spec:
    out_file = os.path.join(ICONSET, item["filename"])
    px = item["pixels"]
    # Resize with sips
    subprocess.run(["sips", "-z", str(px), str(px), LOGO, "--out", out_file], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    contents_images.append({
        "size": item["size"],
        "idiom": item["idiom"],
        "scale": item["scale"],
        "filename": item["filename"]
    })

contents = {
    "images": contents_images,
    "info": {
        "version": 1,
        "author": "xcode"
    }
}

with open(os.path.join(ICONSET, "Contents.json"), "w", encoding="utf-8") as f:
    json.dump(contents, f, indent=2)

print("==> AppIcon.appiconset generated with all iOS dimensions.")
