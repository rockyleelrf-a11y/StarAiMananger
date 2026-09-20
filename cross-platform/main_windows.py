#!/usr/bin/env python3
"""
StarAI Manager - Windows System Tray
Run: python main_windows.py
Deps: pip install pystray pillow psutil
"""

import sys
import threading
import time
import subprocess
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
    import pystray
except ImportError:
    sys.exit("Missing deps. Run: pip install pystray pillow psutil")

sys.path.insert(0, str(Path(__file__).parent))
from agent_manager import default_agents, refresh, AgentApp

REFRESH_INTERVAL = 3.0

agents = default_agents()


def make_icon(running_count: int) -> Image.Image:
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    color = (52, 199, 89, 220) if running_count > 0 else (142, 142, 147, 200)
    d.ellipse([4, 4, size - 4, size - 4], fill=color)
    txt = str(running_count) if running_count <= 9 else "9+"
    # Windows font path
    font_paths = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ]
    font = ImageFont.load_default()
    for fp in font_paths:
        try:
            font = ImageFont.truetype(fp, 28)
            break
        except Exception:
            pass
    bbox = d.textbbox((0, 0), txt, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((size - tw) // 2, (size - th) // 2 - 2), txt, fill="white", font=font)
    return img


def launch_app(agent: AgentApp):
    def _do(_icon, _item):
        try:
            # Windows: try to find app in common paths
            app_paths = [
                Path("C:/Program Files") / agent.display_name,
                Path("C:/Program Files (x86)") / agent.display_name,
                Path.home() / "AppData/Local" / agent.display_name,
            ]
            for p in app_paths:
                if p.exists():
                    subprocess.Popen([str(p)])
                    return
            # fallback: try running by name
            subprocess.Popen([agent.name.lower() + ".exe"])
        except Exception:
            pass
    return _do


def kill_app(agent: AgentApp):
    def _do(_icon, _item):
        if agent.pid:
            try:
                import psutil
                psutil.Process(agent.pid).terminate()
            except Exception:
                pass
    return _do


def build_menu(icon):
    global agents
    items = []
    running = [a for a in agents if a.is_running]
    stopped = [a for a in agents if not a.is_running]

    def agent_submenu(agent: AgentApp):
        lines = []
        if agent.model_name:
            lines.append(pystray.MenuItem(f"Model: {agent.model_name}", None, enabled=False))
        if agent.current_task:
            task = agent.current_task[:45] + "..." if len(agent.current_task) > 45 else agent.current_task
            lines.append(pystray.MenuItem(f"Task: {task}", None, enabled=False))
        if agent.today_tokens or agent.history_tokens:
            lines.append(pystray.MenuItem(
                f"Today: {agent.fmt_tokens(agent.today_tokens)} | Total: {agent.fmt_tokens(agent.history_tokens)}",
                None, enabled=False))
        if agent.is_running:
            lines.append(pystray.MenuItem("Stop", kill_app(agent)))
        else:
            lines.append(pystray.MenuItem("Launch", launch_app(agent)))
        return pystray.Menu(*lines)

    if running:
        items.append(pystray.MenuItem(f"--- Running ({len(running)}) ---", None, enabled=False))
        for a in running:
            state = "[Infer]" if a.state == "inferencing" else "[Idle]"
            items.append(pystray.MenuItem(f"{state} {a.display_name}", agent_submenu(a)))

    if stopped:
        items.append(pystray.MenuItem(f"--- Stopped ({len(stopped)}) ---", None, enabled=False))
        for a in stopped:
            items.append(pystray.MenuItem(f"[Off] {a.display_name}", agent_submenu(a)))

    items.append(pystray.Menu.SEPARATOR)
    items.append(pystray.MenuItem("Exit StarAI Manager", lambda icon, _: icon.stop()))
    return pystray.Menu(*items)


def bg_refresh(icon):
    global agents
    while True:
        time.sleep(REFRESH_INTERVAL)
        agents = refresh(agents)
        running_count = sum(1 for a in agents if a.is_running)
        icon.icon = make_icon(running_count)
        icon.menu = build_menu(icon)


def main():
    global agents
    agents = refresh(agents)
    running_count = sum(1 for a in agents if a.is_running)

    icon = pystray.Icon(
        "StarAI Manager",
        make_icon(running_count),
        "StarAI Manager",
    )
    icon.menu = build_menu(icon)

    t = threading.Thread(target=bg_refresh, args=(icon,), daemon=True)
    t.start()

    icon.run()


if __name__ == "__main__":
    main()
