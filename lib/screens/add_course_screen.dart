import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../utils/course_color_palette.dart';
import '../utils/hex_color.dart';
import '../widgets/about_info_sheet.dart';
import '../widgets/course_color_picker_sheet.dart';
import '../widgets/course_field_picker_sheet.dart';
import '../widgets/course_template_picker_sheet.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/time_scheme_picker_sheet.dart';

enum _WeekSelectionMode { range, custom }

class AddCourseScreen extends StatefulWidget {
  final Course? course;
  final CourseGroup? courseGroup;
  final Course? initialCourse;
  final int? initialDayOfWeek;
  final int? initialStartSection;
  final int? initialWeek;

  const AddCourseScreen({
    super.key,
    this.course,
    this.courseGroup,
    this.initialCourse,
    this.initialDayOfWeek,
    this.initialStartSection,
    this.initialWeek,
  });

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _ScheduleEntryData {
  String id;
  int dayOfWeek;
  int startSection;
  int endSection;
  String teacher;
  String location;
  int startWeek;
  int endWeek;
  bool isOddWeek;
  bool isEvenWeek;
  _WeekSelectionMode weekSelectionMode;
  Set<int> selectedCustomWeeks;
  List<int>? suspendedWeeks;
  String? note;
  String? timeSchemeIdOverride;

  _ScheduleEntryData({
    required this.id,
    this.dayOfWeek = 1,
    this.startSection = 1,
    this.endSection = 2,
    this.teacher = '',
    this.location = '',
    this.startWeek = 1,
    this.endWeek = 16,
    this.isOddWeek = false,
    this.isEvenWeek = false,
    this.weekSelectionMode = _WeekSelectionMode.range,
    Set<int>? selectedCustomWeeks,
    this.suspendedWeeks,
    this.note,
    this.timeSchemeIdOverride,
  }) : selectedCustomWeeks = selectedCustomWeeks ?? <int>{};

  static _ScheduleEntryData fromCourse(Course course) {
    final customWeeks = course.normalizedCustomWeeks;
    return _ScheduleEntryData(
      id: course.id,
      dayOfWeek: course.dayOfWeek,
      startSection: course.startSection,
      endSection: course.endSection,
      teacher: course.teacher,
      location: course.location,
      startWeek: course.startWeek,
      endWeek: course.endWeek,
      isOddWeek: course.isOddWeek,
      isEvenWeek: course.isEvenWeek,
      weekSelectionMode: customWeeks != null
          ? _WeekSelectionMode.custom
          : _WeekSelectionMode.range,
      selectedCustomWeeks: customWeeks?.toSet() ?? <int>{},
      suspendedWeeks: course.normalizedSuspendedWeeks,
      note: course.note,
      timeSchemeIdOverride: course.timeSchemeIdOverride,
    );
  }

  Course toCourse({
    required String name,
    String? shortName,
    required String color,
    required CourseNature courseNature,
    String? description,
    required String startTime,
    required String endTime,
  }) {
    List<int>? customWeeks;
    if (weekSelectionMode == _WeekSelectionMode.custom &&
        selectedCustomWeeks.isNotEmpty) {
      customWeeks = selectedCustomWeeks.toList()..sort();
    }
    return Course(
      id: id,
      name: name,
      shortName: shortName,
      teacher: teacher,
      location: location,
      dayOfWeek: dayOfWeek,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
      color: color,
      startWeek: customWeeks == null ? startWeek : customWeeks.first,
      endWeek: customWeeks == null ? endWeek : customWeeks.last,
      isOddWeek: customWeeks == null ? isOddWeek : false,
      isEvenWeek: customWeeks == null ? isEvenWeek : false,
      customWeeks: customWeeks,
      suspendedWeeks: suspendedWeeks,
      courseNature: courseNature,
      description: description,
      note: note,
      timeSchemeIdOverride: timeSchemeIdOverride,
    );
  }
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  static const _reuseCourseActionWidth = 108.0;
  static const _shortNameActionWidth = 76.0;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _teacherController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  CourseNature _courseNature = CourseNature.required;
  String _selectedColor = '#2196F3';
  List<_ScheduleEntryData> _scheduleEntries = [];
  final List<TextEditingController> _entryTeacherControllers = [];
  final List<TextEditingController> _entryLocationControllers = [];

  List<String> _weekdayLabels(AppLocalizations l10n) => [
    l10n.weekdayMon,
    l10n.weekdayTue,
    l10n.weekdayWed,
    l10n.weekdayThu,
    l10n.weekdayFri,
    l10n.weekdaySat,
    l10n.weekdaySun,
  ];

  final List<String> _colors = kPresetCourseColorHexes;

  Color _parseColor(String colorHex) {
    return parseHexColorOrFallback(colorHex, fallback: const Color(0xFF2196F3));
  }

  @override
  void initState() {
    super.initState();
    {
      if (widget.courseGroup != null) {
        // Editing existing group: load shared fields from the first course.
        final courses = widget.courseGroup!.courses;
        // Put the tapped course first so it's immediately visible.
        final ordered = widget.initialCourse != null
            ? [
                widget.initialCourse!,
                ...courses.where((c) => c.id != widget.initialCourse!.id),
              ]
            : courses;
        final first = ordered.first;
        _nameController.text = first.name;
        _shortNameController.text = first.shortName ?? '';
        _descriptionController.text = first.description ?? first.note ?? '';
        _courseNature = first.courseNature;
        _selectedColor = first.color;
        // Build per-schedule entries from all courses.
        _scheduleEntries = ordered
            .map((c) => _ScheduleEntryData.fromCourse(c))
            .toList();
      } else if (widget.course != null) {
        // Editing a single existing course in group mode: wrap as one entry.
        _loadCourseData(widget.course!);
        _scheduleEntries = [_ScheduleEntryData.fromCourse(widget.course!)];
      } else {
        // Adding new course: start with one empty schedule entry.
        _scheduleEntries = [
          _ScheduleEntryData(
            id: const Uuid().v4(),
            dayOfWeek: widget.initialDayOfWeek ?? 1,
            startSection: widget.initialStartSection ?? 1,
            endSection: (widget.initialStartSection ?? 1) + 1,
            startWeek: 1,
            endWeek: 16, // default; will be clamped in build
            teacher: '',
            location: '',
          ),
        ];
      }
      for (final entry in _scheduleEntries) {
        _entryTeacherControllers.add(
          TextEditingController(text: entry.teacher),
        );
        _entryLocationControllers.add(
          TextEditingController(text: entry.location),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    for (final c in _entryTeacherControllers) {
      c.dispose();
    }
    for (final c in _entryLocationControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final settings = provider.settings;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(_resolveTitle()),
      suffixes: [
        if (widget.courseGroup != null)
          FHeaderAction(
            icon: const Icon(Icons.delete_outline_rounded),
            semanticsLabel: l10n.deleteCourseTitle,
            onPress: _confirmDeleteGroup,
          )
        else if (widget.course != null)
          FHeaderAction(
            icon: const Icon(Icons.delete_outline_rounded),
            semanticsLabel: l10n.deleteCourseTitle,
            onPress: _confirmDeleteCourse,
          ),
        FHeaderAction(
          icon: const Icon(Icons.check_rounded),
          semanticsLabel: l10n.saveAction,
          onPress: () => _saveCourse(provider, settings),
        ),
      ],
      child: Form(
        key: _formKey,
        child: _buildGroupEditingBody(provider, settings),
      ),
    );
  }

  Future<void> _confirmDeleteCourse() async {
    final course = widget.course;
    if (course == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteCourseTitle,
      message: l10n.confirmDeleteCourseMessage(course.name),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await context.read<TimetableProvider>().deleteCourse(course.id);
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.courseDeleted,
      kind: AppToastKind.success,
    );
    Navigator.pop(context);
  }

  void _loadCourseData(Course course) {
    _nameController.text = course.name;
    _shortNameController.text = course.shortName ?? '';
    _teacherController.text = course.teacher;
    _locationController.text = course.location;
    _descriptionController.text = course.description ?? course.note ?? '';
    _courseNature = course.courseNature;
    _selectedColor = course.color;
  }

  String _resolveTitle() {
    final l10n = AppLocalizations.of(context)!;
    return widget.courseGroup != null || widget.course != null
        ? l10n.editCourseTitle
        : l10n.addCourseTitle;
  }

  // ---------------------------------------------------------------------------
  // Teacher / Location picker — see [showCourseFieldPickerSheet]
  // ---------------------------------------------------------------------------

  /// Shows a time scheme picker bottom sheet.
  ///
  /// [currentValue] is the currently selected time scheme override ID
  /// (null means "follow profile").
  /// [onSelected] is called when the user picks a scheme (null = follow profile).
  // ---------------------------------------------------------------------------
  // Group editing UI
  // ---------------------------------------------------------------------------

  List<Widget> _withSpacing(List<Widget> children, {double spacing = 16}) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        spaced.add(SizedBox(height: spacing));
      }
      spaced.add(children[index]);
    }
    return spaced;
  }

  Widget _buildPickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onPress,
    bool isPlaceholder = false,
  }) {
    return HyperosListTile(
      icon: icon,
      title: label,
      details: isPlaceholder ? null : value,
      onTap: onPress,
    );
  }

  Future<void> _pickFromSelectSheet({
    required String title,
    required Map<String, int> items,
    required int currentValue,
    required ValueChanged<int> onSelected,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showHyperosSelectSheet<int>(
      context: context,
      title: title,
      items: items,
      currentValue: currentValue,
      cancelLabel: l10n.cancelAction,
    );
    if (!mounted || selected == null || selected == currentValue) {
      return;
    }
    onSelected(selected);
  }

  Widget _buildGroupEditingBody(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosListView(
      children: [
        _buildGroupSharedInfoSection(provider, l10n),
        const HyperosSectionGap(),
        _buildScheduleEntriesSection(provider, settings, l10n),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGroupSharedInfoSection(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;
    return HyperosControlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.sharedInfoTitle,
                    style: typo.sm.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: l10n.sharedInfoHint,
                  onPressed: () => _showSharedInfoHintSheet(l10n),
                  icon: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          ..._withSpacing([
            _buildCourseNameField(provider, l10n),
            _buildShortNameField(l10n),
            HyperosSelectTile<CourseNature>(
              label: l10n.courseNatureLabel,
              items: {
                for (final item in CourseNature.values)
                  courseNatureLabel(l10n, item): item,
              },
              value: _courseNature,
              onChanged: (value) => setState(() => _courseNature = value),
            ),
            HyperosTextField(
              controller: _descriptionController,
              label: l10n.courseDescriptionOptional,
              minLines: 2,
              maxLines: 4,
            ),
            Text(
              l10n.courseColorTitle,
              style: typo.xs2.copyWith(color: colors.mutedForeground),
            ),
            _buildCompactColorPalette(l10n),
          ], spacing: 8),
        ],
      ),
    );
  }

  void _showSharedInfoHintSheet(AppLocalizations l10n) {
    showHyperosSheet<void>(
      context: context,
      builder: (_) => AboutInfoSheetBody(
        title: l10n.sharedInfoTitle,
        items: [
          l10n.sharedInfoSheetItemCourseName,
          l10n.sharedInfoSheetItemShortName,
          l10n.sharedInfoSheetItemSharedSync,
        ],
      ),
    );
  }

  Widget _buildCompactColorPalette(AppLocalizations l10n) {
    const swatchSize = 32.0;
    const swatchSpacing = 8.0;
    final theme = context.theme;
    final selectionBorder = theme.colors.foreground;
    final isCustomSelected = !_colors.contains(_selectedColor);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final color in _colors) ...[
            _buildColorSwatch(
              colorHex: color,
              size: swatchSize,
              isSelected: _selectedColor == color,
              selectionBorder: selectionBorder,
              onTap: () => setState(() => _selectedColor = color),
            ),
            const SizedBox(width: swatchSpacing),
          ],
          _buildColorSwatch(
            colorHex: isCustomSelected ? _selectedColor : null,
            size: swatchSize,
            isSelected: isCustomSelected,
            selectionBorder: selectionBorder,
            onTap: _showCustomColorPicker,
            icon: isCustomSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Icon(
                    Icons.palette_outlined,
                    size: 16,
                    color: theme.colors.mutedForeground,
                  ),
            tooltip: l10n.customPaletteAction,
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch({
    required double size,
    required bool isSelected,
    required Color selectionBorder,
    required VoidCallback onTap,
    String? colorHex,
    Widget? icon,
    String? tooltip,
  }) {
    final theme = context.theme;
    final swatch = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorHex == null
              ? theme.colors.secondary
              : _parseColor(colorHex),
          borderRadius: BorderRadius.circular(
            // Color chips are short squares — keep radius << size/2 so corners
            // stay distinct (Miuix icon-badge proportion, not settings card 24).
            size * HyperosTokens.iconBadgeRadius / HyperosTokens.iconBadgeSize,
          ),
          border: Border.all(
            color: isSelected ? selectionBorder : theme.colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: icon == null && isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Center(child: icon),
      ),
    );
    if (tooltip == null) {
      return swatch;
    }
    return Tooltip(message: tooltip, child: swatch);
  }

  Map<String, int> _sectionSelectItems(
    Iterable<int> sectionNumbers,
    AppLocalizations l10n,
  ) {
    return {
      for (final section in sectionNumbers)
        l10n.scheduleSectionNumberLabel(section): section,
    };
  }

  void _autofillShortNameFromCourseName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() {
      _shortNameController.text = name.characters.take(2).string;
    });
  }

  Widget _buildCourseNameField(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;
    final showReuseAction = widget.course == null;

    return FormField<String>(
      validator: (value) {
        final name = (value ?? _nameController.text).trim();
        if (name.isEmpty) {
          return l10n.pleaseEnterCourseName;
        }
        return null;
      },
      builder: (field) {
        final helperText = field.hasError
            ? field.errorText
            : l10n.courseNameHelper;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.courseNameLabel,
              style: typo.sm.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: HyperosTextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    onChanged: field.didChange,
                  ),
                ),
                if (showReuseAction) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: _reuseCourseActionWidth,
                    child: HyperosButton(
                      label: l10n.reuseExistingCourseLabel,
                      variant: HyperosButtonVariant.secondary,
                      dense: true,
                      expand: true,
                      fitLabel: true,
                      onPressed: () => _showCourseTemplateSheet(provider),
                    ),
                  ),
                ],
              ],
            ),
            if (helperText != null) ...[
              const SizedBox(height: 6),
              Text(
                helperText,
                style: typo.xs2.copyWith(
                  color: colors.mutedForeground,
                  height: 1.35,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildShortNameField(AppLocalizations l10n) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.courseShortNameOptional,
          style: typo.sm.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: HyperosTextField(
                controller: _shortNameController,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: _shortNameActionWidth,
              child: HyperosButton(
                label: l10n.courseShortNameAutoFillAction,
                variant: HyperosButtonVariant.secondary,
                dense: true,
                expand: true,
                fitLabel: true,
                onPressed: _autofillShortNameFromCourseName,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.courseShortNameHelper,
          style: typo.xs2.copyWith(color: colors.mutedForeground, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildScheduleConflictLinks(int index, AppLocalizations l10n) {
    final entry = _scheduleEntries[index];
    final provider = context.read<TimetableProvider>();
    final partners = provider.courseConflictMap[entry.id] ?? const <Course>[];
    if (partners.isEmpty) {
      return const SizedBox.shrink();
    }

    // HyperOS preference-row style (not a custom alert banner):
    // title + optional tag + detail + chevron; whole row is the action.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (
          var partnerIndex = 0;
          partnerIndex < partners.length;
          partnerIndex++
        )
          Padding(
            padding: EdgeInsets.only(top: partnerIndex == 0 ? 4 : 8),
            child: _ScheduleConflictPartnerRow(
              partner: partners[partnerIndex],
              onOpen: () => _openPartnerSchedule(partners[partnerIndex]),
            ),
          ),
      ],
    );
  }

  void _openPartnerSchedule(Course partner) {
    CourseGroup? group;
    for (final candidate in context.read<TimetableProvider>().courseGroups) {
      if (candidate.courses.any((course) => course.id == partner.id)) {
        group = candidate;
        break;
      }
    }
    if (group == null || !mounted) {
      return;
    }
    Navigator.of(context).push(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/course/edit-partner'),
        builder: (_) =>
            AddCourseScreen(courseGroup: group, initialCourse: partner),
      ),
    );
  }

  Widget _buildScheduleEntriesSection(
    TimetableProvider provider,
    TimetableSettings settings,
    AppLocalizations l10n,
  ) {
    final hasMultipleEntries = _scheduleEntries.length > 1;
    return HyperosControlCard(
      title: hasMultipleEntries
          ? l10n.scheduleEntryTitle(1).replaceFirst(RegExp(r'\s?1$'), '')
          : l10n.scheduleEntrySingleTitle,
      subtitle: l10n.scheduleEntryCardSubtitle,
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _scheduleEntries.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _buildScheduleEntryFields(provider, settings, i, l10n),
            ],
            if (_scheduleEntries.isNotEmpty) const SizedBox(height: 8),
            _buildAddScheduleEntryButton(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleEntryFields(
    TimetableProvider provider,
    TimetableSettings settings,
    int index,
    AppLocalizations l10n,
  ) {
    final entry = _scheduleEntries[index];
    final weekDays = _weekdayLabels(l10n);
    final sectionNumbers = List.generate(settings.sectionCount, (i) => i + 1);
    final availableWeeks = settings.availableWeeks;
    final teacherText = _entryTeacherControllers[index].text;
    final locationText = _entryLocationControllers[index].text;
    final hasMultipleEntries = _scheduleEntries.length > 1;
    final entrySelectedWeeks =
        entry.weekSelectionMode == _WeekSelectionMode.range
        ? _buildEntryWeeksFromRange(entry)
        : (entry.selectedCustomWeeks.toList()..sort());
    final entryWeekSummary = _selectedWeeksSummaryText(
      entrySelectedWeeks,
      availableWeeks,
      entry.startWeek,
      entry.endWeek,
      entry.isOddWeek,
      entry.isEvenWeek,
      entry.weekSelectionMode,
      l10n,
    );

    final entryFields = _withSpacing([
      _buildScheduleTimeRow(
        weekDays: weekDays,
        sectionNumbers: sectionNumbers,
        entry: entry,
        l10n: l10n,
      ),
      _buildCompactWeekSummaryRow(
        label: l10n.scheduleEntryWeeksSectionTitle,
        summary: entryWeekSummary,
        onTap: () => _showEntryWeekPickerDialog(entry, availableWeeks, l10n),
      ),
      _buildResponsiveFieldPair(
        spacing: 8,
        leading: _buildCompactPickerField(
          label: l10n.teacherLabel,
          value: teacherText.isEmpty ? l10n.manualInputLabel : teacherText,
          isPlaceholder: teacherText.isEmpty,
          onPress: () => showCourseFieldPickerSheet(
            context,
            title: l10n.selectTeacherTitle,
            suggestions: provider.uniqueTeachers,
            controller: _entryTeacherControllers[index],
            onConfirmed: () {
              setState(() {
                entry.teacher = _entryTeacherControllers[index].text;
              });
            },
          ),
        ),
        trailing: _buildCompactPickerField(
          label: l10n.locationLabel,
          value: locationText.isEmpty ? l10n.manualInputLabel : locationText,
          isPlaceholder: locationText.isEmpty,
          onPress: () => showCourseFieldPickerSheet(
            context,
            title: l10n.selectLocationTitle,
            suggestions: provider.uniqueLocations,
            controller: _entryLocationControllers[index],
            onConfirmed: () {
              setState(() {
                entry.location = _entryLocationControllers[index].text;
              });
            },
          ),
        ),
      ),
      _buildEntryTimeSchemeField(provider, index, l10n, compact: true),
      if (hasMultipleEntries)
        _buildCompactDeleteEntryRow(
          l10n: l10n,
          onTap: () => _removeScheduleEntry(index),
        ),
      _buildScheduleConflictLinks(index, l10n),
    ], spacing: 8);

    if (!hasMultipleEntries) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entryFields,
      );
    }

    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final courseColor = parseHexColorOrFallback(
      _selectedColor,
      fallback: colors.primary,
    );
    final weekdayLabel =
        weekDays[entry.dayOfWeek.clamp(1, weekDays.length) - 1];
    final timePreview =
        '$weekdayLabel · ${l10n.sectionRangeLabel(entry.startSection, entry.endSection)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(HyperosTokens.cardRadius),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: HyperosTokens.iconBadgeSize,
                height: HyperosTokens.iconBadgeSize,
                decoration: BoxDecoration(
                  color: courseColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(
                    HyperosTokens.iconBadgeRadius,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: typo.sm.copyWith(
                    color: courseColor,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scheduleEntryTitle(index + 1),
                      style: typo.sm.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timePreview,
                      style: typo.xs2.copyWith(
                        color: colors.mutedForeground,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...entryFields,
        ],
      ),
    );
  }

  Widget _buildScheduleTimeRow({
    required List<String> weekDays,
    required List<int> sectionNumbers,
    required _ScheduleEntryData entry,
    required AppLocalizations l10n,
  }) {
    final weekdayItems = {
      for (var i = 0; i < weekDays.length; i++) weekDays[i]: i + 1,
    };
    final weekdaySelect = _buildCompactPickerField(
      label: l10n.weekdayLabel,
      value: weekDays[entry.dayOfWeek - 1],
      onPress: () => _pickFromSelectSheet(
        title: l10n.weekdayLabel,
        items: weekdayItems,
        currentValue: entry.dayOfWeek,
        onSelected: (value) => setState(() => entry.dayOfWeek = value),
      ),
    );
    final startSelect = _buildCompactPickerField(
      label: l10n.startSectionLabel,
      value: l10n.scheduleSectionNumberLabel(entry.startSection),
      onPress: () => _pickFromSelectSheet(
        title: l10n.startSectionLabel,
        items: _sectionSelectItems(sectionNumbers, l10n),
        currentValue: entry.startSection,
        onSelected: (value) {
          setState(() {
            entry.startSection = value;
            if (entry.endSection < entry.startSection) {
              entry.endSection = entry.startSection;
            }
          });
        },
      ),
    );
    final endSelect = _buildCompactPickerField(
      label: l10n.endSectionLabel,
      value: l10n.scheduleSectionNumberLabel(entry.endSection),
      onPress: () => _pickFromSelectSheet(
        title: l10n.endSectionLabel,
        items: _sectionSelectItems(
          sectionNumbers.where((s) => s >= entry.startSection),
          l10n,
        ),
        currentValue: entry.endSection,
        onSelected: (value) => setState(() => entry.endSection = value),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              weekdaySelect,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: startSelect),
                  const SizedBox(width: 8),
                  Expanded(child: endSelect),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: weekdaySelect),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: startSelect),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: endSelect),
          ],
        );
      },
    );
  }

  Widget _buildCompactPickerField({
    required String label,
    required String value,
    required VoidCallback onPress,
    bool isPlaceholder = false,
  }) {
    final theme = context.theme;
    final fieldRadius = BorderRadius.circular(HyperosTokens.controlRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: fieldRadius,
        onTap: onPress,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: HyperosTokens.controlMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: fieldRadius,
            border: Border.all(color: theme.colors.border),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: theme.typography.body.sm,
                    children: [
                      TextSpan(
                        text: '$label ',
                        style: TextStyle(color: theme.colors.mutedForeground),
                      ),
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          color: isPlaceholder
                              ? theme.colors.mutedForeground
                              : null,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: theme.colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDeleteEntryRow({
    required AppLocalizations l10n,
    required VoidCallback onTap,
  }) {
    final theme = context.theme;
    final fieldRadius = BorderRadius.circular(HyperosTokens.controlRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: fieldRadius,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: HyperosTokens.controlMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: fieldRadius,
            border: Border.all(color: theme.colors.border),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: theme.colors.destructive,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.deleteScheduleEntryAction,
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.destructive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactWeekSummaryRow({
    required String label,
    required String summary,
    required VoidCallback onTap,
  }) {
    final theme = context.theme;
    final fieldRadius = BorderRadius.circular(HyperosTokens.controlRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: fieldRadius,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: HyperosTokens.controlMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: fieldRadius,
            border: Border.all(color: theme.colors.border),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: theme.typography.body.sm,
                    children: [
                      TextSpan(
                        text: '$label · ',
                        style: TextStyle(color: theme.colors.mutedForeground),
                      ),
                      TextSpan(text: summary),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: theme.colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryTimeSchemeField(
    TimetableProvider provider,
    int index,
    AppLocalizations l10n, {
    bool compact = false,
  }) {
    final entry = _scheduleEntries[index];
    final followLabel =
        provider.activeTimeScheme?.name ?? l10n.timetableAppName;
    final currentName = entry.timeSchemeIdOverride == null
        ? l10n.followCurrentTimetableWithName(followLabel)
        : provider.timeSchemes
                  .where((s) => s.id == entry.timeSchemeIdOverride)
                  .firstOrNull
                  ?.name ??
              l10n.followCurrentTimetableWithName(followLabel);
    void onPress() {
      showTimeSchemePickerSheet(
        context,
        currentValue: entry.timeSchemeIdOverride,
        onSelected: (value) {
          setState(() {
            entry.timeSchemeIdOverride = value;
          });
        },
      ).whenComplete(() {
        if (mounted) setState(() {});
      });
    }

    if (compact) {
      return _buildCompactPickerField(
        label: l10n.timeSchemeLabel,
        value: currentName,
        onPress: onPress,
      );
    }
    return _buildPickerTile(
      label: l10n.timeSchemeLabel,
      value: currentName,
      icon: Icons.schedule_rounded,
      onPress: onPress,
    );
  }

  Widget _buildAddScheduleEntryButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: HyperosButton(
        label: l10n.addScheduleEntryAction,
        variant: HyperosButtonVariant.secondary,
        expand: true,
        onPressed: _addScheduleEntry,
      ),
    );
  }

  void _addScheduleEntry() {
    final last = _scheduleEntries.isNotEmpty ? _scheduleEntries.last : null;
    setState(() {
      final newEntry = _ScheduleEntryData(
        id: const Uuid().v4(),
        dayOfWeek: last?.dayOfWeek ?? 1,
        startSection: last?.startSection ?? 1,
        endSection: last?.endSection ?? 2,
        startWeek: last?.startWeek ?? 1,
        endWeek: last?.endWeek ?? 16,
        teacher: last?.teacher ?? _teacherController.text,
        location: last?.location ?? _locationController.text,
      );
      _scheduleEntries.add(newEntry);
      _entryTeacherControllers.add(
        TextEditingController(text: newEntry.teacher),
      );
      _entryLocationControllers.add(
        TextEditingController(text: newEntry.location),
      );
    });
  }

  void _removeScheduleEntry(int index) {
    setState(() {
      _scheduleEntries.removeAt(index);
      _entryTeacherControllers[index].dispose();
      _entryTeacherControllers.removeAt(index);
      _entryLocationControllers[index].dispose();
      _entryLocationControllers.removeAt(index);
    });
  }

  Future<void> _confirmDeleteGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.courseGroup!.name;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteCourseTitle,
      message: l10n.confirmDeleteCourseMessage(name),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );

    if (confirmed != true || !mounted) return;

    await context.read<TimetableProvider>().deleteCourseGroup(name);
    if (!mounted) return;
    showAppToast(
      context,
      message: l10n.courseDeleted,
      kind: AppToastKind.success,
    );
    Navigator.pop(context);
  }

  void _applyCourseTemplate(Course course) {
    _nameController.text = course.name;
    _shortNameController.text = course.shortName ?? '';
    _teacherController.text = course.teacher;
    _descriptionController.text = course.description ?? course.note ?? '';
    _courseNature = course.courseNature;
    _selectedColor = course.color;
    // Sync existing schedule entries' teacher/location with shared info.
    for (var i = 0; i < _scheduleEntries.length; i++) {
      _scheduleEntries[i].teacher = course.teacher;
      _entryTeacherControllers[i].text = course.teacher;
      _scheduleEntries[i].location = course.location;
      _entryLocationControllers[i].text = course.location;
    }
  }

  Future<void> _showCourseTemplateSheet(TimetableProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    if (provider.courseGroups.isEmpty) {
      showAppLightTip(context, message: l10n.noTemplateCoursesHint);
      return;
    }
    final course = await showCourseTemplatePickerSheet(
      context,
      title: l10n.reuseExistingCourseHelper,
      courseGroups: provider.courseGroups,
    );
    if (course != null && mounted) {
      setState(() => _applyCourseTemplate(course));
    }
  }

  Widget _buildResponsiveFieldPair({
    required Widget leading,
    required Widget trailing,
    double spacing = 16,
    double breakpoint = 420,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              leading,
              SizedBox(height: spacing),
              trailing,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: leading),
            SizedBox(width: spacing),
            Expanded(child: trailing),
          ],
        );
      },
    );
  }

  Future<void> _showCustomColorPicker() async {
    final result = await showCourseColorPickerSheet(
      context,
      initialColorHex: _selectedColor,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedColor = result;
    });
  }

  List<int> _buildEntryWeeksFromRange(_ScheduleEntryData entry) {
    final weeks = <int>[];
    for (var w = entry.startWeek; w <= entry.endWeek; w++) {
      if (entry.isOddWeek && w.isEven) continue;
      if (entry.isEvenWeek && w.isOdd) continue;
      weeks.add(w);
    }
    return weeks;
  }

  String _formatWeekList(List<int> weeks) {
    if (weeks.isEmpty) {
      return '';
    }
    final ranges = <String>[];
    var rangeStart = weeks.first;
    var previous = weeks.first;
    for (var index = 1; index < weeks.length; index++) {
      final current = weeks[index];
      if (current == previous + 1) {
        previous = current;
        continue;
      }
      ranges.add(
        rangeStart == previous ? '$rangeStart' : '$rangeStart-$previous',
      );
      rangeStart = current;
      previous = current;
    }
    ranges.add(
      rangeStart == previous ? '$rangeStart' : '$rangeStart-$previous',
    );
    return ranges.join('、');
  }

  String _selectedWeeksSummaryText(
    List<int> selectedWeeks,
    List<int> availableWeeks,
    int startWeek,
    int endWeek,
    bool isOddWeek,
    bool isEvenWeek,
    _WeekSelectionMode mode,
    AppLocalizations l10n,
  ) {
    if (mode == _WeekSelectionMode.range) {
      final isAll =
          startWeek == availableWeeks.first &&
          endWeek == availableWeeks.last &&
          !isOddWeek &&
          !isEvenWeek;
      if (isAll) return l10n.allWeeksFilter;
      final range = '${l10n.weekLabel(startWeek)}-${l10n.weekLabel(endWeek)}';
      if (isOddWeek) return '$range · ${l10n.oddWeeksFilter}';
      if (isEvenWeek) return '$range · ${l10n.evenWeeksFilter}';
      return range;
    }
    if (selectedWeeks.isEmpty) return '';
    if (selectedWeeks.length == availableWeeks.length) {
      return l10n.allWeeksFilter;
    }
    return _formatWeekList(selectedWeeks);
  }

  // ---------------------------------------------------------------------------
  // Week summary row (compact)
  // ---------------------------------------------------------------------------

  Widget _buildWeekGridTile({
    required int week,
    required bool isSelected,
    required VoidCallback onPress,
  }) {
    final theme = context.theme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: theme.style.borderRadius.md,
        onTap: onPress,
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected ? theme.colors.primary : theme.colors.secondary,
            borderRadius: theme.style.borderRadius.md,
            border: Border.all(
              color: isSelected ? theme.colors.primary : theme.colors.border,
            ),
          ),
          child: Center(
            child: Text(
              '$week',
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? theme.colors.primaryForeground
                    : theme.colors.secondaryForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekModeTileGroup({
    required _WeekSelectionMode tempMode,
    required AppLocalizations l10n,
    required ValueChanged<_WeekSelectionMode> onSelect,
  }) {
    return HyperosChoiceGroup(
      children: [
        HyperosChoiceTile(
          prefix: const Icon(Icons.linear_scale_rounded),
          title: l10n.rangeWeeksLabel,
          selected: tempMode == _WeekSelectionMode.range,
          highlightSelectedText: true,
          onTap: () => onSelect(_WeekSelectionMode.range),
        ),
        HyperosChoiceTile(
          prefix: const Icon(Icons.apps_rounded),
          title: l10n.customWeeksLabel,
          selected: tempMode == _WeekSelectionMode.custom,
          highlightSelectedText: true,
          onTap: () => onSelect(_WeekSelectionMode.custom),
        ),
      ],
    );
  }

  Widget _buildWeekParityTileGroup({
    required AppLocalizations l10n,
    required bool isAllWeeks,
    required bool isOddWeek,
    required bool isEvenWeek,
    required VoidCallback onSelectAll,
    required VoidCallback onSelectOdd,
    required VoidCallback onSelectEven,
  }) {
    return HyperosChoiceGroup(
      children: [
        HyperosChoiceTile(
          title: l10n.allWeeksFilter,
          selected: isAllWeeks,
          highlightSelectedText: true,
          onTap: onSelectAll,
        ),
        HyperosChoiceTile(
          title: l10n.oddWeeksFilter,
          selected: isOddWeek,
          highlightSelectedText: true,
          onTap: onSelectOdd,
        ),
        HyperosChoiceTile(
          title: l10n.evenWeeksFilter,
          selected: isEvenWeek,
          highlightSelectedText: true,
          onTap: onSelectEven,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Entry-week picker dialog (group editing mode)
  // ---------------------------------------------------------------------------

  Future<void> _showEntryWeekPickerDialog(
    _ScheduleEntryData entry,
    List<int> availableWeeks,
    AppLocalizations l10n,
  ) async {
    var tempMode = entry.weekSelectionMode;
    var tempStartWeek = entry.startWeek;
    var tempEndWeek = entry.endWeek;
    var tempIsOddWeek = entry.isOddWeek;
    var tempIsEvenWeek = entry.isEvenWeek;
    var tempCustomWeeks = Set<int>.from(entry.selectedCustomWeeks);

    List<int> buildTempWeeksFromRange() {
      final weeks = <int>[];
      for (var w = tempStartWeek; w <= tempEndWeek; w++) {
        if (tempIsOddWeek && w.isEven) continue;
        if (tempIsEvenWeek && w.isOdd) continue;
        weeks.add(w);
      }
      return weeks;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedWeeks = tempMode == _WeekSelectionMode.range
                ? buildTempWeeksFromRange()
                : (tempCustomWeeks.toList()..sort());

            return Dialog.fullscreen(
              child: HyperosSubpage(
                onBack: () => Navigator.pop(context, false),
                title: Text(l10n.weekPickerTitle),
                childPad: false,
                child: Material(
                  type: MaterialType.transparency,
                  child: HyperosBlurredBodyInset(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildWeekModeTileGroup(
                                tempMode: tempMode,
                                l10n: l10n,
                                onSelect: (nextMode) {
                                  setDialogState(() {
                                    if (nextMode == _WeekSelectionMode.custom &&
                                        tempCustomWeeks.isEmpty) {
                                      tempCustomWeeks =
                                          buildTempWeeksFromRange().toSet();
                                      if (tempCustomWeeks.isEmpty) {
                                        tempCustomWeeks = {tempStartWeek};
                                      }
                                    }
                                    if (nextMode == _WeekSelectionMode.range &&
                                        tempCustomWeeks.isNotEmpty) {
                                      final sorted = tempCustomWeeks.toList()
                                        ..sort();
                                      tempStartWeek = sorted.first;
                                      tempEndWeek = sorted.last;
                                      tempIsOddWeek = false;
                                      tempIsEvenWeek = false;
                                    }
                                    tempMode = nextMode;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              if (tempMode == _WeekSelectionMode.range) ...[
                                _buildResponsiveFieldPair(
                                  spacing: 8,
                                  leading: _buildCompactPickerField(
                                    label: l10n.startWeekLabel,
                                    value: l10n.weekLabel(tempStartWeek),
                                    onPress: () => _pickFromSelectSheet(
                                      title: l10n.startWeekLabel,
                                      items: {
                                        for (final week in availableWeeks)
                                          l10n.weekLabel(week): week,
                                      },
                                      currentValue: tempStartWeek,
                                      onSelected: (value) {
                                        setDialogState(() {
                                          tempStartWeek = value;
                                          if (tempEndWeek < tempStartWeek) {
                                            tempEndWeek = tempStartWeek;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  trailing: _buildCompactPickerField(
                                    label: l10n.endWeekLabel,
                                    value: l10n.weekLabel(tempEndWeek),
                                    onPress: () => _pickFromSelectSheet(
                                      title: l10n.endWeekLabel,
                                      items: {
                                        for (final week in availableWeeks.where(
                                          (w) => w >= tempStartWeek,
                                        ))
                                          l10n.weekLabel(week): week,
                                      },
                                      currentValue: tempEndWeek,
                                      onSelected: (value) {
                                        setDialogState(
                                          () => tempEndWeek = value,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildWeekParityTileGroup(
                                  l10n: l10n,
                                  isAllWeeks: !tempIsOddWeek && !tempIsEvenWeek,
                                  isOddWeek: tempIsOddWeek,
                                  isEvenWeek: tempIsEvenWeek,
                                  onSelectAll: () {
                                    setDialogState(() {
                                      tempIsOddWeek = false;
                                      tempIsEvenWeek = false;
                                    });
                                  },
                                  onSelectOdd: () {
                                    setDialogState(() {
                                      tempIsOddWeek = true;
                                      tempIsEvenWeek = false;
                                    });
                                  },
                                  onSelectEven: () {
                                    setDialogState(() {
                                      tempIsOddWeek = false;
                                      tempIsEvenWeek = true;
                                    });
                                  },
                                ),
                              ] else ...[
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;
                                    final crossAxisCount = width < 340
                                        ? 4
                                        : width < 420
                                        ? 5
                                        : 6;
                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: availableWeeks.length,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount,
                                            mainAxisSpacing: 8,
                                            crossAxisSpacing: 8,
                                            mainAxisExtent: 44,
                                          ),
                                      itemBuilder: (context, i) {
                                        final week = availableWeeks[i];
                                        final isSelected = tempCustomWeeks
                                            .contains(week);
                                        return _buildWeekGridTile(
                                          week: week,
                                          isSelected: isSelected,
                                          onPress: () {
                                            setDialogState(() {
                                              if (isSelected) {
                                                if (tempCustomWeeks.length >
                                                    1) {
                                                  tempCustomWeeks.remove(week);
                                                }
                                              } else {
                                                tempCustomWeeks.add(week);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ActionChip(
                                      label: Text(l10n.selectAllAction),
                                      onPressed: () {
                                        setDialogState(() {
                                          tempCustomWeeks = availableWeeks
                                              .toSet();
                                        });
                                      },
                                    ),
                                    ActionChip(
                                      label: Text(l10n.selectOddWeeksAction),
                                      onPressed: () {
                                        setDialogState(() {
                                          tempCustomWeeks = availableWeeks
                                              .where((week) => week.isOdd)
                                              .toSet();
                                        });
                                      },
                                    ),
                                    ActionChip(
                                      label: Text(l10n.selectEvenWeeksAction),
                                      onPressed: () {
                                        setDialogState(() {
                                          tempCustomWeeks = availableWeeks
                                              .where((week) => week.isEven)
                                              .toSet();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                l10n.selectedWeeksSummary(
                                  selectedWeeks.length,
                                  _formatWeekList(selectedWeeks),
                                ),
                                style: context.theme.typography.body.sm,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: HyperosButton(
                                  label: l10n.cancelAction,
                                  variant: HyperosButtonVariant.secondary,
                                  expand: true,
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: HyperosButton(
                                  label: l10n.confirmAction,
                                  expand: true,
                                  onPressed: () => Navigator.pop(context, true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      entry.weekSelectionMode = tempMode;
      entry.startWeek = tempStartWeek;
      entry.endWeek = tempEndWeek;
      entry.isOddWeek = tempIsOddWeek;
      entry.isEvenWeek = tempIsEvenWeek;
      entry.selectedCustomWeeks = tempCustomWeeks;
    });
  }

  Future<void> _saveCourse(
    TimetableProvider provider,
    TimetableSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 16));

    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      _formKey.currentState?.validate();
      if (!mounted) return;
      showAppToast(
        context,
        message: l10n.pleaseEnterCourseName,
        kind: AppToastKind.warning,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }
    await _saveGroup(provider, settings, l10n);
  }

  Future<void> _saveGroup(
    TimetableProvider provider,
    TimetableSettings settings,
    AppLocalizations l10n,
  ) async {
    final name = _nameController.text.trim();
    final shortName = _shortNameController.text.isEmpty
        ? null
        : _shortNameController.text;
    final description = _descriptionController.text.isEmpty
        ? null
        : _descriptionController.text;

    // Validate all entries.
    for (var i = 0; i < _scheduleEntries.length; i++) {
      final entry = _scheduleEntries[i];
      // Sync teacher/location from controllers.
      entry.teacher = _entryTeacherControllers[i].text;
      entry.location = _entryLocationControllers[i].text;

      final validationMessage = provider.validateCourseTimeSchemeOverride(
        timeSchemeId: entry.timeSchemeIdOverride,
        startSection: entry.startSection,
        endSection: entry.endSection,
      );
      if (validationMessage != null) {
        showAppToast(
          context,
          message:
              '${l10n.scheduleEntryTitle(i + 1)}: ${localizeServiceMessage(l10n, validationMessage)}',
          kind: AppToastKind.warning,
        );
        return;
      }

      if (entry.weekSelectionMode == _WeekSelectionMode.custom &&
          entry.selectedCustomWeeks.isEmpty) {
        showAppToast(
          context,
          message:
              '${l10n.scheduleEntryTitle(i + 1)}: ${l10n.selectAtLeastOneWeek}',
          kind: AppToastKind.warning,
        );
        return;
      }
    }

    // Build courses from entries.
    final courses = <Course>[];
    for (final entry in _scheduleEntries) {
      final resolvedScheme = _resolveEntryTimeScheme(provider, entry);
      final startTime = resolvedScheme == null
          ? settings.sectionAt(entry.startSection).startTime
          : resolvedScheme.sections[entry.startSection - 1].startTime;
      final endTime = resolvedScheme == null
          ? settings.sectionAt(entry.endSection).endTime
          : resolvedScheme.sections[entry.endSection - 1].endTime;

      courses.add(
        entry.toCourse(
          name: name,
          shortName: shortName,
          color: _selectedColor,
          courseNature: _courseNature,
          description: description,
          startTime: startTime,
          endTime: endTime,
        ),
      );
    }

    try {
      if (widget.courseGroup != null) {
        // Editing existing group: replace all entries.
        await provider.updateCourseGroup(widget.courseGroup!.name, courses);
      } else if (widget.course != null) {
        // Editing a single existing course: delete original, add all new entries.
        await provider.deleteCourse(widget.course!.id);
        for (final course in courses) {
          await provider.addCourse(course);
        }
      } else {
        // Adding new courses: add all entries.
        for (final course in courses) {
          await provider.addCourse(course);
        }
      }
    } on ArgumentError catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        message: error.message != null
            ? localizeServiceMessage(l10n, error.message!)
            : l10n.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }

    if (!mounted) return;
    showAppToast(
      context,
      message: widget.courseGroup == null && widget.course == null
          ? l10n.courseAddedSuccess
          : l10n.courseUpdatedSuccess,
      kind: AppToastKind.success,
    );
    Navigator.pop(context);
  }

  TimeScheme? _resolveEntryTimeScheme(
    TimetableProvider provider,
    _ScheduleEntryData entry,
  ) {
    if (entry.timeSchemeIdOverride == null) {
      return provider.activeTimeScheme;
    }
    for (final scheme in provider.timeSchemes) {
      if (scheme.id == entry.timeSchemeIdOverride) {
        return scheme;
      }
    }
    return null;
  }
}

/// Compact HyperOS list row for a conflicting partner schedule.
///
/// Matches preference navigation chrome: title + status tag + detail + chevron.
/// Avoids custom red banners and trailing text-as-button.
class _ScheduleConflictPartnerRow extends StatelessWidget {
  const _ScheduleConflictPartnerRow({
    required this.partner,
    required this.onOpen,
  });

  final Course partner;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final dayLabel = _weekdayShort(l10n, partner.dayOfWeek);
    final schedule = l10n.weekdaySectionSummary(
      dayLabel,
      partner.startSection,
      partner.endSection,
    );

    return Material(
      color: HyperosColors.secondaryVariant(context),
      // Nested compact row — use control radius, not settings-group 24.
      borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
      clipBehavior: Clip.antiAlias,
      child: HyperosPressableRow(
        onTap: onOpen,
        backgroundColor: HyperosColors.secondaryVariant(context),
        highlightColor: HyperosColors.rowHighlight(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: HyperosTokens.controlMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              partner.name,
                              style: HyperosTypography.listTitle(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          HyperosTag(
                            label: l10n.conflictLabel,
                            backgroundColor: theme.colors.destructive
                                .withValues(alpha: 0.12),
                            textStyle: HyperosTypography.listDetail(context)
                                .copyWith(
                                  color: theme.colors.destructive,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule,
                        style: HyperosTypography.listDetail(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: HyperosTokens.titleChevronGap),
                const HyperosChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _weekdayShort(AppLocalizations l10n, int dayOfWeek) {
    return switch (dayOfWeek) {
      1 => l10n.weekdayShortMonday,
      2 => l10n.weekdayShortTuesday,
      3 => l10n.weekdayShortWednesday,
      4 => l10n.weekdayShortThursday,
      5 => l10n.weekdayShortFriday,
      6 => l10n.weekdayShortSaturday,
      7 => l10n.weekdayShortSunday,
      _ => dayOfWeek.toString(),
    };
  }
}
