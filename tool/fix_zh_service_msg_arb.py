#!/usr/bin/env python3
"""只修 `i18n/app_zh.arb` 里 **serviceMsg 系列**的译文，其余键一个不碰。

用法：
    python tool/fix_zh_service_msg_arb.py                 # 只检查，不写盘（默认）
    python tool/fix_zh_service_msg_arb.py --write         # 真写盘（写盘前强制校验）
    python tool/fix_zh_service_msg_arb.py --arb-dir DIR   # 换一个 ARB 目录（自测用）

为什么重写成这样（2026-10-27）：

上一版先把 zh 里**所有** serviceMsg 键删掉，再从 en 逐键回填
`ZH_VALUES.get(key, value)` —— 表里没有的键就直接是英文。实测：

* 不丢键，但会改 **44 条**已有中文（其中不少是比脚本表更新的、更好的文案）；
* `ZH_VALUES` 只有 144 条、对 en 的 149 个 serviceMsg 键，**5 条中文回退成英文**：
  `serviceMsgImportRollbackIncomplete`、`serviceMsgUpdateDownloadHashMismatch`、
  `serviceMsgUpdateSha256UnverifiedRefused`、`serviceMsgWarehouseScriptChecksumFailed`、
  `serviceMsgTimetableShareFailed`；
* 更根本的问题：它**整份重写**文件（`json.dumps` 全量序列化）。ARB 里既有压成
  一行的 `{ "type": "String" }`，也有展开成多行的写法，重排后 diff 有上千行，
  真正的改动（几条文案）被淹没；任何顺手的格式化 bug 也会一次性覆盖全文件。

因此本版守四条：

1. **只碰 serviceMsg 那几行**：按行定位 `"serviceMsgXxx": "..."`，
   只替换「引号里的值」，键名、缩进、行尾逗号、其余行原样保留。
2. **补全那 5 条中文**，并把判据写死：要写入的新值必须含中文（否则判为英文回退，
   整份放弃）；写完之后 zh 的 serviceMsg 普通键里**一个英文值都不许有**。
3. **写盘前强制校验**：`json.loads` 通过；serviceMsg 之外的键集合与值逐一未变；
   serviceMsg 键集合未变；除计划改动的行以外，文件其余部分逐行相同。
   任一不通过 → 整份放弃、原文件一个字节不动、非 0 退出码。
4. 默认**只检查不写盘**，要 `--write` 才落盘；先写临时文件再原子替换。

配套咬合探针：`tool/selftest_destructive_scripts.py`（只在临时目录跑）。
"""

from __future__ import annotations

import json
import os
import re
import sys
import tempfile
from pathlib import Path

# Windows 控制台默认 GBK，直接 print 中文会变乱码（2026-10-27 实测）。
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

ROOT = Path(__file__).resolve().parents[1] / "lib" / "l10n"

CJK_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]")

