#!/usr/bin/env python3
"""Generate terminal-style SVG previews for remnawave-scripts READMEs.

Usage: python3 assets/gen_previews.py   (from anywhere — paths are script-relative)
"""
import html
import os

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

# GitHub-dark-friendly palette (looks good on light too)
C = {
    "bg":     "#0d1117",
    "chrome": "#161b22",
    "border": "#30363d",
    "title":  "#8b949e",
    "white":  "#e6edf3",
    "gray":   "#8b949e",
    "dim":    "#484f58",
    "green":  "#3fb950",
    "red":    "#f85149",
    "yellow": "#d29922",
    "blue":   "#58a6ff",
    "cyan":   "#39c5cf",
    "purple": "#bc8cff",
}

LINE_H = 21
PAD_X = 22
PAD_TOP = 56          # below chrome bar
CHROME_H = 36
FONT = "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace"


def esc(s):
    return html.escape(s, quote=False)


def render(filename, term_title, width, lines):
    height = PAD_TOP + len(lines) * LINE_H + 18
    out = []
    out.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" role="img" aria-label="{esc(term_title)}">'
    )
    # window
    out.append(
        f'<rect x="0.5" y="0.5" width="{width-1}" height="{height-1}" rx="10" '
        f'fill="{C["bg"]}" stroke="{C["border"]}"/>'
    )
    # chrome bar
    out.append(
        f'<path d="M0.5 10.5 a10 10 0 0 1 10-10 h{width-21} a10 10 0 0 1 10 10 v{CHROME_H-10} h-{width-1} z" '
        f'fill="{C["chrome"]}"/>'
    )
    out.append(f'<line x1="0.5" y1="{CHROME_H}" x2="{width-0.5}" y2="{CHROME_H}" stroke="{C["border"]}"/>')
    # traffic lights
    for i, col in enumerate(("#ff5f56", "#ffbd2e", "#27c93f")):
        out.append(f'<circle cx="{20 + i*20}" cy="{CHROME_H//2}" r="6" fill="{col}"/>')
    # window title
    out.append(
        f'<text x="{width//2}" y="{CHROME_H//2 + 4}" text-anchor="middle" font-family="{FONT}" '
        f'font-size="12" fill="{C["title"]}">{esc(term_title)}</text>'
    )
    # body text
    def text_el(x, y, segs):
        tspans = ""
        for seg in segs:
            if isinstance(seg, tuple):
                text, color, *rest = seg
                bold = rest[0] if rest else False
            else:
                text, color, bold = seg, "gray", False
            w = ' font-weight="600"' if bold else ""
            tspans += f'<tspan fill="{C[color]}"{w}>{esc(text)}</tspan>'
        return f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="13.5" xml:space="preserve">{tspans}</text>'

    y = PAD_TOP
    for line in lines:
        if line == "SEP":
            out.append(
                f'<line x1="{PAD_X}" y1="{y-5}" x2="{width-PAD_X}" y2="{y-5}" '
                f'stroke="{C["dim"]}" stroke-dasharray="1 0" stroke-width="1"/>'
            )
            y += LINE_H - 8
            continue
        # two fixed columns: ("2COL", left_segs, right_segs)
        if isinstance(line, tuple) and line and line[0] == "2COL":
            out.append(text_el(PAD_X, y, line[1]))
            out.append(text_el(width // 2 + 20, y, line[2]))
            y += LINE_H
            continue
        segs = line if isinstance(line, list) else [line]
        out.append(text_el(PAD_X, y, segs))
        y += LINE_H
    out.append("</svg>")
    with open(filename, "w") as f:
        f.write("\n".join(out) + "\n")
    print(f"{filename}: {width}x{height}, {len(lines)} lines")


N = lambda n: ("   " + n + ")  ", "white", True)          # numbered item prefix
H = lambda t: (t, "white", True)                           # section header

# ---------------------------------------------------------------- remnawave
render("assets/preview-remnawave.svg", "remnawave — Panel Management", 720, [
    ("2COL",
     [("⚡ remnawave Panel Management ", "white", True), ("v6.4.0", "gray")],
     [("", "gray")]),
    "SEP",
    ("2COL",
     [("✅ Panel: Running", "green", True)],
     [("✅ Caddy: Running", "green", True)]),
    [("🌐 ", "gray"), ("https://panel.example.com", "blue")],
    "SEP",
    [H("📊 Status & Monitoring:")],
    ("2COL", [N("1"), ("📊 Service status", "gray")], [N("3"), ("🩺 Health check", "gray")]),
    ("2COL", [N("2"), ("📋 View logs", "gray")],      [N("4"), ("📈 PM2 monitor", "gray")]),
    [H("⚙️  Services & Proxy:")],
    ("2COL", [N("5"), ("⚙️  Services control →", "gray")], [N("6"), ("🌐 Caddy management →", "gray")]),
    [H("📄 Subscription page:")],
    [N("7"), ("📄 Subscription page →", "gray")],
    [H("💾 Backup & Restore:")],
    ("2COL", [N("8"), ("💾 Manual backup", "gray")], [N("10"), ("🔄 Restore", "gray")]),
    [N("9"), ("📅 Scheduled backups →", "gray")],
    [H("🛠️  Installation & Advanced:")],
    ("2COL", [N("11"), ("🛠️  Installation →", "gray")], [N("12"), ("📝 Edit configs →", "gray")]),
    "SEP",
    [("Remnawave Panel CLI v6.4.0 by DigneZzZ • gig.ovh", "dim")],
    [("Select option [0-14, L]: ", "white", True), ("▊", "green")],
])

# ---------------------------------------------------------------- remnanode
render("assets/preview-remnanode.svg", "remnanode — Node Management", 720, [
    [("🚀 remnanode Node Management ", "white", True), ("v4.3.7", "gray")],
    "SEP",
    [("✅ Node Status: RUNNING", "green", True)],
    [("⚙️  Components:  ", "white", True), ("node ", "gray"), ("✅ v3.0.0", "green"), ("    ", "gray"),
     ("Xray-core ", "gray"), ("✅ v25.8.3", "green")],
    [("💾 Resources:   ", "white", True), ("CPU 2% · RAM 118 MB · Up 6 days", "gray")],
    "SEP",
    [H("🚀 Installation & Management:")],
    ("2COL", [N("1"), ("🛠️  Install RemnaNode", "gray")], [N("4"), ("🔄 Restart services", "gray")]),
    ("2COL", [N("2"), ("▶️  Start services", "gray")],    [N("5"), ("🗑️  Uninstall", "gray")]),
    [N("3"), ("⏹️  Stop services", "gray")],
    [H("📊 Monitoring & Logs:")],
    ("2COL", [N("6"), ("📊 Node status", "gray")],    [N("8"), ("📤 Xray output logs", "gray")]),
    ("2COL", [N("7"), ("📋 Container logs", "gray")], [N("9"), ("📥 Xray error logs", "gray")]),
    [H("⚙️  Updates & Configuration:")],
    ("2COL", [N("10"), ("🔄 Update RemnaNode", "gray")], [N("11"), ("⬆️  Update Xray-core", "gray")]),
    "SEP",
    [("Select option: ", "white", True), ("▊", "green")],
])

# ---------------------------------------------------------------- selfsteal
render("assets/preview-selfsteal.svg", "selfsteal — Reality Masking", 720, [
    [("🔗 Caddy for Reality Selfsteal ", "white", True), ("v2.10.0", "gray")],
    "SEP",
    ("2COL",
     [("✅ Status: Running", "green", True)],
     [("🌐 ", "gray"), ("domain.example.com:9443", "blue")]),
    "SEP",
    [H("🔧 Service Management:")],
    ("2COL", [N("1"), ("🚀 Install Caddy", "gray")],   [N("4"), ("🔄 Restart services", "gray")]),
    ("2COL", [N("2"), ("▶️  Start services", "gray")], [N("5"), ("📊 Service status", "gray")]),
    [N("3"), ("⏹️  Stop services", "gray")],
    [H("🎨 Website Management:")],
    [N("6"), ("🎨 Website templates ", "gray"), ("(8 built-in, randomized)", "purple")],
    [N("7"), ("📖 Setup guide & examples", "gray")],
    [H("📝 Logs & Monitoring:")],
    ("2COL", [N("8"), ("📝 View logs", "gray")], [N("9"), ("📊 Log sizes", "gray")]),
    "SEP",
    [("Project: gig.ovh | Author: DigneZzZ", "dim")],
    [("Select option: ", "white", True), ("▊", "green")],
])

# ---------------------------------------------------------------- wtm
render("assets/preview-wtm.svg", "wtm — WARP & Tor Manager", 720, [
    [("🌐 WARP & Tor Manager ", "white", True), ("v1.5.2", "gray")],
    "SEP",
    [("📡 WARP:  ", "white", True), ("✅ Connected ", "green"), ("· WARP+ · native WireGuard outbound", "gray")],
    [("🧅 Tor:   ", "white", True), ("✅ Active ", "green"), ("· SOCKS5 127.0.0.1:9050", "gray")],
    "SEP",
    [H("🛠️  Service Management:")],
    ("2COL", [N("1"), ("📡 WARP Menu", "gray")], [N("3"), ("🔄 Quick Actions", "gray")]),
    [N("2"), ("🧅 Tor Menu", "gray")],
    [H("📊 Monitoring & Tools:")],
    ("2COL", [N("4"), ("🧪 Test Connections", "gray")], [N("6"), ("💻 System Information", "gray")]),
    [N("5"), ("📋 View Logs", "gray")],
    [H("📖 Configuration:")],
    ("2COL", [N("7"), ("⚙️  XRay Configuration", "gray")], [N("8"), ("❓ Help & Examples", "gray")]),
    "SEP",
    [("WARP & Tor Manager • Network Proxy Solutions", "dim")],
    [("Select option [0-9]: ", "white", True), ("▊", "green")],
])

# ---------------------------------------------------------------- hero
W, HH = 880, 240
hero = []
hero.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{HH}" viewBox="0 0 {W} {HH}" role="img" aria-label="Remnawave Scripts">')
hero.append('<defs>'
            '<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">'
            '<stop offset="0" stop-color="#0d1117"/><stop offset="1" stop-color="#161b3a"/>'
            '</linearGradient>'
            '<linearGradient id="accent" x1="0" y1="0" x2="1" y2="0">'
            '<stop offset="0" stop-color="#58a6ff"/><stop offset="0.5" stop-color="#bc8cff"/><stop offset="1" stop-color="#39c5cf"/>'
            '</linearGradient>'
            '</defs>')
hero.append(f'<rect x="0.5" y="0.5" width="{W-1}" height="{HH-1}" rx="14" fill="url(#bg)" stroke="#30363d"/>')
# faint grid dots
for gx in range(40, W, 60):
    for gy in range(30, HH, 55):
        hero.append(f'<circle cx="{gx}" cy="{gy}" r="1" fill="#21262d"/>')
hero.append(f'<text x="{W//2}" y="92" text-anchor="middle" font-family="-apple-system, \'Segoe UI\', system-ui, sans-serif" font-size="44" font-weight="800" fill="#e6edf3">Remnawave <tspan fill="url(#accent)">Scripts</tspan></text>')
hero.append(f'<text x="{W//2}" y="128" text-anchor="middle" font-family="-apple-system, \'Segoe UI\', system-ui, sans-serif" font-size="17" fill="#8b949e">Panel · Node · Reality Masking · WARP &amp; Tor · Backups — one-liner installs, full-featured CLI</text>')
# fake prompt line
hero.append(f'<rect x="{W//2-315}" y="156" width="630" height="44" rx="8" fill="#0d1117" stroke="#30363d"/>')
hero.append(f'<text x="{W//2}" y="184" text-anchor="middle" font-family="{FONT}" font-size="14.5" xml:space="preserve">'
            f'<tspan fill="#3fb950" font-weight="600">$</tspan>'
            f'<tspan fill="#e6edf3"> bash &lt;(curl -Ls …/raw/main/remnawave.sh) </tspan>'
            f'<tspan fill="#58a6ff">@</tspan><tspan fill="#e6edf3"> install</tspan>'
            f'<tspan fill="#3fb950"> ▊</tspan></text>')
hero.append('</svg>')
with open("assets/hero.svg", "w") as f:
    f.write("\n".join(hero) + "\n")
print(f"assets/hero.svg: {W}x{HH}")
