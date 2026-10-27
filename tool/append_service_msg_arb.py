#!/usr/bin/env python3
"""把 serviceMsg 系列 ARB 键补进六份 app_*.arb（**只补缺的，已有的一个字节都不碰**）。

用法：
    python tool/append_service_msg_arb.py                 # 只检查，不写盘（默认）
    python tool/append_service_msg_arb.py --write         # 真写盘（写盘前强制校验）
    python tool/append_service_msg_arb.py --arb-dir DIR   # 换一个 ARB 目录（自测用）

为什么重写成这样（2026-10-27）：

上一版每次都把 `EN_BLOCK` 整块追加到文件末尾，**没有任何「这个键已经有了」的判断**。
`EN_BLOCK` 的 195 个键在六份 ARB 里全都已经存在，所以：

* 跑第二遍 → 每份文件多出 195 个**重复键**（JSON 里后出现的赢，值被顶掉）；
* 其中 ja / ko / zh_TW / zh_HK 四份被整块塞进**英文**，繁体日文韩文界面直接变英文；
* 更糟的是它用「英文整串 → 中文」的 `str.replace` 来造中文块，
  替换串会命中**键名**：`serviceMsgWeekdayMustBe1To7` 里的 `Weekday` 变成 `星期`，
  于是凭空造出 `serviceMsg星期MustBe1To7`、`@serviceMsgAiCourseCustom周数Empty`
  这类非法键名，原有的正确键虽还在，却多出一批垃圾键。

因此本版守四条：

1. **幂等**：逐份读 JSON，只追加「文件里还没有」的键；一个都不缺就一个字节都不写。
2. **中文块结构化生成**，不再对整块文本做 `str.replace`，键名永远不会被替换串命中。
3. **写盘前强制校验**：`json.loads` 必须通过；已有键的键集合与值必须**逐一未变**；
   新增键数必须等于计划数；zh 系列新增的普通键值必须含 CJK（防止中文文件被塞英文）。
   任一不通过 → 整份放弃、原文件一个字节不动、以非 0 退出码报告。
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

# Windows 控制台默认 GBK，直接 print 中文会变乱码（2026-10-27 实测：同一段
# 输出在 cmd 里读不出来，「跳过 195 条」这种关键数字没人看得到）。
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):  # 老 Python / 被重定向到非文本流
    pass

ROOT = Path(__file__).resolve().parents[1] / "lib" / "l10n"

EN_BLOCK = r'''
  "serviceMsgImportFileUnrecognized": "Import failed. The file content could not be recognized.",
  "serviceMsgImportUseOverwriteForFullBackup": "This is a full data backup. Please import using overwrite current timetable.",
  "serviceMsgImportNoProfilesInBackup": "No recoverable timetables were found in the backup file.",
  "serviceMsgUnrecognizedMikcbDataFile": "Not a recognizable mikcb data file.",
  "serviceMsgMissingSettingsData": "Settings data is missing.",
  "serviceMsgUnrecognizedMikcbFullBackup": "Not a recognizable mikcb full backup file.",
  "serviceMsgMissingFullBackupData": "Complete backup data is missing.",
  "serviceMsgUseProfileBackupNotFull": "Use a timetable profile backup JSON, not a full data backup.",
  "serviceMsgUnrecognizedSyncSnapshot": "Not a recognizable mikcb cloud sync snapshot.",
  "serviceMsgMissingSyncTimetableData": "Cloud sync timetable data is missing.",
  "serviceMsgSyncSnapshotChecksumFailed": "Cloud sync snapshot verification failed.",
  "serviceMsgSyncSnapshotNoProfiles": "No recoverable timetables in the cloud sync snapshot.",
  "serviceMsgSyncSnapshotUnrecognized": "Cloud sync snapshot could not be recognized.",
  "serviceMsgTimeSchemeNotFound": "Time scheme not found.",
  "serviceMsgTimeSchemeConfigUnavailable": "Current timetable time configuration is unavailable.",
  "serviceMsgTimeSchemeNotFoundSelected": "Selected time scheme was not found.",
  "serviceMsgTimeSchemeSectionsInsufficient": "Selected time scheme does not have enough sections for sections {startSection}-{endSection}.",
  "@serviceMsgTimeSchemeSectionsInsufficient": {"placeholders": {"startSection": {"type": "int"}, "endSection": {"type": "int"}}},
  "serviceMsgSectionCountBelowUsage": "Section count cannot be less than the maximum section in use (section {requiredMaxSection}).",
  "@serviceMsgSectionCountBelowUsage": {"placeholders": {"requiredMaxSection": {"type": "int"}}},
  "serviceMsgSectionCountBelowUsageDetail": "Section count cannot be less than the maximum section in use (section {requiredMaxSection}). In use: {profileName} · {courseName} (weekday {dayOfWeek} sections {startSection}-{endSection}, {usageType})",
  "@serviceMsgSectionCountBelowUsageDetail": {"placeholders": {"requiredMaxSection": {"type": "int"}, "profileName": {"type": "String"}, "courseName": {"type": "String"}, "dayOfWeek": {"type": "int"}, "startSection": {"type": "int"}, "endSection": {"type": "int"}, "usageType": {"type": "String"}}},
  "serviceMsgAtLeastOneSectionRequired": "At least one section time must be kept.",
  "serviceMsgSectionEndMustAfterStart": "Section {sectionNumber} end time must be later than start time. Overnight classes are not supported.",
  "@serviceMsgSectionEndMustAfterStart": {"placeholders": {"sectionNumber": {"type": "int"}}},
  "serviceMsgSectionStartBeforePreviousEnd": "Section {sectionNumber} start time cannot be earlier than the previous section end time.",
  "@serviceMsgSectionStartBeforePreviousEnd": {"placeholders": {"sectionNumber": {"type": "int"}}},
  "serviceMsgPeriodStartTimeRequired": "Set the first section start time for periods that have sections.",
  "serviceMsgSectionCrossesMidnight": "Section {sectionNumber} would cross midnight. Overnight classes are not supported.",
  "@serviceMsgSectionCrossesMidnight": {"placeholders": {"sectionNumber": {"type": "int"}}},
  "serviceMsgClassDurationMustPositive": "Class duration must be greater than 0.",
  "serviceMsgBreakDurationMustNonNegative": "Break duration cannot be less than 0.",
  "serviceMsgAtLeastOnePeriodSection": "At least one period must have sections.",
  "serviceMsgInvalidTimeFormat": "Time format is invalid.",
  "serviceMsgLinkedCourseNotFound": "Linked course was not found.",
  "serviceMsgCourseNotFoundForDelete": "Course to delete was not found.",
  "serviceMsgCourseNotScheduledWeek": "This course is not scheduled in week {sourceWeek}.",
  "@serviceMsgCourseNotScheduledWeek": {"placeholders": {"sourceWeek": {"type": "int"}}},
  "serviceMsgCourseNotFoundForReschedule": "Course to reschedule was not found.",
  "serviceMsgTargetWeekOutOfRange": "Target week is outside the current semester range.",
  "serviceMsgAtLeastOneScheduleSlot": "At least one class time slot must be kept.",
  "serviceMsgCourseNameRequired": "Course name cannot be empty.",
  "serviceMsgBackupContentRequired": "Backup content cannot be empty.",
  "serviceMsgSpreadsheetFormatOrEncodingUnrecognized": "Could not recognize spreadsheet format or encoding. Save CSV as UTF-8 and try again.",
  "serviceMsgSpreadsheetXlsxParseFailed": "Failed to parse XLSX file: {error}",
  "@serviceMsgSpreadsheetXlsxParseFailed": {"placeholders": {"error": {"type": "String"}}},
  "serviceMsgSpreadsheetRowWarning": "Row {rowNumber}: {message}",
  "@serviceMsgSpreadsheetRowWarning": {"placeholders": {"rowNumber": {"type": "int"}, "message": {"type": "String"}}},
  "serviceMsgSpreadsheetWakeupInsufficientColumns": "WakeUp format needs at least 7 columns, but row {rowNumber} has only {columnCount}.",
  "@serviceMsgSpreadsheetWakeupInsufficientColumns": {"placeholders": {"rowNumber": {"type": "int"}, "columnCount": {"type": "int"}}},
  "serviceMsgWeekdayMustBe1To7": "Weekday must be between 1 and 7.",
  "serviceMsgCustomWeeksRequired": "Weeks cannot be empty.",
  "serviceMsgClassWeeksRequired": "Class weeks cannot be empty.",
  "serviceMsgStartWeekMustBeAtLeast1": "Start week must be at least 1.",
  "serviceMsgStartWeekExceedsSemester": "Start week {startWeek} exceeds semester week count {semesterWeekCount}.",
  "@serviceMsgStartWeekExceedsSemester": {"placeholders": {"startWeek": {"type": "int"}, "semesterWeekCount": {"type": "int"}}},
  "serviceMsgEndWeekBeforeStartWeek": "End week cannot be earlier than start week.",
  "serviceMsgWeeksRangeRequired": "Class weeks or start week + end week must be provided.",
  "serviceMsgFieldMustBeAtLeast1": "{field} must be at least 1.",
  "@serviceMsgFieldMustBeAtLeast1": {"placeholders": {"field": {"type": "String"}}},
  "serviceMsgFieldCannotBeLessThan": "{endField} cannot be less than {startField}.",
  "@serviceMsgFieldCannotBeLessThan": {"placeholders": {"startField": {"type": "String"}, "endField": {"type": "String"}}},
  "serviceMsgSectionOutOfRange": "Section {section} is outside the time scheme range (1-{maxSection}).",
  "@serviceMsgSectionOutOfRange": {"placeholders": {"section": {"type": "int"}, "maxSection": {"type": "int"}}},
  "serviceMsgFieldMustBeInteger": "{field} must be an integer.",
  "@serviceMsgFieldMustBeInteger": {"placeholders": {"field": {"type": "String"}}},
  "serviceMsgFieldCannotBeEmpty": "{field} cannot be empty.",
  "@serviceMsgFieldCannotBeEmpty": {"placeholders": {"field": {"type": "String"}}},
  "serviceMsgSpreadsheetEndWeekClamped": "Row {rowNumber}: end week {endWeek} exceeds semester week count {semesterWeekCount}; adjusted to {semesterWeekCount}.",
  "@serviceMsgSpreadsheetEndWeekClamped": {"placeholders": {"rowNumber": {"type": "int"}, "endWeek": {"type": "int"}, "semesterWeekCount": {"type": "int"}}},
  "serviceMsgSpreadsheetOddEvenBoth": "Row {rowNumber}: odd and even weeks cannot both be selected; treated as odd weeks.",
  "@serviceMsgSpreadsheetOddEvenBoth": {"placeholders": {"rowNumber": {"type": "int"}}},
  "serviceMsgFieldCourseName": "Course name",
  "serviceMsgFieldWeekday": "Weekday",
  "serviceMsgFieldStartSection": "Start section",
  "serviceMsgFieldEndSection": "End section",
  "serviceMsgFieldCustomWeeks": "Weeks",
  "serviceMsgFieldClassWeeks": "Class weeks",
  "serviceMsgFieldStartWeek": "Start week",
  "serviceMsgFieldEndWeek": "End week",
  "serviceMsgWeekStartInvalid": "{itemName}: week range start is invalid.",
  "@serviceMsgWeekStartInvalid": {"placeholders": {"itemName": {"type": "String"}}},
  "serviceMsgWeekRangeInvalid": "{itemName}: week range is invalid.",
  "@serviceMsgWeekRangeInvalid": {"placeholders": {"itemName": {"type": "String"}}},
  "serviceMsgWeekRangeTooLarge": "{itemName}: week range is too large. Please check.",
  "@serviceMsgWeekRangeTooLarge": {"placeholders": {"itemName": {"type": "String"}}},
  "serviceMsgWeekTokenUnrecognized": "{itemName}: unrecognized week token: {token}",
  "@serviceMsgWeekTokenUnrecognized": {"placeholders": {"itemName": {"type": "String"}, "token": {"type": "String"}}},
  "serviceMsgWeeksExceedSemesterClamped": "{itemName} contains weeks beyond semester week count {semesterWeekCount} ({weeks}); excess weeks were ignored.",
  "@serviceMsgWeeksExceedSemesterClamped": {"placeholders": {"itemName": {"type": "String"}, "semesterWeekCount": {"type": "int"}, "weeks": {"type": "String"}}},
  "serviceMsgAiResultNotObject": "AI result is not a valid JSON object. Copy the full JSON again.",
  "serviceMsgAiSchemaMustBe": "schema must be {schema}",
  "@serviceMsgAiSchemaMustBe": {"placeholders": {"schema": {"type": "String"}}},
  "serviceMsgAiCoursesMustBeArray": "courses must be an array.",
  "serviceMsgAiWarningsMustBeArray": "warnings must be a string array.",
  "serviceMsgAiWarningItemMustBeString": "Each warnings item must be a string.",
  "serviceMsgAiCourseNotObject": "courses[{index}] is not a valid object.",
  "@serviceMsgAiCourseNotObject": {"placeholders": {"index": {"type": "int"}}},
  "serviceMsgAiCourseNameEmpty": "courses[{index}].name cannot be empty.",
  "@serviceMsgAiCourseNameEmpty": {"placeholders": {"index": {"type": "int"}}},
  "serviceMsgAiCourseDayOfWeekInvalid": "courses[{index}].dayOfWeek must be between 1 and 7.",
  "@serviceMsgAiCourseDayOfWeekInvalid": {"placeholders": {"index": {"type": "int"}}},
  "serviceMsgAiCourseStartSectionInvalid": "courses[{index}].startSection must be at least 1.",
  "@serviceMsgAiCourseStartSectionInvalid": {"placeholders": {"index": {"type": "int"}}},
  "serviceMsgAiCourseEndSectionInvalid": "courses[{index}].endSection cannot be less than startSection.",
  "@serviceMsgAiCourseEndSectionInvalid": {"placeholders": {"index": {"type": "int"}}},
  "serviceMsgAiCourseCustomWeeksEmpty": "courses[{index}].customWeeks cannot be empty.",
  "@serviceMsgAiCourseCustomWeeksEmpty": {"placeholders": {"index": {"type": "int"}}},
  "serviceMsgAiCourseNatureInvalid": "courses[{index}].courseNature must be required or elective.",
  "@serviceMsgAiCourseNatureInvalid": {"placeholders": {"index": {"type": "int"}}},
  "serviceMsgAiUnknownFields": "{targetName} contains unsupported fields: {fields}",
  "@serviceMsgAiUnknownFields": {"placeholders": {"targetName": {"type": "String"}, "fields": {"type": "String"}}},
  "serviceMsgAiFieldMustBeString": "{field} must be a string.",
  "@serviceMsgAiFieldMustBeString": {"placeholders": {"field": {"type": "String"}}},
  "serviceMsgAiFieldMustBeInteger": "{field} must be an integer.",
  "@serviceMsgAiFieldMustBeInteger": {"placeholders": {"field": {"type": "String"}}},
  "serviceMsgAiWeekListInvalid": "{itemName} can only contain integers greater than or equal to 1.",
  "@serviceMsgAiWeekListInvalid": {"placeholders": {"itemName": {"type": "String"}}},
  "serviceMsgAiWeekListTypeInvalid": "{field} must be an integer array or week string.",
  "@serviceMsgAiWeekListTypeInvalid": {"placeholders": {"field": {"type": "String"}}},
  "serviceMsgNoReleaseAvailable": "No release has been published yet.",
  "serviceMsgNoReleaseWithPrerelease": "No stable or prerelease version is available yet.",
  "serviceMsgUpdateCheckHttpFailed": "Update check failed (HTTP {statusCode}).",
  "@serviceMsgUpdateCheckHttpFailed": {"placeholders": {"statusCode": {"type": "int"}}},
  "serviceMsgUpdateCheckNetworkFailed": "Network error. Unable to check for updates right now.",
  "serviceMsgUpdateDownloadUrlUntrusted": "Update download URL failed security validation.",
  "serviceMsgUpdateDownloadHttpFailed": "Download failed (HTTP {statusCode}).",
  "@serviceMsgUpdateDownloadHttpFailed": {"placeholders": {"statusCode": {"type": "int"}}},
  "serviceMsgUpdateOpenInstallerFailed": "Failed to open installer: {detail}",
  "@serviceMsgUpdateOpenInstallerFailed": {"placeholders": {"detail": {"type": "String"}}},
  "serviceMsgUpdateDownloadInstallError": "Download or installation error: {detail}",
  "@serviceMsgUpdateDownloadInstallError": {"placeholders": {"detail": {"type": "String"}}},
  "serviceMsgInvalidUrl": "Invalid URL.",
  "serviceMsgUpdateAvailablePrerelease": "A new prerelease version is available.",
  "serviceMsgUpdateAvailable": "A new version is available.",
  "serviceMsgAlreadyLatest": "You are already on the latest version.",
  "serviceMsgShareBackupText": "This is a full backup of the current timetable. Import it to restore courses and settings.",
  "serviceMsgShareBackupSubject": "Qingyu Timetable backup",
  "serviceMsgShareBackupSubjectNamed": "{profileName} - Qingyu Timetable backup",
  "@serviceMsgShareBackupSubjectNamed": {"placeholders": {"profileName": {"type": "String"}}},
  "serviceMsgShareFullBackupText": "This is a full data backup containing all timetables, the active timetable, and time schemes.",
  "serviceMsgShareFullBackupSubject": "Qingyu Timetable - full data backup",
  "serviceMsgInvalidRepositoryUrl": "Repository URL format is invalid.",
  "serviceMsgIncompleteGithubRepoUrl": "GitHub repository URL is incomplete.",
  "serviceMsgIncompleteRawGithubUrl": "raw.githubusercontent.com URL is incomplete.",
  "serviceMsgGithubOnlySupported": "Only GitHub repository URLs are supported.",
  "serviceMsgWarehouseNoSchoolsIndex": "No school or tool index was found.",
  "serviceMsgWarehouseNoAdapters": "No adapter information was found for {schoolName}.",
  "@serviceMsgWarehouseNoAdapters": {"placeholders": {"schoolName": {"type": "String"}}},
  "serviceMsgWarehouseFetchFailedMirror": "Unable to read the adapter repository. Tried {candidatesCount} mirror endpoints. Check your network or switch mirror in Version Update.",
  "@serviceMsgWarehouseFetchFailedMirror": {"placeholders": {"candidatesCount": {"type": "int"}}},
  "serviceMsgWarehouseFetchFailedGithub": "Unable to read the adapter repository on GitHub. Check your network or switch to a mirror in Version Update.",
  "serviceMsgManualInputCaptcha": "Enter the captcha manually, then tap Continue.",
  "serviceMsgManualInputPassword": "Enter the password manually. If it was auto-filled, tap Continue.",
  "serviceMsgMacroNoSteps": "No recorded steps.",
  "serviceMsgMacroUserCancelled": "Cancelled by user.",
  "serviceMsgMacroStepFailed": "Step {stepIndex}/{totalSteps} failed: {detail}",
  "@serviceMsgMacroStepFailed": {"placeholders": {"stepIndex": {"type": "int"}, "totalSteps": {"type": "int"}, "detail": {"type": "String"}}},
  "serviceMsgMacroNavigateUrlEmpty": "Navigation URL is empty.",
  "serviceMsgMacroNavigateUrlInvalid": "Invalid URL: {url}",
  "@serviceMsgMacroNavigateUrlInvalid": {"placeholders": {"url": {"type": "String"}}},
  "serviceMsgMacroFillSelectorEmpty": "Fill-field selector is empty.",
  "serviceMsgMacroElementNotFound": "Element not found: {selector}",
  "@serviceMsgMacroElementNotFound": {"placeholders": {"selector": {"type": "String"}}},
  "serviceMsgMacroClickSelectorEmpty": "Click selector is empty.",
  "serviceMsgMacroUrlPatternEmpty": "URL pattern is empty.",
  "serviceMsgMacroWaitSelectorEmpty": "Wait selector is empty.",
  "serviceMsgMacroManualInputDefault": "Manual action required.",
  "serviceMsgMacroPollTimeout": "{stepLabel} timed out ({timeoutSeconds}s){lastError}",
  "@serviceMsgMacroPollTimeout": {"placeholders": {"stepLabel": {"type": "String"}, "timeoutSeconds": {"type": "int"}, "lastError": {"type": "String"}}},
  "serviceMsgMacroReplayNavigate": "Navigating…",
  "serviceMsgMacroReplayFillField": "Filling form…",
  "serviceMsgMacroReplayClick": "Clicking…",
  "serviceMsgMacroReplayWaitUrl": "Waiting for navigation…",
  "serviceMsgMacroReplayWaitSelector": "Waiting for page element…",
  "serviceMsgMacroReplayWaitManual": "Waiting for user action…",
  "serviceMsgMacroReplayExecuteScript": "Running import script…",
  "serviceMsgMacroReplayDelay": "Waiting…",
  "serviceMsgMacroReplayFailed": "Failed: {detail}",
  "@serviceMsgMacroReplayFailed": {"placeholders": {"detail": {"type": "String"}}},
  "serviceMsgMacroReplayPaused": "Waiting for manual action: {reason}",
  "@serviceMsgMacroReplayPaused": {"placeholders": {"reason": {"type": "String"}}},
  "serviceMsgSupportDonorsLoadFailed": "Failed to load supporters list: {detail}",
  "@serviceMsgSupportDonorsLoadFailed": {"placeholders": {"detail": {"type": "String"}}},
  "serviceMsgStatisticsShareFailed": "Share failed: {detail}",
  "@serviceMsgStatisticsShareFailed": {"placeholders": {"detail": {"type": "String"}}},
  "serviceMsgAuthFailed": "Invalid username or password.",
  "serviceMsgAccessDenied": "Access denied.",
  "serviceMsgCertificateError": "Certificate validation failed.",
  "serviceMsgConnectionTimeout": "Connection timed out.",
  "serviceMsgConnectionFailed": "Could not connect to the server.",
  "serviceMsgInvalidResponse": "Invalid server response.",
  "serviceMsgSyncFailed": "Sync failed.",
  "serviceMsgUsageTypeOverride": "override time scheme",
  "serviceMsgUsageTypeProfile": "profile main time scheme"
'''

# 英文文案 → 中文译文。**只按整串精确匹配**，绝不拿它去做整块文本替换
# （旧版就是这么干才把 `Weekday` 替进了键名里）。
ZH_TRANSLATIONS = {
    "Import failed. The file content could not be recognized.": "导入失败，文件内容无法识别",
    "This is a full data backup. Please import using overwrite current timetable.": "这是全部数据备份，请使用“覆盖当前课表”方式导入",
    "No recoverable timetables were found in the backup file.": "备份文件中没有可恢复的课表",
    "Not a recognizable mikcb data file.": "不是可识别的 mikcb 数据文件",
    "Settings data is missing.": "缺少设置数据",
    "Not a recognizable mikcb full backup file.": "不是可识别的 mikcb 全量备份文件",
    "Complete backup data is missing.": "缺少完整备份数据",
    "Use a timetable profile backup JSON, not a full data backup.": "请使用课表档案备份 JSON，而非全部数据备份",
    "Not a recognizable mikcb cloud sync snapshot.": "不是可识别的 mikcb 云同步快照",
    "Cloud sync timetable data is missing.": "缺少云同步课表数据",
    "Cloud sync snapshot verification failed.": "云同步快照校验失败",
    "No recoverable timetables in the cloud sync snapshot.": "云同步快照中没有可恢复的课表",
    "Cloud sync snapshot could not be recognized.": "云同步快照无法识别",
    "Time scheme not found.": "时间模板不存在",
    "Current timetable time configuration is unavailable.": "当前课表时间配置不可用",
    "Selected time scheme was not found.": "未找到所选时间模板",
    "Selected time scheme does not have enough sections for sections {startSection}-{endSection}.": "所选时间模板节次数不足，无法覆盖第 {startSection}-{endSection} 节",
    "Section count cannot be less than the maximum section in use (section {requiredMaxSection}).": "节次数量不能小于当前已使用的最大节次（第{requiredMaxSection}节）",
    "Section count cannot be less than the maximum section in use (section {requiredMaxSection}). In use: {profileName} · {courseName} (weekday {dayOfWeek} sections {startSection}-{endSection}, {usageType})": "节次数量不能小于当前已使用的最大节次（第{requiredMaxSection}节）。正在使用：{profileName} · {courseName}（周{dayOfWeek} {startSection}-{endSection}节，{usageType}）",
    "At least one section time must be kept.": "至少需要保留一节课的时间",
    "Section {sectionNumber} end time must be later than start time. Overnight classes are not supported.": "第 {sectionNumber} 节结束时间必须晚于开始时间，暂不支持跨 0 点课程",
    "Section {sectionNumber} start time cannot be earlier than the previous section end time.": "第 {sectionNumber} 节开始时间不能早于上一节的结束时间",
    "Set the first section start time for periods that have sections.": "请为有节次的时段设置第一节开始时间",
    "Section {sectionNumber} would cross midnight. Overnight classes are not supported.": "第 {sectionNumber} 节会跨到次日，当前暂不支持跨 0 点课程",
    "Class duration must be greater than 0.": "上课时长必须大于 0",
    "Break duration cannot be less than 0.": "课间时长不能小于 0",
    "At least one period must have sections.": "至少需要设置一个时段的节次数",
    "Time format is invalid.": "时间格式不正确",
    "Linked course was not found.": "关联的课程不存在",
    "Course to delete was not found.": "未找到要删除的课程",
    "This course is not scheduled in week {sourceWeek}.": "这门课在第 {sourceWeek} 周没有排课",
    "Course to reschedule was not found.": "未找到要调课的课程",
    "Target week is outside the current semester range.": "目标周次超出当前学期范围",
    "At least one class time slot must be kept.": "至少需要保留一个上课时间段",
    "Course name cannot be empty.": "课程名称不能为空",
    "Backup content cannot be empty.": "备份内容不能为空",
    "Could not recognize spreadsheet format or encoding. Save CSV as UTF-8 and try again.": "无法识别表格格式或编码，请将 CSV 另存为 UTF-8 后重试",
    "Failed to parse XLSX file: {error}": "XLSX 文件解析失败：{error}",
    "Row {rowNumber}: {message}": "第 {rowNumber} 行：{message}",
    "WakeUp format needs at least 7 columns, but row {rowNumber} has only {columnCount}.": "WakeUp 格式需要至少 7 列，但第 {rowNumber} 行只有 {columnCount} 列",
    "Weekday must be between 1 and 7.": "星期必须是 1-7",
    "Weeks cannot be empty.": "周数 不能为空",
    "Class weeks cannot be empty.": "上课周 不能为空",
    "Start week must be at least 1.": "开始周 必须大于等于 1",
    "Start week {startWeek} exceeds semester week count {semesterWeekCount}.": "开始周 {startWeek} 超过学期周数 {semesterWeekCount}",
    "End week cannot be earlier than start week.": "结束周 不能小于开始周",
    "Class weeks or start week + end week must be provided.": "上课周 或 开始周+结束周 必须填写",
    "{field} must be at least 1.": "{field} 必须大于等于 1",
    "{endField} cannot be less than {startField}.": "{endField} 不能小于{startField}",
    "Section {section} is outside the time scheme range (1-{maxSection}).": "节次 {section} 超出时间模板范围（1-{maxSection}）",
    "{field} must be an integer.": "{field} 必须是整数",
    "{field} cannot be empty.": "{field} 不能为空",
    "Row {rowNumber}: end week {endWeek} exceeds semester week count {semesterWeekCount}; adjusted to {semesterWeekCount}.": "第 {rowNumber} 行：结束周 {endWeek} 超过学期周数 {semesterWeekCount}，已调整为 {semesterWeekCount}",
    "Row {rowNumber}: odd and even weeks cannot both be selected; treated as odd weeks.": "第 {rowNumber} 行：单周与双周不能同时勾选，已按单周处理",
    "Course name": "课程名称",
    "Weekday": "星期",
    "Start section": "开始节数",
    "End section": "结束节数",
    "Weeks": "周数",
    "Class weeks": "上课周",
    "Start week": "开始周",
    "End week": "结束周",
    "{itemName}: week range start is invalid.": "{itemName} 周次起始值不合法",
    "{itemName}: week range is invalid.": "{itemName} 周次范围不合法",
    "{itemName}: week range is too large. Please check.": "{itemName} 周次范围过大，请检查",
    "{itemName}: unrecognized week token: {token}": "{itemName} 含有无法识别的周次：{token}",
    "{itemName} contains weeks beyond semester week count {semesterWeekCount} ({weeks}); excess weeks were ignored.": "{itemName} 含有超过学期周数 {semesterWeekCount} 的周次（{weeks}），已忽略超出部分",
    "AI result is not a valid JSON object. Copy the full JSON again.": "AI 结果不是合法对象，请重新复制完整 JSON",
    "schema must be {schema}": "schema 必须为 {schema}",
    "courses must be an array.": "courses 必须是数组",
    "warnings must be a string array.": "warnings 必须是字符串数组",
    "Each warnings item must be a string.": "warnings 中的每一项都必须是字符串",
    "courses[{index}] is not a valid object.": "courses[{index}] 不是合法对象",
    "courses[{index}].name cannot be empty.": "courses[{index}].name 不能为空",
    "courses[{index}].dayOfWeek must be between 1 and 7.": "courses[{index}].dayOfWeek 必须是 1-7",
    "courses[{index}].startSection must be at least 1.": "courses[{index}].startSection 必须大于等于 1",
    "courses[{index}].endSection cannot be less than startSection.": "courses[{index}].endSection 不能小于 startSection",
    "courses[{index}].customWeeks cannot be empty.": "courses[{index}].customWeeks 不能为空",
    "courses[{index}].courseNature must be required or elective.": "courses[{index}].courseNature 只能是 required 或 elective",
    "{targetName} contains unsupported fields: {fields}": "{targetName} 包含不支持的字段：{fields}",
    "{field} must be a string.": "{field} 必须是字符串",
    "{field} must be an integer.": "{field} 必须是整数",
    "{itemName} can only contain integers greater than or equal to 1.": "{itemName} 只能包含大于等于 1 的整数",
    "{field} must be an integer array or week string.": "{field} 必须是整数数组或周次字符串",
    "No release has been published yet.": "仓库还没有发布 Release。",
    "No stable or prerelease version is available yet.": "还没有可用的正式版或预发布版本。",
    "Update check failed (HTTP {statusCode}).": "检查更新失败（HTTP {statusCode}）。",
    "Network error. Unable to check for updates right now.": "网络异常，暂时无法检查更新。",
    "Update download URL failed security validation.": "更新下载地址未通过安全校验",
    "Download failed (HTTP {statusCode}).": "下载失败（HTTP {statusCode}）",
    "Failed to open installer: {detail}": "打开安装包失败: {detail}",
    "Download or installation error: {detail}": "下载或安装过程中出现错误: {detail}",
    "Invalid URL.": "地址无效",
    "A new prerelease version is available.": "发现新的预发布版本",
    "A new version is available.": "发现新版本",
    "You are already on the latest version.": "当前已经是最新版本",
    "This is a full backup of the current timetable. Import it to restore courses and settings.": "这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置。",
    "Qingyu Timetable backup": "轻屿课表备份",
    "{profileName} - Qingyu Timetable backup": "{profileName} - 轻屿课表备份",
    "This is a full data backup containing all timetables, the active timetable, and time schemes.": "这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板。",
    "Qingyu Timetable - full data backup": "轻屿课表 - 全部数据备份",
    "Repository URL format is invalid.": "仓库地址格式不正确",
    "GitHub repository URL is incomplete.": "GitHub 仓库地址不完整",
    "raw.githubusercontent.com URL is incomplete.": "raw.githubusercontent.com 地址不完整",
    "Only GitHub repository URLs are supported.": "当前只支持 GitHub 仓库地址",
    "No school or tool index was found.": "未读取到任何学校或工具索引",
    "No adapter information was found for {schoolName}.": "未读取到 {schoolName} 的适配器信息",
    "Unable to read the adapter repository. Tried {candidatesCount} mirror endpoints. Check your network or switch mirror in Version Update.": "暂时无法读取适配仓。已尝试 {candidatesCount} 个镜像线路均失败。请检查网络，或到「版本更新」里切到其他镜像线路后重试。",
    "Unable to read the adapter repository on GitHub. Check your network or switch to a mirror in Version Update.": "暂时无法读取适配仓。当前正在使用 GitHub 原始线路，请检查网络，或在「版本更新」里切到国内镜像后重试。",
    "Enter the captcha manually, then tap Continue.": "请手动输入验证码；完成后点击继续",
    "Enter the password manually. If it was auto-filled, tap Continue.": "请手动输入密码；如已自动填充请直接继续",
    "No recorded steps.": "没有录制的步骤",
    "Cancelled by user.": "用户取消",
    "Step {stepIndex}/{totalSteps} failed: {detail}": "第 {stepIndex}/{totalSteps} 步失败: {detail}",
    "Navigation URL is empty.": "导航 URL 为空",
    "Invalid URL: {url}": "无效的 URL: {url}",
    "Fill-field selector is empty.": "填充字段的选择器为空",
    "Element not found: {selector}": "未找到元素: {selector}",
    "Click selector is empty.": "点击元素的选择器为空",
    "URL pattern is empty.": "URL 模式为空",
    "Wait selector is empty.": "等待元素的选择器为空",
    "Manual action required.": "需要手动操作",
    "{stepLabel} timed out ({timeoutSeconds}s){lastError}": "{stepLabel} 超时（{timeoutSeconds}秒）{lastError}",
    "Navigating…": "正在导航...",
    "Filling form…": "正在填充表单...",
    "Clicking…": "正在点击...",
    "Waiting for navigation…": "等待页面跳转...",
    "Waiting for page element…": "等待页面元素...",
    "Waiting for user action…": "等待用户操作",
    "Running import script…": "正在执行导入脚本...",
    "Waiting…": "等待中...",
    "Failed: {detail}": "失败: {detail}",
    "Waiting for manual action: {reason}": "等待手动操作: {reason}",
    "Failed to load supporters list: {detail}": "加载鸣谢名单失败：{detail}",
    "Share failed: {detail}": "分享失败: {detail}",
    "Invalid username or password.": "账号或密码错误",
    "Access denied.": "没有访问权限",
    "Certificate validation failed.": "证书校验失败",
    "Connection timed out.": "连接超时",
    "Could not connect to the server.": "无法连接服务器",
    "Invalid server response.": "服务器响应无效",
    "Sync failed.": "同步失败",
    "override time scheme": "副时间表",
    "profile main time scheme": "课表主时间表",
}

# 这些语系的「新键」用英文兜底（旧版就是这么做的，现状也是如此：zh_TW / zh_HK
# 的 129 个 serviceMsg 键里有 122 个就是英文）。这里保留行为，但**逐份报告**
# 有几个键走了英文兜底，方便以后有人真有精力翻译时能找到位置。
EN_FALLBACK_LOCALES = ("app_ja.arb", "app_ko.arb", "app_zh_TW.arb", "app_zh_HK.arb")

# 只有简体中文这一份必须保证「新值真的是中文」：现状里 app_zh.arb 的
# serviceMsg 没有一个英文值，所以任何英文新值都是回归，必须拦下来。
CJK_REQUIRED_LOCALES = ("app_zh.arb",)

CJK_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]")


def parse_en_block() -> dict[str, object]:
    """把 EN_BLOCK 当 JSON 对象解析（带前导两个空格与尾逗号，套一层花括号即可）。"""
    data = json.loads("{" + EN_BLOCK + "\n}")
    if not isinstance(data, dict):
        raise SystemExit("EN_BLOCK 解析结果不是对象，脚本自身有问题")
    return data


def build_block(data: dict[str, object], keys: list[str], zh: bool) -> str:
    """按给定键顺序生成可插入 ARB 的片段（每行一个键，行尾带逗号）。

    中文块在这里**结构化**生成：只对「值」做整串查表，键名原样保留。
    """
    lines: list[str] = []
    missing_zh: list[str] = []
    for key in keys:
        value = data[key]
        if zh and not key.startswith("@") and isinstance(value, str):
            translated = ZH_TRANSLATIONS.get(value)
            if translated is None:
                missing_zh.append(key)
                continue
            value = translated
        dumped = json.dumps(value, ensure_ascii=False)
        lines.append(f'  {json.dumps(key, ensure_ascii=False)}: {dumped},')
    if missing_zh:
        raise BlockBuildError(missing_zh)
    return "\n".join(lines)


class BlockBuildError(Exception):
    def __init__(self, keys: list[str]) -> None:
        self.keys = keys
        super().__init__(", ".join(keys[:5]))


def merge_text(original: str, block: str) -> str:
    """把 block 插到最外层 `}` 前面，返回新文本（不改动原有内容）。"""
    text = original.rstrip()
    if not text.endswith("}"):
        raise ValueError("文件没有以 } 结尾，不是合法 ARB 形态，放弃")
    body = text[:-1].rstrip()
    if not body.endswith(","):
        body += ","

    # block 的每一行都带行尾逗号（方便逐行增删），但**最后一行不能带**：
    # `{"a": 1,}` 不是合法 JSON。这里去掉末尾那一个逗号。
    tail = block.rstrip()
    while tail.endswith(","):
        tail = tail[:-1].rstrip()
    return body + "\n" + tail + "\n}\n"


def validate(path: Path, old_text: str, new_text: str,
             old: dict[str, object], added: list[str],
             cjk_required: bool) -> list[str]:
    """写盘前的硬校验。返回错误消息列表，空列表 = 通过。"""
    errors: list[str] = []

    try:
        new = json.loads(new_text)
    except json.JSONDecodeError as exc:
        return [f"改完不是合法 JSON（{exc}）"]
    if not isinstance(new, dict):
        return ["改完的顶层不是 JSON 对象"]

    # 1) 原有每一个键都还在，且值逐字相同
    for key, value in old.items():
        if key not in new:
            errors.append(f"原有键 {key} 丢失")
        elif new[key] != value:
            errors.append(f"原有键 {key} 的值被改动")

    # 2) 新增的键数正好等于计划数，且一个都不缺
    for key in added:
        if key not in new:
            errors.append(f"计划新增的键 {key} 没写进去")
    unexpected = [k for k in new if k not in old and k not in added]
    if unexpected:
        errors.append(f"出现了计划外的新键：{unexpected[:5]}")

    # 3) 简体中文那份不许出现英文新值
    if cjk_required:
        for key in added:
            value = new.get(key)
            if isinstance(value, str) and not CJK_RE.search(value):
                errors.append(f"{key} 的值不含中文，疑似英文回退：{value[:40]!r}")

    # 4) 物理层面不许有重复键（旧版就栽在这）
    physical = re.findall(r'^  "([^"]+)":', new_text, re.M)
    dups = {k for k in physical if physical.count(k) > 1}
    if dups:
        errors.append(f"文件里出现重复键：{sorted(dups)[:5]}")

    return errors


def atomic_write(path: Path, text: str) -> None:
    """先写同目录临时文件再 os.replace，避免写一半留下残file。"""
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".arbfix-", suffix=".tmp")
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

    try:
        data = parse_en_block()
    except json.JSONDecodeError as exc:
        print(f"ERROR EN_BLOCK 自身不是合法 JSON（{exc}），脚本有问题，什么都不做", file=sys.stderr)
        return 3

    order = list(data)
    targets = [arb_dir / name for name in
               ("app_en.arb", "app_zh.arb", "app_ja.arb", "app_ko.arb",
                "app_zh_TW.arb", "app_zh_HK.arb")]
    targets = [p for p in targets if p.exists()]
    if not targets:
        print(f"ERROR 在 {arb_dir} 里没找到 app_*.arb", file=sys.stderr)
        return 2

    failures: list[str] = []
    planned_total = 0
    skipped_total = 0

    for path in targets:
        original = path.read_text(encoding="utf-8")
        try:
            old = json.loads(original)
        except json.JSONDecodeError as exc:
            failures.append(f"{path.name}: 现有文件不是合法 JSON（{exc}），拒绝改动")
            continue
        if not isinstance(old, dict):
            failures.append(f"{path.name}: 顶层不是 JSON 对象，拒绝改动")
            continue

        existing = [key for key in order if key in old]
        missing = [key for key in order if key not in old]
        skipped_total += len(existing)

        if not missing:
            print(f"SKIP  {path.name}：{len(existing)} 个键全已存在，未改动")
            continue

        zh = path.name == "app_zh.arb"
        try:
            block = build_block(data, missing, zh)
        except BlockBuildError as exc:
            failures.append(
                f"{path.name}: {len(exc.keys)} 个键缺中文译文，拒绝写盘：{exc.keys}"
            )
            continue

        new_text = merge_text(original, block)
        errors = validate(
            path, original, new_text, old, missing,
            cjk_required=path.name in CJK_REQUIRED_LOCALES,
        )
        if errors:
            failures.extend(f"{path.name}: {msg}" for msg in errors)
            continue

        planned_total += len(missing)
        note = ""
        if path.name in EN_FALLBACK_LOCALES:
            note = "，本次英文兜底"
        print(f"ADD   {path.name}：缺 {len(missing)} 个键（已存在 {len(existing)} 个，跳过{note}）")
        if write:
            atomic_write(path, new_text)
            print(f"      已写回 {path.name}")
        else:
            print("      只检查模式，未写盘（加 --write 才落盘）")

    print()
    if failures:
        for msg in failures:
            print(f"ERROR {msg}", file=sys.stderr)
        print("\n有文件未通过校验，已全部放弃，原文件一个字节都没动。", file=sys.stderr)
        return 1

    if planned_total == 0:
        print(f"六份 ARB 的 {len(order)} 个键都已在位（共跳过 {skipped_total} 个），无需改动。")
    elif write:
        print(f"共补 {planned_total} 个键，全部通过 JSON 与格式校验。")
    else:
        print(f"共需补 {planned_total} 个键。加 --write 才落盘。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