ZH_VALUES = {
    "serviceMsgImportFileUnrecognized": "导入失败，文件内容无法识别",
    "serviceMsgImportUseOverwriteForFullBackup": "这是全部数据备份，请使用“覆盖当前课表”方式导入",
    "serviceMsgImportNoProfilesInBackup": "备份文件中没有可恢复的课表",
    "serviceMsgUnrecognizedMikcbDataFile": "不是可识别的 mikcb 数据文件",
    "serviceMsgMissingSettingsData": "缺少设置数据",
    "serviceMsgUnrecognizedMikcbFullBackup": "不是可识别的 mikcb 全量备份文件",
    "serviceMsgMissingFullBackupData": "缺少完整备份数据",
    "serviceMsgUseProfileBackupNotFull": "请使用课表档案备份 JSON，而非全部数据备份",
    "serviceMsgUnrecognizedSyncSnapshot": "不是可识别的 mikcb 云同步快照",
    "serviceMsgMissingSyncTimetableData": "缺少云同步课表数据",
    "serviceMsgSyncSnapshotChecksumFailed": "云同步快照校验失败",
    "serviceMsgSyncSnapshotNoProfiles": "云同步快照中没有可恢复的课表",
    "serviceMsgSyncSnapshotUnrecognized": "云同步快照无法识别",
    "serviceMsgTimeSchemeNotFound": "时间模板不存在",
    "serviceMsgTimeSchemeConfigUnavailable": "当前课表时间配置不可用",
    "serviceMsgTimeSchemeNotFoundSelected": "未找到所选时间模板",
    "serviceMsgTimeSchemeSectionsInsufficient": "所选时间模板节次数不足，无法覆盖第 {startSection}-{endSection} 节",
    "serviceMsgSectionCountBelowUsage": "节次数量不能小于当前已使用的最大节次（第{requiredMaxSection}节）",
    "serviceMsgSectionCountBelowUsageDetail": "节次数量不能小于当前已使用的最大节次（第{requiredMaxSection}节）。正在使用：{profileName} · {courseName}（周{dayOfWeek} {startSection}-{endSection}节，{usageType}）",
    "serviceMsgAtLeastOneSectionRequired": "至少需要保留一节课的时间",
    "serviceMsgSectionEndMustAfterStart": "第 {sectionNumber} 节结束时间必须晚于开始时间，暂不支持跨 0 点课程",
    "serviceMsgSectionStartBeforePreviousEnd": "第 {sectionNumber} 节开始时间不能早于上一节的结束时间",
    "serviceMsgPeriodStartTimeRequired": "请为有节次的时段设置第一节开始时间",
    "serviceMsgSectionCrossesMidnight": "第 {sectionNumber} 节会跨到次日，当前暂不支持跨 0 点课程",
    "serviceMsgClassDurationMustPositive": "上课时长必须大于 0",
    "serviceMsgBreakDurationMustNonNegative": "课间时长不能小于 0",
    "serviceMsgAtLeastOnePeriodSection": "至少需要设置一个时段的节次数",
    "serviceMsgInvalidTimeFormat": "时间格式不正确",
    "serviceMsgLinkedCourseNotFound": "关联的课程不存在",
    "serviceMsgCourseNotFoundForDelete": "未找到要删除的课程",
    "serviceMsgCourseNotScheduledWeek": "这门课在第 {sourceWeek} 周没有排课",
    "serviceMsgCourseNotFoundForReschedule": "未找到要调课的课程",
    "serviceMsgTargetWeekOutOfRange": "目标周次超出当前学期范围",
    "serviceMsgAtLeastOneScheduleSlot": "至少需要保留一个上课时间段",
    "serviceMsgCourseNameRequired": "课程名称不能为空",
    "serviceMsgBackupContentRequired": "备份内容不能为空",
    "serviceMsgSpreadsheetFormatOrEncodingUnrecognized": "无法识别表格格式或编码，请将 CSV 另存为 UTF-8 后重试",
    "serviceMsgSpreadsheetXlsxParseFailed": "XLSX 文件解析失败：{error}",
    "serviceMsgSpreadsheetRowWarning": "第 {rowNumber} 行：{message}",
    "serviceMsgSpreadsheetWakeupInsufficientColumns": "WakeUp 格式需要至少 7 列，但第 {rowNumber} 行只有 {columnCount} 列",
    "serviceMsgWeekdayMustBe1To7": "星期必须是 1-7",
    "serviceMsgCustomWeeksRequired": "周数 不能为空",
    "serviceMsgClassWeeksRequired": "上课周 不能为空",
    "serviceMsgStartWeekMustBeAtLeast1": "开始周 必须大于等于 1",
    "serviceMsgStartWeekExceedsSemester": "开始周 {startWeek} 超过学期周数 {semesterWeekCount}",
    "serviceMsgEndWeekBeforeStartWeek": "结束周 不能小于开始周",
    "serviceMsgWeeksRangeRequired": "上课周 或 开始周+结束周 必须填写",
    "serviceMsgFieldMustBeAtLeast1": "{field} 必须大于等于 1",
    "serviceMsgFieldCannotBeLessThan": "{endField} 不能小于{startField}",
    "serviceMsgSectionOutOfRange": "节次 {section} 超出时间模板范围（1-{maxSection}）",
    "serviceMsgFieldMustBeInteger": "{field} 必须是整数",
    "serviceMsgFieldCannotBeEmpty": "{field} 不能为空",
    "serviceMsgSpreadsheetEndWeekClamped": "第 {rowNumber} 行：结束周 {endWeek} 超过学期周数 {semesterWeekCount}，已调整为 {semesterWeekCount}",
    "serviceMsgSpreadsheetOddEvenBoth": "第 {rowNumber} 行：单周与双周不能同时勾选，已按单周处理",
    "serviceMsgFieldCourseName": "课程名称",
    "serviceMsgFieldWeekday": "星期",
    "serviceMsgFieldStartSection": "开始节数",
    "serviceMsgFieldEndSection": "结束节数",
    "serviceMsgFieldCustomWeeks": "周数",
    "serviceMsgFieldClassWeeks": "上课周",
    "serviceMsgFieldStartWeek": "开始周",
    "serviceMsgFieldEndWeek": "结束周",
    "serviceMsgWeekStartInvalid": "{itemName} 周次起始值不合法",
    "serviceMsgWeekRangeInvalid": "{itemName} 周次范围不合法",
    "serviceMsgWeekRangeTooLarge": "{itemName} 周次范围过大，请检查",
    "serviceMsgWeekTokenUnrecognized": "{itemName} 含有无法识别的周次：{token}",
    "serviceMsgWeeksExceedSemesterClamped": "{itemName} 含有超过学期周数 {semesterWeekCount} 的周次（{weeks}），已忽略超出部分",
    "serviceMsgAiResultNotObject": "AI 结果不是合法对象，请重新复制完整 JSON",
    "serviceMsgAiSchemaMustBe": "schema 必须为 {schema}",
    "serviceMsgAiCoursesMustBeArray": "courses 必须是数组",
    "serviceMsgAiWarningsMustBeArray": "warnings 必须是字符串数组",
    "serviceMsgAiWarningItemMustBeString": "warnings 中的每一项都必须是字符串",
    "serviceMsgAiCourseNotObject": "courses[{index}] 不是合法对象",
    "serviceMsgAiCourseNameEmpty": "courses[{index}].name 不能为空",
    "serviceMsgAiCourseDayOfWeekInvalid": "courses[{index}].dayOfWeek 必须是 1-7",
    "serviceMsgAiCourseStartSectionInvalid": "courses[{index}].startSection 必须大于等于 1",
    "serviceMsgAiCourseEndSectionInvalid": "courses[{index}].endSection 不能小于 startSection",
    "serviceMsgAiCourseCustomWeeksEmpty": "courses[{index}].customWeeks 不能为空",
    "serviceMsgAiCourseNatureInvalid": "courses[{index}].courseNature 只能是 required 或 elective",
    "serviceMsgAiUnknownFields": "{targetName} 包含不支持的字段：{fields}",
    "serviceMsgAiFieldMustBeString": "{field} 必须是字符串",
    "serviceMsgAiFieldMustBeInteger": "{field} 必须是整数",
    "serviceMsgAiWeekListInvalid": "{itemName} 只能包含大于等于 1 的整数",
    "serviceMsgAiWeekListTypeInvalid": "{field} 必须是整数数组或周次字符串",
    "serviceMsgNoReleaseAvailable": "仓库还没有发布 Release。",
    "serviceMsgNoReleaseWithPrerelease": "还没有可用的正式版或预发布版本。",
    "serviceMsgUpdateCheckHttpFailed": "检查更新失败（HTTP {statusCode}）。",
    "serviceMsgUpdateCheckNetworkFailed": "网络异常，暂时无法检查更新。",
    "serviceMsgUpdateDownloadUrlUntrusted": "更新下载地址未通过安全校验",
    "serviceMsgUpdateDownloadHttpFailed": "下载失败（HTTP {statusCode}）",
    "serviceMsgUpdateOpenInstallerFailed": "打开安装包失败: {detail}",
    "serviceMsgUpdateDownloadInstallError": "下载或安装过程中出现错误: {detail}",
    "serviceMsgInvalidUrl": "地址无效",
    "serviceMsgUpdateAvailablePrerelease": "发现新的预发布版本",
    "serviceMsgUpdateAvailable": "发现新版本",
    "serviceMsgAlreadyLatest": "当前已经是最新版本",
    "serviceMsgShareBackupText": "这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置。",
    "serviceMsgShareBackupSubject": "轻屿课表备份",
    "serviceMsgShareBackupSubjectNamed": "{profileName} - 轻屿课表备份",
    "serviceMsgShareFullBackupText": "这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板。",
    "serviceMsgShareFullBackupSubject": "轻屿课表 - 全部数据备份",
    "serviceMsgInvalidRepositoryUrl": "仓库地址格式不正确",
    "serviceMsgIncompleteGithubRepoUrl": "GitHub 仓库地址不完整",
    "serviceMsgIncompleteRawGithubUrl": "raw.githubusercontent.com 地址不完整",
    "serviceMsgGithubOnlySupported": "当前只支持 GitHub 仓库地址",
    "serviceMsgWarehouseNoSchoolsIndex": "未读取到任何学校或工具索引",
    "serviceMsgWarehouseNoAdapters": "未读取到 {schoolName} 的适配器信息",
    "serviceMsgWarehouseFetchFailedMirror": "暂时无法读取适配仓。已尝试 {candidatesCount} 个镜像线路均失败。请检查网络，或到「版本更新」里切到其他镜像线路后重试。",
    "serviceMsgWarehouseFetchFailedGithub": "暂时无法读取适配仓。当前正在使用 GitHub 原始线路，请检查网络，或在「版本更新」里切到国内镜像后重试。",
    "serviceMsgManualInputCaptcha": "请手动输入验证码；完成后点击继续",
    "serviceMsgManualInputPassword": "请手动输入密码；如已自动填充请直接继续",
    "serviceMsgMacroNoSteps": "没有录制的步骤",
    "serviceMsgMacroUserCancelled": "用户取消",
    "serviceMsgMacroStepFailed": "第 {stepIndex}/{totalSteps} 步失败: {detail}",
    "serviceMsgMacroNavigateUrlEmpty": "导航 URL 为空",
    "serviceMsgMacroNavigateUrlInvalid": "无效的 URL: {url}",
    "serviceMsgMacroFillSelectorEmpty": "填充字段的选择器为空",
    "serviceMsgMacroElementNotFound": "未找到元素: {selector}",
    "serviceMsgMacroClickSelectorEmpty": "点击元素的选择器为空",
    "serviceMsgMacroUrlPatternEmpty": "URL 模式为空",
    "serviceMsgMacroWaitSelectorEmpty": "等待元素的选择器为空",
    "serviceMsgMacroManualInputDefault": "需要手动操作",
    "serviceMsgMacroPollTimeout": "{stepLabel} 超时（{timeoutSeconds}秒）{lastError}",
    "serviceMsgMacroReplayNavigate": "正在导航...",
    "serviceMsgMacroReplayFillField": "正在填充表单...",
    "serviceMsgMacroReplayClick": "正在点击...",
    "serviceMsgMacroReplayWaitUrl": "等待页面跳转...",
    "serviceMsgMacroReplayWaitSelector": "等待页面元素...",
    "serviceMsgMacroReplayWaitManual": "等待用户操作",
    "serviceMsgMacroReplayExecuteScript": "正在执行导入脚本...",
    "serviceMsgMacroReplayDelay": "等待中...",
    "serviceMsgMacroReplayFailed": "失败: {detail}",
    "serviceMsgMacroReplayPaused": "等待手动操作: {reason}",
    "serviceMsgSupportDonorsLoadFailed": "加载鸣谢名单失败：{detail}",
    "serviceMsgStatisticsShareFailed": "分享失败: {detail}",
    "serviceMsgAuthFailed": "账号或密码错误",
    "serviceMsgAccessDenied": "没有访问权限",
    "serviceMsgCertificateError": "证书校验失败",
    "serviceMsgConnectionTimeout": "连接超时",
    "serviceMsgConnectionFailed": "无法连接服务器",
    "serviceMsgInvalidResponse": "服务器响应无效",
    "serviceMsgSyncFailed": "同步失败",
    "serviceMsgUsageTypeOverride": "副时间表",
    "serviceMsgUsageTypeProfile": "课表主时间表",
    # 下面这 5 条是旧版漏掉、把中文回退成英文的那几条（2026-10-27 补）。
    "serviceMsgImportRollbackIncomplete": "导入失败，导入前的数据未能完整恢复，请重试或检查设备存储",
    "serviceMsgUpdateDownloadHashMismatch": "安装包校验失败，为防止安装被篡改的文件已取消本次更新",
    "serviceMsgUpdateSha256UnverifiedRefused": "安装包完整性校验失败，已取消更新，请前往发布页下载",
    "serviceMsgWarehouseScriptChecksumFailed": "适配器脚本完整性校验失败：下载内容与仓库声明的 SHA-256 不一致，已阻止执行。请刷新学校列表后重试；若反复出现，请到 qingyu_warehouse 反馈该适配器",
    "serviceMsgTimetableShareFailed": "分享失败：{detail}",
}

