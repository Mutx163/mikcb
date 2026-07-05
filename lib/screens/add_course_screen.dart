import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import 'time_scheme_management_screen.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';
import '../widgets/settings_section_widgets.dart';

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
      courseNature: courseNature,
      description: description,
      timeSchemeIdOverride: timeSchemeIdOverride,
    );
  }
}

class _AddCourseScreenState extends State<AddCourseScreen> {
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

  final List<String> _colors = const [
    '#2196F3',
    '#4CAF50',
    '#FF9800',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#FF5722',
    '#795548',
    '#607D8B',
  ];

  Color _parseColor(String colorHex) {
    return parseHexColorOrFallback(colorHex, fallback: const Color(0xFF2196F3));
  }

  String _toHex(Color color) {
    final red = (color.r * 255).round().clamp(0, 255);
    final green = (color.g * 255).round().clamp(0, 255);
    final blue = (color.b * 255).round().clamp(0, 255);
    final value = (red << 16) | (green << 8) | blue;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
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

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
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
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: Form(
          key: _formKey,
          child: _buildGroupEditingBody(provider, settings),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCourse() async {
    final course = widget.course;
    if (course == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.deleteCourseTitle),
        body: Text(l10n.confirmDeleteCourseMessage(course.name)),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await context.read<TimetableProvider>().deleteCourse(course.id);
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.courseDeleted)),
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
  // Teacher / Location picker
  // ---------------------------------------------------------------------------

  void _showPickerSheet({
    required String title,
    required List<String> suggestions,
    required TextEditingController controller,
    required VoidCallback? onEntrySync,
  }) {
    final l10n = AppLocalizations.of(context)!;
    // Save original text so we can restore on cancel (tap outside).
    final originalText = controller.text;
    var confirmed = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final filtered = controller.text.isEmpty
                ? suggestions
                : suggestions
                      .where((s) => s.contains(controller.text))
                      .toList();
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FTextField(
                    control: FTextFieldControl.managed(controller: controller),
                    hint: l10n.manualInputLabel,
                    prefixBuilder: (context, style, variants) =>
                        const Icon(Icons.search),
                    suffixBuilder: controller.text.isNotEmpty
                        ? (context, style, variants) => IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: controller.clear,
                          )
                        : null,
                    onSubmit: (_) {
                      confirmed = true;
                      onEntrySync?.call();
                      Navigator.pop(sheetContext);
                    },
                  ),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.historyRecordsLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filtered.map((s) {
                        return ActionChip(
                          label: Text(s),
                          onPressed: () {
                            controller.text = s;
                            confirmed = true;
                            onEntrySync?.call();
                            Navigator.pop(sheetContext);
                          },
                        );
                      }).toList(),
                    ),
                  ] else if (suggestions.isNotEmpty &&
                      controller.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.noHistoryRecords,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FButton(
                      onPress: () {
                        confirmed = true;
                        onEntrySync?.call();
                        Navigator.pop(sheetContext);
                      },
                      child: Text(l10n.saveAction),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Restore original text if user dismissed without confirming.
      if (!confirmed) {
        controller.text = originalText;
      }
    });
  }

  /// Shows a time scheme picker bottom sheet.
  ///
  /// [currentValue] is the currently selected time scheme override ID
  /// (null means "follow profile").
  /// [onSelected] is called when the user picks a scheme (null = follow profile).
  void _showTimeSchemePickerSheet({
    required String? currentValue,
    required ValueChanged<String?> onSelected,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final followLabel =
        provider.activeTimeScheme?.name ?? l10n.timetableAppName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final schemes = provider.timeSchemes;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.selectTimeSchemeTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FButton(
                        variant: FButtonVariant.ghost,
                        onPress: () async {
                          Navigator.pop(sheetContext);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                name: '/settings/time-schemes',
                              ),
                              builder: (_) =>
                                  const TimeSchemeManagementScreen(),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                        prefix: const Icon(Icons.settings_rounded, size: 18),
                        child: Text(l10n.manageTimeSchemesAction),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(sheetContext).size.height * 0.5,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "Follow profile" option
                          _buildSchemeTile(
                            title: l10n.followCurrentTimetableWithName(
                              followLabel,
                            ),
                            subtitle: null,
                            isSelected: currentValue == null,
                            onTap: () {
                              onSelected(null);
                              Navigator.pop(sheetContext);
                            },
                            trailing: null,
                          ),
                          if (schemes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                          ],
                          // Existing schemes
                          ...schemes.map((scheme) {
                            final isSelected = currentValue == scheme.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _buildSchemeTile(
                                title: scheme.name,
                                subtitle: scheme.sections.isNotEmpty
                                    ? '${scheme.sections.first.startTime}–${scheme.sections.last.endTime} · ${scheme.sectionCount}'
                                    : null,
                                isSelected: isSelected,
                                onTap: () {
                                  onSelected(scheme.id);
                                  Navigator.pop(sheetContext);
                                },
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 20,
                                  ),
                                  tooltip: l10n.editTimeSchemeTitle,
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        settings: const RouteSettings(
                                          name: '/settings/time-schemes',
                                        ),
                                        builder: (_) =>
                                            TimeSchemeManagementScreen(
                                              initialEditSchemeId: scheme.id,
                                            ),
                                      ),
                                    );
                                    setSheetState(() {});
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Create new scheme button
                  SizedBox(
                    width: double.infinity,
                    child: FButton(
                      variant: FButtonVariant.secondary,
                      onPress: () async {
                        Navigator.pop(sheetContext);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: '/settings/time-schemes',
                            ),
                            builder: (_) => const TimeSchemeManagementScreen(),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      prefix: const Icon(Icons.add_rounded),
                      child: Text(l10n.createTimeSchemeTitle),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  Widget _buildSchemeTile({
    required String title,
    required String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

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
    final theme = context.theme;
    return FTile(
      prefix: Icon(icon),
      title: Text(label),
      details: Text(
        value,
        style: theme.typography.body.sm.copyWith(
          fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
          color: isPlaceholder ? theme.colors.mutedForeground : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      suffix: Icon(
        Icons.chevron_right_rounded,
        color: theme.colors.mutedForeground,
      ),
      onPress: onPress,
    );
  }

  Widget _buildGroupEditingBody(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGroupSharedInfoSection(provider, l10n),
        const SizedBox(height: 12),
        _buildGroupColorSection(l10n),
        const SizedBox(height: 12),
        _buildScheduleEntriesSection(provider, settings, l10n),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGroupSharedInfoSection(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    return SettingsSectionCard(
      title: l10n.sharedInfoTitle,
      subtitle: l10n.sharedInfoHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _withSpacing([
          FTextFormField(
            control: FTextFieldControl.managed(controller: _nameController),
            label: Text(l10n.courseNameLabel),
            description: Text(l10n.courseNameHelper),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.pleaseEnterCourseName;
              }
              return null;
            },
            suffixBuilder: widget.course == null
                ? (context, style, variants) => IconButton(
                    tooltip: l10n.reuseExistingCourseLabel,
                    icon: const Icon(Icons.auto_awesome_motion_rounded),
                    onPressed: () => _showCourseTemplateSheet(provider),
                  )
                : null,
          ),
          _buildResponsiveFieldPair(
            leading: FTextFormField(
              control: FTextFieldControl.managed(
                controller: _shortNameController,
              ),
              label: Text(l10n.courseShortNameOptional),
              textInputAction: TextInputAction.next,
            ),
            trailing: FSelect<CourseNature>(
              hint: l10n.courseNatureLabel,
              items: {for (final item in CourseNature.values) item.label: item},
              control: FSelectControl.lifted(
                value: _courseNature,
                onChange: (value) {
                  if (value == null) return;
                  setState(() => _courseNature = value);
                },
              ),
            ),
          ),
          FTextFormField.multiline(
            control: FTextFieldControl.managed(
              controller: _descriptionController,
            ),
            label: Text(l10n.courseDescriptionOptional),
            minLines: 2,
            maxLines: 4,
          ),
        ]),
      ),
    );
  }

  Widget _buildGroupColorSection(AppLocalizations l10n) {
    return SettingsSectionCard(
      title: l10n.courseColorTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColorPalette(),
          const SizedBox(height: 12),
          FButton(
            variant: FButtonVariant.secondary,
            onPress: _showCustomColorPicker,
            prefix: const Icon(Icons.palette_outlined, size: 18),
            child: Text(l10n.customPaletteAction),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPalette() {
    final selectionBorder = context.theme.colors.foreground;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colors.map((color) {
        final isSelected = color == _selectedColor;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _parseColor(color),
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: selectionBorder, width: 3)
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }

  ({String startTime, String endTime}) _resolveEntrySectionTimes(
    TimetableProvider provider,
    TimetableSettings settings,
    _ScheduleEntryData entry,
  ) {
    final scheme = _resolveEntryTimeScheme(provider, entry);
    if (scheme != null &&
        entry.startSection >= 1 &&
        entry.endSection <= scheme.sections.length) {
      return (
        startTime: scheme.sections[entry.startSection - 1].startTime,
        endTime: scheme.sections[entry.endSection - 1].endTime,
      );
    }
    return (
      startTime: settings.sectionAt(entry.startSection).startTime,
      endTime: settings.sectionAt(entry.endSection).endTime,
    );
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

  Widget _buildScheduleEntriesSection(
    TimetableProvider provider,
    TimetableSettings settings,
    AppLocalizations l10n,
  ) {
    final hasMultipleEntries = _scheduleEntries.length > 1;
    return SettingsSectionCard(
      title: hasMultipleEntries
          ? l10n.scheduleEntryTitle(1).replaceFirst(RegExp(r'\s?1$'), '')
          : l10n.scheduleEntrySingleTitle,
      subtitle: l10n.scheduleEntryCardSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _scheduleEntries.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: context.theme.colors.border),
              const SizedBox(height: 8),
            ],
            _buildScheduleEntryFields(provider, settings, i, l10n),
          ],
          if (_scheduleEntries.isNotEmpty) const SizedBox(height: 8),
          _buildAddScheduleEntryButton(l10n),
        ],
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
    final times = _resolveEntrySectionTimes(provider, settings, entry);
    final weekday = weekDays[entry.dayOfWeek - 1];
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _withSpacing([
        if (hasMultipleEntries)
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.weekdaySectionTimeSummary(
                    weekday,
                    entry.startSection,
                    entry.endSection,
                    times.startTime,
                    times.endTime,
                  ),
                  style: theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: l10n.deleteScheduleEntryAction,
                onPressed: () => _removeScheduleEntry(index),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: theme.colors.destructive,
                ),
              ),
            ],
          ),
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
            onPress: () => _showPickerSheet(
              title: l10n.selectTeacherTitle,
              suggestions: provider.uniqueTeachers,
              controller: _entryTeacherControllers[index],
              onEntrySync: () =>
                  entry.teacher = _entryTeacherControllers[index].text,
            ),
          ),
          trailing: _buildCompactPickerField(
            label: l10n.locationLabel,
            value: locationText.isEmpty ? l10n.manualInputLabel : locationText,
            isPlaceholder: locationText.isEmpty,
            onPress: () => _showPickerSheet(
              title: l10n.selectLocationTitle,
              suggestions: provider.uniqueLocations,
              controller: _entryLocationControllers[index],
              onEntrySync: () =>
                  entry.location = _entryLocationControllers[index].text,
            ),
          ),
        ),
        if (entry.timeSchemeIdOverride != null)
          _buildEntryTimeSchemeField(provider, index, l10n, compact: true)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: FButton(
              variant: FButtonVariant.ghost,
              onPress: () => _showTimeSchemePickerSheet(
                currentValue: entry.timeSchemeIdOverride,
                onSelected: (value) {
                  setState(() {
                    entry.timeSchemeIdOverride = value;
                  });
                },
              ),
              child: Text(
                l10n.scheduleEntryTimeSchemeSectionTitle,
                style: theme.typography.body.xs2.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          ),
      ], spacing: 8),
    );
  }

  Widget _buildScheduleTimeRow({
    required List<String> weekDays,
    required List<int> sectionNumbers,
    required _ScheduleEntryData entry,
    required AppLocalizations l10n,
  }) {
    final weekdaySelect = FSelect<int>(
      label: Text(l10n.weekdayLabel),
      hint: l10n.weekdayLabel,
      size: FTextFieldSizeVariant.sm,
      items: {for (var i = 0; i < weekDays.length; i++) weekDays[i]: i + 1},
      control: FSelectControl.lifted(
        value: entry.dayOfWeek,
        onChange: (value) {
          if (value == null) return;
          setState(() => entry.dayOfWeek = value);
        },
      ),
    );
    final startSelect = FSelect<int>(
      label: Text(l10n.startSectionLabel),
      hint: l10n.startSectionLabel,
      size: FTextFieldSizeVariant.sm,
      items: _sectionSelectItems(sectionNumbers, l10n),
      control: FSelectControl.lifted(
        value: entry.startSection,
        onChange: (value) {
          if (value == null) return;
          setState(() {
            entry.startSection = value;
            if (entry.endSection < entry.startSection) {
              entry.endSection = entry.startSection;
            }
          });
        },
      ),
    );
    final endSelect = FSelect<int>(
      label: Text(l10n.endSectionLabel),
      hint: l10n.endSectionLabel,
      size: FTextFieldSizeVariant.sm,
      items: _sectionSelectItems(
        sectionNumbers.where((s) => s >= entry.startSection),
        l10n,
      ),
      control: FSelectControl.lifted(
        value: entry.endSection,
        onChange: (value) {
          if (value == null) return;
          setState(() => entry.endSection = value);
        },
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colors.border),
          ),
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
                          fontWeight: isPlaceholder
                              ? FontWeight.normal
                              : FontWeight.w600,
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

  Widget _buildCompactWeekSummaryRow({
    required String label,
    required String summary,
    required VoidCallback onTap,
  }) {
    final theme = context.theme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colors.border),
          ),
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
                      TextSpan(
                        text: summary,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
    final onPress = () => _showTimeSchemePickerSheet(
      currentValue: entry.timeSchemeIdOverride,
      onSelected: (value) {
        setState(() {
          entry.timeSchemeIdOverride = value;
        });
      },
    );
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
      child: FButton(
        variant: FButtonVariant.secondary,
        onPress: _addScheduleEntry,
        prefix: const Icon(Icons.add_rounded),
        child: Text(l10n.addScheduleEntryAction),
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
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.deleteCourseTitle),
        body: Text(l10n.confirmDeleteCourseMessage(name)),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<TimetableProvider>().deleteCourseGroup(name);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.courseDeleted)));
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

  void _showCourseTemplateSheet(TimetableProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final courseGroups = provider.courseGroups;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reuseExistingCourseHelper,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (courseGroups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.courseNameHelper,
                        style: Theme.of(sheetContext).textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: courseGroups.length,
                      itemBuilder: (context, index) {
                        final group = courseGroups[index];
                        final representative = group.courses.first;
                        return FTile(
                          prefix: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: parseHexColorOrFallback(
                                representative.color,
                                fallback: const Color(0xFF2196F3),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          details: representative.teacher.isNotEmpty
                              ? Text(
                                  representative.teacher,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onPress: () {
                            setState(
                              () => _applyCourseTemplate(representative),
                            );
                            Navigator.pop(sheetContext);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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
    final l10n = AppLocalizations.of(context)!;
    var selected = _parseColor(_selectedColor);
    final hexController = TextEditingController(text: _selectedColor);

    final result = await showFDialog<String>(
      context: context,
      builder: (context, style, animation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateFromColor(Color color) {
              selected = color;
              hexController.text = _toHex(color);
            }

            void updateFromHex(String value) {
              final normalized = value.trim().toUpperCase();
              final match = RegExp(r'^#?[0-9A-F]{6}$').firstMatch(normalized);
              if (match == null) {
                return;
              }
              final withHash = normalized.startsWith('#')
                  ? normalized
                  : '#$normalized';
              updateFromColor(_parseColor(withHash));
            }

            final hsv = HSVColor.fromColor(selected);
            return FDialog(
              title: Text(l10n.colorPaletteTitle),
              body: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 72,
                      decoration: BoxDecoration(
                        color: selected,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: hexController,
                      decoration: InputDecoration(
                        labelText: l10n.colorHexLabel,
                        hintText: '#2563EB',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          updateFromHex(value);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.hueLabel(hsv.hue.round())),
                    Slider(
                      value: hsv.hue,
                      min: 0,
                      max: 360,
                      onChanged: (value) {
                        setDialogState(() {
                          updateFromColor(hsv.withHue(value).toColor());
                        });
                      },
                    ),
                    Text(l10n.saturationLabel((hsv.saturation * 100).round())),
                    Slider(
                      value: hsv.saturation,
                      min: 0,
                      max: 1,
                      onChanged: (value) {
                        setDialogState(() {
                          updateFromColor(hsv.withSaturation(value).toColor());
                        });
                      },
                    ),
                    Text(l10n.brightnessLabel((hsv.value * 100).round())),
                    Slider(
                      value: hsv.value,
                      min: 0,
                      max: 1,
                      onChanged: (value) {
                        setDialogState(() {
                          updateFromColor(hsv.withValue(value).toColor());
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                FButton(
                  variant: FButtonVariant.ghost,
                  onPress: () => Navigator.pop(context),
                  child: Text(l10n.cancelAction),
                ),
                FButton(
                  variant: FButtonVariant.primary,
                  onPress: () => Navigator.pop(context, _toHex(selected)),
                  child: Text(l10n.useThisColor),
                ),
              ],
            );
          },
        );
      },
    );

    hexController.dispose();

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

  Widget _buildWeekModeTileGroup({
    required _WeekSelectionMode tempMode,
    required AppLocalizations l10n,
    required ValueChanged<_WeekSelectionMode> onSelect,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return FTileGroup(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FTile(
          prefix: const Icon(Icons.linear_scale_rounded),
          title: Text(l10n.rangeWeeksLabel),
          suffix: tempMode == _WeekSelectionMode.range
              ? Icon(Icons.check_rounded, color: colorScheme.primary, size: 20)
              : null,
          onPress: () => onSelect(_WeekSelectionMode.range),
        ),
        FTile(
          prefix: const Icon(Icons.apps_rounded),
          title: Text(l10n.customWeeksLabel),
          suffix: tempMode == _WeekSelectionMode.custom
              ? Icon(Icons.check_rounded, color: colorScheme.primary, size: 20)
              : null,
          onPress: () => onSelect(_WeekSelectionMode.custom),
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
    final colorScheme = Theme.of(context).colorScheme;
    return FTileGroup(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FTile(
          title: Text(l10n.allWeeksFilter),
          suffix: isAllWeeks
              ? Icon(Icons.check_rounded, color: colorScheme.primary, size: 20)
              : null,
          onPress: onSelectAll,
        ),
        FTile(
          title: Text(l10n.oddWeeksFilter),
          suffix: isOddWeek
              ? Icon(Icons.check_rounded, color: colorScheme.primary, size: 20)
              : null,
          onPress: onSelectOdd,
        ),
        FTile(
          title: Text(l10n.evenWeeksFilter),
          suffix: isEvenWeek
              ? Icon(Icons.check_rounded, color: colorScheme.primary, size: 20)
              : null,
          onPress: onSelectEven,
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
              child: FScaffold(
                header: FHeader.nested(
                  prefixes: [
                    FHeaderAction.back(
                      onPress: () => Navigator.pop(context, false),
                    ),
                  ],
                  title: Text(l10n.weekPickerTitle),
                ),
                childPad: false,
                child: Material(
                  type: MaterialType.transparency,
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
                                    tempCustomWeeks = buildTempWeeksFromRange()
                                        .toSet();
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
                                leading: FSelect<int>(
                                  hint: l10n.startWeekLabel,
                                  items: {
                                    for (final week in availableWeeks)
                                      l10n.weekLabel(week): week,
                                  },
                                  control: FSelectControl.lifted(
                                    value: tempStartWeek,
                                    onChange: (value) {
                                      if (value == null) return;
                                      setDialogState(() {
                                        tempStartWeek = value;
                                        if (tempEndWeek < tempStartWeek) {
                                          tempEndWeek = tempStartWeek;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                trailing: FSelect<int>(
                                  hint: l10n.endWeekLabel,
                                  items: {
                                    for (final week in availableWeeks.where(
                                      (w) => w >= tempStartWeek,
                                    ))
                                      l10n.weekLabel(week): week,
                                  },
                                  control: FSelectControl.lifted(
                                    value: tempEndWeek,
                                    onChange: (value) {
                                      if (value == null) return;
                                      setDialogState(() => tempEndWeek = value);
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
                                  final availableWidth =
                                      width - (crossAxisCount - 1) * 8;
                                  final tileWidth =
                                      availableWidth / crossAxisCount;
                                  final targetMinHeight = width < 340
                                      ? 46.0
                                      : 44.0;
                                  final childAspectRatio =
                                      tileWidth / targetMinHeight;
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
                                          childAspectRatio: childAspectRatio,
                                        ),
                                    itemBuilder: (context, i) {
                                      final week = availableWeeks[i];
                                      final isSelected = tempCustomWeeks
                                          .contains(week);
                                      return FButton(
                                        variant: isSelected
                                            ? FButtonVariant.primary
                                            : FButtonVariant.secondary,
                                        onPress: () {
                                          setDialogState(() {
                                            if (isSelected) {
                                              if (tempCustomWeeks.length > 1) {
                                                tempCustomWeeks.remove(week);
                                              }
                                            } else {
                                              tempCustomWeeks.add(week);
                                            }
                                          });
                                        },
                                        child: Text(
                                          '$week',
                                          style: context
                                              .theme
                                              .typography
                                              .body
                                              .sm
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
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
                              child: FButton(
                                variant: FButtonVariant.ghost,
                                onPress: () => Navigator.pop(context, false),
                                child: Text(l10n.cancelAction),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FButton(
                                variant: FButtonVariant.primary,
                                onPress: () => Navigator.pop(context, true),
                                child: Text(l10n.confirmAction),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 16));

    await _saveGroup(provider, settings, l10n);
  }

  Future<void> _saveGroup(
    TimetableProvider provider,
    TimetableSettings settings,
    AppLocalizations l10n,
  ) async {
    final name = _nameController.text;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.scheduleEntryTitle(i + 1)}: $validationMessage',
            ),
          ),
        );
        return;
      }

      if (entry.weekSelectionMode == _WeekSelectionMode.custom &&
          entry.selectedCustomWeeks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.scheduleEntryTitle(i + 1)}: ${l10n.selectAtLeastOneWeek}',
            ),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? l10n.saveFailed)),
      );
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.courseGroup == null && widget.course == null
              ? l10n.courseAddedSuccess
              : l10n.courseUpdatedSuccess,
        ),
      ),
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
