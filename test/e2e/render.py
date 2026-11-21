"""Render a captured terminal screen (ANSI) as a self-contained HTML page.

The end-to-end test captures the real Neovim TUI from tmux with `capture-pane
-ep`, so the HTML below is a faithful rendering of what the editor actually
displayed, including the highlight colors.
"""

from __future__ import annotations

import html
import re
from dataclasses import dataclass, replace

DEFAULT_FG = (224, 226, 234)
DEFAULT_BG = (20, 22, 27)

ANSI_RE = re.compile(r"\x1b\[([0-9;:?<>!]*)([@-~])")
OSC_RE = re.compile(r"\x1b\].*?(?:\x07|\x1b\\)", re.DOTALL)

BASE_COLORS = [
    (0, 0, 0),
    (128, 0, 0),
    (0, 128, 0),
    (128, 128, 0),
    (0, 0, 128),
    (128, 0, 128),
    (0, 128, 128),
    (192, 192, 192),
    (128, 128, 128),
    (255, 0, 0),
    (0, 255, 0),
    (255, 255, 0),
    (0, 0, 255),
    (255, 0, 255),
    (0, 255, 255),
    (255, 255, 255),
]


@dataclass
class Style:
    fg: tuple[int, int, int] | None = None
    bg: tuple[int, int, int] | None = None
    bold: bool = False
    italic: bool = False
    underline: bool = False
    reverse: bool = False
    dim: bool = False

    def copy(self) -> "Style":
        return replace(self)