# 逐行匹配 `  "serviceMsgXxx": "值",` / `  "serviceMsgXxx": "值"`（不带 @ 前缀的普通键）。
SERVICE_MSG_LINE = re.compile(r'^(?P<head>  "(?P<key>serviceMsg[^"]+)": ")(?P<value>.*)(?P<tail>")(?P<comma>,?)$')


class Plan:
    """一份计划的改动：行号 → 新值。"""

    def __init__(self) -> None:
        self.repairs: list[tuple[int, str, str, str]] = []  # 要修的：(行号, 键, 旧值, 新值)
        self.preserved: list[tuple[int, str, str]] = []  # 已有中文、保留：(行号, 键, 现值)
        self.not_found: list[str] = []

    @property
    def changes(self) -> list[tuple[int, str, str, str]]:
        return self.repairs


def is_english_fallback(value: str) -> bool:
    """值里一个中日韩字符都没有 → 当作「空值 / 源自英文」，这是唯一该修的情形。"""
    return not CJK_RE.search(value)


def plan_lines(text: str) -> Plan:
    """只把「空值或英文」的 serviceMsg 行列进修复清单。

    已经有中文的行一律不动 —— 它们可能是后来手工改好的、比 ZH_VALUES 更贴切
    的译文，本脚本没有资格用一张静态表把它们顶掉（这正是旧版最大的破坏面：
    它会改动 44 条并不需要动的已有中文）。
    """
    plan = Plan()
    lines = text.splitlines()
    seen: dict[str, int] = {}
    for index, line in enumerate(lines):
        match = SERVICE_MSG_LINE.match(line)
        if not match:
            continue
        key = match.group("key")
        seen[key] = seen.get(key, 0) + 1
        current = match.group("value")
        if not is_english_fallback(current):
            plan.preserved.append((index, key, current))
            continue
        want = ZH_VALUES.get(key)
        if want is None:
            plan.not_found.append(key)
            continue
        plan.repairs.append((index, key, current, want))
    for key in ZH_VALUES:
        if key not in seen:
            plan.not_found.append(key)
    return plan


