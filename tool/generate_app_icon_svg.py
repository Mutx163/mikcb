#!/usr/bin/env python3
"""Generate docs/app-icon.svg: the launcher icon with the app's own corner radius.

README 直接引用官网方图，GitHub README 会过滤 CSS，无法用样式裁圆角；
因此照 lib/screens/about_screen.dart 里应用图标的做法（84px 显示、24px
圆角，比例 24/84 ≈ 28.6%）把图标缩放后嵌入自绘 SVG，用 clipPath 裁出
同样的圆角。图标资产更新后重跑本脚本即可：

    python tool/generate_app_icon_svg.py
"""

from __future__ import annotations

import base64
import io
from pathlib import Path

from PIL import Image

SOURCE = Path("assets/branding/launcher_icon.png")
OUTPUT = Path("docs/app-icon.svg")
EMBED_SIZE = 192  # README 显示 96，嵌入 2 倍图保证高分屏清晰
# 与 about_screen.dart 一致：显示 84px、圆角 24px。
INSET_DISPLAY = 84
RADIUS_DISPLAY = 24


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    image = image.resize((EMBED_SIZE, EMBED_SIZE), Image.LANCZOS)
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")

    radius = round(RADIUS_DISPLAY / INSET_DISPLAY * EMBED_SIZE)
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{EMBED_SIZE}" height="{EMBED_SIZE}" '
        f'viewBox="0 0 {EMBED_SIZE} {EMBED_SIZE}">'
        "<defs>"
        f'<clipPath id="r"><rect x="0" y="0" width="{EMBED_SIZE}" '
        f'height="{EMBED_SIZE}" rx="{radius}" ry="{radius}"/></clipPath>'
        "</defs>"
        f'<g clip-path="url(#r)"><image x="0" y="0" width="{EMBED_SIZE}" '
        f'height="{EMBED_SIZE}" xlink:href="data:image/png;base64,{encoded}"/></g>'
        "</svg>"
    )
    OUTPUT.write_text(svg, encoding="utf-8")
    print(f"wrote {OUTPUT} ({OUTPUT.stat().st_size / 1024:.0f} KB, radius {radius}px)")


if __name__ == "__main__":
    main()
