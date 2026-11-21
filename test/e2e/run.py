#!/usr/bin/env python3
"""End-to-end test for vim-ditto in a real Neovim TUI.

The test starts Neovim inside a dedicated tmux server, drives it through a
small writing scenario over RPC, checks the plugin state and the actual
highlight attributes on screen, captures the terminal after every step, and
renders the captures to PNG screenshots with Playwright.

Run it with:

    make e2e

Artifacts are written to test/e2e/out/.
"""

from __future__ import annotations

import html
import http.server
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

import render

ROOT = Path(__file__).resolve().parents[2]
E2E_DIR = Path(__file__).resolve().parent
OUT = E2E_DIR / "out"
ANSI_DIR = OUT / "ansi"
STATE_DIR = OUT / "state"
HTML_DIR = OUT / "html"
SHOT_DIR = OUT / "screenshots"
DITTO_DIR = OUT / "ditto"
INIT = E2E_DIR / "init.vim"
FIXTURE = E2E_DIR / "fixtures" / "sample.txt"

TMUX_SOCKET = f"ditto-e2e-{os.getpid()}"
TMUX_SESSION = "ditto"
NVIM_SOCKET = OUT / "nvim.sock"


@dataclass
class Step:
    slug: str
    title: str
    caption: str
    action: tuple[str, str] | None = None
    setup: list[str] = field(default_factory=list)
    expected: dict = field(default_factory=dict)
    redraw_after: bool = True


ON_AUTOCMDS = {"TextChanged": 1, "TextChangedI": 1, "WinEnter": 1}
OFF_AUTOCMDS = {"TextChanged": 0, "TextChangedI": 0, "WinEnter": 0}


def step(
    slug: str,
    title: str,
    caption: str,
    action: tuple[str, str] | None = None,
    *,
    setup: list[str] | None = None,
    redraw_after: bool = True,
    **expected,
) -> Step:
    return Step(
        slug=slug,
        title=title,
        caption=caption,
        action=action,
        setup=setup or [],
        expected=expected,
        redraw_after=redraw_after,
    )