def apply_plan(text: str, plan: Plan) -> str:
    lines = text.splitlines()
    for index, _key, _old, new_value in plan.changes:
        line = lines[index]
        match = SERVICE_MSG_LINE.match(line)
        assert match is not None
        lines[index] = (
            match.group("head") + new_value + match.group("tail") + match.group("comma")
        )
    joined = "\n".join(lines)
    return joined + ("\n" if text.endswith("\n") else "")


def validate(path: Path, old_text: str, new_text: str, plan: Plan) -> list[str]:
    """写盘前的硬校验。返回错误消息列表，空列表 = 通过。"""
    errors: list[str] = []

    try:
        old = json.loads(old_text)
        new = json.loads(new_text)
    except json.JSONDecodeError as exc:
        return [f"JSON 解析失败（{exc}）"]
    if not isinstance(old, dict) or not isinstance(new, dict):
        return ["顶层不是 JSON 对象"]

    # 1) 键集合完全不许变
    lost = [k for k in old if k not in new]
    if lost:
        errors.append(f"丢失了 {len(lost)} 个键：{lost[:5]}")
    added = [k for k in new if k not in old]
    if added:
        errors.append(f"多出了 {len(added)} 个键：{added[:5]}")

    # 2) serviceMsg 之外的键，值逐字不变
    outside = [k for k in old if not k.startswith("serviceMsg")]
    touched = [k for k in outside if k in new and new[k] != old[k]]
    if touched:
        errors.append(f"改动越界，serviceMsg 之外有 {len(touched)} 个键被改：{touched[:5]}")

    # 2b) 没有被列入修复清单的 serviceMsg 键，值也必须逐字不变
    repair_keys = {key for _i, key, _o, _n in plan.changes}
    untouched_msgs = [k for k in old if k.startswith("serviceMsg") and k not in repair_keys]
    drifted = [k for k in untouched_msgs if k in new and new[k] != old[k]]
    if drifted:
        errors.append(f"有 {len(drifted)} 个不需要修的 serviceMsg 被改了：{drifted[:5]}")

    # 3) serviceMsg 的键不许丢（旧版虽没丢，但这条是防回归的核心）
    old_msg = {k for k in old if k.startswith("serviceMsg")}
    new_msg = {k for k in new if k.startswith("serviceMsg")}
    if old_msg != new_msg:
        errors.append(f"serviceMsg 键集变了：少 {sorted(old_msg - new_msg)[:5]} 多 {sorted(new_msg - old_msg)[:5]}")

    # 4) 改完之后 zh 的 serviceMsg 里一个英文值都不许有
    english = sorted(k for k in new_msg if isinstance(new[k], str) and is_english_fallback(new[k]))
    if english:
        errors.append(
            f"改完仍有 {len(english)} 个 serviceMsg 是英文（不允许写盘）：{english[:5]}"
        )

    # 5) 计划改的行之外，文件其余行逐行相同（防止顺手重排/格式化）
    old_lines = old_text.splitlines()
    new_lines = new_text.splitlines()
    if len(old_lines) != len(new_lines):
        errors.append(f"行数变了：{len(old_lines)} → {len(new_lines)}，本脚本不允许增删行")
    else:
        allowed = {index for index, *_ in plan.changes}
        stray = [
            i for i, (a, b) in enumerate(zip(old_lines, new_lines))
            if a != b and i not in allowed
        ]
        if stray:
            errors.append(
                f"计划外有 {len(stray)} 行被改动（第 {[i + 1 for i in stray[:5]]} 行）"
            )

    # 6) 每一处计划改动都真的生效，且新值含中文
    for index, key, _old_value, new_value in plan.changes:
        if is_english_fallback(new_value):
            errors.append(f"{key} 要写入的新值是英文：{new_value[:40]!r}")
        if index < len(new_lines):
            line = new_lines[index]
            if new_value not in line:
                errors.append(f"第 {index + 1} 行没写进去：{key}")

    return errors


