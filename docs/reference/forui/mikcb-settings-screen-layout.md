# Settings Screen Layout (Forui)

Executable UI contracts for settings-style screens in mikcb.

## Problem: nested “box in box”

Forui settings pages already render grouped content as rounded containers. Wrapping an `FTileGroup` inside `SettingsSectionCard` stacks two card surfaces (`FCard.raw` + tile group chrome) and looks visually heavy.

**Forbidden**

```dart
SettingsSectionCard(
  title: 'Download channel',
  subtitle: '…',
  child: FTileGroup(
    children: [FTile(...), FTile(...)],
  ),
)
```

## Canonical pattern

Follow **Super Island / live settings** screens (`lib/screens/live_settings_subpages.dart`).

| Content type | Container | Notes |
|--------------|-----------|-------|
| List rows, switches, single-choice tiles | `FTileGroup` only | Use `label` / `description` for section title and helper text |
| Buttons, `FSelect`, sliders, color pickers, custom controls | `SettingsSectionCard` only | Do **not** put an `FTileGroup` inside the card |
| Navigation entry to a sub-screen | `FTileGroup` + `SettingsEntryTile` or plain `FTile` | Same as main settings list |

### List / choice sections

```dart
FTileGroup(
  label: Text(l10n.someSectionTitle),
  description: Text(l10n.someSectionSubtitle),
  physics: const NeverScrollableScrollPhysics(),
  children: [
    FTile(
      title: Text('Option A'),
      suffix: isSelectedA
          ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary, size: 20)
          : null,
      onPress: () => selectA(),
    ),
    SettingSwitchTile(
      title: Text(l10n.someSwitchTitle),
      subtitle: Text(l10n.someSwitchSubtitle),
      value: enabled,
      onChanged: onChanged,
    ),
  ],
)
```

**Contracts**

- One visual group per section — pick **`FTileGroup` *or* `SettingsSectionCard`**, not both.
- Selected list item: `Icons.check_rounded` + `colorScheme.primary` (see theme preset list in `timetable_settings_screen.dart`).
- Avoid custom segmented controls with `surfaceContainerLow` / `primaryContainer` fills unless there is no Forui equivalent.
- `ListView` page padding: `const EdgeInsets.all(16)` on settings sub-pages.

### Action / control sections

```dart
SettingsSectionCard(
  title: l10n.diagnosticsTitle,
  subtitle: l10n.diagnosticsSubtitle,
  plainTitle: true,
  child: Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      FButton(
        variant: FButtonVariant.secondary,
        onPress: onExport,
        prefix: const Icon(Icons.ios_share_rounded, size: 18),
        child: Text(l10n.exportAction),
      ),
    ],
  ),
)
```

`SettingsSectionCard` may omit `title` when the child control is self-explanatory (e.g. a lone `FSelect`), but still must **not** wrap an `FTileGroup`.

## Reference implementations

| Screen | File | What to copy |
|--------|------|--------------|
| Super Island reminder timing | `lib/screens/live_settings_subpages.dart` → `LiveReminderTimingScreen` | `FTileGroup` sections + `SettingsSectionCard` for thresholds |
| Super Island display content | same file → `LiveDisplaySettingsScreen` | Multiple `FTileGroup` blocks; cards only for selects / image pickers |
| App update advanced options | `lib/screens/about_screen.dart` → `_AdvancedOptionsScreen` | Download channel/method/mirror as `FTileGroup`; diagnostics as `SettingsSectionCard` + `Wrap` |
| Shared widgets | `lib/widgets/settings_section_widgets.dart` | `SettingsSectionCard`, `SettingSwitchTile`, `SettingsEntryTile` |

## Section spacing

- `const SizedBox(height: 12)` between top-level sections in a settings `ListView`.
- Do not add extra `Container` backgrounds between sections; rely on Forui group/card styling.

## Common mistakes

| Mistake | Why it fails | Fix |
|---------|--------------|-----|
| `SettingsSectionCard` → `FTileGroup` | Double border / padding | Move title to `FTileGroup.label` / `description` |
| Segmented `Row` in `surfaceContainerLow` | Off-brand vs Forui tiles | Replace with `FTileGroup` + check suffix |
| Duplicate section title on both group label and every tile | Redundant copy | Group label for section; tiles keep item-specific titles only |
| Hard-coded bold section titles | Inconsistent with `plainTitle: true` convention | Use `SettingsSectionCard(plainTitle: true)` or `FTileGroup` label typography |

## Related

- Localization: section strings belong in `lib/l10n/app_zh.arb` (source) — see `docs/WEB_AND_L10N_WORKFLOW.md`.
- `SettingsSectionCard.plainTitle`: section headers use `FontWeight.w400`, not `w600`.
