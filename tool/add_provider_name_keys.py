"""Add provider-layer default name keys to all ARB files."""
from pathlib import Path

ENTRIES = {
    "timeSchemeImportSupplementName": {
        "zh": "{name}（导入补齐）",
        "en": "{name} (import supplement)",
        "ja": "{name}（インポート補完）",
        "ko": "{name} (가져오기 보완)",
        "zh_HK": "{name}（匯入補齊）",
        "zh_TW": "{name}（匯入補齊）",
    },
    "profileTimeSchemeName": {
        "zh": "{profileName} 时间",
        "en": "{profileName} schedule",
        "ja": "{profileName} 時間",
        "ko": "{profileName} 시간",
        "zh_HK": "{profileName} 時間",
        "zh_TW": "{profileName} 時間",
    },
    "currentProfileTimeSchemeName": {
        "zh": "当前课表时间",
        "en": "Current timetable schedule",
        "ja": "現在の時間割",
        "ko": "현재 시간표",
        "zh_HK": "目前課表時間",
        "zh_TW": "目前課表時間",
    },
    "unnamedTimetableProfile": {
        "zh": "未命名课表",
        "en": "Unnamed timetable",
        "ja": "無題の時間割",
        "ko": "이름 없는 시간표",
        "zh_HK": "未命名課表",
        "zh_TW": "未命名課表",
    },
    "aboutUpdateAvailableHeadline": {
        "zh": "有版本更新",
        "en": "Update available",
        "ja": "アップデートあり",
        "ko": "업데이트 있음",
        "zh_HK": "有版本更新",
        "zh_TW": "有版本更新",
    },
    "aboutAlreadyLatestHeadline": {
        "zh": "已是最新版本",
        "en": "Already up to date",
        "ja": "最新バージョンです",
        "ko": "최신 버전입니다",
        "zh_HK": "已是最新版本",
        "zh_TW": "已是最新版本",
    },
    "aboutDownloadChannelSectionTitle": {
        "zh": "下载渠道",
        "en": "Download channel",
        "ja": "ダウンロードチャネル",
        "ko": "다운로드 채널",
        "zh_HK": "下載渠道",
        "zh_TW": "下載渠道",
    },
    "aboutMirrorProbeFailedLabel": {
        "zh": "失败",
        "en": "Failed",
        "ja": "失敗",
        "ko": "실패",
        "zh_HK": "失敗",
        "zh_TW": "失敗",
    },
}

PLACEHOLDERS = {
    "timeSchemeImportSupplementName": {
        "name": "String",
    },
    "profileTimeSchemeName": {
        "profileName": "String",
    },
}

LOCALE_FILES = {
    "zh": "app_zh.arb",
    "en": "app_en.arb",
    "ja": "app_ja.arb",
    "ko": "app_ko.arb",
    "zh_HK": "app_zh_HK.arb",
    "zh_TW": "app_zh_TW.arb",
}

arb_dir = Path(__file__).resolve().parent.parent / "lib" / "l10n"

for locale, filename in LOCALE_FILES.items():
    path = arb_dir / filename
    text = path.read_text(encoding="utf-8").rstrip()
    if not text.endswith("}"):
        raise SystemExit(f"unexpected arb end: {path}")
    body = text[:-1].rstrip()
    if not body.endswith(","):
        body += ","
    lines = []
    for key, translations in ENTRIES.items():
        if f'"{key}"' in text:
            continue
        value = translations[locale]
        lines.append(f'  "{key}": "{value}"')
        ph = PLACEHOLDERS.get(key)
        if ph:
            lines.append(f'  "@{key}": {{')
            lines.append('    "placeholders": {')
            for pname, ptype in ph.items():
                lines.append(f'      "{pname}": {{ "type": "{ptype}" }}')
            lines.append("    }")
            lines.append("  }")
    if not lines:
        print(f"skip {filename} (keys exist)")
        continue
    path.write_text(body + "\n" + ",\n".join(lines) + "\n}\n", encoding="utf-8")
    print(f"updated {filename}")
