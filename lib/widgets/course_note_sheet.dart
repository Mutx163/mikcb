import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';

/// Opens the dual-type course note editor as a home HyperOS sheet.
///
/// Both whole-course and this-week notes are shown on the same page.
/// Returns `true` when notes were saved, `false` when cancelled/dismissed.
Future<bool> showCourseNoteSheet(
  BuildContext context, {
  required Course course,
  required int week,
  bool readOnly = false,
}) async {
  final result = await showHomeHyperosSheet<bool>(
    context: context,
    padForKeyboard: true,
    builder: (sheetContext) =>
        CourseNoteSheetBody(course: course, week: week, readOnly: readOnly),
  );
  return result ?? false;
}

enum _NoteFocusTarget { none, course, session }

class CourseNoteSheetBody extends StatefulWidget {
  const CourseNoteSheetBody({
    super.key,
    required this.course,
    required this.week,
    this.readOnly = false,
  });

  final Course course;
  final int week;
  final bool readOnly;

  @override
  State<CourseNoteSheetBody> createState() => _CourseNoteSheetBodyState();
}

class _CourseNoteSheetBodyState extends State<CourseNoteSheetBody> {
  final _courseNoteFocusNode = FocusNode();
  final _sessionNoteFocusNode = FocusNode();
  late final TextEditingController _courseNoteController;
  late final TextEditingController _sessionNoteController;
  late bool _hasHomework;
  bool _isSaving = false;
  _NoteFocusTarget _focusTarget = _NoteFocusTarget.none;

  Course get _liveCourse {
    final provider = context.read<TimetableProvider>();
    for (final item in provider.courses) {
      if (item.id == widget.course.id) {
        return item;
      }
    }
    return widget.course;
  }

