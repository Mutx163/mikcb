#!/usr/bin/env python3
"""按软件结构重排页面索引，并同时刷出两份（仓库 docs/ 与 android/docs/）。

新增/删除页面后跑这一条即可：
    python tool/page_index.py

读取 docs/reference/page-index.md 里的表格作为数据源（页面中文名已在那里），
按 App 路由分区（a..j，见 main/pages/ShellPageIndex.kt）重排，输出：
  - docs/reference/page-index.md         链接相对 android/
  - android/docs/reference/page-index.md 链接相对 app/（Studio 工程内可直接点）
"""
import os
import re

SRC = "docs/reference/page-index.md"
PAGES_REL = "composeP1/kotlin/com/mutx163/qingyu/pages"

# 域 -> (章节标题, 官方路由前缀)；顺序即输出顺序，按「打开 App 到设置的路径」排
GROUPS = [
    ("课表", "c", ["timetable"]),
    ("课程", "d1", ["course", "conflict"]),
    ("日程与任务", "d2", ["schedule", "task"]),
    ("时间与考试", "d3", ["time_scheme", "exam"]),
    ("统计", "e", ["statistics"]),
    ("导入", "g1 / g2", ["import"]),
    ("迁移与导出", "g3", ["transfer", "export"]),
    ("同步与备份", "f", ["sync"]),
    ("实时显示", "j", ["live"]),
    ("设置", "b", ["settings", "weather"]),
    ("帮助与展示", "i", ["guide", "showcase"]),
    ("诊断", "h", ["diagnostics"]),
    ("关于", "a", ["about", "feedback"]),
]

ROW = re.compile(
    r"^\| ([a-z_]+) \| \[(.+?)\]\((.+?)\) \| `(\w+)` \| `pages/([^`]+?\.kt)` \| (\d+) \|$"
)


def load_rows():
    rows = []
    for line in open(SRC, encoding="utf-8"):
        m = ROW.match(line.strip())
        if m:
            rows.append({
                "domain": m.group(1),
                "title": m.group(2),
                "entry": m.group(4),
                "file": m.group(5),
                "previews": int(m.group(6)),
            })
    return rows


def render(rows, prefix):
    total = sum(r["previews"] for r in rows)
    by_domain = {}
    for r in rows:
        by_domain.setdefault(r["domain"], []).append(r)

    out = []
    out.append("# 页面索引\n")
    out.append("按软件结构分区。找页面就找功能区，点中文名直接打开源码。\n")
    out.append("共 **%d** 个整页入口、**%d** 个预览。\n" % (len(rows), total))
    out.append("## 怎么用\n")
    out.append("1. **直接点**：「页面」那列是指向源码文件的链接，按住 `Ctrl` 点一下（macOS 是 `Cmd`）就打开。")
    out.append("2. 不确定在哪就 `Ctrl+F` 搜中文。")
    out.append("3. 打开文件滚到底、右侧点 **Split / Preview**，就是这一页的全部档位。\n")
    out.append("> **这个文件是生成的，别手改。** 在 `pages/` 下新增、改名或删除整页入口后，")
    out.append("> 在仓库根跑 `python tool/page_index.py` 重新生成，并随代码一起提交。\n")
    out.append("## 口径\n")
    out.append("- 分区对应 App 的路由编号（`ShellPageIndex.kt` 里的 `a.*` … `j.*`）；一页属于哪个区由它所在域决定。")
    out.append("- 入口 = 非 `private` 的 `fun XxxPage(` / `fun XxxScreen(`；`XxxHost` 是接线层，不收。")
    out.append("- 没有固定中文标题的页（设置类的 `spec.title`、周/日/月视图等），显示入口函数名，同样可点。")
    out.append("- 预览数按 `@Preview` 后调用的公共体归属，用来判断「这页铺没铺」，不是精确统计。\n")

    placed = set()
    for title, prefix_tag, domains in GROUPS:
        group_rows = []
        for d in domains:
            group_rows.extend(by_domain.get(d, []))
            placed.add(d)
        if not group_rows:
            continue
        group_rows.sort(key=lambda r: (r["domain"], r["entry"]))
        out.append("## %s（%s）\n" % (title, prefix_tag))
        out.append("| 域 | 页面 | 入口函数 | 文件 | 预览 |")
        out.append("|---|---|---|---|---|")
        for r in group_rows:
            out.append("| %s | [%s](%s%s) | `%s` | `pages/%s` | %d |"
                       % (r["domain"], r["title"], prefix, r["file"], r["entry"], r["file"], r["previews"]))
        out.append("")

    rest = [r for r in rows if r["domain"] not in placed]
    if rest:
        out.append("## 未归类\n")
        out.append("| 域 | 页面 | 入口函数 | 文件 | 预览 |")
        out.append("|---|---|---|---|---|")
        for r in sorted(rest, key=lambda r: (r["domain"], r["entry"])):
            out.append("| %s | [%s](%s%s) | `%s` | `pages/%s` | %d |"
                       % (r["domain"], r["title"], prefix, r["file"], r["entry"], r["file"], r["previews"]))
        out.append("")

    out.append("## 按分区统计\n")
    out.append("| 分区 | 入口数 |\n|---|---|")
    for title, prefix_tag, domains in GROUPS:
        n = sum(len(by_domain.get(d, [])) for d in domains)
        if n:
            out.append("| %s | %d |" % (title, n))
    return "\n".join(out) + "\n"


def main():
    rows = load_rows()
    if not rows:
        raise SystemExit("没读到表格行，检查 docs/reference/page-index.md 是否存在")
    targets = [
        ("docs/reference/page-index.md", "../../android/app/src/" + PAGES_REL + "/"),
        ("android/docs/reference/page-index.md", "../../app/src/" + PAGES_REL + "/"),
    ]
    for path, prefix in targets:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(render(rows, prefix))
        print("写入 %s（%d 行）" % (path, render(rows, prefix).count("\n")))


if __name__ == "__main__":
    main()
