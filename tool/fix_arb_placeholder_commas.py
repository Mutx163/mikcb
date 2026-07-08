from pathlib import Path

for path in Path("lib/l10n").glob("app_*.arb"):
    lines = path.read_text(encoding="utf-8").splitlines()
    out = []
    for line in lines:
        if '{ "type": "String" },' in line:
            line = line.replace('{ "type": "String" },', '{ "type": "String" }')
        if line.strip() == '},' and out and out[-1].strip() == '}':
            line = '  }'
        out.append(line)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(path.name)
