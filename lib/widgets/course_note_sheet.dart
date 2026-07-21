import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';

/// Opens the dual-type course note editor as a home HyperOS sheet.
///
/// Both whole-course and this-week notes stay on one page. When the keyboard
/// opens, the sheet lifts above the IME and the focused field scrolls into
/// view — no separate editing layout.
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

class _CourseNoteSheetBodyState extends State<CourseNoteSheetBody>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _courseFieldKey = GlobalKey();
  final _sessionFieldKey = GlobalKey();
  final _courseNoteFocusNode = FocusNode();
  final _sessionNoteFocusNode = FocusNode();
  late final TextEditingController _courseNoteController;
  late final TextEditingController _sessionNoteController;
  late bool _hasHomework;
  bool _isSaving = false;
  double _lastKeyboardHeight = 0;

  Course get _liveCourse {
    final provider = context.read<TimetableProvider>();
    for (final item in provider.courses) {
      if (item.id == widget.course.id) {
        return item;
      }
    }
    return widget.course;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final course = widget.course;
    final sessionNote = course.sessionNoteForWeek(widget.week);
    _courseNoteController = TextEditingController(text: course.note ?? '');
    _sessionNoteController = TextEditingController(
      text: sessionNote?.text ?? '',
    );
    _hasHomework = sessionNote?.hasHomework ?? false;
    _courseNoteFocusNode.addListener(_handleFocusChange);
    _sessionNoteFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _courseNoteFocusNode.removeListener(_handleFocusChange);
    _sessionNoteFocusNode.removeListener(_handleFocusChange);
    _courseNoteFocusNode.dispose();
    _sessionNoteFocusNode.dispose();
    _courseNoteController.dispose();
    _sessionNoteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) {
      return;
    }
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    if ((keyboardHeight - _lastKeyboardHeight).abs() < 1) {
      return;
    }
    _lastKeyboardHeight = keyboardHeight;
    if (keyboardHeight > 0) {
      _scrollFocusedFieldIntoView();
    }
  }

  void _handleFocusChange() {
    if (_courseNoteFocusNode.hasFocus || _sessionNoteFocusNode.hasFocus) {
      _scrollFocusedFieldIntoView();
    }
  }

  void _scrollFocusedFieldIntoView() {
    final targetKey = _courseNoteFocusNode.hasFocus
        ? _courseFieldKey
        : (_sessionNoteFocusNode.hasFocus ? _sessionFieldKey : null);
    if (targetKey == null) {
      return;
    }
    // Wait one frame so viewInsets / sheet pad settle with the IME.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetContext = targetKey.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        // Sit the field near the bottom of the visible sheet area (just
        // above the keyboard after outer padForKeyboard lifts the sheet).
        alignment: 0.9,
      );
    });
  }

  Future<void> _save() async {
    if (widget.readOnly || _isSaving) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
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
    // Outer sheet already pads for the keyboard; cap height to remaining space.
    final availableHeight =
        mediaQuery.size.height - keyboardHeight - mediaQuery.padding.top;
    final maxHeight = (availableHeight * 0.9).clamp(
      280.0,
      mediaQuery.size.height * 0.88,
    );
    final muted = typo.xs2.copyWith(color: colors.mutedForeground, height: 1.4);
    final subtitle =
        '${widget.course.name} · ${l10n.weekLabel(widget.week)} · '
        '${l10n.sectionRangeLabel(widget.course.startSection, widget.course.endSection)}';

    return HyperosSheetFrame(
      frosted: true,
      maxHeight: maxHeight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SingleChildScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + mediaQuery.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            _buildSectionLabel(
              context,
              label: l10n.courseNoteWholeCourseLabel,
              hint: l10n.courseNoteWholeCourseHint,
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _courseFieldKey,
              child: HyperosTextField(
                controller: _courseNoteController,
                focusNode: _courseNoteFocusNode,
                hint: l10n.courseNoteWholeCoursePlaceholder,
                enabled: !widget.readOnly,
                maxLines: 4,
                minLines: 2,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(height: 18),
            _buildSectionLabel(
              context,
              label: l10n.courseNoteSessionLabel,
              hint: l10n.courseNoteSessionHint(widget.week),
            ),
            const SizedBox(height: 8),
            HyperosFrostedSurface(
              borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
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
            KeyedSubtree(
              key: _sessionFieldKey,
              child: HyperosTextField(
                controller: _sessionNoteController,
                focusNode: _sessionNoteFocusNode,
                hint: l10n.courseNoteSessionPlaceholder,
                enabled: !widget.readOnly,
                maxLines: 4,
                minLines: 2,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
            ),
            if (widget.readOnly) ...[
              const SizedBox(height: 12),
              Text(l10n.courseNoteReadOnlyNotice, style: muted),
            ],
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
        ),
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
