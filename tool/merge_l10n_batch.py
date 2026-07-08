#!/usr/bin/env python3
"""Append i18n batch keys to all ARB files."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent
ARB_DIR = ROOT / "lib" / "l10n"

# locale -> {key: value}  (values may contain {placeholders})
BATCH: dict[str, dict[str, str]] = {
    "zh": {
        "weekListSeparator": "、",
        "courseWeekListLabel": "第{weeks}周",
        "courseWeekRangeLabel": "第{startWeek}-{endWeek}周{mode}",
        "courseWeekSuspendedLabel": "第{weeks}周停课",
        "importSemesterStartDateTitle": "开学日期",
        "importSemesterStartDateSubtitle": "按这一天所在周作为校历第 1 周",
        "importFirstCourseWeekMappingLabel": "课表第 1 周对应校历第几周",
        "importFirstCourseWeekMappingSubtitle": "如果学校第一周没课，就选第 2 周；前两周都没课就选第 3 周。",
        "importSemesterMappingNoShiftHint": "导入后会直接把课表第 1 周当作校历第 1 周。",
        "importSemesterMappingShiftHint": "导入后会把所有课程周次整体顺延 {shiftedWeeks} 周，让课表第 1 周落在校历第 {calendarWeek} 周。",
        "calendarWeekOption": "校历第 {week} 周",
        "aboutDownloadPackageMethodTitle": "下载安装包方式",
        "aboutInAppDownloadTitle": "应用内下载",
        "aboutInAppDownloadSubtitle": "下载完成后直接在应用内安装",
        "aboutSystemDownloaderTitle": "系统管理器",
        "aboutSystemDownloaderChoiceSubtitle": "交给系统下载管理器处理",
        "syncErrorAuthFailed": "账号或密码错误",
        "syncErrorAccessDenied": "没有访问权限",
        "syncErrorCertificateError": "证书校验失败",
        "syncErrorConnectionTimeout": "连接超时",
        "syncErrorConnectionFailed": "无法连接服务器",
        "syncErrorNetworkError": "网络异常",
        "syncErrorInvalidResponse": "服务器响应无效",
        "syncErrorLocalChangesPendingSync": "本地有未同步修改，已跳过自动覆盖",
        "syncErrorMissingCredentials": "请先配置云同步账号",
        "syncErrorBackupNotFound": "备份不存在",
        "syncErrorMissingBackupSnapshot": "备份快照缺失",
        "syncErrorCannotDeleteCurrentBackup": "不能删除当前备份",
        "syncErrorProviderNotReady": "课表尚未就绪",
        "syncErrorSyncFailed": "同步失败",
        "sectionTimeDisplayHidden": "不显示",
        "sectionTimeDisplayStartOnly": "仅显示上课时间",
        "sectionTimeDisplayStartAndEnd": "显示上下课时间",
        "examReminderNone": "不提醒",
        "examReminderMin30": "考前 30 分钟",
        "examReminderHour1": "考前 1 小时",
        "examReminderHour1AndMin30": "考前 1 小时 + 30 分钟",
        "examReminderDay1": "考前 1 天",
        "examReminderDay1AndHour1": "考前 1 天 + 1 小时",
        "examReminderCustom": "自定义",
        "debugCopiedJson": "已复制 JSON",
        "liveDuringClassTimeNearest": "最近时间",
        "liveDuringClassTimeTotal": "总时间",
        "liveCountdownTextStyleSmart": "智能（中文）",
        "liveCountdownTextStyleSmartMinS": "智能（英文）",
        "liveCountdownTextStyleMinuteSecondCn": "分秒（5分钟19秒）",
        "liveCountdownTextStyleMinuteSecondColon": "mm:ss（05:19）",
        "liveCountdownTextStyleMinuteSecondMinS": "min+s（5min19s）",
        "liveCountdownTextStyleMinuteSecondMinSlashS": "min/s（5min/19s）",
        "liveCountdownTextStyleMinuteOnlyCn": "纯分钟（5分钟）",
        "liveCountdownTextStyleMinuteOnlyMin": "min（5min）",
        "liveCountdownTextStyleMinuteOnlySlash": "/min（5/min）",
        "liveCountdownTextStyleSecondOnlyCn": "纯秒（5秒）",
        "liveCountdownTextStyleSecondOnlyShort": "s（5s）",
        "liveCountdownTextStyleSecondOnlySlash": "/s（5/s）",
        "miuiIslandLabelStyleTextOnly": "仅文字",
        "miuiIslandLabelStyleIconAndText": "图标+文字",
        "miuiIslandLabelContentCourseName": "课程名",
        "miuiIslandLabelContentLocation": "教室",
        "miuiIslandLabelContentCourseNameAndLocation": "课程名+教室",
        "miuiIslandLabelFontWeightRegular": "常规",
        "miuiIslandLabelFontWeightMedium": "中等",
        "miuiIslandLabelFontWeightBold": "加粗",
        "miuiIslandLabelRenderQualityStandard": "标准",
        "miuiIslandLabelRenderQualityHigh": "高清",
        "miuiIslandLabelRenderQualityUltra": "超高清",
        "miuiIslandExpandedIconAppIcon": "应用图标",
        "miuiIslandExpandedIconCustomImage": "自定义图片",
        "miuiIslandExpandedIconHidden": "不显示",
        "liveBeforeClassQuickActionNone": "不显示",
        "liveBeforeClassQuickActionSilent": "打开静音",
        "liveBeforeClassQuickActionDoNotDisturb": "打开免打扰",
        "courseCardVerticalAlignTop": "顶部对齐",
        "courseCardVerticalAlignCenter": "垂直居中",
        "courseCardVerticalAlignBottom": "底部对齐",
        "courseCardVerticalAlignSpaceEvenly": "上下均布",
        "courseCardHorizontalAlignLeft": "居左",
        "courseCardHorizontalAlignCenter": "居中",
        "courseCardHorizontalAlignRight": "居右",
        "timetableTimeColumnWidthNarrow": "窄",
        "timetableTimeColumnWidthWide": "宽",
        "timetableCourseSpacingNarrow": "窄",
        "timetableCourseSpacingWide": "宽",
        "appUpdateDownloadSourceOriginal": "GitHub 原版",
        "appUpdateDownloadSourceMirror": "国内镜像",
        "appUpdateDownloadChannelPgyer": "蒲公英下载",
        "appUpdateDownloadChannelGithub": "GitHub 下载",
        "appUpdateDownloadChannelPgyerDescription": "国内高速下载，推荐使用",
        "appUpdateDownloadChannelGithubDescription": "GitHub 原生 + 国内镜像",
        "holidayStatutoryLabel": "法定节假日",
    },
    "en": {
        "weekListSeparator": ", ",
        "courseWeekListLabel": "Weeks {weeks}",
        "courseWeekRangeLabel": "Weeks {startWeek}-{endWeek}{mode}",
        "courseWeekSuspendedLabel": "Suspended weeks {weeks}",
        "importSemesterStartDateTitle": "Semester start date",
        "importSemesterStartDateSubtitle": "Treat the week containing this date as calendar week 1",
        "importFirstCourseWeekMappingLabel": "Timetable week 1 maps to calendar week",
        "importFirstCourseWeekMappingSubtitle": "If the first school week has no classes, choose week 2; if the first two weeks are empty, choose week 3.",
        "importSemesterMappingNoShiftHint": "After import, timetable week 1 will be treated as calendar week 1.",
        "importSemesterMappingShiftHint": "All course weeks will shift forward by {shiftedWeeks} so timetable week 1 lands on calendar week {calendarWeek}.",
        "calendarWeekOption": "Calendar week {week}",
        "aboutDownloadPackageMethodTitle": "Download install method",
        "aboutInAppDownloadTitle": "In-app download",
        "aboutInAppDownloadSubtitle": "Install directly in the app after download completes",
        "aboutSystemDownloaderTitle": "System download manager",
        "aboutSystemDownloaderChoiceSubtitle": "Hand off to the system download manager",
        "syncErrorAuthFailed": "Invalid username or password",
        "syncErrorAccessDenied": "Access denied",
        "syncErrorCertificateError": "Certificate error",
        "syncErrorConnectionTimeout": "Connection timed out",
        "syncErrorConnectionFailed": "Could not connect to server",
        "syncErrorNetworkError": "Network error",
        "syncErrorInvalidResponse": "Invalid server response",
        "syncErrorLocalChangesPendingSync": "Skipped auto sync because local changes are pending",
        "syncErrorMissingCredentials": "Configure sync account first",
        "syncErrorBackupNotFound": "Backup not found",
        "syncErrorMissingBackupSnapshot": "Backup snapshot is missing",
        "syncErrorCannotDeleteCurrentBackup": "Cannot delete the current backup",
        "syncErrorProviderNotReady": "Timetable is not ready",
        "syncErrorSyncFailed": "Sync failed",
        "sectionTimeDisplayHidden": "Hidden",
        "sectionTimeDisplayStartOnly": "Start time only",
        "sectionTimeDisplayStartAndEnd": "Start and end times",
        "examReminderNone": "No reminder",
        "examReminderMin30": "30 minutes before",
        "examReminderHour1": "1 hour before",
        "examReminderHour1AndMin30": "1 hour and 30 minutes before",
        "examReminderDay1": "1 day before",
        "examReminderDay1AndHour1": "1 day and 1 hour before",
        "examReminderCustom": "Custom",
        "debugCopiedJson": "JSON copied",
        "liveDuringClassTimeNearest": "Nearest time",
        "liveDuringClassTimeTotal": "Total time",
        "liveCountdownTextStyleSmart": "Smart (localized)",
        "liveCountdownTextStyleSmartMinS": "Smart (min/s)",
        "liveCountdownTextStyleMinuteSecondCn": "Minutes and seconds (5m19s)",
        "liveCountdownTextStyleMinuteSecondColon": "mm:ss (05:19)",
        "liveCountdownTextStyleMinuteSecondMinS": "min+s (5min19s)",
        "liveCountdownTextStyleMinuteSecondMinSlashS": "min/s (5min/19s)",
        "liveCountdownTextStyleMinuteOnlyCn": "Minutes only (5 min)",
        "liveCountdownTextStyleMinuteOnlyMin": "min (5min)",
        "liveCountdownTextStyleMinuteOnlySlash": "/min (5/min)",
        "liveCountdownTextStyleSecondOnlyCn": "Seconds only (5 s)",
        "liveCountdownTextStyleSecondOnlyShort": "s (5s)",
        "liveCountdownTextStyleSecondOnlySlash": "/s (5/s)",
        "miuiIslandLabelStyleTextOnly": "Text only",
        "miuiIslandLabelStyleIconAndText": "Icon + text",
        "miuiIslandLabelContentCourseName": "Course name",
        "miuiIslandLabelContentLocation": "Room",
        "miuiIslandLabelContentCourseNameAndLocation": "Course + room",
        "miuiIslandLabelFontWeightRegular": "Regular",
        "miuiIslandLabelFontWeightMedium": "Medium",
        "miuiIslandLabelFontWeightBold": "Bold",
        "miuiIslandLabelRenderQualityStandard": "Standard",
        "miuiIslandLabelRenderQualityHigh": "High",
        "miuiIslandLabelRenderQualityUltra": "Ultra",
        "miuiIslandExpandedIconAppIcon": "App icon",
        "miuiIslandExpandedIconCustomImage": "Custom image",
        "miuiIslandExpandedIconHidden": "Hidden",
        "liveBeforeClassQuickActionNone": "Hidden",
        "liveBeforeClassQuickActionSilent": "Turn on silent mode",
        "liveBeforeClassQuickActionDoNotDisturb": "Turn on Do Not Disturb",
        "courseCardVerticalAlignTop": "Top",
        "courseCardVerticalAlignCenter": "Center",
        "courseCardVerticalAlignBottom": "Bottom",
        "courseCardVerticalAlignSpaceEvenly": "Space evenly",
        "courseCardHorizontalAlignLeft": "Left",
        "courseCardHorizontalAlignCenter": "Center",
        "courseCardHorizontalAlignRight": "Right",
        "timetableTimeColumnWidthNarrow": "Narrow",
        "timetableTimeColumnWidthWide": "Wide",
        "timetableCourseSpacingNarrow": "Narrow",
        "timetableCourseSpacingWide": "Wide",
        "appUpdateDownloadSourceOriginal": "GitHub original",
        "appUpdateDownloadSourceMirror": "Mirror",
        "appUpdateDownloadChannelPgyer": "Pgyer download",
        "appUpdateDownloadChannelGithub": "GitHub download",
        "appUpdateDownloadChannelPgyerDescription": "Fast download in China, recommended",
        "appUpdateDownloadChannelGithubDescription": "GitHub plus mirrors",
        "holidayStatutoryLabel": "Public holiday",
    },
}

# ja, ko, zh_HK, zh_TW - use en as base and adjust key locales
BATCH["ja"] = {**BATCH["en"]}
BATCH["ja"].update({
    "weekListSeparator": "、",
    "courseWeekListLabel": "第{weeks}週",
    "courseWeekRangeLabel": "第{startWeek}-{endWeek}週{mode}",
    "courseWeekSuspendedLabel": "第{weeks}週休講",
    "importSemesterStartDateTitle": "学期開始日",
    "importSemesterStartDateSubtitle": "この日を含む週を校歴第1週として扱います",
    "holidayStatutoryLabel": "祝日",
    "syncErrorSyncFailed": "同期に失敗しました",
})

BATCH["ko"] = {**BATCH["en"]}
BATCH["ko"].update({
    "weekListSeparator": ", ",
    "courseWeekListLabel": "제{weeks}주",
    "courseWeekRangeLabel": "제{startWeek}-{endWeek}주{mode}",
    "courseWeekSuspendedLabel": "제{weeks}주 휴강",
    "importSemesterStartDateTitle": "개학일",
    "holidayStatutoryLabel": "공휴일",
    "syncErrorSyncFailed": "동기화 실패",
})

BATCH["zh_HK"] = {**BATCH["zh"]}
BATCH["zh_HK"].update({
    "importSemesterStartDateSubtitle": "按這一天所在週作為校曆第 1 週",
    "importFirstCourseWeekMappingLabel": "課表第 1 週對應校曆第幾週",
    "importFirstCourseWeekMappingSubtitle": "如果學校第一週沒課，就選第 2 週；前兩週都沒課就選第 3 週。",
    "importSemesterMappingNoShiftHint": "匯入後會直接把課表第 1 週當作校曆第 1 週。",
    "importSemesterMappingShiftHint": "匯入後會把所有課程週次整體順延 {shiftedWeeks} 週，讓課表第 1 週落在校曆第 {calendarWeek} 週。",
    "calendarWeekOption": "校曆第 {week} 週",
    "aboutInAppDownloadSubtitle": "下載完成後直接在應用內安裝",
    "aboutSystemDownloaderChoiceSubtitle": "交給系統下載管理器處理",
    "syncErrorAuthFailed": "帳號或密碼錯誤",
    "syncErrorAccessDenied": "沒有存取權限",
    "syncErrorCertificateError": "憑證校驗失敗",
    "syncErrorConnectionTimeout": "連線逾時",
    "syncErrorConnectionFailed": "無法連線伺服器",
    "syncErrorNetworkError": "網路異常",
    "syncErrorInvalidResponse": "伺服器回應無效",
    "syncErrorLocalChangesPendingSync": "本機有未同步修改，已跳過自動覆蓋",
    "syncErrorMissingCredentials": "請先設定雲同步帳號",
    "syncErrorBackupNotFound": "備份不存在",
    "syncErrorMissingBackupSnapshot": "備份快照缺失",
    "syncErrorCannotDeleteCurrentBackup": "不能刪除目前備份",
    "syncErrorProviderNotReady": "課表尚未就緒",
    "syncErrorSyncFailed": "同步失敗",
    "debugCopiedJson": "已複製 JSON",
    "holidayStatutoryLabel": "法定假日",
})

BATCH["zh_TW"] = {**BATCH["zh_HK"]}

PLACEHOLDER_META = {
    "courseWeekListLabel": {"weeks": "String"},
    "courseWeekRangeLabel": {"startWeek": "int", "endWeek": "int", "mode": "String"},
    "courseWeekSuspendedLabel": {"weeks": "String"},
    "importSemesterMappingShiftHint": {"shiftedWeeks": "int", "calendarWeek": "int"},
    "calendarWeekOption": {"week": "int"},
}

LOCALE_FILE = {
    "zh": "app_zh.arb",
    "en": "app_en.arb",
    "ja": "app_ja.arb",
    "ko": "app_ko.arb",
    "zh_HK": "app_zh_HK.arb",
    "zh_TW": "app_zh_TW.arb",
}


def append_keys(locale: str, path: Path, keys: dict[str, str]) -> list[str]:
    text = path.read_text(encoding="utf-8")
    added = []
    insert_lines = []
    for key, value in keys.items():
        if re.search(rf'^\s*"{re.escape(key)}"\s*:', text, re.M):
            continue
        added.append(key)
        insert_lines.append(f'  "{key}": {json.dumps(value, ensure_ascii=False)},')
        if key in PLACEHOLDER_META:
            ph = PLACEHOLDER_META[key]
            meta = {"placeholders": {k: {"type": v} for k, v in ph.items()}}
            insert_lines.append(f'  "@{key}": {json.dumps(meta, ensure_ascii=False)},')

    if not insert_lines:
        return added

    text = text.rstrip()
    if text.endswith("}"):
        text = text[:-1].rstrip() + "\n" + "\n".join(insert_lines) + "\n}\n"
    path.write_text(text, encoding="utf-8")
    return added


def main():
    for locale, filename in LOCALE_FILE.items():
        path = ARB_DIR / filename
        added = append_keys(locale, path, BATCH[locale])
        print(f"{filename}: added {len(added)} keys")


if __name__ == "__main__":
    main()
