#!/usr/bin/env python3
"""Compile the FCG white paper from X article JSON into readable HTML + plain text."""

from __future__ import annotations

import html
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "build" / "fcg_article.json"
DOCS_IMG = ROOT / "docs" / "fcg"
HTML_OUT = ROOT / "fcg_white_paper.html"
TXT_OUT = ROOT / "fcg_white_paper.txt"
API_URL = "https://api.fxtwitter.com/rgsneddon/status/2048748971246358967"


def fetch_json() -> dict:
    if JSON_PATH.exists():
        return json.loads(JSON_PATH.read_text(encoding="utf-8"))
    with urllib.request.urlopen(API_URL, timeout=60) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return data


def download_image(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 0:
        return
    with urllib.request.urlopen(url, timeout=60) as resp:
        dest.write_bytes(resp.read())


def apply_inline_styles(text: str, ranges: list[dict]) -> str:
    if not ranges:
        return html.escape(text)
    parts: list[str] = []
    cursor = 0
    for span in sorted(ranges, key=lambda r: r["offset"]):
        start = span["offset"]
        end = start + span["length"]
        if start > cursor:
            parts.append(html.escape(text[cursor:start]))
        chunk = html.escape(text[start:end])
        style = span.get("style", "")
        if style == "Bold":
            parts.append(f"<strong>{chunk}</strong>")
        elif style == "Italic":
            parts.append(f"<em>{chunk}</em>")
        else:
            parts.append(chunk)
        cursor = end
    if cursor < len(text):
        parts.append(html.escape(text[cursor:]))
    return "".join(parts)


def build_entity_media(blocks: list[dict], media_entities: list[dict]) -> dict[int, dict]:
    """Map Draft.js entity keys to downloaded media (keys 0/1 are URLs, 2+ are images)."""
    image_keys: list[int] = []
    for block in blocks:
        if block.get("type") != "atomic":
            continue
        for ent in block.get("entityRanges", []):
            image_keys.append(ent["key"])
    entity_media: dict[int, dict] = {}
    for idx, key in enumerate(image_keys):
        if idx < len(media_entities):
            entity_media[key] = media_entities[idx]
    return entity_media


def section_header_html(text: str, ranges: list[dict]) -> str | None:
    bold = [r for r in ranges if r.get("style") == "Bold"]
    if (
        len(bold) == 1
        and bold[0]["offset"] == 0
        and bold[0]["length"] == len(text)
        and text.isupper()
        and len(text) <= 80
    ):
        return f"<h2>{html.escape(text)}</h2>"
    return None


def block_to_html(block: dict, entity_media: dict[int, dict]) -> str:
    btype = block.get("type", "unstyled")
    text = block.get("text", "")
    data = block.get("data", {}) or {}

    if btype == "atomic":
        for ent in block.get("entityRanges", []):
            media = entity_media.get(ent["key"])
            if media:
                url = media["media_info"]["original_img_url"]
                fname = url.rsplit("/", 1)[-1]
                local = f"docs/fcg/{fname}"
                return (
                    f'<figure class="equation"><img src="{html.escape(local)}" '
                    f'alt="FCG equation diagram" loading="lazy"><figcaption>Equation / diagram</figcaption></figure>'
                )
        return ""

    ranges = block.get("inlineStyleRanges", [])

    if btype in ("header-one", "header-two", "header-three"):
        level = {"header-one": 2, "header-two": 3, "header-three": 4}[btype]
        body = apply_inline_styles(text, ranges)
        return f"<h{level}>{body}</h{level}>"

    if btype == "unordered-list-item":
        body = apply_inline_styles(text, ranges)
        return f"<li>{body}</li>"

    header = section_header_html(text, ranges)
    if header:
        return header

    body = apply_inline_styles(text, ranges)
    for url_ent in data.get("urls", []):
        raw = url_ent["text"]
        link = html.escape(raw, quote=True)
        body = body.replace(html.escape(raw), f'<a href="{link}">{html.escape(raw)}</a>')
    return f"<p>{body}</p>" if body.strip() else ""


def blocks_to_html(blocks: list[dict], entity_media: dict[int, dict]) -> str:
    chunks: list[str] = []
    in_list = False
    for block in blocks:
        btype = block.get("type", "unstyled")
        if btype == "unordered-list-item":
            if not in_list:
                chunks.append("<ul>")
                in_list = True
            chunks.append(block_to_html(block, entity_media))
            continue
        if in_list:
            chunks.append("</ul>")
            in_list = False
        chunk = block_to_html(block, entity_media)
        if chunk:
            chunks.append(chunk)
    if in_list:
        chunks.append("</ul>")
    return "\n".join(chunks)


def blocks_to_text(blocks: list[dict], entity_media: dict[int, dict]) -> str:
    lines: list[str] = []
    for block in blocks:
        btype = block.get("type", "unstyled")
        text = block.get("text", "").strip()
        if btype == "atomic":
            for ent in block.get("entityRanges", []):
                media = entity_media.get(ent["key"])
                if media:
                    url = media["media_info"]["original_img_url"]
                    fname = url.rsplit("/", 1)[-1]
                    lines.append(f"[IMAGE: docs/fcg/{fname}]")
            continue
        if not text:
            continue
        if btype.startswith("header"):
            lines.append("")
            lines.append(text.upper())
            lines.append("-" * min(len(text), 72))
        elif btype == "unordered-list-item":
            lines.append(f"  • {text}")
        else:
            lines.append(text)
    return "\n".join(lines)


def main() -> int:
    data = fetch_json()
    article = data["tweet"]["article"]
    blocks = article["content"]["blocks"]
    media_entities = article.get("media_entities", [])

    entity_media = build_entity_media(blocks, media_entities)
    for item in media_entities:
        url = item["media_info"]["original_img_url"]
        fname = url.rsplit("/", 1)[-1]
        download_image(url, DOCS_IMG / fname)

    cover = article.get("cover_media", {})
    cover_url = cover.get("media_info", {}).get("original_img_url")
    if cover_url:
        download_image(cover_url, DOCS_IMG / "fcg_cover.jpg")

    title = article.get("title", "Full Community Governance White Paper")
    modified = article.get("modified_at", article.get("created_at", ""))

    body_html = blocks_to_html(blocks, entity_media)
    body_txt = blocks_to_text(blocks, entity_media)

    html_doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)} — Evolve FCG</title>
  <style>
    :root {{ color-scheme: light dark; }}
    body {{
      font-family: Georgia, "Times New Roman", serif;
      line-height: 1.55;
      max-width: 52rem;
      margin: 0 auto;
      padding: 2rem 1.25rem 3rem;
      background: #0a0e18;
      color: #d8dce8;
    }}
    h1, h2, h3, h4 {{ font-family: system-ui, sans-serif; color: #f4f6fb; }}
    h1 {{ font-size: 1.75rem; margin-bottom: 0.25rem; }}
    .meta {{ color: #9ba3b8; font-size: 0.9rem; margin-bottom: 1.5rem; }}
    a {{ color: #8b83ff; }}
    figure.cover, figure.equation {{
      margin: 1.5rem 0;
      text-align: center;
    }}
    figure img {{
      max-width: 100%;
      height: auto;
      border-radius: 8px;
      border: 1px solid #2d3348;
    }}
    figcaption {{ font-size: 0.8rem; color: #9ba3b8; margin-top: 0.5rem; }}
    ul {{ padding-left: 1.25rem; }}
    li {{ margin: 0.35rem 0; }}
    p {{ margin: 0.75rem 0; }}
    .source {{ margin-top: 2rem; font-size: 0.85rem; color: #9ba3b8; border-top: 1px solid #2d3348; padding-top: 1rem; }}
  </style>
</head>
<body>
  <header>
    <h1>{html.escape(title)}</h1>
    <p class="meta">Full Community Governance (FCG) · SSUCF social cohesion voting · Last updated {html.escape(modified)}</p>
    <figure class="cover">
      <img src="docs/fcg/fcg_cover.jpg" alt="FCG white paper cover" width="1168" height="467">
      <figcaption>Cover — Hyper-Local Democracy · Estimated Costings &amp; Potential Savings (UK)</figcaption>
    </figure>
  </header>
  <main>
{body_html}
  </main>
  <p class="source">Compiled for the Evolve repository from the author's X article (April 2026). Original: <a href="https://x.com/rgsneddon/status/2048748971246358967">@rgsneddon</a></p>
</body>
</html>
"""

    txt_doc = f"""{title}
{'=' * len(title)}
Source: https://x.com/rgsneddon/status/2048748971246358967
Last updated: {modified}

[COVER: docs/fcg/fcg_cover.jpg]

{body_txt}
"""

    HTML_OUT.write_text(html_doc, encoding="utf-8")
    TXT_OUT.write_text(txt_doc, encoding="utf-8")
    print(f"Wrote {HTML_OUT}")
    print(f"Wrote {TXT_OUT}")
    print(f"Images in {DOCS_IMG}")
    return 0


if __name__ == "__main__":
    sys.exit(main())