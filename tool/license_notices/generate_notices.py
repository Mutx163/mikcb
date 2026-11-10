#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""重生成 APK 内的开源许可清单（assets/licenses/NOTICES.gz）。

**为什么存在**：去 Flutter 化 P4-C 之后，`flutter_assets/NOTICES.Z` 永远不会再生成；
`android/app/src/main/assets/licenses/NOTICES.gz` 里那 1.49 MB 快照是 Flutter 时代
（Dart pub 包 + Flutter 引擎第三方）留下来的，和现在真正打进 APK 的 AndroidX / Compose /
Kotlin / miuix / okhttp / 友盟 / ML Kit 依赖完全对不上。本脚本从 **Gradle 解析出的
release 运行时 classpath** 重新汇总一份，格式与旧文件一致，App 侧解析器零改动。

## 格式（由 `parseFlutterNotices` 定死，不能改）

每个条目之间用**一整行恰好 80 个 `-`** 分隔；条目内：开头连续非空行 = 包名（一行一个），
空行之后是许可证正文，正文里的空行分段。

## 用法

```powershell
# 1) 从 Gradle 取依赖树（走全机互斥闸门，安静窗口执行；不会编译）
#    也可以自己先把输出存成文件，再用 --from-deps 喂进来
python tool/license_notices/generate_notices.py --dry-run

# 2) 真写（会覆盖 android/app/src/main/assets/licenses/NOTICES.gz）
python tool/license_notices/generate_notices.py --write

# 3) 只校验现有文件能不能被解析
python tool/license_notices/generate_notices.py --verify
```

## 许可正文本地化（不联网）

`templates/` 下的 Apache-2.0 / MIT / BSD 模板由 `--harvest` 从**旧 NOTICES 快照**里
原样摘出（同一份文件 App 一直在用），不是手抄。模板缺失时脚本会拒绝生成，
避免把「只写许可名、正文空着」的半成品打进 APK。

## 归属判定顺序（每条依赖）

1. 构件内自带的 `META-INF/LICENSE` / `LICENSE` / `COPYING` 正文；
2. 构件 POM 的 `<licenses><license><name>` → 映射到模板；
3. 已知 Maven group 的确定归属（androidx.* / org.jetbrains.kotlin* / okhttp / okio / miuix → Apache-2.0）；
4. 闭源商业 SDK（友盟、ML Kit、GMS）写「闭源组件 + 条款链接」；
5. 以上都不中 → 记为 **未解析**，正文写明确说明并列入报告，绝不静默吞掉。