def atomic_write(path: Path, text: str) -> None:
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".zhfix-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    write = "--write" in args
    arb_dir = ROOT
    if "--arb-dir" in args:
        idx = args.index("--arb-dir")
        if idx + 1 >= len(args):
            print("--arb-dir 后面要跟一个目录", file=sys.stderr)
            return 2
        arb_dir = Path(args[idx + 1]).resolve()

    zh_path = arb_dir / "app_zh.arb"
    if not zh_path.exists():
        print(f"ERROR 找不到 {zh_path}", file=sys.stderr)
        return 2

    original = zh_path.read_text(encoding="utf-8")
    try:
        parsed = json.loads(original)
    except json.JSONDecodeError as exc:
        print(f"ERROR {zh_path.name} 本身不是合法 JSON（{exc}），什么都不做", file=sys.stderr)
        return 3

    plan = plan_lines(original)

    if plan.not_found:
        print(
            f"ERROR 有 {len(plan.not_found)} 个键在文件里找不到或没有译文，"
            f"拒绝改动：{plan.not_found[:8]}",
            file=sys.stderr,
        )
        return 4

    print(f"检查 {zh_path.name}：serviceMsg 普通键 {len([k for k in parsed if k.startswith('serviceMsg')])} 个")
    print(f"  已有中文、原样保留 {len(plan.preserved)} 个")
    print(f"  空值或英文、需要修 {len(plan.repairs)} 个")

    for _index, key, old_value, new_value in plan.repairs[:20]:
        print(f"    {key}")
        print(f"        现：{old_value!r}")
        print(f"        新：{new_value}")
    if len(plan.repairs) > 20:
        print(f"    …… 还有 {len(plan.repairs) - 20} 个，省略")

    if not plan.repairs:
        print("\n全部合规，无需改动。")
        return 0

    new_text = apply_plan(original, plan)
    errors = validate(zh_path, original, new_text, plan)
    if errors:
        for msg in errors:
            print(f"ERROR {msg}", file=sys.stderr)
        print("\n校验不通过，已放弃写盘，原文件一个字节都没动。", file=sys.stderr)
        return 1

    if not write:
        print(f"\n共需修 {len(plan.repairs)} 条。加 --write 才落盘。")
        return 0

    atomic_write(zh_path, new_text)
    print(f"\n已写回 {zh_path.name}：修 {len(plan.repairs)} 条，全部通过校验。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