STEPS: list[Step] = [
    step(
        "01-baseline",
        "Baseline — no highlights",
        "The sample text is open in Neovim. Ditto has not been enabled yet.",
        setup=["cursor(1, 1)"],
        mode="",
        match_words=set(),
        groups={},
        autocmds=OFF_AUTOCMDS,
        good_words=[],
        screen_plain=["quick", "beagle", "writing", "needs"],
    ),
    step(
        "02-paragraph-on",
        "Paragraph mode — :DittoOn",
        "Each paragraph highlights its own most-repeated words: beagle, writing and needs.",
        ("ex", "DittoOn"),
        setup=["cursor(1, 1)"],
        mode="paragraph",
        match_words={"beagle", "writing", "needs"},
        groups={
            "beagle": "DittoE2E1",
            "writing": "DittoE2E1",
            "needs": "DittoE2E2",
        },
        autocmds=ON_AUTOCMDS,
        good_words=[],
        screen_plain=["quick"],
        screen_nonplain=["beagle", "writing", "needs"],
        screen_groups=[["beagle", "writing"], ["needs"]],
    ),
    step(
        "03-next",
        "DittoNext — jump to a highlighted word",
        "The cursor moves from line 1 to the first highlighted word, beagle.",
        ("map", "DittoNext"),
        setup=["cursor(1, 1)"],
        mode="paragraph",
        match_words={"beagle", "writing", "needs"},
        groups={
            "beagle": "DittoE2E1",
            "writing": "DittoE2E1",
            "needs": "DittoE2E2",
        },
        autocmds=ON_AUTOCMDS,
        good_words=[],
        cursor_line=3,
        cursor_word="beagle",
        screen_plain=["quick"],
        screen_nonplain=["beagle", "writing", "needs"],
        screen_groups=[["beagle", "writing"], ["needs"]],
    ),
    step(
        "04-good-word",
        "DittoGood — ignore “beagle”",
        "The ignored word disappears from the highlights and is saved to dittofile.txt.",
        ("map", "DittoGood"),
        redraw_after=False,
        mode="paragraph",
        match_words={"writing", "needs"},
        groups={"writing": "DittoE2E1", "needs": "DittoE2E2"},
        autocmds=ON_AUTOCMDS,
        good_words=["beagle"],
        cursor_line=3,
        cursor_word="beagle",
        screen_plain=["quick", "beagle"],
        screen_nonplain=["writing", "needs"],
        screen_groups=[["writing"], ["needs"]],
    ),
    step(
        "05-bad-word",
        "DittoBad — stop ignoring “beagle”",
        "The word is removed from the good-words file and highlighted again.",
        ("map", "DittoBad"),
        redraw_after=False,
        mode="paragraph",
        match_words={"beagle", "writing", "needs"},
        groups={
            "beagle": "DittoE2E1",
            "writing": "DittoE2E1",
            "needs": "DittoE2E2",
        },
        autocmds=ON_AUTOCMDS,
        good_words=[],
        cursor_line=3,
        cursor_word="beagle",
        screen_plain=["quick"],
        screen_nonplain=["beagle", "writing", "needs"],
        screen_groups=[["beagle", "writing"], ["needs"]],
    ),
    step(
        "06-more",
        "DittoMore — cycle to the next word",
        "Only the next most-used word in each paragraph is shown: beagle and needs.",
        ("map", "DittoMore"),
        mode="paragraph",
        match_words={"beagle", "needs"},
        groups={"beagle": "DittoE2E1", "needs": "DittoE2E1"},
        autocmds=ON_AUTOCMDS,
        good_words=[],
        screen_plain=["quick", "writing"],
        screen_nonplain=["beagle", "needs"],
        screen_groups=[["beagle", "needs"]],
    ),
    step(
        "07-less",
        "DittoLess — cycle back",
        "All configured highlight groups are used again: beagle, writing and needs.",
        ("map", "DittoLess"),
        mode="paragraph",
        match_words={"beagle", "writing", "needs"},
        groups={
            "beagle": "DittoE2E1",
            "writing": "DittoE2E1",
            "needs": "DittoE2E2",
        },
        autocmds=ON_AUTOCMDS,
        good_words=[],
        screen_plain=["quick"],
        screen_nonplain=["beagle", "writing", "needs"],
        screen_groups=[["beagle", "writing"], ["needs"]],
    ),
    step(
        "08-file-on",
        "File mode — :DittoFileOn",
        "File scope changes the winners: writing and beagle across the whole file. needs is no longer highlighted.",
        ("ex", "DittoFileOn"),
        mode="file",
        match_words={"writing", "beagle"},
        groups={"writing": "DittoE2E1", "beagle": "DittoE2E2"},
        autocmds=ON_AUTOCMDS,
        good_words=[],
        screen_plain=["quick", "needs"],
        screen_nonplain=["writing", "beagle"],
        screen_groups=[["writing"], ["beagle"]],
    ),
    step(
        "09-off",
        "DittoOff — clean up",
        "Matches and buffer-local autocmds are removed.",
        ("ex", "DittoOff"),
        mode="",
        match_words=set(),
        groups={},
        autocmds=OFF_AUTOCMDS,
        good_words=[],
        screen_plain=["quick", "beagle", "writing", "needs"],
    ),
]


class E2EFailure(Exception):
    pass


def run_cmd(args: list[str], *, check: bool = True, timeout: float = 30) -> subprocess.CompletedProcess:
    result = subprocess.run(
        args,
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
    )
    if check and result.returncode != 0:
        raise E2EFailure(
            "command failed: {}\nstdout:\n{}\nstderr:\n{}".format(
                " ".join(shlex.quote(part) for part in args),
                result.stdout.strip(),
                result.stderr.strip(),
            )
        )
    return result


def require(executable: str, hint: str) -> None:
    if shutil.which(executable) is None:
        raise E2EFailure(f"required executable not found: {executable}\n{hint}")


