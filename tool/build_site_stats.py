#!/usr/bin/env python3
"""抓 GitHub 星标数与版本数，写入同域静态文件 docs/site-stats.json。

为什么要有这个脚本：官网首页的「GitHub Stars」和「公开版本数」过去由浏览器直接请求
api.github.com。国内网络经常几十秒不返回，页面就只剩「—」。现在改成 CI 定时跑这个脚本，
把数字写成 163366.xyz 自己的静态文件，浏览器只读同域文件。

版本数取自 docs/releases/latest.json 的 releaseCount（由 update-docs-releases.yml 维护），
不重复打 GitHub 的 releases 列表接口。抓取失败时保留旧文件、退出码仍为 0，避免定时任务红。
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "site-stats.json"
LATEST = ROOT / "docs" / "releases" / "latest.json"
REPO = "Mutx163/mikcb"


def github_json(url: str) -> dict:
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "mikcb-site-stats",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    try:
        info = github_json(f"https://api.github.com/repos/{REPO}")
        stars = int(info.get("stargazers_count") or 0)
        if stars <= 0:
            raise ValueError(f"unexpected stars: {stars}")
        latest = json.loads(LATEST.read_text(encoding="utf-8"))
        release_count = int(latest.get("releaseCount") or 0)
        if release_count <= 0:
            raise ValueError(f"unexpected releaseCount in {LATEST}: {release_count}")
        payload = {
            "stars": stars,
            "releaseCount": release_count,
            "updatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
        OUT.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"site-stats: stars={stars} releaseCount={release_count}")
        return 0
    except Exception as error:  # noqa: BLE001 - 失败要保留旧值，不让定时任务红
        print(f"WARN: 抓取失败，保留现有 {OUT}：{error}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
