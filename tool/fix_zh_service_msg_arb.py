#!/usr/bin/env python3
"""Fix corrupted serviceMsg keys in app_zh.arb by copying keys from app_en.arb."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib" / "l10n"

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
}


def strip_service_msg(data: dict) -> dict:
    return {
        key: value
        for key, value in data.items()
        if not key.startswith("serviceMsg") and not key.startswith("@serviceMsg")
    }


def main() -> None:
    en = json.loads((ROOT / "app_en.arb").read_text(encoding="utf-8"))
    zh = json.loads((ROOT / "app_zh.arb").read_text(encoding="utf-8"))
    base = strip_service_msg(zh)
    for key, value in en.items():
        if not key.startswith("serviceMsg") and not key.startswith("@serviceMsg"):
            continue
        if key.startswith("serviceMsg") and not key.startswith("@serviceMsg"):
            base[key] = ZH_VALUES.get(key, value)
        else:
            base[key] = value
    (ROOT / "app_zh.arb").write_text(
        json.dumps(base, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