  bool get _isEditingField => _focusTarget != _NoteFocusTarget.none;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    final sessionNote = course.sessionNoteForWeek(widget.week);
    _courseNoteController = TextEditingController(text: course.note ?? '');
    _sessionNoteController = TextEditingController(
      text: sessionNote?.text ?? '',
    );
    _hasHomework = sessionNote?.hasHomework ?? false;
    _courseNoteFocusNode.addListener(_syncFocusTarget);
    _sessionNoteFocusNode.addListener(_syncFocusTarget);
  }

  @override
  void dispose() {
    _courseNoteFocusNode.removeListener(_syncFocusTarget);
    _sessionNoteFocusNode.removeListener(_syncFocusTarget);
    _courseNoteFocusNode.dispose();
    _sessionNoteFocusNode.dispose();
    _courseNoteController.dispose();
    _sessionNoteController.dispose();
    super.dispose();
  }

  void _syncFocusTarget() {
    final next = _courseNoteFocusNode.hasFocus
        ? _NoteFocusTarget.course
        : (_sessionNoteFocusNode.hasFocus
              ? _NoteFocusTarget.session
              : _NoteFocusTarget.none);
    if (next == _focusTarget || !mounted) {
      return;
    }
    setState(() => _focusTarget = next);
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _save() async {
    if (widget.readOnly || _isSaving) {
      return;
    }
    _dismissKeyboard();
    setState(() => _isSaving = true);
    try {
      final provider = context.read<TimetableProvider>();
      final current = _liveCourse;
      final courseNoteText = _courseNoteController.text.trim();
      final sessionNoteText = _sessionNoteController.text.trim();
      final sessionNote = CourseSessionNote(
        text: sessionNoteText,
        hasHomework: _hasHomework,
      ).normalizedOrNull;
      final updated = current.copyWith(
        note: courseNoteText.isEmpty ? null : courseNoteText,
        sessionNotes: current.withSessionNote(widget.week, sessionNote),
      );
      await provider.updateCourse(updated);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final availableHeight =
        mediaQuery.size.height - keyboardHeight - mediaQuery.padding.top;
    // While editing, keep the sheet compact so only the active field sits
    // just above the IME — not the whole form + action row.
    final maxHeight = _isEditingField
        ? (availableHeight * 0.42).clamp(200.0, 320.0)
        : (availableHeight * 0.88).clamp(280.0, mediaQuery.size.height * 0.88);
    final muted = typo.xs2.copyWith(color: colors.mutedForeground, height: 1.4);
    final subtitle =
        '${widget.course.name} · ${l10n.weekLabel(widget.week)} · '
        '${l10n.sectionRangeLabel(widget.course.startSection, widget.course.endSection)}';

    final showCourseSection =
        !_isEditingField || _focusTarget == _NoteFocusTarget.course;
    final showSessionSection =
        !_isEditingField || _focusTarget == _NoteFocusTarget.session;

    return HyperosSheetFrame(
      frosted: true,
      maxHeight: maxHeight,
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        _isEditingField ? 12 : 12 + mediaQuery.padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact header while typing; full header in overview mode.
          if (_isEditingField)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _focusTarget == _NoteFocusTarget.course
                        ? l10n.courseNoteWholeCourseLabel
                        : l10n.courseNoteSessionLabel,
                    style: typo.sm.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _dismissKeyboard,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.courseNoteDoneEditingAction,
                    style: typo.sm.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.sticky_note_2_outlined,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.courseNoteSheetTitle,
                        style: typo.sm.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: muted,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          if (showCourseSection) ...[
            if (!_isEditingField) ...[
              _buildSectionLabel(
                context,
                label: l10n.courseNoteWholeCourseLabel,
                hint: l10n.courseNoteWholeCourseHint,
              ),
              const SizedBox(height: 8),
            ],
            HyperosTextField(
              controller: _courseNoteController,
              focusNode: _courseNoteFocusNode,
              hint: l10n.courseNoteWholeCoursePlaceholder,
              enabled: !widget.readOnly,
              maxLines: _isEditingField ? 6 : 4,
              minLines: _isEditingField ? 3 : 2,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            if (!_isEditingField) const SizedBox(height: 18),
          ],
          if (showSessionSection) ...[
            if (!_isEditingField) ...[
              _buildSectionLabel(
                context,
                label: l10n.courseNoteSessionLabel,
                hint: l10n.courseNoteSessionHint(widget.week),
              ),
              const SizedBox(height: 8),
              HyperosFrostedSurface(
                borderRadius: BorderRadius.circular(
                  HyperosTokens.controlRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.courseNoteHasHomeworkTitle,
                              style: typo.sm.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.courseNoteHasHomeworkSubtitle,
                              style: muted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      HyperosSwitch(
                        value: _hasHomework,
                        onChanged: widget.readOnly
                            ? null
                            : (value) => setState(() => _hasHomework = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (!widget.readOnly) ...[
              // Keep homework toggle reachable while editing the session field.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.courseNoteHasHomeworkTitle,
                        style: typo.sm.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    HyperosSwitch(
                      value: _hasHomework,
                      onChanged: (value) =>
                          setState(() => _hasHomework = value),
                    ),
                  ],
                ),
              ),
            ],
            HyperosTextField(
              controller: _sessionNoteController,
              focusNode: _sessionNoteFocusNode,
              hint: l10n.courseNoteSessionPlaceholder,
              enabled: !widget.readOnly,
              maxLines: _isEditingField ? 6 : 4,
              minLines: _isEditingField ? 3 : 2,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ],
          if (widget.readOnly && !_isEditingField) ...[
            const SizedBox(height: 12),
            Text(l10n.courseNoteReadOnlyNotice, style: muted),
          ],
          // Actions only in overview mode — never lifted with the IME field.
          if (!_isEditingField) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: HyperosButton(
                    label: l10n.cancelAction,
                    variant: HyperosButtonVariant.secondary,
                    expand: true,
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                if (!widget.readOnly) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: HyperosButton(
                      label: l10n.courseNoteSaveAction,
                      expand: true,
                      onPressed: _isSaving ? null : _save,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(
    BuildContext context, {
    required String label,
    required String hint,
  }) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;
    final muted = typo.xs2.copyWith(color: colors.mutedForeground, height: 1.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: typo.sm.copyWith(fontWeight: FontWeight.w600, height: 1.2),
        ),
        const SizedBox(height: 3),
        Text(hint, style: muted, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
