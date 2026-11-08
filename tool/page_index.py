#!/usr/bin/env python3
"""按软件结构重排页面索引，并同时刷出两份（仓库 docs/ 与 android/docs/）。

新增/删除页面后跑这一条即可：
    python tool/page_index.py

读取 docs/reference/page-index.md 里的表格作为数据源，按 App 路由分区（a..j，
见 main/pages/ShellPageIndex.kt）重排，输出：
  - docs/reference/page-index.md         链接相对 android/
  - android/docs/reference/page-index.md 链接相对 app/（Studio 工程内可直接点）

表格用**引用式链接**（`[名字][p1]` + 文末 `[p1]: 路径`），避免长地址把表格撑宽。
"""
import os
import re

SRC = "docs/reference/page-index.md"
PAGES_REL = "composeP1/kotlin/com/mutx163/qingyu/pages"

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

# 这些页面在代码里没有固定中文标题（标题由 spec / 日期 / 登录状态在运行期决定），
# 按功能给一个人工确认过的中文名，避免表里混着英文入口名。
ALIAS = {
    "DayViewPage": "日视图",
    "MonthViewPage": "月视图",
    "TimetableWeekPage": "周视图",
    "SettingsPageScreen": "设置（通用）",
    "AppearanceEditorScreen": "外观编辑",
    "GlassDockIconPickerScreen": "坞站图标选择",
    "StatisticsAnalysisPage": "统计分析",
    "AboutUpdatePage": "版本更新",
    "OpenSourceLicenseDetailPage": "开源许可详情",
    "WarehouseNoTargetPage": "教务导入中转",
    "WarehouseWebLoginPage": "教务网页登录",
    "CourseStatisticsPage": "课程统计",
    "LocationTimeMatchPage": "地点作息匹配",
    "TimeSchemeManagementPage": "时间模板管理",
}

CELL = r"`([^`]+?\.kt)`"
ROW_INLINE = re.compile(
    r"^\| ([a-z_]+) \| \[(.+?)\]\((.+?)\) \| `(\w+)` \| " + CELL + r" \| (\d+) \|$"
)
ROW_REF = re.compile(
    r"^\| ([a-z_]+) \| \[(.+?)\]\[[^\]]+\] \| `(\w+)` \| " + CELL + r" \| (\d+) \|$"
)
DEF = re.compile(r"^\[(\w+)\]: (\S+)$")


def load_rows():
    """同时认 inline 与 reference 两种写法，保证重跑幂等。"""
    defs = {}
    rows = []
    for line in open(SRC, encoding="utf-8"):
        line = line.strip()
        m = DEF.match(line)
        if m:
            defs[m.group(1)] = m.group(2)
            continue
        m = ROW_INLINE.match(line)
        if m:
            domain, title, _url, entry, file, prev = m.groups()
        else:
            m = ROW_REF.match(line)
            if not m:
                continue
            domain, title, entry, file, prev = m.groups()
        rows.append({
            "domain": domain,
            "title": title,
            "entry": entry,
            "file": file.replace("pages/", "", 1),
            "previews": int(prev),
        })
    # 解析失败的格子回填人工别名
    for r in rows:
        if r["title"] == r["entry"] and r["entry"] in ALIAS:
            r["title"] = ALIAS[r["entry"]]
    return rows


def render(rows, prefix):
    total = sum(r["previews"] for r in rows)
    by_domain = {}
    for r in rows:
        by_domain.setdefault(r["domain"], []).append(r)

    out = []
    out.append("# 页面索引\n")
    out.append("按软件结构分区。找页面就找功能区，点名字直接打开源码。\n")
    out.append("共 **%d** 个整页入口、**%d** 个预览。\n" % (len(rows), total))
    out.append("## 怎么用\n")
    out.append("1. **直接点**：按住 `Ctrl` 点名字（macOS 是 `Cmd`），打开对应源码文件。")
    out.append("2. 不确定在哪就 `Ctrl+F` 搜中文。")
    out.append("3. 打开文件滚到底、右侧点 **Split / Preview**，就是这一页的全部档位。\n")
    out.append("> **这个文件是生成的，别手改。** 在 `pages/` 下新增、改名或删除整页入口后，")
    out.append("> 在仓库根跑 `python tool/page_index.py` 重新生成，并随代码一起提交。\n")
    out.append("## 口径\n")
    out.append("- 分区对应 App 的路由编号（`ShellPageIndex.kt` 里的 `a.*` … `j.*`）；一页属于哪个区由它所在域决定。")
    out.append("- 入口 = 非 `private` 的 `fun XxxPage(` / `fun XxxScreen(`；`XxxHost` 是接线层，不收。")
    out.append("- 少数页面的标题由运行期决定（设置类的 `spec.title`、周/日/月视图、网页登录页），"
               "表里用的是按功能确定的中文名，可能与运行时的顶栏文字不完全一致。")
    out.append("- 预览数按 `@Preview` 后调用的公共体归属，用来判断「这页铺没铺」，不是精确统计。\n")

    definitions = []
    n = 0
    placed = set()

    def table(group_rows):
        nonlocal n
        out.append("| 域 | 页面 | 入口 | 文件 | 预览 |")
        out.append("|---|---|---|---|---|")
        for r in group_rows:
            n += 1
            ref = "p%d" % n
            definitions.append((ref, prefix + r["file"]))
            out.append("| %s | [%s][%s] | `%s` | `%s` | %d |"
                       % (r["domain"], r["title"], ref, r["entry"], r["file"], r["previews"]))
        out.append("")

    for title, prefix_tag, domains in GROUPS:
        group_rows = []
        for d in domains:
            group_rows.extend(by_domain.get(d, []))
            placed.add(d)
        if not group_rows:
            continue
        group_rows.sort(key=lambda r: (r["domain"], r["entry"]))
        out.append("## %s（%s）\n" % (title, prefix_tag))
        table(group_rows)

    rest = [r for r in rows if r["domain"] not in placed]
    if rest:
        out.append("## 未归类\n")
        table(sorted(rest, key=lambda r: (r["domain"], r["entry"])))

    out.append("## 按分区统计\n")
    out.append("| 分区 | 入口数 |\n|---|---|")
    for title, prefix_tag, domains in GROUPS:
        c = sum(len(by_domain.get(d, [])) for d in domains)
        if c:
            out.append("| %s | %d |" % (title, c))
    out.append("")

    out.append("<!-- 链接定义（表格里的 [名字][pN] 指到这里）-->")
    for ref, path in definitions:
        out.append("[%s]: %s" % (ref, path))
    return "\n".join(out) + "\n"


def main():
    rows = load_rows()
    if not rows:
        raise SystemExit("没读到表格行，检查 %s 是否存在" % SRC)
    targets = [
        ("docs/reference/page-index.md", "../../android/app/src/" + PAGES_REL + "/"),
        ("android/docs/reference/page-index.md", "../../app/src/" + PAGES_REL + "/"),
    ]
    for path, prefix in targets:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        text = render(rows, prefix)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("写入 %s（%d 行）" % (path, text.count("\n")))


if __name__ == "__main__":
    main()