判定来源（artifact / pom / group / proprietary / unresolved）会打印成统计，便于复核。
"""

from __future__ import annotations

import argparse
import gzip
import os
import re
import shutil
import subprocess
import sys
import zipfile
from collections import Counter
from pathlib import Path

# Windows 下 stdout 可能不是 UTF-8（cp936），中文报告会变乱码：能换就换掉
for _stream in (sys.stdout, sys.stderr):
    try:
        if (_stream.encoding or "").lower() not in ("utf-8", "utf8"):
            _stream.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        pass

SEPARATOR = "-" * 80
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
TEMPLATE_DIR = HERE / "templates"
DEFAULT_ASSET = REPO / "android" / "app" / "src" / "main" / "assets" / "licenses" / "NOTICES.gz"
DEFAULT_CONFIGURATION = "prodReleaseRuntimeClasspath"
DEFAULT_MODULE = ":app"
GRADLE_CACHE = Path(os.environ.get("GRADLE_USER_HOME", Path.home() / ".gradle")) / (
    "caches/modules-2/files-2.1"
)

# 3) 已知 group 的确定归属（都是 Apache-2.0，不是猜的：AndroidX / Kotlin 全家、okhttp 生态、
#    miuix 上游 compose-miuix-ui 都是 Apache-2.0；改库注释见 android/third_party/miuix-ui/build.gradle:1）
GROUP_APACHE_PREFIXES = (
    "androidx.",
    "org.jetbrains.kotlin",
    "org.jetbrains",
    "com.squareup.okhttp3",
    "com.squareup.okio",
    "top.yukonga.miuix",
)

# 4) 闭源商业组件：必须如实写「闭源 + 条款链接」，不能伪装成开源许可
# 工程内模块（不在 Maven 缓存里）：只有确认过归属的才自动写入，其余进报告等人工补
DEFAULT_PROJECT_LICENSES = {
    # 上游 compose-miuix-ui/miuix 0.9.4 为 Apache-2.0；
    # 见 android/third_party/miuix-ui/build.gradle:1
    ":third_party:miuix-ui": "apache-2.0",
}

# 空占位构件：不含代码，只是依赖图里的「版本占位」。只登记有实测证据的几个。
EMPTY_PLACEHOLDER_ARTIFACTS = {
    (
        "com.google.guava",
        "listenablefuture",
        "9999.0-empty-to-avoid-conflict-with-guava",
    ): (
        "空占位构件：不包含任何可执行代码（实测 0 个 .class，jar 里只有 7 个 META-INF 条目），"
        "只用于让依赖图选中 Guava 自带的 ListenableFuture 版本——构件自带 POM 的 description 原文是"
        "「An empty artifact that Guava depends on to signal that it is providing ListenableFuture」。"
        "不含可分发代码，许可跟随 Guava（Apache-2.0）。"
    ),
}

PROPRIETARY = (
    ("com.umeng.", "https://www.umeng.com/policy", "友盟移动统计 / APM（闭源商业 SDK）"),
    ("com.google.mlkit", "https://developers.google.com/ml-kit/terms", "Google ML Kit（闭源 SDK）"),
    (
        "com.google.android.gms",
        "https://developers.google.com/android/guides/overview",
        "Google Play services（闭源 SDK）",
    ),
)

DEP_LINE_RE = re.compile(
    r"^[\s|+\\-]*[+\\]-{2,}\s+(?P<body>\S.*?)\s*$"
)
COORD_RE = re.compile(
    r"^(?P<group>[A-Za-z0-9_.\-]+):(?P<name>[A-Za-z0-9_.\-]+):(?P<version>[A-Za-z0-9_.+\-]+)"
    r"(?:\s*->\s*(?P<resolved>[A-Za-z0-9_.+\-]+))?"
)
PROJECT_RE = re.compile(r"^project\s+'?(?P<path>:[\w:\-]+)'?")
# 依赖替换成工程模块的形态：`…:miuix-ui-android:0.9.4 -> project ':third_party:miuix-ui'`
PROJECT_SUBST_RE = re.compile(r"->\s+project\s+'?(?P<path>:[\w:\-]+)'?")


# --------------------------------------------------------------------------- #
# NOTICES 读写
# --------------------------------------------------------------------------- #
def parse_notices(text: str) -> list[tuple[list[str], str]]:
    """与 Kotlin `parseFlutterNotices` 同规则解析，供 harvest / verify 使用。"""
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    blocks: list[list[str]] = []
    current: list[str] = []
    for line in normalized.split("\n"):
        if line == SEPARATOR:
            blocks.append(current)
            current = []
        else:
            current.append(line)
    if current:
        blocks.append(current)

    entries: list[tuple[list[str], str]] = []
    for block in blocks:
        lines = list(block)
        while lines and not lines[0].strip():
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
        if not lines:
            continue
        cut = 0
        while cut < len(lines) and lines[cut].strip():
            cut += 1
        names = [line.strip() for line in lines[:cut] if line.strip()]
        body = lines[cut:]
        while body and not body[0].strip():
            body.pop(0)
        text_body = "\n".join(body).strip()
        if names and text_body:
            entries.append((names, text_body))
    return entries


def render_notices(entries: list[tuple[str, str]]) -> str:
    chunks = [f"{name}\n\n{text.strip()}\n" for name, text in entries]
    return ("\n" + SEPARATOR + "\n").join(chunks)


def write_notices(path: Path, entries: list[tuple[str, str]]) -> bytes:
    data = render_notices(entries).encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    # mtime=0：同一输入产出同一字节，方便对拍与钉哈希
    path.write_bytes(gzip.compress(data, compresslevel=9, mtime=0))
    return data


# --------------------------------------------------------------------------- #
# 模板：从旧快照摘取，不手抄
# --------------------------------------------------------------------------- #
def classify_license(text: str) -> str | None:
    low = text.lower()
    if "apache license" in low and "version 2.0, january 2004" in low:
        return "apache-2.0"
    if "permission is hereby granted, free of charge" in low:
        return "mit"
    if "redistribution and use in source and binary forms" in low:
        return "bsd-3-clause" if "neither the name" in low else "bsd-2-clause"
    if "eclipse public license" in low:
        return "epl-2.0"
    return None


def _pick_template_text(key: str, pool: list[str]) -> str | None:
    """从同类候选里挑「最像标准全文」的那份。

    旧快照里有把多份许可拼在同一个条目里的情况（例如 Unicode License 后接一段
    MIT 风格声明），按长度取最长会拿到拼接体，所以每类都按特征 + 长度上限卡。
    """
    lows = [(body, body.lower()) for body in pool]
    if key == "apache-2.0":
        good = [body for body, low in lows if "end of terms and conditions" in low and "appendix" in low]
        return min(good, key=len) if good else None
    if key == "mit":
        good = [body for body, low in lows if "the software is provided" in low and len(body) < 2500]
        return min(good, key=len) if good else None
    if key == "bsd-3-clause":
        good = [
            body
            for body, low in lows
            if "neither the name" in low and "redistributions in binary form" in low and len(body) < 3500
        ]
        return min(good, key=len) if good else None
    if key == "bsd-2-clause":
        good = [
            body
            for body, low in lows
            if "redistributions in binary form" in low and "neither the name" not in low and len(body) < 2500
        ]
        return min(good, key=len) if good else None
    if key == "epl-2.0":
        good = [body for body, low in lows if "eclipse public license - v 2.0" in low]
        return min(good, key=len) if good else None
    return min(pool, key=len) if pool else None


def harvest_templates(source: Path) -> dict[str, str]:
    raw = source.read_bytes()
    text = gzip.decompress(raw).decode("utf-8", "replace") if raw[:2] == b"\x1f\x8b" else raw.decode(
        "utf-8", "replace"
    )
    pools: dict[str, list[str]] = {}
    for _names, body in parse_notices(text):
        key = classify_license(body)
        if key is None:
            continue
        pools.setdefault(key, []).append(body)
    candidates: dict[str, str] = {}
    for key, pool in pools.items():
        picked = _pick_template_text(key, pool)
        if picked:
            candidates[key] = picked
    TEMPLATE_DIR.mkdir(parents=True, exist_ok=True)
    for key, body in candidates.items():
        (TEMPLATE_DIR / f"{key}.txt").write_text(body.rstrip() + "\n", encoding="utf-8")
    return candidates


def load_templates(required: set[str]) -> dict[str, str]:
    templates: dict[str, str] = {}
    for key in sorted(required):
        path = TEMPLATE_DIR / f"{key}.txt"
        if not path.is_file():
            raise SystemExit(
                f"缺少许可模板 {path.name}。先跑一次 --harvest（从旧 NOTICES 快照摘取），"
                f"或手工放入原文；脚本不允许生成只有许可名、没有正文的条目。"
            )
        templates[key] = path.read_text(encoding="utf-8").strip()
    return templates


# --------------------------------------------------------------------------- #
# 依赖树解析
# --------------------------------------------------------------------------- #
def parse_dependency_report(text: str) -> tuple[list[tuple[str, str, str]], list[str]]:
    modules: dict[tuple[str, str, str], None] = {}
    projects: list[str] = []
    for raw_line in text.replace("\r\n", "\n").split("\n"):
        line = raw_line.rstrip()
        if not line.strip():
            continue
        match = DEP_LINE_RE.match(line)
        body = (match.group("body") if match else line.strip()).strip()
        project_match = PROJECT_RE.match(body)
        if project_match:
            path = project_match.group("path")
            if path not in projects:
                projects.append(path)
            continue
        substituted = PROJECT_SUBST_RE.search(body)
        if substituted:
            path = substituted.group("path")
            if path not in projects:
                projects.append(path)
            continue
        coord = COORD_RE.match(body)
        if not coord:
            continue
        version = coord.group("resolved") or coord.group("version")
        modules[(coord.group("group"), coord.group("name"), version)] = None
    return list(modules), projects


def run_gradle_dependencies(module: str, configuration: str) -> str:
    script = REPO / "scripts" / "safe-gradle.ps1"
    if not script.is_file():
        raise SystemExit(f"找不到 {script}，请从仓库根执行")
    cmd = [
        "pwsh",
        "-NoProfile",
        "-File",
        str(script),
        f"{module}:dependencies",
        "--configuration",
        configuration,
        "--console=plain",
    ]
    print(f"[info] 运行: {' '.join(cmd)}", file=sys.stderr)
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout[-4000:])
        sys.stderr.write(proc.stderr[-4000:])
        raise SystemExit(f"Gradle 依赖树获取失败（exit {proc.returncode}）")
    return proc.stdout


# --------------------------------------------------------------------------- #
# 单条依赖的归属判定
# --------------------------------------------------------------------------- #
def module_dir(group: str, name: str, version: str) -> Path:
    return GRADLE_CACHE / group / name / version


def find_artifact(group: str, name: str, version: str) -> Path | None:
    base = module_dir(group, name, version)
    if not base.is_dir():
        return None
    candidates = [
        path
        for path in base.rglob("*")
        if path.suffix in (".aar", ".jar")
        and "-sources" not in path.name
        and "-javadoc" not in path.name
    ]
    aars = [path for path in candidates if path.suffix == ".aar"]
    if aars:
        return sorted(aars)[0]
    return sorted(candidates)[0] if candidates else None


def find_pom(group: str, name: str, version: str) -> Path | None:
    base = module_dir(group, name, version)
    if base.is_dir():
        poms = sorted(base.rglob("*.pom"))
        if poms:
            return poms[0]
    parent = GRADLE_CACHE / group / name
    if parent.is_dir():
        poms = sorted(parent.glob(f"*/{name}-{version}.pom"))
        if poms:
            return poms[0]
    return None


def license_name_from_manifest(path: Path) -> str | None:
    """OSGi 风格的 `Bundle-License` 头（Guava 系 / jspecify / error_prone 都带）。"""
    try:
        with zipfile.ZipFile(path) as archive:
            if "META-INF/MANIFEST.MF" not in archive.namelist():
                return None
            manifest = archive.read("META-INF/MANIFEST.MF").decode("utf-8", "replace")
    except (zipfile.BadZipFile, OSError):
        return None
    # MANIFEST 会折行：续行以单个空格开头
    unfolded = manifest.replace("\r\n", "\n").replace("\n ", "")
    for line in unfolded.split("\n"):
        if line.lower().startswith("bundle-license:"):
            return line.split(":", 1)[1].strip().strip('"')
    return None


POM_MIRRORS = (
    "https://dl.google.com/dl/android/maven2/{path}",
    "https://repo1.maven.org/maven2/{path}",
    "https://maven.aliyun.com/repository/public/{path}",
)
POM_CACHE = REPO / ".tmp" / "pom-cache"


def fetch_pom(group: str, name: str, version: str) -> Path | None:
    """本地 Gradle 缓存没有 POM 时，从 Google / Central / 阿里云补取（带缓存）。"""
    cached = POM_CACHE / group / f"{name}-{version}.pom"
    if cached.is_file():
        return cached
    rel = f"{group.replace('.', '/')}/{name}/{version}/{name}-{version}.pom"
    cached.parent.mkdir(parents=True, exist_ok=True)
    curl = shutil.which("curl.exe") or shutil.which("curl")
    if curl is None:
        return None
    for template_url in POM_MIRRORS:
        url = template_url.format(path=rel)
        proc = subprocess.run(
            [curl, "-sfL", "--max-time", "20", "-o", str(cached), url],
            capture_output=True,
            text=True,
        )
        if proc.returncode == 0 and cached.is_file() and cached.stat().st_size > 0:
            return cached
    if cached.is_file():
        cached.unlink(missing_ok=True)
    return None


def license_from_artifact(path: Path) -> str | None:
    pattern = re.compile(r"(?i)^(?:META-INF/)?(?:LICENSE|NOTICE|COPYING)(?:\.\w+)?$")
    try:
        with zipfile.ZipFile(path) as archive:
            texts = []
            for entry in archive.namelist():
                if not pattern.match(entry):
                    continue
                try:
                    body = archive.read(entry).decode("utf-8", "replace").strip()
                except Exception:  # noqa: BLE001 - 坏的构件条目直接跳过
                    continue
                if body:
                    texts.append(body)
    except (zipfile.BadZipFile, OSError):
        return None
    if not texts:
        return None
    return max(texts, key=len)


def license_entries_from_pom_text(raw: str) -> list[tuple[str, str]]:
    block = re.search(r"<licenses>(.*?)</licenses>", raw, re.S)
    if not block:
        return []
    out: list[tuple[str, str]] = []
    for item in re.findall(r"<license>(.*?)</license>", block.group(1), re.S):
        name = re.search(r"<name>(.*?)</name>", item, re.S)
        url = re.search(r"<url>(.*?)</url>", item, re.S)
        out.append(
            (
                (name.group(1).strip() if name else ""),
                (url.group(1).strip() if url else ""),
            )
        )
    return out


def license_names_from_pom(path: Path) -> list[tuple[str, str]]:
    return license_entries_from_pom_text(path.read_text(encoding="utf-8", errors="replace"))


def embedded_pom_text(artifact: Path) -> str | None:
    """jar 里自带的 `META-INF/maven/**/pom.xml`（listen 这类空容器构件只靠它）。"""
    try:
        with zipfile.ZipFile(artifact) as archive:
            for entry in archive.namelist():
                if re.match(r"META-INF/maven/.+/pom\.xml$", entry):
                    return archive.read(entry).decode("utf-8", "replace")
    except (zipfile.BadZipFile, OSError):
        return None
    return None


# POM 只给许可名、没给地址时的官方条款页（名字命中才用，不是兜底猜测）
LICENSE_NAME_URLS = (
    ("ml kit", "https://developers.google.com/ml-kit/terms"),
    ("android software development kit", "https://developer.android.com/studio/terms"),
    ("google apis terms", "https://developers.google.com/terms"),
    ("eclipse public license", "https://www.eclipse.org/legal/epl-2.0/"),
    ("cc0", "https://creativecommons.org/publicdomain/zero/1.0/"),
)


def license_url_for_name(name: str) -> str:
    low = name.lower()
    for needle, url in LICENSE_NAME_URLS:
        if needle in low:
            return url
    return ""


def template_for_license_name(name: str) -> str | None:
    low = name.lower()
    if "apache" in low:
        return "apache-2.0"
    if low.strip() in {"mit", "mit license", "the mit license"} or "mit license" in low:
        return "mit"
    if "bsd" in low:
        return "bsd-3-clause" if ("3" in low or "three" in low) else "bsd-2-clause"
    if "eclipse" in low:
        return "epl-2.0"
    return None


def resolve_license(
    group: str,
    name: str,
    version: str,
    templates: dict[str, str],
    allow_network: bool = True,
) -> tuple[str, str, str]:
    """返回 (正文, 判定来源, 备注)。"""
    # 闭源商业 SDK 优先判定：即便构件或 POM 里带了 Apache 文本，也不能把商业 SDK 报成开源。
    # 友盟的 POM 就把 <licenses> 写成了 Apache-2.0，和它自己的使用协议不一致（见下方 note）。
    # 只对确认「POM 声明不可信」的两家强制优先；GMS 的 POM 写的是 Android SDK License，照 POM 走。
    for prefix, url, label in (
        (prefix, url, label)
        for prefix, url, label in PROPRIETARY
        if prefix in ("com.umeng.", "com.google.mlkit")
    ):
        if group.startswith(prefix):
            note = ""
            if group.startswith("com.umeng."):
                note = (
                    "\n\n注意：该 SDK 的 Maven POM 把 <licenses> 标注为 Apache-2.0，"
                    "但实际使用受《友盟 SDK 使用协议》约束，两者不一致时以官方协议为准。"
                )
            return (
                f"{label}\n\n本组件为闭源商业 SDK，不随本仓库源码分发，适用其自有条款：{url}{note}",
                "proprietary",
                label,
            )

    artifact = find_artifact(group, name, version)
    if artifact is not None:
        body = license_from_artifact(artifact)
        if body:
            return body, "artifact", artifact.name
        embedded = embedded_pom_text(artifact)
        if embedded:
            for license_name, _url in license_entries_from_pom_text(embedded):
                key = template_for_license_name(license_name)
                if key and key in templates:
                    return templates[key], "artifact-pom", license_name
        bundle_license = license_name_from_manifest(artifact)
        if bundle_license:
            key = template_for_license_name(bundle_license)
            if key and key in templates:
                return templates[key], "manifest", bundle_license

    pom = find_pom(group, name, version)
    pom_source = "pom"
    if pom is None and allow_network:
        pom = fetch_pom(group, name, version)
        pom_source = "pom-remote"
    if pom is not None:
        raw_pom = pom.read_text(encoding="utf-8", errors="replace")
        licenses = license_entries_from_pom_text(raw_pom)
        if licenses:
            license_name, license_url = licenses[0]
            key = template_for_license_name(license_name)
            if key and key in templates:
                return templates[key], pom_source, license_name
            url = license_url or license_url_for_name(license_name)
            body = (
                f"{license_name or 'License'}\n\n条款全文：{url}"
                if url
                else f"{license_name or 'License'}（POM 未给出条款地址）"
            )
            return body, f"{pom_source}-short", license_name
        # 有些 POM 不写 <licenses>，只在文件头注释里声明（如 auto-value-annotations 1.6.3）
        low_pom = raw_pom.lower()
        if "apache license" in low_pom and "version 2.0" in low_pom:
            return templates["apache-2.0"], f"{pom_source}-header", "POM 文件头声明 Apache-2.0"

    for prefix in GROUP_APACHE_PREFIXES:
        if group == prefix.rstrip(".") or group.startswith(prefix):
            return templates["apache-2.0"], "group", prefix

    placeholder = EMPTY_PLACEHOLDER_ARTIFACTS.get((group, name, version))
    if placeholder:
        return placeholder, "placeholder", ""

    return (
        "本组件未能在本地 Gradle 缓存中确认许可证正文。请按构件 POM 的 <licenses> 手工补录，"
        "不要当作已核对。",
        "unresolved",
        "",
    )


# --------------------------------------------------------------------------- #
# 主流程
# --------------------------------------------------------------------------- #
def build_entries(
    modules: list[tuple[str, str, str]],
    projects: list[str],
    templates: dict[str, str],
    include_self: bool,
    allow_network: bool = True,
) -> tuple[list[tuple[str, str]], Counter, list[str], list[str]]:
    entries: list[tuple[str, str]] = []
    sources: Counter = Counter()
    unresolved: list[str] = []
    for group, name, version in modules:
        coord = f"{group}:{name}:{version}"
        body, source, note = resolve_license(
            group, name, version, templates, allow_network=allow_network
        )
        sources[source] += 1
        if source == "unresolved":
            unresolved.append(coord)
        entries.append((coord, body))

    unresolved_projects: list[str] = []
    for project in projects:
        if project == ":app":
            continue
        key = DEFAULT_PROJECT_LICENSES.get(project)
        if key and key in templates:
            entries.append((f"{project}（工程内模块）", templates[key]))
            sources["project"] += 1
        else:
            unresolved_projects.append(project)

    if include_self:
        license_path = REPO / "LICENSE"
        if not license_path.is_file():
            raise SystemExit("仓库根缺少 LICENSE，无法写入本应用自身的 GPL 条目")
        entries.append(("mikcb / 轻屿课表（本应用）", license_path.read_text(encoding="utf-8")))
        sources["self"] += 1

    entries.sort(key=lambda item: item[0].lower())
    return entries, sources, unresolved, unresolved_projects


def cmd_harvest(args: argparse.Namespace) -> int:
    source = Path(args.harvest)
    if not source.is_absolute():
        source = (REPO / source).resolve()
    if not source.is_file():
        raise SystemExit(f"找不到旧快照: {source}")
    found = harvest_templates(source)
    if not found:
        raise SystemExit("旧快照里没有识别出任何标准许可正文，模板未写入")
    for key in sorted(found):
        path = TEMPLATE_DIR / f"{key}.txt"
        print(f"[harvest] {key}: {len(found[key])} chars -> {path.relative_to(REPO)}")
    return 0


def cmd_generate(args: argparse.Namespace) -> int:
    required = {"apache-2.0"}
    # 先宽松加载：模板按需补齐；缺模板时 resolve 会报未解析并写入报告
    templates: dict[str, str] = {}
    for path in sorted(TEMPLATE_DIR.glob("*.txt")):
        templates[path.stem] = path.read_text(encoding="utf-8").strip()
    missing = sorted(key for key in required if key not in templates)
    if missing:
        raise SystemExit(
            f"缺少基础许可模板 {missing}；先跑 --harvest 从旧 NOTICES 快照摘取。"
        )

    if args.from_deps:
        deps_text = Path(args.from_deps).read_text(encoding="utf-8", errors="replace")
    else:
        deps_text = run_gradle_dependencies(args.module, args.configuration)

    modules, projects = parse_dependency_report(deps_text)
    if not modules:
        raise SystemExit("依赖树里没有解析出任何 Maven 坐标，检查 --configuration 是否正确")

    entries, sources, unresolved, unresolved_projects = build_entries(
        modules, projects, templates, not args.no_self, allow_network=not args.offline
    )
    if not entries:
        raise SystemExit("没有任何条目，拒绝生成空清单")

    out = Path(args.out) if args.out else DEFAULT_ASSET
    if not out.is_absolute():
        out = (REPO / out).resolve()
    # 安全默认：没写 --write 一律只试写到 .tmp/，绝不悄悄覆盖打进 APK 的资产
    if args.dry_run or not args.write:
        out = REPO / ".tmp" / "NOTICES.dryrun.gz"
        print(f"[dry-run] 未加 --write，不覆盖 {DEFAULT_ASSET.relative_to(REPO)}；试写 {out.relative_to(REPO)}")

    data = write_notices(out, entries)
    parsed = parse_notices(data.decode("utf-8"))

    print(f"[ok] 条目 {len(entries)}（解析回读 {len(parsed)}），明文 {len(data)} B，gzip {out.stat().st_size} B")
    print(f"[ok] 输出: {out}")
    print("[ok] 判定来源: " + ", ".join(f"{key}={value}" for key, value in sorted(sources.items())))
    if unresolved_projects:
        print("[warn] 这些工程内模块没有确认归属，需人工补: " + ", ".join(unresolved_projects))
    if unresolved:
        print(f"[warn] {len(unresolved)} 条未解析，必须人工补录：")
        for coord in unresolved:
            print(f"       - {coord}")
    if args.report:
        report = Path(args.report)
        if not report.is_absolute():
            report = (REPO / report).resolve()
        lines = ["# NOTICES 重生成报告", "", f"- 输入配置：`{args.configuration}`", f"- 条目数：{len(entries)}"]
        lines += ["", "## 判定来源", ""]
        lines += [f"- {key}: {value}" for key, value in sorted(sources.items())]
        if unresolved_projects:
            lines += ["", "## 工程内模块（需人工确认归属）", ""]
            lines += [f"- `{path}`" for path in unresolved_projects]
        if unresolved:
            lines += ["", "## 未解析（必须补录）", ""]
            lines += [f"- `{coord}`" for coord in unresolved]
        report.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"[ok] 报告: {report}")
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    path = Path(args.verify) if args.verify else DEFAULT_ASSET
    if not path.is_absolute():
        path = (REPO / path).resolve()
    raw = path.read_bytes()
    text = gzip.decompress(raw).decode("utf-8") if raw[:2] == b"\x1f\x8b" else raw.decode("utf-8")
    entries = parse_notices(text)
    if not entries:
        print("[fail] 解析不出任何条目")
        return 1
    names = [names[0] for names, _body in entries]
    print(f"[ok] {path}: {len(entries)} 条，明文 {len(text)} B，gzip {len(raw)} B")
    print(f"[ok] 首条 {names[0]}；末条 {names[-1]}")
    flutter = [name for name in names if name.startswith("flutter")]
    print(f"[info] flutter_* 条目 {len(flutter)} 条" + (f"：{flutter[:5]}" if flutter else ""))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="重生成 APK 内开源许可清单（NOTICES.gz）")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--harvest", metavar="OLD_NOTICES", nargs="?", const=str(DEFAULT_ASSET),
                      help="从旧快照摘取许可模板（默认取当前 assets 里的 NOTICES.gz）")
    mode.add_argument("--verify", metavar="NOTICES", nargs="?", const=str(DEFAULT_ASSET),
                      help="只解析校验现有清单")
    parser.add_argument("--from-deps", metavar="FILE", help="用已保存的 Gradle 依赖树输出（不跑 Gradle）")
    parser.add_argument("--module", default=DEFAULT_MODULE, help=f"Gradle 模块（默认 {DEFAULT_MODULE}）")
    parser.add_argument("--configuration", default=DEFAULT_CONFIGURATION,
                        help=f"要解析的运行时配置（默认 {DEFAULT_CONFIGURATION}）")
    parser.add_argument("--out", metavar="PATH", help=f"输出路径（默认 {DEFAULT_ASSET.name}）")
    parser.add_argument("--dry-run", action="store_true", help="只试写到 .tmp/，不覆盖 assets")
    parser.add_argument("--write", action="store_true", help="确实写 assets（与 --dry-run 相对）")
    parser.add_argument("--no-self", action="store_true", help="不附加本应用自身的 GPL 条目")
    parser.add_argument(
        "--offline",
        action="store_true",
        help="不联网补取缺失的 POM（只用本地 Gradle 缓存与构件自带证据）",
    )
    parser.add_argument("--report", metavar="PATH", help="同时写出 Markdown 复核报告")
    args = parser.parse_args(argv)

    if args.harvest is not None:
        return cmd_harvest(args)
    if args.verify is not None:
        return cmd_verify(args)
    return cmd_generate(args)


if __name__ == "__main__":
    sys.exit(main())
