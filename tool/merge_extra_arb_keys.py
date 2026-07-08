"""Safely merge extra ARB keys using JSON parse."""
import json
from pathlib import Path

EXTRA_ZH = {
    "appUpdateMirrorPresetGhfast": "默认镜像",
    "appUpdateMirrorPresetGhproxyCn": "备用镜像 1",
    "appUpdateMirrorPresetGhLlkk": "备用镜像 2",
    "appUpdateMirrorPresetGhProxyCom": "备用镜像 3",
    "appUpdateMirrorPresetGhproxyNet": "备用镜像 4",
    "appUpdateMirrorPresetCustom": "自定义",
    "appUpdateMirrorPresetCustomDescription": "填写自定义镜像地址前缀",
    "cloudBackupRetentionTitle": "备份保留策略",
    "cloudBackupMaxCountTitle": "最多保留份数",
    "cloudBackupMaxCountSubtitle": "超过后自动删除最旧的备份",
    "cloudBackupMaxCountOption": "{count} 份",
    "cloudBackupMaxAgeTitle": "最长保留天数",
    "cloudBackupMaxAgeSubtitle": "超过后自动删除过期备份",
    "cloudBackupMaxAgeOption": "{days} 天",
    "statisticsShareText": "来自轻屿课表的学期统计",
    "aboutUpdateAvailableHeadline": "有版本更新",
    "aboutAlreadyLatestHeadline": "已是最新版本",
    "aboutDownloadChannelSectionTitle": "下载渠道",
    "aboutMirrorProbeFailedLabel": "失败",
    "timeSchemeImportSupplementName": "{name}（导入补齐）",
    "profileTimeSchemeName": "{profileName} 时间",
    "currentProfileTimeSchemeName": "当前课表时间",
    "unnamedTimetableProfile": "未命名课表",
}

EXTRA_EN = {
    "appUpdateMirrorPresetGhfast": "Default mirror",
    "appUpdateMirrorPresetGhproxyCn": "Backup mirror 1",
    "appUpdateMirrorPresetGhLlkk": "Backup mirror 2",
    "appUpdateMirrorPresetGhProxyCom": "Backup mirror 3",
    "appUpdateMirrorPresetGhproxyNet": "Backup mirror 4",
    "appUpdateMirrorPresetCustom": "Custom",
    "appUpdateMirrorPresetCustomDescription": "Enter a custom mirror URL prefix",
    "cloudBackupRetentionTitle": "Backup retention",
    "cloudBackupMaxCountTitle": "Maximum backups",
    "cloudBackupMaxCountSubtitle": "Oldest backups are removed when exceeded",
    "cloudBackupMaxCountOption": "{count} backups",
    "cloudBackupMaxAgeTitle": "Maximum age",
    "cloudBackupMaxAgeSubtitle": "Backups older than this are removed",
    "cloudBackupMaxAgeOption": "{days} days",
    "statisticsShareText": "Semester statistics from mikcb",
    "aboutUpdateAvailableHeadline": "Update available",
    "aboutAlreadyLatestHeadline": "Already up to date",
    "aboutDownloadChannelSectionTitle": "Download channel",
    "aboutMirrorProbeFailedLabel": "Failed",
    "timeSchemeImportSupplementName": "{name} (import supplement)",
    "profileTimeSchemeName": "{profileName} schedule",
    "currentProfileTimeSchemeName": "Current timetable schedule",
    "unnamedTimetableProfile": "Unnamed timetable",
}

META = {
    "cloudBackupMaxCountOption": {"count": "int"},
    "cloudBackupMaxAgeOption": {"days": "int"},
    "timeSchemeImportSupplementName": {"name": "String"},
    "profileTimeSchemeName": {"profileName": "String"},
}

FILES = {
    "app_zh.arb": EXTRA_ZH,
    "app_zh_HK.arb": EXTRA_ZH,
    "app_zh_TW.arb": EXTRA_ZH,
    "app_en.arb": EXTRA_EN,
    "app_ja.arb": EXTRA_EN,
    "app_ko.arb": EXTRA_EN,
}

arb_dir = Path(__file__).resolve().parent.parent / "lib" / "l10n"
for filename, extra in FILES.items():
    path = arb_dir / filename
    data = json.loads(path.read_text(encoding="utf-8"))
    added = 0
    for key, value in extra.items():
        if key in data:
            continue
        data[key] = value
        added += 1
        if key in META:
            data[f"@{key}"] = {
                "placeholders": {k: {"type": v} for k, v in META[key].items()}
            }
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{filename}: added {added} keys")