def ansi256(index: int) -> tuple[int, int, int]:
    if index < 16:
        return BASE_COLORS[index]
    if index < 232:
        index -= 16
        levels = [0, 95, 135, 175, 215, 255]
        return (levels[index // 36], levels[(index % 36) // 6], levels[index % 6])
    level = 8 + 10 * (index - 232)
    return (level, level, level)


def hex_color(rgb: tuple[int, int, int]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def reset(style: Style) -> None:
    style.fg = None
    style.bg = None
    style.bold = False
    style.italic = False
    style.underline = False
    style.reverse = False
    style.dim = False


def apply_sgr(style: Style, params: str) -> None:
    if not params:
        reset(style)
        return

    parts: list[str] = []
    for part in params.split(";"):
        if ":" in part:
            parts.extend(part.split(":"))
        else:
            parts.append(part)

    i = 0
    while i < len(parts):
        raw = parts[i]
        if not raw:
            i += 1
            continue

        try:
            code = int(raw)
        except ValueError:
            i += 1
            continue

        if code == 0:
            reset(style)
        elif code == 1:
            style.bold = True
        elif code == 2:
            style.dim = True
        elif code == 3:
            style.italic = True
        elif code == 4:
            style.underline = True
        elif code == 7:
            style.reverse = True
        elif code == 22:
            style.bold = False
            style.dim = False
        elif code == 23:
            style.italic = False
        elif code == 24:
            style.underline = False
        elif code == 27:
            style.reverse = False
        elif 30 <= code <= 37:
            style.fg = BASE_COLORS[code - 30]
        elif code == 39:
            style.fg = None
        elif 40 <= code <= 47:
            style.bg = BASE_COLORS[code - 40]
        elif code == 49:
            style.bg = None
        elif 90 <= code <= 97:
            style.fg = BASE_COLORS[code - 90 + 8]
        elif 100 <= code <= 107:
            style.bg = BASE_COLORS[code - 100 + 8]
        elif code in (38, 48):
            foreground = code == 38
            if i + 1 >= len(parts):
                break
            mode = parts[i + 1]
            if mode == "5" and i + 2 < len(parts):
                try:
                    color = ansi256(int(parts[i + 2]))
                except ValueError:
                    break
                if foreground:
                    style.fg = color
                else:
                    style.bg = color
                i += 3
                continue
            if mode == "2" and i + 4 < len(parts):
                try:
                    color = tuple(int(value) for value in parts[i + 2:i + 5])
                except ValueError:
                    break
                if len(color) == 3:
                    if foreground:
                        style.fg = color
                    else:
                        style.bg = color
                    i += 5
                    continue
            i += 2
            continue

        i += 1


def parse_ansi(text: str) -> list[list[tuple[str, Style]]]:
    lines: list[list[tuple[str, Style]]] = []
    current: list[tuple[str, Style]] = []
    style = Style()
    i = 0

    while i < len(text):
        char = text[i]

        if char == "\x1b":
            match = ANSI_RE.match(text, i)
            if match:
                params, final = match.groups()
                if final == "m" and (not params or params[0] not in "?<>!"):
                    apply_sgr(style, params)
                i = match.end()
                continue

            match = OSC_RE.match(text, i)
            if match:
                i = match.end()
                continue

            i += 1
            continue

        if char == "\n":
            lines.append(current)
            current = []
            i += 1
            continue

        if char == "\r":
            i += 1
            continue

        if char == "\t":
            current.append((" ", style.copy()))
            i += 1
            continue

        current.append((char, style.copy()))
        i += 1

    if current or not lines:
        lines.append(current)

    return lines


def css_for(style: Style) -> str:
    fg = style.fg or DEFAULT_FG
    bg = style.bg or DEFAULT_BG
    if style.reverse:
        fg, bg = bg, fg

    declarations = [
        f"color:{hex_color(fg)}",
        f"background-color:{hex_color(bg)}",
    ]
    if style.bold:
        declarations.append("font-weight:700")
    if style.italic:
        declarations.append("font-style:italic")
    if style.underline:
        declarations.append("text-decoration:underline")
    if style.dim:
        declarations.append("opacity:0.65")

    return ";".join(declarations)


def matched_words(state: dict) -> list[str]:
    words = []
    for match in state.get("matches", []):
        found = re.search(r"\\<([^\\]+)\\>", match.get("pattern", ""))
        if found:
            words.append(found.group(1))
    return words


def state_summary(state: dict) -> str:
    words = ", ".join(sorted(matched_words(state))) or "none"
    autocmds = sum(state.get("autocmds", {}).values())
    return (
        f"mode: {state.get('mode') or 'off'} · "
        f"matches: {len(state.get('matches', []))} ({words}) · "
        f"autocmds: {autocmds}"
    )


def render_terminal(
    ansi_text: str,
    *,
    width: int,
    height: int,
    cursor: tuple[int, int] | None,
) -> str:
    lines = parse_ansi(ansi_text)
    if len(lines) > height:
        lines = lines[:height]
    while len(lines) < height:
        lines.append([])

    rendered = []
    for row, cells in enumerate(lines):
        if len(cells) > width:
            cells = cells[:width]
        if len(cells) < width:
            cells = cells + [(" ", Style()) for _ in range(width - len(cells))]

        spans = []
        for col, (char, style) in enumerate(cells):
            escaped = html.escape(char)
            if cursor is not None and cursor == (col, row):
                spans.append(f'<span class="cursor">{escaped}</span>')
            else:
                spans.append(f'<span style="{css_for(style)}">{escaped}</span>')

        rendered.append('<div class="line">' + "".join(spans) + "</div>")

    return "\n".join(rendered)


def render_html(
    *,
    title: str,
    caption: str,
    command: str | None,
    state: dict,
    ansi_text: str,
    cursor: tuple[int, int] | None,
    width: int,
    height: int,
    status: str,
    detail: str = "",
) -> str:
    status_class = "pass" if status == "PASS" else "fail"
    command_html = (
        f'<code>{html.escape(command)}</code>' if command else "<em>no command</em>"
    )
    detail_html = f'<p class="detail">{html.escape(detail)}</p>' if detail else ""
    terminal = render_terminal(
        ansi_text, width=width, height=height, cursor=cursor
    )

    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} — vim-ditto E2E</title>
<style>
  :root {{
    color-scheme: dark;
    --bg: #0b0d10;
    --panel: #14161b;
    --border: #2a2f3a;
    --text: #e0e2ea;
    --muted: #9aa0af;
    --accent: #ffd866;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0;
    padding: 32px;
    background: var(--bg);
    color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }}
  main {{ width: max-content; max-width: 100%; }}
  .eyebrow {{
    margin: 0 0 6px;
    color: var(--accent);
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.14em;
    text-transform: uppercase;
  }}
  h1 {{ margin: 0 0 6px; font-size: 24px; line-height: 1.2; }}
  .caption {{ margin: 0 0 10px; color: var(--muted); font-size: 15px; }}
  .meta {{
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 10px;
    margin: 0 0 16px;
    color: var(--muted);
    font-size: 13px;
  }}
  .badge {{
    border-radius: 999px;
    padding: 3px 9px;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 0.08em;
  }}
  .badge.pass {{ background: #1f6f43; color: #d8ffe8; }}
  .badge.fail {{ background: #7a2430; color: #ffe2e6; }}
  code {{
    border: 1px solid var(--border);
    border-radius: 5px;
    padding: 2px 6px;
    background: #191c22;
    color: #f2d27a;
    font: 12px/1.4 "SFMono-Regular", Menlo, Monaco, Consolas, monospace;
  }}
  .frame {{
    overflow: hidden;
    border: 1px solid var(--border);
    border-radius: 12px;
    background: var(--panel);
    box-shadow: 0 18px 50px rgba(0, 0, 0, 0.45);
  }}
  .bar {{
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 14px;
    border-bottom: 1px solid var(--border);
    background: #1b1e25;
    color: var(--muted);
    font-size: 12px;
  }}
  .dot {{ width: 10px; height: 10px; border-radius: 50%; display: inline-block; }}
  .dot.red {{ background: #ff5f57; }}
  .dot.yellow {{ background: #febc2e; }}
  .dot.green {{ background: #28c840; }}
  .bar-title {{ margin-left: 6px; }}
  .terminal {{
    margin: 0;
    padding: 14px 18px;
    overflow: visible;
    font-family: "SFMono-Regular", Menlo, Monaco, Consolas, "Liberation Mono", monospace;
    font-size: 14px;
    line-height: 1.35;
    font-variant-ligatures: none;
    tab-size: 8;
  }}
  .line {{ min-height: 1.35em; white-space: pre; }}
  .cursor {{ background: #e0e2ea !important; color: #14161b !important; }}
  .detail {{
    margin: 14px 0 0;
    color: var(--muted);
    font-size: 13px;
  }}
</style>
</head>
<body>
<main>
  <p class="eyebrow">vim-ditto end-to-end</p>
  <h1>{html.escape(title)}</h1>
  <p class="caption">{html.escape(caption)}</p>
  <div class="meta">
    <span class="badge {status_class}">{html.escape(status)}</span>
    <span>{html.escape(state_summary(state))}</span>
    <span>command: {command_html}</span>
  </div>
  <section class="frame">
    <div class="bar">
      <span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span>
      <span class="bar-title">nvim — test/e2e/fixtures/sample.txt</span>
    </div>
    <div class="terminal">
{terminal}
    </div>
  </section>
  {detail_html}
</main>
</body>
</html>
"""