def rpc(expr: str) -> str:
    result = run_cmd(
        ["nvim", "--server", str(NVIM_SOCKET), "--remote-expr", expr],
        check=False,
        timeout=20,
    )
    if result.returncode != 0:
        raise E2EFailure(
            f"Neovim RPC failed for {expr!r}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result.stdout.rstrip("\n")


def ex(command: str) -> str:
    return rpc(f"execute({json.dumps(command)})")


def mapping(name: str) -> str:
    # The double-quoted string is evaluated by Neovim, so \<Plug> becomes the
    # special key.  feedkeys() runs the mapping as if it had been typed, which
    # also makes the command-line message from DittoGood/DittoBad visible.
    return rpc(f'feedkeys("\\<Plug>{name}>", "xt")')


def get_state() -> dict:
    raw = rpc("json_encode(DittoE2EState())")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise E2EFailure(f"could not parse state JSON: {raw}") from exc


def tmux(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return run_cmd(
        ["tmux", "-L", TMUX_SOCKET, *args],
        check=check,
        timeout=20,
    )


def start_editor() -> None:
    DITTO_DIR.mkdir(parents=True, exist_ok=True)
    (DITTO_DIR / "dittofile.txt").write_text("", encoding="utf-8")

    editor_command = " ".join(
        [
            "env",
            "TERM=xterm-256color",
            f"DITTO_E2E_DIR={shlex.quote(str(DITTO_DIR))}",
            "nvim",
            "--listen",
            shlex.quote(str(NVIM_SOCKET)),
            "-Nu",
            shlex.quote(str(INIT)),
            "-n",
            shlex.quote(str(FIXTURE)),
        ]
    )

    tmux(
        "-f",
        "/dev/null",
        "new-session",
        "-d",
        "-s",
        TMUX_SESSION,
        "-x",
        "110",
        "-y",
        "26",
        "-c",
        str(ROOT),
        editor_command,
    )

    deadline = time.time() + 15
    while time.time() < deadline:
        if NVIM_SOCKET.exists():
            try:
                rpc("1")
                return
            except E2EFailure:
                pass
        time.sleep(0.05)

    raise E2EFailure(f"Neovim did not start listening on {NVIM_SOCKET}")


def stop_editor() -> None:
    tmux("kill-server", check=False)
    try:
        NVIM_SOCKET.unlink()
    except FileNotFoundError:
        pass


def pane_size() -> tuple[int, int]:
    output = tmux(
        "display-message",
        "-p",
        "-t",
        TMUX_SESSION,
        "#{pane_width},#{pane_height}",
    ).stdout.strip()
    width, height = (int(value) for value in output.split(",", 1))
    return width, height


def screen_cursor() -> tuple[int, int] | None:
    output = tmux(
        "display-message",
        "-p",
        "-t",
        TMUX_SESSION,
        "#{cursor_x},#{cursor_y},#{cursor_flag}",
    ).stdout.strip()
    x, y, visible = (int(value) for value in output.split(",", 2))
    return (x, y) if visible else None


def capture_screen() -> str:
    return tmux(
        "capture-pane",
        "-ep",
        "-t",
        TMUX_SESSION,
    ).stdout


def redraw() -> None:
    rpc('execute("redraw!")')
    time.sleep(0.08)


def clear_message() -> None:
    rpc(r'feedkeys(":echo \"\"\<CR>", "xt")')
    time.sleep(0.05)


def words_from_matches(state: dict) -> set[str]:
    return set(render.matched_words(state))


def group_map(state: dict) -> dict[str, str]:
    result = {}
    for match in state.get("matches", []):
        found = re.search(r"\\<([^\\]+)\\>", match.get("pattern", ""))
        if found:
            result[found.group(1)] = match.get("group", "")
    return result


def attr_for(state: dict, word: str) -> int | None:
    entry = state.get("screen_attrs", {}).get(word)
    if not entry or len(entry) != 5:
        return None
    return entry[4]


def check_step(
    current: Step,
    state: dict,
    fixture_lines: list[str],
    failures: list[str],
) -> list[str]:
    step_failures: list[str] = []
    expected = current.expected

    def fail(message: str) -> None:
        step_failures.append(message)

    def expect_equal(name: str, actual, wanted) -> None:
        if actual != wanted:
            fail(f"{name}: expected {wanted!r}, got {actual!r}")

    if "mode" in expected:
        expect_equal("mode", state.get("mode", ""), expected["mode"])

    actual_words = words_from_matches(state)
    if "match_words" in expected:
        expect_equal("matched words", actual_words, set(expected["match_words"]))

    if "groups" in expected:
        expect_equal("highlight groups", group_map(state), expected["groups"])

    if "autocmds" in expected:
        expect_equal("autocmds", state.get("autocmds", {}), expected["autocmds"])

    if "good_words" in expected:
        expect_equal("good words", state.get("good_words", []), expected["good_words"])

    if "cursor_line" in expected:
        expect_equal("cursor line", state.get("cursor", [0, 0])[0], expected["cursor_line"])

    if "cursor_word" in expected:
        expect_equal("word under cursor", state.get("word", ""), expected["cursor_word"])

    if state.get("lines") != fixture_lines:
        fail("buffer contents changed unexpectedly")

    plain = attr_for(state, "quick")
    for word in expected.get("screen_plain", []):
        actual = attr_for(state, word)
        if actual is None or actual != plain:
            fail(
                f"expected {word!r} to be rendered without a Ditto highlight "
                f"(attr {actual!r}, plain attr {plain!r})"
            )

    for word in expected.get("screen_nonplain", []):
        actual = attr_for(state, word)
        if actual is None or actual == plain:
            fail(
                f"expected {word!r} to be rendered with a Ditto highlight "
                f"(attr {actual!r}, plain attr {plain!r})"
            )

    groups = expected.get("screen_groups", [])
    group_attrs = []
    for group in groups:
        attrs = {attr_for(state, word) for word in group}
        if None in attrs or len(attrs) != 1:
            fail(f"expected {group!r} to share one rendered highlight, got {attrs!r}")
        group_attrs.append(next(iter(attrs), None))
    if len(set(group_attrs)) != len(group_attrs):
        fail(f"expected different colors for {groups!r}, got {group_attrs!r}")

    failures.extend(f"{current.slug}: {message}" for message in step_failures)
    return step_failures


def action_label(current: Step) -> str | None:
    if current.action is None:
        return None
    kind, name = current.action
    if kind == "map":
        return f"<Plug>{name}"
    return f":{name}"


def perform(current: Step) -> str | None:
    clear_message()
    for expression in current.setup:
        rpc(expression)

    label = action_label(current)
    if current.action is not None:
        kind, name = current.action
        if kind == "ex":
            ex(name)
        elif kind == "map":
            mapping(name)
        else:
            raise E2EFailure(f"unknown action kind: {kind}")

    if current.redraw_after:
        redraw()
    else:
        time.sleep(0.08)
    return label


def save_step(current: Step, ansi: str, state: dict, cursor) -> None:
    (ANSI_DIR / f"{current.slug}.ansi").write_text(ansi, encoding="utf-8")
    (STATE_DIR / f"{current.slug}.json").write_text(
        json.dumps(state, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def write_step_html(
    current: Step,
    state: dict,
    ansi: str,
    cursor,
    width: int,
    height: int,
    status: str,
    detail: str,
) -> Path:
    page = render.render_html(
        title=current.title,
        caption=current.caption,
        command=action_label(current),
        state=state,
        ansi_text=ansi,
        cursor=cursor,
        width=width,
        height=height,
        status=status,
        detail=detail,
    )
    path = HTML_DIR / f"{current.slug}.html"
    path.write_text(page, encoding="utf-8")
    return path


def run_playwright(args: list[str], *, session: str, check: bool = True) -> subprocess.CompletedProcess:
    return run_cmd(
        ["playwright-cli", f"-s={session}", *args],
        check=check,
        timeout=90,
    )


class QuietHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:
        pass


def start_http_server() -> tuple[http.server.ThreadingHTTPServer, str]:
    handler = lambda *args, **kwargs: QuietHTTPRequestHandler(  # noqa: E731
        *args, directory=str(OUT), **kwargs
    )
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    host, port = server.server_address
    return server, f"http://{host}:{port}"


def take_screenshots(html_paths: list[tuple[Step, Path]], base_url: str) -> list[Path]:
    session = f"ditto-e2e-{os.getpid()}"
    screenshots: list[Path] = []
    first = True
    try:
        for current, html_path in html_paths:
            url = f"{base_url}/html/{html_path.name}"
            if first:
                run_playwright(
                    ["open", url, "--browser=chrome"],
                    session=session,
                )
                run_playwright(["resize", "1400", "900"], session=session)
                first = False
            else:
                run_playwright(["goto", url], session=session)

            png_path = SHOT_DIR / f"{current.slug}.png"
            result = run_playwright(
                [
                    "screenshot",
                    "--filename",
                    str(png_path),
                    "--full-page",
                    "--hires",
                ],
                session=session,
                check=False,
            )
            if result.returncode != 0:
                run_playwright(
                    [
                        "screenshot",
                        "--filename",
                        str(png_path),
                        "--full-page",
                    ],
                    session=session,
                )
            if not png_path.exists() or png_path.stat().st_size == 0:
                raise E2EFailure(f"screenshot was not created: {png_path}")
            screenshots.append(png_path)
    finally:
        run_playwright(["close"], session=session, check=False)
    return screenshots


def mono_font() -> str:
    for path in (
        "/System/Library/Fonts/Menlo.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ):
        if Path(path).exists():
            return path

    if shutil.which("fc-match"):
        result = run_cmd(
            ["fc-match", "-f", "%{file}", "monospace"],
            check=False,
            timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()

    return "monospace"


def make_contact_sheet(screenshots: list[Path]) -> Path | None:
    if not screenshots or shutil.which("montage") is None:
        return None

    output = OUT / "contact-sheet.png"
    font = mono_font()

    result = run_cmd(
        [
            "montage",
            "-background",
            "#0b0d10",
            "-fill",
            "#e0e2ea",
            "-font",
            font,
            "-pointsize",
            "14",
            "-label",
            "%t",
            *[str(path) for path in screenshots],
            "-tile",
            "3x",
            "-geometry",
            "+14+14",
            str(output),
        ],
        check=False,
        timeout=60,
    )
    if result.returncode != 0 or not output.exists():
        print("warning: could not create contact sheet", file=sys.stderr)
        if result.stderr.strip():
            print(result.stderr.strip(), file=sys.stderr)
        return None
    return output


def write_report(
    results: list[dict],
    screenshots: list[Path],
    contact_sheet: Path | None,
    failures: list[str],
) -> Path:
    rows = []
    for result in results:
        current = result["step"]
        state = result["state"]
        status = "PASS" if not result["failures"] else "FAIL"
        badge = "pass" if status == "PASS" else "fail"
        shot = f"screenshots/{current.slug}.png"
        details = ""
        if result["failures"]:
            details = "<ul>" + "".join(
                f"<li>{html.escape(message)}</li>" for message in result["failures"]
            ) + "</ul>"
        rows.append(
            f"""
            <section class="step {badge}">
              <div class="step-head">
                <h2>{html.escape(current.title)}</h2>
                <span class="badge {badge}">{status}</span>
              </div>
              <p>{html.escape(current.caption)}</p>
              <p class="meta"><code>{html.escape(action_label(current) or "no command")}</code>
                 · {html.escape(render.state_summary(state))}</p>
              <a class="shot" href="{shot}"><img src="{shot}" alt="{html.escape(current.title)}"></a>
              {details}
            </section>
            """
        )

    contact_html = ""
    if contact_sheet is not None:
        contact_html = (
            '<p><a href="contact-sheet.png">Open the contact sheet</a></p>'
        )

    page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>vim-ditto E2E report</title>
<style>
  :root {{ color-scheme: dark; }}
  body {{
    margin: 0; padding: 40px; background: #0b0d10; color: #e0e2ea;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }}
  h1 {{ margin-top: 0; }}
  .summary {{ color: #9aa0af; margin-bottom: 28px; }}
  .step {{
    margin: 0 0 36px; padding: 20px; border: 1px solid #2a2f3a;
    border-radius: 12px; background: #14161b;
  }}
  .step-head {{ display: flex; align-items: center; gap: 12px; }}
  .step h2 {{ margin: 0; font-size: 20px; }}
  .step p {{ color: #b6bcc9; }}
  .meta {{ color: #9aa0af; font-size: 13px; }}
  code {{
    padding: 2px 6px; border: 1px solid #2a2f3a; border-radius: 5px;
    background: #191c22; color: #f2d27a;
    font-family: "SFMono-Regular", Menlo, Monaco, Consolas, monospace;
  }}
  .badge {{
    border-radius: 999px; padding: 3px 9px;
    font-size: 11px; font-weight: 800; letter-spacing: 0.08em;
  }}
  .badge.pass {{ background: #1f6f43; color: #d8ffe8; }}
  .badge.fail {{ background: #7a2430; color: #ffe2e6; }}
  .shot img {{ max-width: 100%; border-radius: 8px; border: 1px solid #2a2f3a; }}
  ul {{ color: #ffb3bd; }}
</style>
</head>
<body>
<h1>vim-ditto end-to-end report</h1>
<p class="summary">
  {len(results)} steps · {len(failures)} failure(s) ·
  real Neovim TUI captured from tmux · screenshots rendered from the terminal.
</p>
{contact_html}
{''.join(rows)}
</body>
</html>
"""
    path = OUT / "report.html"
    path.write_text(page, encoding="utf-8")
    return path


def main() -> int:
    require("tmux", "Install tmux (for example: brew install tmux).")
    require("nvim", "Install Neovim 0.5 or newer.")
    require(
        "playwright-cli",
        "Install it with: npm install -g @playwright/cli",
    )

    if OUT.exists():
        shutil.rmtree(OUT)
    for directory in (ANSI_DIR, STATE_DIR, HTML_DIR, SHOT_DIR, DITTO_DIR):
        directory.mkdir(parents=True, exist_ok=True)

    fixture_lines = FIXTURE.read_text(encoding="utf-8").splitlines()
    failures: list[str] = []
    results: list[dict] = []
    html_paths: list[tuple[Step, Path]] = []

    try:
        start_editor()
        width, height = pane_size()
        redraw()

        for current in STEPS:
            perform(current)
            ansi = capture_screen()
            cursor = screen_cursor()
            state = get_state()
            save_step(current, ansi, state, cursor)

            step_failures = check_step(current, state, fixture_lines, failures)
            status = "PASS" if not step_failures else "FAIL"
            detail = ""
            if step_failures:
                detail = " | ".join(step_failures)

            html_path = write_step_html(
                current,
                state,
                ansi,
                cursor,
                width,
                height,
                status,
                detail,
            )
            html_paths.append((current, html_path))
            results.append(
                {
                    "step": current,
                    "state": state,
                    "failures": step_failures,
                }
            )

            word_list = ", ".join(sorted(words_from_matches(state))) or "none"
            print(
                f"{status} {current.slug:<18} "
                f"mode={state.get('mode') or 'off':<9} "
                f"matches={len(state.get('matches', [])):<2} ({word_list})"
            )
    finally:
        stop_editor()

    screenshots: list[Path] = []
    server, base_url = start_http_server()
    try:
        screenshots = take_screenshots(html_paths, base_url)
    except E2EFailure as exc:
        failures.append(f"screenshots: {exc}")
        print(f"FAIL screenshots: {exc}", file=sys.stderr)
    finally:
        server.shutdown()
        server.server_close()

    contact_sheet = make_contact_sheet(screenshots)
    report = write_report(results, screenshots, contact_sheet, failures)

    print()
    if failures:
        print(f"{len(failures)} failure(s):", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        print(f"\nArtifacts: {OUT}", file=sys.stderr)
        print(f"Report:    {report}", file=sys.stderr)
        return 1

    print(f"All {len(STEPS)} E2E steps passed.")
    print(f"Report:          {report}")
    if contact_sheet is not None:
        print(f"Contact sheet:   {contact_sheet}")
    print(f"Screenshots:     {SHOT_DIR}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except E2EFailure as error:
        print(f"E2E setup failed: {error}", file=sys.stderr)
        stop_editor()
        raise SystemExit(2)
