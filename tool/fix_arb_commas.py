"""Fix missing commas in appUpdateMirrorPreset ARB block."""
from pathlib import Path

arb_dir = Path(__file__).resolve().parent.parent / "lib" / "l10n"
keys = [
    "appUpdateMirrorPresetGhfast",
    "appUpdateMirrorPresetGhproxyCn",
    "appUpdateMirrorPresetGhLlkk",
    "appUpdateMirrorPresetGhProxyCom",
    "appUpdateMirrorPresetGhproxyNet",
    "appUpdateMirrorPresetCustom",
    "appUpdateMirrorPresetCustomDescription",
]

for path in sorted(arb_dir.glob("app_*.arb")):
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('"appUpdateMirrorPreset') and not stripped.endswith(","):
            next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""
            if next_line.startswith('"appUpdateMirrorPreset'):
                line = line.rstrip() + ","
        out.append(line)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"fixed {path.name}")
