#!/usr/bin/env python3
"""Generate contributor avatar walls for README.md.

两个墙：
- 上游 shiguang_warehouse 全部贡献者（绝大多数学校适配在上游完成）。
- 教务仓库 qingyu_warehouse 的"直接贡献者"：出现在 fork 贡献者里、
  但从未出现在上游贡献者里的人。同步上游的合并提交会把上游作者
  带进 fork 的贡献者图，必须减掉，否则与上游墙重复。

头像是方形原图，GitHub README 会过滤 CSS，无法用样式裁圆；因此脚本
把头像下载后内嵌进自绘 SVG（嵌套 svg + pattern + circle，与 contrib.rocks
同款结构），按圆形裁切后落盘 docs/contributors/*.svg，README 引用。
头像字节不变则文件不变，重复运行幂等，供 GitHub Actions 定时重写：
  <!-- CONTRIBUTORS:AUTO:START --> ... <!-- CONTRIBUTORS:AUTO:END -->
  <!-- CONTRIBUTORS_DIRECT:AUTO:START --> ... <!-- CONTRIBUTORS_DIRECT:AUTO:END -->
"""

from __future__ import annotations

import base64
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

DEFAULT_UPSTREAM = "XingHeYuZhuan/shiguang_warehouse"
DEFAULT_FORK = "Mutx163/qingyu_warehouse"
README_PATH = Path("README.md")
SVG_DIR = Path("docs/contributors")

UPSTREAM_START = "<!-- CONTRIBUTORS:AUTO:START -->"
UPSTREAM_END = "<!-- CONTRIBUTORS:AUTO:END -->"
DIRECT_START = "<!-- CONTRIBUTORS_DIRECT:AUTO:START -->"
DIRECT_END = "<!-- CONTRIBUTORS_DIRECT:AUTO:END -->"

CELL = 64  # 单个头像显示直径（px）
GAP = 4  # 头像间距（px）
COLUMNS = 12
USER_AGENT = "mikcb-contributors-generator"


def fetch_contributors(repo: str, token: str | None) -> list[str]:
    """GitHub API 按贡献数降序返回贡献者，逐页取完。"""
    logins: list[str] = []
    page = 1
    while True:
        url = f"https://api.github.com/repos/{repo}/contributors?per_page=100&page={page}"
        request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
        if token:
            request.add_header("Authorization", f"Bearer {token}")
        with urllib.request.urlopen(request, timeout=30) as response:
            items = json.load(response)
        if not items:
            break
        logins.extend(item["login"] for item in items if item.get("type") == "User")
        if len(items) < 100:
            break
        page += 1
    return logins


def is_bot(login: str) -> bool:
    return login.endswith("[bot]")


def fetch_avatar(login: str) -> tuple[bytes | None, str]:
    """返回 (图片字节, MIME 类型)；下载失败或类型不明时返回 (None, "")。"""
    url = f"https://github.com/{login}.png?size={CELL * 2}"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = response.read()
    except OSError as error:
        print(f"warn: avatar download failed for {login}: {error}", file=sys.stderr)
        return None, ""
    if data.startswith(b"\x89PNG"):
        return data, "image/png"
    if data.startswith(b"\xff\xd8"):
        return data, "image/jpeg"
    print(f"warn: unknown avatar format for {login}", file=sys.stderr)
    return None, ""


def avatar_tile(login: str, index: int, x: int, y: int, data: bytes | None, mime: str) -> str:
    """单个头像：嵌套 svg + pattern + 圆形裁切（contrib.rocks 同款结构）。"""
    inner = f"<title>@{login}</title>"
    if data is not None:
        encoded = base64.b64encode(data).decode("ascii")
        inner += (
            f'<defs><pattern id="p{index}" x="0" y="0" width="{CELL}" height="{CELL}" '
            f'patternUnits="userSpaceOnUse">'
            f'<image x="0" y="0" width="{CELL}" height="{CELL}" '
            f'xlink:href="data:{mime};base64,{encoded}"/></pattern></defs>'
            f'<circle cx="{CELL // 2}" cy="{CELL // 2}" r="{CELL // 2}" fill="url(#p{index})"/>'
        )
    else:
        inner += (
            f'<circle cx="{CELL // 2}" cy="{CELL // 2}" r="{CELL // 2}" fill="#c8c8c8"/>'
        )
    return f'<svg x="{x}" y="{y}" width="{CELL}" height="{CELL}">{inner}</svg>'


def build_wall_svg(logins: list[str]) -> str:
    """把头像铺成网格，输出完整 SVG 文本。头像并发下载。"""
    columns = min(COLUMNS, max(len(logins), 1))
    rows = (len(logins) + columns - 1) // columns
    width = columns * CELL + (columns - 1) * GAP
    height = rows * CELL + (rows - 1) * GAP

    with ThreadPoolExecutor(max_workers=8) as pool:
        avatars = list(pool.map(fetch_avatar, logins))

    tiles = []
    for index, (login, (data, mime)) in enumerate(zip(logins, avatars)):
        x = (index % columns) * (CELL + GAP)
        y = (index // columns) * (CELL + GAP)
        tiles.append(avatar_tile(login, index, x, y, data, mime))
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{width}" height="{height}" viewBox="0 0 {width} {height}">'
        + "".join(tiles)
        + "</svg>"
    )


def replace_between(text: str, start: str, end: str, payload: str, label: str) -> str:
    begin = text.find(start)
    finish = text.find(end)
    if begin == -1 or finish == -1 or finish < begin:
        raise SystemExit(f"README 缺少 {label} 标记（{start} / {end}），无法写入")
    return text[: begin + len(start)] + "\n" + payload + "\n" + text[finish:]


def main() -> None:
    upstream_repo = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_UPSTREAM
    fork_repo = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_FORK
    token = os.environ.get("GITHUB_TOKEN") or None

    upstream = fetch_contributors(upstream_repo, token)
    fork = fetch_contributors(fork_repo, token)
    upstream_set = set(upstream)
    direct = [login for login in fork if login not in upstream_set and not is_bot(login)]

    SVG_DIR.mkdir(parents=True, exist_ok=True)
    (SVG_DIR / "upstream.svg").write_text(build_wall_svg(upstream), encoding="utf-8")
    (SVG_DIR / "direct.svg").write_text(build_wall_svg(direct), encoding="utf-8")

    readme = README_PATH.read_text(encoding="utf-8")
    readme = replace_between(
        readme,
        UPSTREAM_START,
        UPSTREAM_END,
        f'<img src="{SVG_DIR.as_posix()}/upstream.svg" alt="{upstream_repo} 贡献者" />',
        "上游贡献者",
    )
    readme = replace_between(
        readme,
        DIRECT_START,
        DIRECT_END,
        f'<img src="{SVG_DIR.as_posix()}/direct.svg" alt="{fork_repo} 直接贡献者" />',
        "直接贡献者",
    )
    README_PATH.write_text(readme, encoding="utf-8")
    print(f"upstream({upstream_repo}): {len(upstream)} contributors")
    print(f"direct({fork_repo}): {len(direct)} contributors")


if __name__ == "__main__":
    main()
