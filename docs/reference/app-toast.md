# App Toast (HyperOS)

Transient user feedback in mikcb. Implementation delegates to `showHyperosRichSnackBar` via `lib/utils/app_toast.dart`.

## Canonical API

Import: `import '../utils/app_toast.dart';` (adjust relative path).

| Helper | When | Duration |
|--------|------|----------|
| `showAppToast` | Default success/info/warning/error | 4s (override with `duration:`) |
| `showAppLightTip` | Lightweight validation / script hints | 2s |
| `showAppToastWithAction` | Undo, switch mirror, etc. | 8s + action label |
| `showThemeFeedbackToast` | Theme apply/export/import only | delegates to above; pass `onUndo:` for theme revert |

### `showAppToast`

```dart
showAppToast(
  context,
  message: l10n.copiedIssueAddress,
  kind: AppToastKind.success,
);
```

**`AppToastKind` → visual**

| Kind | Default icon |
|------|--------------|
| `info` | `Icons.info_outline_rounded` |
| `success` | `Icons.check_circle_outline_rounded` |
| `warning` | `Icons.warning_amber_rounded` |
| `error` | `Icons.error_outline_rounded` |

Optional: `description`, `icon`, `duration`.

## Contracts

1. **Context** must be under `MaterialApp` with `ScaffoldMessenger` (app root — already wired).
2. **Strings** from `AppLocalizations`; no hard-coded user-facing text in helpers.
3. **Kind selection**: success = completed action; warning = validation; error = failed operation; info = neutral state change.
4. **No duplicate channels**: do not combine toast + raw `SnackBar` for the same event.
5. **Dialogs vs toasts**: confirmations use `showHyperosDialog` / `app_dialogs.dart`; toasts are non-blocking feedback only.

## Forbidden

Do not call raw Material `SnackBar` or legacy `showFToast` / `FToaster` in feature code.

## Reference

- Implementation: `lib/utils/app_toast.dart`
- Low-level API: `showHyperosRichSnackBar` in `lib/ui/hyperos/hyperos_snackbar.dart`
- Theme wrapper: `lib/widgets/theme_manage_sheets.dart`
- UI kit: [hyperos-ui-kit.md](./hyperos-ui-kit.md)
