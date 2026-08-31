"""Renders PRIVACY.md into a standalone site/index.html.

Play requires the privacy policy to live at a public URL. Keeping the policy in
Markdown as the source of truth and generating the page means the hosted
version cannot drift from the one in the repo.

Handles only the constructs PRIVACY.md actually uses: headings, bullets,
blockquotes, bold, inline code, and two-space hard line breaks.

    python3 tool/build_privacy_page.py
"""

import html
import pathlib
import re

SOURCE = pathlib.Path("PRIVACY.md")
OUTPUT = pathlib.Path("site/index.html")

STYLE = """
  :root { color-scheme: light dark; }
  body {
    font: 16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    max-width: 44rem; margin: 0 auto; padding: 2.5rem 1.25rem 4rem;
    color: #1a1c1e; background: #fff;
  }
  h1 { font-size: 1.75rem; line-height: 1.25; margin: 0 0 1rem; }
  h2 { font-size: 1.2rem; margin: 2.25rem 0 .6rem; }
  p, li { margin: 0 0 .85rem; }
  ul { padding-left: 1.25rem; }
  code {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: .875em; background: #f1f2f4; padding: .1em .35em; border-radius: 4px;
  }
  blockquote {
    margin: 1.25rem 0; padding: .75rem 1rem; border-left: 3px solid #c8ccd2;
    background: #f7f8fa; color: #44484e;
  }
  blockquote p { margin: 0; }
  @media (prefers-color-scheme: dark) {
    body { color: #e3e5e8; background: #16181a; }
    code { background: #26292d; }
    blockquote { background: #1e2124; border-left-color: #3a3f45; color: #b6bac0; }
  }
"""


def inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)


def render(markdown: str) -> str:
    out: list[str] = []
    in_list = in_quote = False

    def close() -> None:
        nonlocal in_list, in_quote
        if in_list:
            out.append("</ul>")
            in_list = False
        if in_quote:
            out.append("</blockquote>")
            in_quote = False

    for raw in markdown.splitlines():
        # Two trailing spaces mean a hard break; note it before stripping.
        hard_break = raw.endswith("  ") and raw.strip()
        line = raw.strip()

        if not line:
            close()
            continue

        if line.startswith("#"):
            close()
            level = len(line) - len(line.lstrip("#"))
            out.append(f"<h{level}>{inline(line[level:].strip())}</h{level}>")
        elif line.startswith("- "):
            if in_quote:
                out.append("</blockquote>")
                in_quote = False
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
        elif line.startswith("> "):
            if in_list:
                out.append("</ul>")
                in_list = False
            if not in_quote:
                out.append("<blockquote>")
                in_quote = True
            out.append(f"<p>{inline(line[2:])}</p>")
        else:
            fragment = inline(line) + ("<br>" if hard_break else "")
            # Continue the open paragraph rather than starting a new one, so
            # hard-wrapped prose reflows instead of breaking every line.
            if out and out[-1].startswith("<p>") and out[-1].endswith("</p>") \
                    and not in_quote and not in_list:
                joiner = "" if out[-1].endswith("<br></p>") else " "
                out[-1] = out[-1][: -len("</p>")] + joiner + fragment + "</p>"
            else:
                close()
                out.append(f"<p>{fragment}</p>")

    close()
    return "\n".join(out)


title = SOURCE.read_text().splitlines()[0].lstrip("# ").strip()
page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>{STYLE}</style>
</head>
<body>
{render(SOURCE.read_text())}
</body>
</html>
"""

OUTPUT.parent.mkdir(exist_ok=True)
OUTPUT.write_text(page)
print(f"wrote {OUTPUT} ({len(page)} bytes)")
