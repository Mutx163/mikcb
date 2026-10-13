#!/usr/bin/env python3
"""Generate contributor avatar walls for README.md.

两个墙：
- 上游 shiguang_warehouse 全部贡献者（绝大多数学校适配在上游完成）。
- 教务仓库 qingyu_warehouse 的"直接贡献者"：出现在 fork 贡献者里、
  但从未出现在上游贡献者里的人。同步上游的合并提交会把上游作者
  带进 fork 的贡献者图，必须减掉，否则与上游墙重复。

README 里由隐藏标记包裹，重复运行幂等，供 GitHub Actions 定时重写：
  <!-- CONTRIBUTORS:AUTO:START --> ... <!-- CONTRIBUTORS:AUTO:END -->
  <!-- CONTRIBUTORS_DIRECT:AUTO:START --> ... <!-- CONTRIBUTORS_DIRECT:AUTO:END -->
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

DEFAULT_UPSTREAM = "XingHeYuZhuan/shiguang_warehouse"
DEFAULT_FORK = "Mutx163/qingyu_warehouse"
README_PATH = Path("README.md")

UPSTREAM_START = "<!-- CONTRIBUTORS:AUTO:START -->"
UPSTREAM_END = "<!-- CONTRIBUTORS:AUTO:END -->"
DIRECT_START = "<!-- CONTRIBUTORS_DIRECT:AUTO:START -->"
DIRECT_END = "<!-- CONTRIBUTORS_DIRECT:AUTO:END -->"


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


def avatar_wall(logins: list[str]) -> str:
    """每行一个头像，git diff 粒度最细，增删一人只动一行。"""
    return "\n".join(
        f'<a href="https://github.com/{login}">'
        f'<img src="https://github.com/{login}.png?size=64" width="64" alt="@{login}" title="@{login}" />'
        f"</a>"
        for login in logins
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

    readme = README_PATH.read_text(encoding="utf-8")
    readme = replace_between(readme, UPSTREAM_START, UPSTREAM_END, avatar_wall(upstream), "上游贡献者")
    readme = replace_between(readme, DIRECT_START, DIRECT_END, avatar_wall(direct), "直接贡献者")
    README_PATH.write_text(readme, encoding="utf-8")
    print(f"upstream({upstream_repo}): {len(upstream)} contributors")
    print(f"direct({fork_repo}): {len(direct)} contributors")


if __name__ == "__main__":
    main()
