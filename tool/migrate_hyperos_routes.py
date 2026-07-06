#!/usr/bin/env python3
"""Replace MaterialPageRoute with HyperosPageRoute and add import if missing."""

from __future__ import annotations

from pathlib import Path

IMPORT_LINE = "import 'package:university_timetable/ui/hyperos/hyperos.dart';\n"


def migrate_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "MaterialPageRoute" not in text:
        return False

    new = text.replace("MaterialPageRoute<void>", "HyperosPageRoute<void>")
    new = new.replace("MaterialPageRoute<", "HyperosPageRoute<")
    new = new.replace("MaterialPageRoute(", "HyperosPageRoute(")

    if IMPORT_LINE.strip() not in new and "HyperosPageRoute" in new:
        first_import = new.find("import ")
        if first_import != -1:
            line_end = new.find("\n", first_import)
            new = new[: line_end + 1] + IMPORT_LINE + new[line_end + 1 :]

    if new != text:
        path.write_text(new, encoding="utf-8")
        return True
    return False


def main() -> None:
    root = Path(__file__).resolve().parents[1] / "lib"
    updated = [p for p in root.rglob("*.dart") if migrate_file(p)]
    for p in sorted(updated):
        print(p.relative_to(root.parent))


if __name__ == "__main__":
    main()
