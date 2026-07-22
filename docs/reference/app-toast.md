# App Toast (HyperOS)

Transient user feedback in mikcb. Implementation: Overlay-hosted **system-style frosted capsule** via `showHyperosRichSnackBar` / `lib/utils/app_toast.dart`.

## Visual (match system HyperOS status toast)

| Trait | Value |
|-------|--------|
| Shape | Content-width rounded rect |
| Insets | Horizontal **2 字** each side; vertical **1 字** above + **1 字** below (glyph = 14dp) |
| Height | ≈ 3 字高 single-line shell (~42dp), not text-only tight pad |
| Material | Live `BackdropFilter` blur (σ≈28) + milky white tint (α≈0.62) |
| Text | Near-black (`#000`), 14 / w400 (not theme primary blue) |
| Position | Bottom-center, ~88dp above safe-area bottom (mid-lower, not glued to bar) |
| Motion | Fade + light scale in/out (not Material slide) |
| Dismiss | **No swipe**; auto-hide only (or action) |
| Channel | Root `Overlay` (not `SnackBar`) |

Blur respects global frosted master switch (`FrostedAppearance.blurEnabled`) and platform support.

## Canonical API

Import: `import '../utils/app_toast.dart';` (adjust relative path).

| Helper | When | Duration |
|--------|------|----------|
| `showAppToast` | Default success/info/warning/error | 2s (override with `duration:`) |
| `showAppLightTip` | Lightweight validation / script hints | 2s |
| `showAppToastWithAction` | Undo, switch mirror, etc. | 2s + action label |
| `showThemeFeedbackToast` | Theme apply/export/import only | delegates to above; pass `onUndo:` for theme revert |
| `hideHyperosToast` | Force dismiss | optional animated |

### `showAppToast`

```dart
showAppToast(
  context,
  message: l10n.copiedIssueAddress,
  kind: AppToastKind.success,
);
```

Default is **text-only** (matches system toast height). Pass `icon:` or `showKindIcon: true` only when a leading glyph is needed.

**`AppToastKind`** (for optional icons / API semantics)

| Kind | Optional icon (`showKindIcon: true`) |
|------|--------------------------------------|
| `info` | `Icons.info_outline_rounded` |
| `success` | `Icons.check_circle_outline_rounded` |
| `warning` | `Icons.warning_amber_rounded` |
| `error` | `Icons.error_outline_rounded` |

Optional: `description`, `icon`, `duration`.

## Contracts

1. **Context** must be under a widget tree with an `Overlay` (normal `MaterialApp` / navigator).
2. **Strings** from `AppLocalizations`; no hard-coded user-facing text in helpers.
3. **Kind selection**: success = completed action; warning = validation; error = failed operation; info = neutral state change.
4. **No duplicate channels**: do not combine toast + raw `SnackBar` for the same event.
5. **Dialogs vs toasts**: confirmations use `showHyperosDialog` / `app_dialogs.dart`; toasts are non-blocking feedback only.
6. **No swipe dismiss**: toast stays put until duration elapses (or action / `hideHyperosToast`).

## Forbidden

Do not call raw Material `SnackBar` or legacy `showFToast` / `FToaster` in feature code.

## Reference

- Implementation: `lib/utils/app_toast.dart`, `lib/ui/hyperos/hyperos_snackbar.dart`
- Frosted stack: `FrostedHeaderBackground` / `HyperosBlurredHeader`
- Theme wrapper: `lib/widgets/theme_manage_sheets.dart`
- UI kit: [hyperos-ui-kit.md](./hyperos-ui-kit.md)
