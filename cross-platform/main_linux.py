#!/usr/bin/env python3
"""
StarAI Manager - Linux System Tray (GTK/AppIndicator via pystray)
Run: python3 main_linux.py
Deps: pip install pystray pillow psutil
"""

import sys
import threading
import time
import platform
import subprocess
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
    import pystray
except ImportError:
    sys.exit("Missing deps. Run: pip install pystray pillow psutil")

# Add parent dir to path for agent_manager import
sys.path.insert(0, str(Path(__file__).parent))
from agent_manager import default_agents, refresh, AgentApp

REFRESH_INTERVAL = 3.0  # seconds

agents = default_agents()

# ─── Icon ─────────────────────────────────────────────────────────────────────

def make_icon(running_count: int) -> Image.Image:
    """Generate a simple tray icon with running agent count."""
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Background circle
    color = (52, 199, 89, 220) if running_count > 0 else (142, 142, 147, 200)
    d.ellipse([4, 4, size - 4, size - 4], fill=color)
    # Count text
    txt = str(running_count) if running_count <= 9 else "9+"
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28)
    except Exception:
        font = ImageFont.load_default()
    bbox = d.textbbox((0, 0), txt, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((size - tw) // 2, (size - th) // 2 - 2), txt, fill="white", font=font)
    return img


# ─── Menu Builder ─────────────────────────────────────────────────────────────

def launch_app(agent: AgentApp):
    def _do(_icon, _item):
        try:
            subprocess.Popen([agent.name.lower()])
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
            lines.append(pystray.MenuItem(f"  🤖 {agent.model_name}", None, enabled=False))
        if agent.current_task:
            task = agent.current_task[:40] + "…" if len(agent.current_task) > 40 else agent.current_task
            lines.append(pystray.MenuItem(f"  📋 {task}", None, enabled=False))
        if agent.today_tokens or agent.history_tokens:
            lines.append(pystray.MenuItem(
                f"  🪙 今日:{agent.fmt_tokens(agent.today_tokens)} 历史:{agent.fmt_tokens(agent.history_tokens)}",
                None, enabled=False))
        if agent.is_running:
            lines.append(pystray.MenuItem("  ⏹  关闭", kill_app(agent)))
        else:
            lines.append(pystray.MenuItem("  ▶  启动", launch_app(agent)))
        return pystray.Menu(*lines)

    if running:
        items.append(pystray.MenuItem(f"── 运行中 ({len(running)}) ──", None, enabled=False))
        for a in running:
            state_icon = "⚡" if a.state == "inferencing" else "🟢"
            items.append(pystray.MenuItem(f"{state_icon} {a.display_name}", agent_submenu(a)))

    if stopped:
        items.append(pystray.MenuItem(f"── 已停止 ({len(stopped)}) ──", None, enabled=False))
        for a in stopped:
            items.append(pystray.MenuItem(f"⚫ {a.display_name}", agent_submenu(a)))

    items.append(pystray.Menu.SEPARATOR)
    items.append(pystray.MenuItem("退出 StarAI Manager", lambda icon, _: icon.stop()))
    return pystray.Menu(*items)


# ─── Background Refresh ───────────────────────────────────────────────────────

def bg_refresh(icon):
    global agents
    while True:
        time.sleep(REFRESH_INTERVAL)
        agents = refresh(agents)
        running_count = sum(1 for a in agents if a.is_running)
        icon.icon = make_icon(running_count)
        icon.menu = build_menu(icon)


# ─── Entry Point ──────────────────────────────────────────────────────────────

def main():
    global agents
    agents = refresh(agents)
    running_count = sum(1 for a in agents if a.is_running)

    icon = pystray.Icon(
        "StarAI Manager",
        make_icon(running_count),
        "StarAI Manager",
        build_menu(None),  # initial menu
    )
    icon.menu = build_menu(icon)

    t = threading.Thread(target=bg_refresh, args=(icon,), daemon=True)
    t.start()

    icon.run()


if __name__ == "__main__":
    main()
