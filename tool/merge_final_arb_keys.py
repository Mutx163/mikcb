import json
from pathlib import Path

extra_zh = {
    "cloudBackupManualProtectedTitle": "手动备份永不过期",
    "cloudBackupManualProtectedSubtitle": "开启后，手动创建的备份不会被自动清理",
    "courseImportPortalUrlMissingBody": "“{schoolName} / {adapterName}” 没有默认登录地址，请先输入学校教务系统网址。",
    "guidePermissionsProgressLabel": "已就绪 {ready}/{total}",
}
extra_en = {
    "cloudBackupManualProtectedTitle": "Protect manual backups",
    "cloudBackupManualProtectedSubtitle": "Manual backups are never auto-deleted when enabled",
    "courseImportPortalUrlMissingBody": '"{schoolName} / {adapterName}" has no default login URL. Enter the school portal URL first.',
    "guidePermissionsProgressLabel": "Ready {ready}/{total}",
}
meta = {
    "courseImportPortalUrlMissingBody": {"schoolName": "String", "adapterName": "String"},
    "guidePermissionsProgressLabel": {"ready": "int", "total": "int"},
}
files = {
    "app_zh.arb": extra_zh,
    "app_zh_HK.arb": extra_zh,
    "app_zh_TW.arb": extra_zh,
    "app_en.arb": extra_en,
    "app_ja.arb": extra_en,
    "app_ko.arb": extra_en,
}
for fn, ex in files.items():
    path = Path("lib/l10n") / fn
    data = json.loads(path.read_text(encoding="utf-8"))
    for key, value in ex.items():
        if key in data:
            continue
        data[key] = value
        if key in meta:
            data[f"@{key}"] = {
                "placeholders": {n: {"type": t} for n, t in meta[key].items()}
            }
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(fn)
