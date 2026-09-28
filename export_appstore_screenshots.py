#!/usr/bin/env python3
"""
Generate professional App Store screenshots for StarButler Companion
Outputs:
1. 6.7" iPhone Display (1290 x 2796) - App Store Primary Requirement
2. 6.5" iPhone Display (1242 x 2688) - Standard alternative
3. Mac Preview / Presentation format
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(BASE_DIR, "AppStoreScreenshots")
os.makedirs(OUT_DIR, exist_ok=True)

# Sources
IMG_DIR = "/Users/removed/.gemini/antigravity/brain/15f3c87c-3711-48a4-8433-bbcb3e775719/.user_uploaded"
RAW_PHONE_1 = os.path.join(IMG_DIR, "media_1790564561136.png") # Dashboard active (TraeWork, Antigravity, 豆包工作)
RAW_PHONE_2 = os.path.join(IMG_DIR, "media_1790564561137.png") # Companion Pairing (Bonjour & WAN)
RAW_PHONE_3 = os.path.join(IMG_DIR, "media_1790564561141.png") # Account & Cloud Control (Cloud Relay)
RAW_PHONE_4 = os.path.join(IMG_DIR, "media_1790564561155.png") # App Launch & Agent Library (StepFun, MiniMax, ChatGPT, ima)
RAW_DESKTOP = os.path.join(IMG_DIR, "media_1790564569992.png") # Mac Desktop screen

FONT_PATH = "/System/Library/Fonts/PingFang.ttc"

def get_font(size, bold=False):
    index = 2 if bold else 0  # 2: Semibold, 0: Regular in PingFang.ttc
    try:
        return ImageFont.truetype(FONT_PATH, size=size, index=index)
    except Exception:
        try:
            return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", size=size)
        except Exception:
            return ImageFont.load_default()

def draw_gradient(width, height, color_top, color_bottom):
    """Create vertical gradient"""
    base = Image.new("RGBA", (width, height), color_top)
    top_r, top_g, top_b = color_top[:3]
    bot_r, bot_g, bot_b = color_bottom[:3]
    
    gradient = Image.new("RGBA", (1, height))
    for y in range(height):
        ratio = y / float(height - 1)
        r = int(top_r + (bot_r - top_r) * ratio)
        g = int(top_g + (bot_g - top_g) * ratio)
        b = int(top_b + (bot_b - top_b) * ratio)
        gradient.putpixel((0, y), (r, g, b, 255))
    return gradient.resize((width, height), Image.Resampling.BILINEAR)

def create_phone_frame(screen_img, target_width, corner_radius=72, bezel=18):
    """
    Wrap screen image inside modern iPhone style rounded bezel with subtle inner shadow
    """
    aspect = screen_img.height / screen_img.width
    inner_w = target_width - (bezel * 2)
    inner_h = int(inner_w * aspect)
    
    scaled_screen = screen_img.resize((inner_w, inner_h), Image.Resampling.LANCZOS)
    
    # Mask screen to rounded corners
    screen_mask = Image.new("L", (inner_w, inner_h), 0)
    draw_smask = ImageDraw.Draw(screen_mask)
    draw_smask.rounded_rectangle([0, 0, inner_w, inner_h], radius=corner_radius - 8, fill=255)
    
    # Phone body (outer bezel)
    body_w = target_width
    body_h = inner_h + (bezel * 2)
    body = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    draw_body = ImageDraw.Draw(body)
    
    # Draw dark titanium bezel border
    draw_body.rounded_rectangle([0, 0, body_w, body_h], radius=corner_radius, fill=(28, 30, 36, 255), outline=(60, 64, 75, 255), width=3)
    
    # Paste masked screen
    body.paste(scaled_screen, (bezel, bezel), screen_mask)
    
    # Outer drop shadow
    shadow_pad = 70
    shadow_img = Image.new("RGBA", (body_w + shadow_pad * 2, body_h + shadow_pad * 2), (0, 0, 0, 0))
    draw_sh = ImageDraw.Draw(shadow_img)
    draw_sh.rounded_rectangle(
        [shadow_pad, shadow_pad + 15, shadow_pad + body_w, shadow_pad + body_h + 15],
        radius=corner_radius,
        fill=(0, 0, 0, 110)
    )
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=32))
    shadow_img.paste(body, (shadow_pad, shadow_pad), body)
    
    return shadow_img, shadow_pad

def render_screenshot_card(
    tag_text,
    title_text,
    subtitle_text,
    main_image,
    secondary_image=None,
    theme_colors=((16, 22, 38), (30, 42, 70)), # Dark navy modern theme
    tag_bg=(64, 128, 255, 45),
    tag_fg=(100, 180, 255, 255),
    canvas_w=1290,
    canvas_h=2796
):
    # 1. Background gradient
    canvas = draw_gradient(canvas_w, canvas_h, theme_colors[0], theme_colors[1])
    draw = ImageDraw.Draw(canvas)
    
    # 2. Header Text Section
    top_margin = 170
    
    # Category / Tag Capsule
    font_tag = get_font(38, bold=True)
    tag_bbox = draw.textbbox((0, 0), tag_text, font=font_tag)
    tag_tw = tag_bbox[2] - tag_bbox[0]
    tag_th = tag_bbox[3] - tag_bbox[1]
    
    tag_px = 36
    tag_py = 18
    tag_w = tag_tw + tag_px * 2
    tag_h = tag_th + tag_py * 2
    tag_x = (canvas_w - tag_w) // 2
    tag_y = top_margin
    
    draw.rounded_rectangle([tag_x, tag_y, tag_x + tag_w, tag_y + tag_h], radius=tag_h//2, fill=tag_bg, outline=(tag_fg[0], tag_fg[1], tag_fg[2], 120), width=2)
    draw.text((tag_x + tag_px, tag_y + tag_py - 4), tag_text, font=font_tag, fill=tag_fg)
    
    # Title
    font_title = get_font(84, bold=True)
    title_bbox = draw.textbbox((0, 0), title_text, font=font_title)
    title_w = title_bbox[2] - title_bbox[0]
    title_x = (canvas_w - title_w) // 2
    title_y = tag_y + tag_h + 40
    draw.text((title_x, title_y), title_text, font=font_title, fill=(255, 255, 255, 255))
    
    # Subtitle
    font_sub = get_font(44, bold=False)
    sub_bbox = draw.textbbox((0, 0), subtitle_text, font=font_sub)
    sub_w = sub_bbox[2] - sub_bbox[0]
    sub_x = (canvas_w - sub_w) // 2
    sub_y = title_y + (title_bbox[3] - title_bbox[1]) + 28
    draw.text((sub_x, sub_y), subtitle_text, font=font_sub, fill=(185, 195, 215, 255))
    
    # 3. Phone Device Mockup placement
    phone_w = 980
    framed_phone, pad = create_phone_frame(main_image, phone_w, corner_radius=72, bezel=18)
    
    # Center phone horizontally, place bottom flush or slightly overflow
    phone_x = (canvas_w - framed_phone.width) // 2
    phone_y = sub_y + 110 - pad
    
    # If there is a secondary desktop illustration or inset card
    if secondary_image is not None:
        # Mini Mac Desktop Card floating behind/beside
        sec_w = 760
        sec_aspect = secondary_image.height / secondary_image.width
        sec_h = int(sec_w * sec_aspect)
        scaled_sec = secondary_image.resize((sec_w, sec_h), Image.Resampling.LANCZOS)
        
        # Round corners of secondary image
        sec_mask = Image.new("L", (sec_w, sec_h), 0)
        draw_sec_mask = ImageDraw.Draw(sec_mask)
        draw_sec_mask.rounded_rectangle([0, 0, sec_w, sec_h], radius=24, fill=255)
        
        # Shadow for secondary
        sec_shadow = Image.new("RGBA", (sec_w + 60, sec_h + 60), (0, 0, 0, 0))
        draw_sec_sh = ImageDraw.Draw(sec_shadow)
        draw_sec_sh.rounded_rectangle([30, 35, sec_w + 30, sec_h + 35], radius=24, fill=(0, 0, 0, 130))
        sec_shadow = sec_shadow.filter(ImageFilter.GaussianBlur(16))
        sec_shadow.paste(scaled_sec, (30, 30), sec_mask)
        
        # Overlay border
        draw_sec_b = ImageDraw.Draw(sec_shadow)
        draw_sec_b.rounded_rectangle([30, 30, sec_w + 30, sec_h + 30], radius=24, outline=(255, 255, 255, 60), width=2)
        
        # Paste secondary behind the phone at an offset
        canvas.paste(sec_shadow, (canvas_w - sec_w - 40, phone_y + 160), sec_shadow)
        
    canvas.paste(framed_phone, (phone_x, phone_y), framed_phone)
    
    return canvas

def main():
    print("==> Loading source screenshots...")
    img1 = Image.open(RAW_PHONE_1).convert("RGBA")
    img2 = Image.open(RAW_PHONE_2).convert("RGBA")
    img3 = Image.open(RAW_PHONE_3).convert("RGBA")
    img4 = Image.open(RAW_PHONE_4).convert("RGBA")
    desktop_img = Image.open(RAW_DESKTOP).convert("RGBA")
    
    # Crop the desktop StarButler popover area to serve as a floating pairing card
    # Popover panel is located at ~ (636, 15, 902, 212) in 1024x549
    dw, dh = desktop_img.size
    panel_crop = desktop_img.crop((int(dw * 0.615), 12, int(dw * 0.885), int(dh * 0.72)))
    
    # Define 4 Core Marketing App Store Screens
    screens = [
        {
            "filename": "1_Dashboard_Active_Agents.png",
            "tag": "实时监控 · 智能调度",
            "title": "Mac AI 智能体状态大屏",
            "subtitle": "多智能体运行状态、Prompt 与耗时一目了然",
            "image": img1,
            "sec_image": panel_crop, # Combined with Mac panel crop!
            "theme": ((14, 20, 36), (28, 40, 68)),
            "tag_bg": (0, 122, 255, 45),
            "tag_fg": (90, 180, 255, 255)
        },
        {
            "filename": "2_Multi_Mode_Pairing.png",
            "tag": "无缝互联 · 极简配对",
            "title": "局域网 + 广域网双重直连",
            "subtitle": "Bonjour 零配置自发现 · 无论身在何处即时掌控",
            "image": img2,
            "sec_image": None,
            "theme": ((18, 22, 34), (32, 45, 62)),
            "tag_bg": (52, 199, 89, 45),
            "tag_fg": (80, 225, 120, 255)
        },
        {
            "filename": "3_Token_Metrics_Manage.png",
            "tag": "精准统计 · 拒绝虚标",
            "title": "今日与历史 Token 详尽分析",
            "subtitle": "Trae · Antigravity · Cursor · 豆包全适配",
            "image": img4,
            "sec_image": None,
            "theme": ((20, 18, 36), (42, 32, 68)),
            "tag_bg": (175, 82, 222, 45),
            "tag_fg": (210, 130, 255, 255)
        },
        {
            "filename": "4_Remote_Cloud_Control.png",
            "tag": "云端中继 · 随身掌门",
            "title": "随时随地一键启停与前台置顶",
            "subtitle": "在外 4G/5G 畅行远程遥控 · 保护算力安全",
            "image": img3,
            "sec_image": None,
            "theme": ((16, 24, 38), (26, 48, 76)),
            "tag_bg": (255, 149, 0, 45),
            "tag_fg": (255, 185, 70, 255)
        },
    ]
    
    # 1. Output 6.7" iPhone Display (1290 x 2796)
    dir_67 = os.path.join(OUT_DIR, "6.7_inch_iPhone_1290x2796")
    os.makedirs(dir_67, exist_ok=True)
    
    # 2. Output 6.5" iPhone Display (1242 x 2688)
    dir_65 = os.path.join(OUT_DIR, "6.5_inch_iPhone_1242x2688")
    os.makedirs(dir_65, exist_ok=True)

    for idx, sc in enumerate(screens):
        print(f"==> Rendering Screen {idx+1}: {sc['title']}...")
        card_67 = render_screenshot_card(
            tag_text=sc["tag"],
            title_text=sc["title"],
            subtitle_text=sc["subtitle"],
            main_image=sc["image"],
            secondary_image=sc["sec_image"],
            theme_colors=sc["theme"],
            tag_bg=sc["tag_bg"],
            tag_fg=sc["tag_fg"],
            canvas_w=1290,
            canvas_h=2796
        )
        
        path_67 = os.path.join(dir_67, sc["filename"])
        # RGB without alpha for App Store standard
        card_67.convert("RGB").save(path_67, "PNG", optimize=True)
        print(f"    Saved: {path_67}")
        
        # 6.5" resize
        card_65 = card_67.resize((1242, 2688), Image.Resampling.LANCZOS)
        path_65 = os.path.join(dir_65, sc["filename"])
        card_65.convert("RGB").save(path_65, "PNG", optimize=True)
        print(f"    Saved: {path_65}")

    print("\n✅ All App Store screenshot sets exported successfully!")

if __name__ == "__main__":
    main()

    # 3. Output 13" iPad Display (2048 x 2732)
    dir_ipad = os.path.join(OUT_DIR, "13_inch_iPad_2048x2732")
    os.makedirs(dir_ipad, exist_ok=True)
    for idx, sc in enumerate(screens):
        card_ipad = render_screenshot_card(
            tag_text=sc["tag"],
            title_text=sc["title"],
            subtitle_text=sc["subtitle"],
            main_image=sc["image"],
            secondary_image=sc["sec_image"],
            theme_colors=sc["theme"],
            tag_bg=sc["tag_bg"],
            tag_fg=sc["tag_fg"],
            canvas_w=2048,
            canvas_h=2732
        )
        path_ipad = os.path.join(dir_ipad, sc["filename"])
        card_ipad.convert("RGB").save(path_ipad, "PNG", optimize=True)
        print(f"    Saved iPad: {path_ipad}")
