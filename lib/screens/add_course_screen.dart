import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import 'time_scheme_management_screen.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';

enum _WeekSelectionMode { range, custom }

enum _RangeWeekFilter { all, odd, even }

enum CourseEditorMode { singleLesson, recurring }

class AddCourseScreen extends StatefulWidget {
  final Course? course;
  final CourseGroup? courseGroup;
  final Course? initialCourse;
  final int? initialDayOfWeek;
  final int? initialStartSection;
  final int? initialWeek;
  final CourseEditorMode mode;

  const AddCourseScreen({
    super.key,
    this.course,
    this.courseGroup,
    this.initialCourse,
    this.initialDayOfWeek,
    this.initialStartSection,
    this.initialWeek,
    this.mode = CourseEditorMode.recurring,
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
      weekSelectionMode:
          customWeeks != null ? _WeekSelectionMode.custom : _WeekSelectionMode.range,
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
  static const String _manualSingleLessonTemplateValue =
      '__manual_single_lesson__';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _teacherController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _selectedDayOfWeek = 1;
  int _startSection = 1;
  int _endSection = 2;
  int _startWeek = 1;
  int _endWeek = 16;
  int _singleWeek = 1;
  bool _isOddWeek = false;
  bool _isEvenWeek = false;
  _WeekSelectionMode _weekSelectionMode = _WeekSelectionMode.range;
  Set<int> _selectedCustomWeeks = <int>{};
  late CourseEditorMode _editorMode;
  String _selectedSingleLessonTemplateId = _manualSingleLessonTemplateValue;
  CourseNature _courseNature = CourseNature.required;
  String _selectedColor = '#2196F3';
  String? _selectedTimeSchemeOverrideId;

  // Group editing state
  // Use group editing body for everything except singleLesson mode.
  // This makes "add course" and "edit course" consistent: both support
  // multiple schedule entries. Only singleLesson keeps the simple body.
  bool get _isGroupEditing =>
      widget.courseGroup != null || _editorMode != CourseEditorMode.singleLesson;
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
    _editorMode = widget.mode;
    if (_isGroupEditing) {
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
        _scheduleEntries = [
          _ScheduleEntryData.fromCourse(widget.course!),
        ];
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
        _entryTeacherControllers.add(TextEditingController(text: entry.teacher));
        _entryLocationControllers.add(TextEditingController(text: entry.location));
      }
    } else if (widget.course != null) {
      _loadCourseData(widget.course!);
    } else {
      _selectedDayOfWeek = widget.initialDayOfWeek ?? 1;
      _startSection = widget.initialStartSection ?? 1;
      _endSection = _startSection + 1;
      _singleWeek = widget.initialWeek ?? 1;
      if (_editorMode == CourseEditorMode.singleLesson) {
        _weekSelectionMode = _WeekSelectionMode.custom;
        _selectedCustomWeeks = {_singleWeek};
        _startWeek = _singleWeek;
        _endWeek = _singleWeek;
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
    if (!_isGroupEditing) {
      _normalizeSections(settings);
      _normalizeWeeks(settings);
      _normalizeSingleWeek(settings);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_resolveTitle()),
        actions: [
          if (widget.courseGroup != null)
            IconButton(
              tooltip: l10n.deleteCourseTitle,
              onPressed: _confirmDeleteGroup,
              icon: const Icon(Icons.delete_outline_rounded),
            )
          else if (widget.course != null)
            IconButton(
              tooltip: l10n.deleteCourseTitle,
              onPressed: _confirmDeleteCourse,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          TextButton(
            onPressed: () => _saveCourse(provider, settings),
            child: Text(
              l10n.saveAction,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: _isGroupEditing
            ? _buildGroupEditingBody(provider, settings)
            : _buildSingleEditingBody(provider, settings),
      ),
    );
  }

  Widget _buildSingleEditingBody(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        if (widget.course == null) ...[
          _buildModeSection(settings),
          const SizedBox(height: 8),
        ],
        _buildBasicInfoSection(provider),
        const SizedBox(height: 8),
        _buildTimeSection(provider, settings),
        const SizedBox(height: 8),
        _buildSingleWeekSummary(settings, AppLocalizations.of(context)!),
        const SizedBox(height: 8),
        _buildColorSection(),
      ],
    );
  }

  Future<void> _confirmDeleteCourse() async {
    final course = widget.course;
    if (course == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteCourseTitle),
        content: Text(
          AppLocalizations.of(context)!.confirmDeleteCourseMessage(course.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.deleteAction),
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
    _selectedDayOfWeek = course.dayOfWeek;
    _startSection = course.startSection;
    _endSection = course.endSection;
    _startWeek = course.startWeek;
    _endWeek = course.endWeek;
    _isOddWeek = course.isOddWeek;
    _isEvenWeek = course.isEvenWeek;
    final customWeeks = course.normalizedCustomWeeks;
    if (customWeeks != null) {
      _weekSelectionMode = _WeekSelectionMode.custom;
      _selectedCustomWeeks = customWeeks.toSet();
    }
    final activeWeeks = course.activeWeeks;
    if (activeWeeks.length == 1) {
      _editorMode = CourseEditorMode.singleLesson;
      _singleWeek = activeWeeks.first;
    }
    _courseNature = course.courseNature;
    _selectedColor = course.color;
    _selectedTimeSchemeOverrideId = course.timeSchemeIdOverride;
  }

  void _normalizeSections(TimetableSettings settings) {
    final maxSection = settings.sectionCount;
    if (_startSection > maxSection) {
      _startSection = maxSection;
    }
    if (_endSection > maxSection) {
      _endSection = maxSection;
    }
    if (_endSection < _startSection) {
      _endSection = _startSection;
    }
  }

  void _normalizeWeeks(TimetableSettings settings) {
    final maxWeek = settings.semesterWeekCount;
    if (_startWeek > maxWeek) {
      _startWeek = maxWeek;
    }
    if (_endWeek > maxWeek) {
      _endWeek = maxWeek;
    }
    if (_startWeek < 1) {
      _startWeek = 1;
    }
    if (_endWeek < _startWeek) {
      _endWeek = _startWeek;
    }

    if (_selectedCustomWeeks.isNotEmpty) {
      _selectedCustomWeeks = _selectedCustomWeeks
          .where((week) => week >= 1 && week <= maxWeek)
          .toSet();
    }
    if (_weekSelectionMode == _WeekSelectionMode.custom &&
        _selectedCustomWeeks.isEmpty) {
      _selectedCustomWeeks = {_startWeek.clamp(1, maxWeek)};
    }
  }

  void _normalizeSingleWeek(TimetableSettings settings) {
    final maxWeek = settings.semesterWeekCount;
    if (_singleWeek < 1) {
      _singleWeek = 1;
    }
    if (_singleWeek > maxWeek) {
      _singleWeek = maxWeek;
    }
  }

  String _resolveTitle() {
    final l10n = AppLocalizations.of(context)!;
    if (_isGroupEditing) {
      return widget.courseGroup != null || widget.course != null
          ? l10n.editCourseTitle
          : l10n.addCourseTitle;
    }
    if (widget.course != null) {
      return _editorMode == CourseEditorMode.singleLesson
          ? l10n.editSingleLessonTitle
          : l10n.editCourseTitle;
    }
    return _editorMode == CourseEditorMode.singleLesson
        ? l10n.addSingleLessonTitle
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
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: l10n.manualInputLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                controller.clear();
                                setSheetState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                    onSubmitted: (_) {
                      confirmed = true;
                      onEntrySync?.call();
                      Navigator.pop(sheetContext);
                    },
                  ),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(l10n.historyRecordsLabel,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                    Text(l10n.noHistoryRecords,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
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
    final followLabel = provider.activeTimeScheme?.name ?? l10n.timetableAppName;

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
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: Text(l10n.manageTimeSchemesAction),
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                  name: '/settings/time-schemes'),
                              builder: (_) =>
                                  const TimeSchemeManagementScreen(),
                            ),
                          );
                          // Refresh state after returning from management screen.
                          if (mounted) setState(() {});
                        },
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
                            title: l10n.followCurrentTimetableWithName(followLabel),
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
                                  icon: const Icon(Icons.edit_rounded, size: 20),
                                  tooltip: l10n.editTimeSchemeTitle,
                                  onPressed: () async {
                                    Navigator.pop(sheetContext);
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        settings: const RouteSettings(
                                            name: '/settings/time-schemes'),
                                        builder: (_) => TimeSchemeManagementScreen(
                                              initialEditSchemeId: scheme.id,
                                            ),
                                      ),
                                    );
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
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.createTimeSchemeTitle),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                                name: '/settings/time-schemes'),
                            builder: (_) => const TimeSchemeManagementScreen(),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
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
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildGroupEditingBody(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        _buildGroupSharedInfoSection(l10n),
        const SizedBox(height: 6),
        for (var i = 0; i < _scheduleEntries.length; i++) ...[
          _buildScheduleEntryCard(provider, settings, i, l10n),
          if (i < _scheduleEntries.length - 1) const SizedBox(height: 4),
        ],
        _buildAddScheduleEntryButton(l10n),
      ],
    );
  }

  Widget _buildGroupSharedInfoSection(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sharedInfoTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: l10n.courseNameLabel,
                helperText: l10n.courseNameHelper,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book_outlined, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterCourseName;
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shortNameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l10n.courseShortNameOptional,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.short_text_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<CourseNature>(
                    isExpanded: true,
                    initialValue: _courseNature,
                    decoration: InputDecoration(
                      labelText: l10n.courseNatureLabel,
                      border: OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: CourseNature.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label, style: const TextStyle(fontSize: 13)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _courseNature = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: l10n.courseDescriptionOptional,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              maxLines: null,
            ),
            const SizedBox(height: 10),
            _buildGroupColorPicker(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupColorPicker(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.courseColorTitle,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colors.map((color) {
            final isSelected = color == _selectedColor;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _parseColor(color),
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Colors.black, width: 3)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showCustomColorPicker,
          icon: const Icon(Icons.palette_outlined, size: 18),
          label: Text(l10n.customPaletteAction),
        ),
      ],
    );
  }

  // Shared compact input decoration for schedule entry fields.
  InputDecoration _compactInputDecoration({
    required String labelText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18)
          : null,
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildScheduleEntryCard(
    TimetableProvider provider,
    TimetableSettings settings,
    int index,
    AppLocalizations l10n,
  ) {
    final entry = _scheduleEntries[index];
    final weekDays = _weekdayLabels(l10n);
    final sectionNumbers =
        List.generate(settings.sectionCount, (i) => i + 1);
    final availableWeeks = settings.availableWeeks;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: title + time scheme + delete ──
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  l10n.scheduleEntryTitle(index + 1),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_scheduleEntries.length > 1)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: colorScheme.error),
                      tooltip: l10n.deleteScheduleEntryAction,
                      padding: EdgeInsets.zero,
                      onPressed: () => _removeScheduleEntry(index),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Time scheme ──
            _buildEntryTimeSchemeDropdown(provider, index, l10n),
            const SizedBox(height: 8),
            // ── Row: Weekday + Start section + End section ──
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: entry.dayOfWeek,
                    decoration: _compactInputDecoration(
                      labelText: l10n.weekdayLabel,
                    ),
                    items: List.generate(weekDays.length, (i) {
                      return DropdownMenuItem(
                        value: i + 1,
                        child: Text(weekDays[i],
                            style: const TextStyle(fontSize: 13)),
                      );
                    }),
                    onChanged: (value) {
                      setState(() => entry.dayOfWeek = value!);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: entry.startSection,
                    decoration: _compactInputDecoration(
                      labelText: l10n.startSectionLabel,
                    ),
                    items: sectionNumbers.map((section) {
                      return DropdownMenuItem(
                        value: section,
                        child: Text(l10n.sectionLabel(section),
                            style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        entry.startSection = value!;
                        if (entry.endSection < entry.startSection) {
                          entry.endSection = entry.startSection;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: entry.endSection,
                    decoration: _compactInputDecoration(
                      labelText: l10n.endSectionLabel,
                    ),
                    items: sectionNumbers
                        .where((s) => s >= entry.startSection)
                        .map((section) {
                      return DropdownMenuItem(
                        value: section,
                        child: Text(l10n.sectionLabel(section),
                            style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => entry.endSection = value!);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Row: Teacher + Location ──
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _entryTeacherControllers[index],
                    readOnly: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: _compactInputDecoration(
                      labelText: l10n.teacherLabel,
                      prefixIcon: Icons.person_outline_rounded,
                      suffixIcon: const Icon(Icons.arrow_drop_down_rounded,
                          size: 20),
                    ),
                    onTap: () => _showPickerSheet(
                      title: l10n.selectTeacherTitle,
                      suggestions: provider.uniqueTeachers,
                      controller: _entryTeacherControllers[index],
                      onEntrySync: () => entry.teacher =
                          _entryTeacherControllers[index].text,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    controller: _entryLocationControllers[index],
                    readOnly: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: _compactInputDecoration(
                      labelText: l10n.locationLabel,
                      prefixIcon: Icons.location_on_outlined,
                      suffixIcon: const Icon(Icons.arrow_drop_down_rounded,
                          size: 20),
                    ),
                    onTap: () => _showPickerSheet(
                      title: l10n.selectLocationTitle,
                      suggestions: provider.uniqueLocations,
                      controller: _entryLocationControllers[index],
                      onEntrySync: () => entry.location =
                          _entryLocationControllers[index].text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Week selection summary ──
            Builder(
              builder: (context) {
                final entrySelectedWeeks =
                    entry.weekSelectionMode == _WeekSelectionMode.range
                        ? _buildEntryWeeksFromRange(entry)
                        : (entry.selectedCustomWeeks.toList()..sort());
                final entrySummary = _selectedWeeksSummaryText(
                  entrySelectedWeeks,
                  availableWeeks,
                  entry.startWeek,
                  entry.endWeek,
                  entry.isOddWeek,
                  entry.isEvenWeek,
                  entry.weekSelectionMode,
                  l10n,
                );
                return _buildWeekSummaryRow(
                  title: l10n.weekSettingsTitle,
                  summary: entrySummary,
                  onTap: () =>
                      _showEntryWeekPickerDialog(entry, availableWeeks, l10n),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTimeSchemeDropdown(
    TimetableProvider provider,
    int index,
    AppLocalizations l10n,
  ) {
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
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showTimeSchemePickerSheet(
        currentValue: entry.timeSchemeIdOverride,
        onSelected: (value) {
          setState(() {
            entry.timeSchemeIdOverride = value;
          });
        },
      ),
      child: InputDecorator(
        decoration: _compactInputDecoration(
          labelText: l10n.timeSchemeLabel,
          prefixIcon: Icons.schedule_rounded,
          suffixIcon:
              const Icon(Icons.arrow_drop_down_rounded, size: 20),
        ),
        child: Text(
          currentName,
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildSingleTimeSchemePicker(
    TimetableProvider provider,
    AppLocalizations l10n,
    String followLabel,
  ) {
    final currentName = _selectedTimeSchemeOverrideId == null
        ? l10n.followCurrentTimetableWithName(followLabel)
        : provider.timeSchemes
                .where((s) => s.id == _selectedTimeSchemeOverrideId)
                .firstOrNull
                ?.name ??
            l10n.followCurrentTimetableWithName(followLabel);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showTimeSchemePickerSheet(
        currentValue: _selectedTimeSchemeOverrideId,
        onSelected: (value) {
          setState(() {
            _selectedTimeSchemeOverrideId = value;
          });
        },
      ),
      child: InputDecorator(
        decoration: _compactInputDecoration(
          labelText: l10n.timeSchemeLabel,
          prefixIcon: Icons.schedule_rounded,
          suffixIcon:
              const Icon(Icons.arrow_drop_down_rounded, size: 20),
        ),
        child: Text(
          currentName,
          style: const TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildAddScheduleEntryButton(AppLocalizations l10n) {
    return OutlinedButton.icon(
      onPressed: _addScheduleEntry,
      icon: const Icon(Icons.add_rounded),
      label: Text(l10n.addScheduleEntryAction),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
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
        teacher: last?.teacher ?? '',
        location: last?.location ?? '',
      );
      _scheduleEntries.add(newEntry);
      _entryTeacherControllers.add(
          TextEditingController(text: newEntry.teacher));
      _entryLocationControllers.add(
          TextEditingController(text: newEntry.location));
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCourseTitle),
        content: Text(l10n.confirmDeleteCourseMessage(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<TimetableProvider>().deleteCourseGroup(name);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.courseDeleted)),
    );
    Navigator.pop(context);
  }

  Widget _buildModeSection(TimetableSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addMethodTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<CourseEditorMode>(
              segments: [
                ButtonSegment(
                  value: CourseEditorMode.singleLesson,
                  icon: Icon(Icons.looks_one_rounded),
                  label: Text(l10n.singleLessonLabel),
                ),
                ButtonSegment(
                  value: CourseEditorMode.recurring,
                  icon: Icon(Icons.view_week_rounded),
                  label: Text(l10n.recurringLessonLabel),
                ),
              ],
              selected: {_editorMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                final nextMode = selection.first;
                setState(() {
                  _editorMode = nextMode;
                  if (nextMode == CourseEditorMode.singleLesson) {
                    final fallbackWeek = widget.initialWeek ?? _startWeek;
                    _singleWeek =
                        fallbackWeek.clamp(1, settings.semesterWeekCount);
                    _weekSelectionMode = _WeekSelectionMode.custom;
                    _selectedCustomWeeks = {_singleWeek};
                    _startWeek = _singleWeek;
                    _endWeek = _singleWeek;
                    _isOddWeek = false;
                    _isEvenWeek = false;
                  } else {
                    if (_selectedCustomWeeks.isNotEmpty) {
                      final sortedWeeks = _selectedCustomWeeks.toList()..sort();
                      _startWeek = sortedWeeks.first;
                      _endWeek = sortedWeeks.last;
                    }
                    _weekSelectionMode = _WeekSelectionMode.range;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              _editorMode == CourseEditorMode.singleLesson
                  ? l10n.singleLessonHint
                  : l10n.recurringLessonHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(TimetableProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final singleLessonTemplates = _buildSingleLessonTemplates(provider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sharedInfoTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (widget.course == null &&
                _editorMode == CourseEditorMode.singleLesson) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: singleLessonTemplates.any(
                  (template) => template.id == _selectedSingleLessonTemplateId,
                )
                    ? _selectedSingleLessonTemplateId
                    : _manualSingleLessonTemplateValue,
                decoration: InputDecoration(
                  labelText: l10n.reuseExistingCourseLabel,
                  helperText: l10n.reuseExistingCourseHelper,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.auto_awesome_motion_rounded),
                ),
                items: [
                  DropdownMenuItem(
                    value: _manualSingleLessonTemplateValue,
                    child: Text(
                      l10n.manualInputLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...singleLessonTemplates.map(
                    (template) => DropdownMenuItem(
                      value: template.id,
                      child: Text(
                        template.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                selectedItemBuilder: (context) => [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.manualInputLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...singleLessonTemplates.map(
                    (template) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        template.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedSingleLessonTemplateId = value;
                    if (value == _manualSingleLessonTemplateValue) {
                      return;
                    }
                    _SingleLessonTemplate? template;
                    for (final item in singleLessonTemplates) {
                      if (item.id == value) {
                        template = item;
                        break;
                      }
                    }
                    if (template != null) {
                      _applySingleLessonTemplate(template.course);
                    }
                  });
                },
              ),
              if (singleLessonTemplates.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.noTemplateCoursesHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: l10n.courseNameLabel,
                helperText: l10n.courseNameHelper,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book_outlined, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterCourseName;
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _shortNameController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: l10n.courseShortNameOptional,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.short_text_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _teacherController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: l10n.teacherLabel,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                      suffixIcon: Icon(Icons.arrow_drop_down_rounded, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onTap: () => _showPickerSheet(
                      title: l10n.selectTeacherTitle,
                      suggestions: provider.uniqueTeachers,
                      controller: _teacherController,
                      onEntrySync: null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<CourseNature>(
                    isExpanded: true,
                    initialValue: _courseNature,
                    decoration: InputDecoration(
                      labelText: l10n.courseNatureLabel,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: CourseNature.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label, style: const TextStyle(fontSize: 13)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _courseNature = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: l10n.courseDescriptionOptional,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              maxLines: null,
            ),
          ],
        ),
      ),
    );
  }

  List<_SingleLessonTemplate> _buildSingleLessonTemplates(
    TimetableProvider provider,
  ) {
    if (provider.courses.isEmpty) {
      return const <_SingleLessonTemplate>[];
    }

    final uniqueCourses = <String, Course>{};
    final sortedCourses = provider.courses.toList()
      ..sort((left, right) {
        final nameCompare = left.name.compareTo(right.name);
        if (nameCompare != 0) {
          return nameCompare;
        }
        final dayCompare = left.dayOfWeek.compareTo(right.dayOfWeek);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return left.startSection.compareTo(right.startSection);
      });

    for (final course in sortedCourses) {
      final key = course.name.trim().toLowerCase();
      uniqueCourses.putIfAbsent(key, () => course);
    }

    return uniqueCourses.values
        .map(
          (course) => _SingleLessonTemplate(
            id: course.id,
            course: course,
            summary: _buildSingleLessonTemplateSummary(course),
          ),
        )
        .toList(growable: false);
  }

  String _buildSingleLessonTemplateSummary(Course course) {
    final parts = <String>[course.name];
    final shortName = course.shortName?.trim();
    final teacher = course.teacher.trim();

    if (shortName != null &&
        shortName.isNotEmpty &&
        shortName.toLowerCase() != course.name.trim().toLowerCase()) {
      parts.add(shortName);
    }
    if (teacher.isNotEmpty) {
      parts.add(teacher);
    }

    return parts.join(' · ');
  }

  void _applySingleLessonTemplate(Course course) {
    _nameController.text = course.name;
    _shortNameController.text = course.shortName ?? '';
    _teacherController.text = course.teacher;
    _descriptionController.text = course.description ?? course.note ?? '';
    _courseNature = course.courseNature;
    _selectedColor = course.color;
  }

  Widget _buildResponsiveFieldPair({
    required Widget leading,
    required Widget trailing,
    double spacing = 16,
    double breakpoint = 360,
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

  _RangeWeekFilter get _rangeWeekFilter {
    if (_isOddWeek) {
      return _RangeWeekFilter.odd;
    }
    if (_isEvenWeek) {
      return _RangeWeekFilter.even;
    }
    return _RangeWeekFilter.all;
  }

  Widget _buildRangeWeekFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: colorScheme.primaryContainer,
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
      ),
      onSelected: (_) => onPressed(),
    );
  }

  Widget _buildTimeSection(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final weekDays = _weekdayLabels(l10n);
    final sectionNumbers =
        List.generate(settings.sectionCount, (index) => index + 1);
    final selectedScheme = _resolveSelectedTimeScheme(provider);
    final validationMessage = provider.validateCourseTimeSchemeOverride(
      timeSchemeId: _selectedTimeSchemeOverrideId,
      startSection: _startSection,
      endSection: _endSection,
    );
    final effectiveScheme = validationMessage == null ? selectedScheme : null;
    final fallbackStartSection = settings.sectionAt(_startSection);
    final fallbackEndSection = settings.sectionAt(_endSection);
    final startTime = effectiveScheme == null
        ? fallbackStartSection.startTime
        : effectiveScheme.sections[_startSection - 1].startTime;
    final endTime = effectiveScheme == null
        ? fallbackEndSection.endTime
        : effectiveScheme.sections[_endSection - 1].endTime;
    final followLabel =
        provider.activeTimeScheme?.name ?? AppLocalizations.of(context)!.timetableAppName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.currentScheduleTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            // Time scheme
            _buildSingleTimeSchemePicker(provider, l10n, followLabel),
            if (validationMessage != null) ...[
              const SizedBox(height: 4),
              Text(validationMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 11)),
            ],
            const SizedBox(height: 10),
            // Row: Weekday + Start section + End section
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _selectedDayOfWeek,
                    decoration: _compactInputDecoration(
                      labelText: l10n.weekdayLabel,
                    ),
                    items: List.generate(weekDays.length, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(weekDays[index], style: const TextStyle(fontSize: 13)),
                      );
                    }),
                    onChanged: (value) {
                      setState(() => _selectedDayOfWeek = value!);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _startSection,
                    decoration: _compactInputDecoration(
                      labelText: l10n.startSectionLabel,
                    ),
                    items: sectionNumbers.map((section) {
                      return DropdownMenuItem(
                        value: section,
                        child: Text(l10n.sectionLabel(section), style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _startSection = value!;
                        if (_endSection < _startSection) _endSection = _startSection;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _endSection,
                    decoration: _compactInputDecoration(
                      labelText: l10n.endSectionLabel,
                    ),
                    items: sectionNumbers
                        .where((section) => section >= _startSection)
                        .map((section) {
                      return DropdownMenuItem(
                        value: section,
                        child: Text(l10n.sectionLabel(section), style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _endSection = value!);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.timeRangeLabel(startTime, endTime),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 10),
            // Location
            TextFormField(
              controller: _locationController,
              readOnly: true,
              style: const TextStyle(fontSize: 13),
              decoration: _compactInputDecoration(
                labelText: l10n.locationLabel,
                prefixIcon: Icons.location_on_outlined,
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
              ),
              onTap: () => _showPickerSheet(
                title: l10n.selectLocationTitle,
                suggestions: provider.uniqueLocations,
                controller: _locationController,
                onEntrySync: null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSection() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.courseColorTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse('FF${color.replaceFirst('#', '')}',
                          radix: 16)),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showCustomColorPicker,
              icon: const Icon(Icons.palette_outlined),
              label: Text(l10n.customPaletteAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomColorPicker() async {
    final l10n = AppLocalizations.of(context)!;
    var selected = _parseColor(_selectedColor);
    final hexController = TextEditingController(text: _selectedColor);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
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
              final withHash =
                  normalized.startsWith('#') ? normalized : '#$normalized';
              updateFromColor(_parseColor(withHash));
            }

            final hsv = HSVColor.fromColor(selected);
            return AlertDialog(
              title: Text(l10n.colorPaletteTitle),
              content: SingleChildScrollView(
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
                        border: OutlineInputBorder(),
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
                          updateFromColor(
                            hsv.withHue(value).toColor(),
                          );
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
                          updateFromColor(
                            hsv.withSaturation(value).toColor(),
                          );
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
                          updateFromColor(
                            hsv.withValue(value).toColor(),
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancelAction),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _toHex(selected)),
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

  TimeScheme? _resolveSelectedTimeScheme(TimetableProvider provider) {
    if (_selectedTimeSchemeOverrideId == null) {
      return provider.activeTimeScheme;
    }

    for (final scheme in provider.timeSchemes) {
      if (scheme.id == _selectedTimeSchemeOverrideId) {
        return scheme;
      }
    }

    return null;
  }

  List<int> _buildWeeksFromRange() {
    final weeks = <int>[];
    for (var week = _startWeek; week <= _endWeek; week++) {
      if (_isOddWeek && week.isEven) {
        continue;
      }
      if (_isEvenWeek && week.isOdd) {
        continue;
      }
      weeks.add(week);
    }
    return weeks;
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
      final isAll = startWeek == availableWeeks.first &&
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
    if (selectedWeeks.length == availableWeeks.length) return l10n.allWeeksFilter;
    return _formatWeekList(selectedWeeks);
  }

  // ---------------------------------------------------------------------------
  // Week summary row (compact)
  // ---------------------------------------------------------------------------

  Widget _buildWeekSummaryRow({
    required String title,
    required String summary,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Single-week picker dialog
  // ---------------------------------------------------------------------------

  Widget _buildSingleWeekSummary(TimetableSettings settings, AppLocalizations l10n) {
    final availableWeeks = settings.availableWeeks;
    if (_editorMode == CourseEditorMode.singleLesson) {
      return _buildWeekSummaryRow(
        title: l10n.weekSettingsTitle,
        summary: l10n.weekLabel(_singleWeek),
        onTap: () => _showSingleWeekPickerDialog(settings, l10n),
      );
    }
    final selectedWeeks = _weekSelectionMode == _WeekSelectionMode.range
        ? _buildWeeksFromRange()
        : (_selectedCustomWeeks.toList()..sort());
    final summary = _selectedWeeksSummaryText(
      selectedWeeks, availableWeeks,
      _startWeek, _endWeek, _isOddWeek, _isEvenWeek,
      _weekSelectionMode, l10n,
    );
    return _buildWeekSummaryRow(
      title: l10n.weekSettingsTitle,
      summary: summary,
      onTap: () => _showSingleWeekPickerDialog(settings, l10n),
    );
  }

  Future<void> _showSingleWeekPickerDialog(
    TimetableSettings settings,
    AppLocalizations l10n,
  ) async {
    final availableWeeks = settings.availableWeeks;
    var tempMode = _weekSelectionMode;
    var tempStartWeek = _startWeek;
    var tempEndWeek = _endWeek;
    var tempIsOddWeek = _isOddWeek;
    var tempIsEvenWeek = _isEvenWeek;
    var tempCustomWeeks = Set<int>.from(_selectedCustomWeeks);
    var tempRangeFilter = _rangeWeekFilter;
    var tempSingleWeek = _singleWeek;

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
              child: Scaffold(
                appBar: AppBar(
                  title: Text(l10n.weekPickerTitle),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_editorMode == CourseEditorMode.singleLesson) ...[
                      DropdownButtonFormField<int>(
                        initialValue: tempSingleWeek,
                        decoration: InputDecoration(
                          labelText: l10n.selectWeekLabel,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event_note_rounded),
                        ),
                        items: availableWeeks
                            .map((week) => DropdownMenuItem(
                                  value: week,
                                  child: Text(l10n.weekLabel(week)),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => tempSingleWeek = value);
                        },
                      ),
                    ] else ...[
                    SegmentedButton<_WeekSelectionMode>(
                      segments: [
                        ButtonSegment(
                          value: _WeekSelectionMode.range,
                          label: Text(l10n.rangeWeeksLabel),
                          icon: Icon(Icons.linear_scale_rounded),
                        ),
                        ButtonSegment(
                          value: _WeekSelectionMode.custom,
                          label: Text(l10n.customWeeksLabel),
                          icon: Icon(Icons.apps_rounded),
                        ),
                      ],
                      selected: {tempMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        final nextMode = selection.first;
                        setDialogState(() {
                          if (nextMode == _WeekSelectionMode.custom &&
                              tempCustomWeeks.isEmpty) {
                            tempCustomWeeks = buildTempWeeksFromRange().toSet();
                            if (tempCustomWeeks.isEmpty) {
                              tempCustomWeeks = {tempStartWeek};
                            }
                          }
                          if (nextMode == _WeekSelectionMode.range &&
                              tempCustomWeeks.isNotEmpty) {
                            final sorted = tempCustomWeeks.toList()..sort();
                            tempStartWeek = sorted.first;
                            tempEndWeek = sorted.last;
                            tempIsOddWeek = false;
                            tempIsEvenWeek = false;
                          }
                          tempMode = nextMode;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (tempMode == _WeekSelectionMode.range) ...[
                      _buildResponsiveFieldPair(
                        leading: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: tempStartWeek,
                          decoration: InputDecoration(
                            labelText: l10n.startWeekLabel,
                            border: OutlineInputBorder(),
                          ),
                          items: availableWeeks.map((week) {
                            return DropdownMenuItem(
                              value: week,
                              child: Text(l10n.weekLabel(week)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              tempStartWeek = value!;
                              if (tempEndWeek < tempStartWeek) {
                                tempEndWeek = tempStartWeek;
                              }
                            });
                          },
                        ),
                        trailing: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: tempEndWeek,
                          decoration: InputDecoration(
                            labelText: l10n.endWeekLabel,
                            border: OutlineInputBorder(),
                          ),
                          items: availableWeeks
                              .where((week) => week >= tempStartWeek)
                              .map((week) {
                            return DropdownMenuItem(
                              value: week,
                              child: Text(l10n.weekLabel(week)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => tempEndWeek = value!);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildRangeWeekFilterChip(
                            label: l10n.allWeeksFilter,
                            selected: tempRangeFilter == _RangeWeekFilter.all,
                            onPressed: () {
                              setDialogState(() {
                                tempRangeFilter = _RangeWeekFilter.all;
                                tempIsOddWeek = false;
                                tempIsEvenWeek = false;
                              });
                            },
                          ),
                          _buildRangeWeekFilterChip(
                            label: l10n.oddWeeksFilter,
                            selected: tempRangeFilter == _RangeWeekFilter.odd,
                            onPressed: () {
                              setDialogState(() {
                                tempRangeFilter = _RangeWeekFilter.odd;
                                tempIsOddWeek = true;
                                tempIsEvenWeek = false;
                              });
                            },
                          ),
                          _buildRangeWeekFilterChip(
                            label: l10n.evenWeeksFilter,
                            selected: tempRangeFilter == _RangeWeekFilter.even,
                            onPressed: () {
                              setDialogState(() {
                                tempRangeFilter = _RangeWeekFilter.even;
                                tempIsOddWeek = false;
                                tempIsEvenWeek = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final theme = Theme.of(context);
                          final colorScheme = theme.colorScheme;
                          final width = constraints.maxWidth;
                          final crossAxisCount =
                              width < 340 ? 4 : width < 420 ? 5 : 6;
                          final availableWidth =
                              width - (crossAxisCount - 1) * 8;
                          final tileWidth = availableWidth / crossAxisCount;
                          final targetMinHeight = width < 340 ? 46.0 : 44.0;
                          final childAspectRatio = tileWidth / targetMinHeight;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: availableWeeks.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemBuilder: (context, index) {
                              final week = availableWeeks[index];
                              final isSelected =
                                  tempCustomWeeks.contains(week);
                              return FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 44),
                                  tapTargetSize:
                                      MaterialTapTargetSize.padded,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 10),
                                  backgroundColor: isSelected
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  foregroundColor: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                  side: BorderSide(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
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
                                  style: theme.textTheme.titleSmall?.copyWith(
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
                                tempCustomWeeks = availableWeeks.toSet();
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
                    ], // close else
                    const SizedBox(height: 12),
                    Text(
                      l10n.selectedWeeksSummary(
                        selectedWeeks.length,
                        _formatWeekList(selectedWeeks),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                bottomNavigationBar: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.cancelAction),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.confirmAction),
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
      if (_editorMode == CourseEditorMode.singleLesson) {
        _singleWeek = tempSingleWeek;
      }
      _weekSelectionMode = tempMode;
      _startWeek = tempStartWeek;
      _endWeek = tempEndWeek;
      _isOddWeek = tempIsOddWeek;
      _isEvenWeek = tempIsEvenWeek;
      _selectedCustomWeeks = tempCustomWeeks;
      _isOddWeek = tempRangeFilter == _RangeWeekFilter.odd;
      _isEvenWeek = tempRangeFilter == _RangeWeekFilter.even;
    });
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
              child: Scaffold(
                appBar: AppBar(
                  title: Text(l10n.weekPickerTitle),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SegmentedButton<_WeekSelectionMode>(
                      segments: [
                        ButtonSegment(
                          value: _WeekSelectionMode.range,
                          label: Text(l10n.rangeWeeksLabel),
                          icon: Icon(Icons.linear_scale_rounded),
                        ),
                        ButtonSegment(
                          value: _WeekSelectionMode.custom,
                          label: Text(l10n.customWeeksLabel),
                          icon: Icon(Icons.apps_rounded),
                        ),
                      ],
                      selected: {tempMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        final nextMode = selection.first;
                        setDialogState(() {
                          if (nextMode == _WeekSelectionMode.custom &&
                              tempCustomWeeks.isEmpty) {
                            tempCustomWeeks = buildTempWeeksFromRange().toSet();
                            if (tempCustomWeeks.isEmpty) {
                              tempCustomWeeks = {tempStartWeek};
                            }
                          }
                          if (nextMode == _WeekSelectionMode.range &&
                              tempCustomWeeks.isNotEmpty) {
                            final sorted = tempCustomWeeks.toList()..sort();
                            tempStartWeek = sorted.first;
                            tempEndWeek = sorted.last;
                            tempIsOddWeek = false;
                            tempIsEvenWeek = false;
                          }
                          tempMode = nextMode;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (tempMode == _WeekSelectionMode.range) ...[
                      _buildResponsiveFieldPair(
                        leading: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: tempStartWeek,
                          decoration: InputDecoration(
                            labelText: l10n.startWeekLabel,
                            border: OutlineInputBorder(),
                          ),
                          items: availableWeeks.map((week) {
                            return DropdownMenuItem(
                              value: week,
                              child: Text(l10n.weekLabel(week)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              tempStartWeek = value!;
                              if (tempEndWeek < tempStartWeek) {
                                tempEndWeek = tempStartWeek;
                              }
                            });
                          },
                        ),
                        trailing: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: tempEndWeek,
                          decoration: InputDecoration(
                            labelText: l10n.endWeekLabel,
                            border: OutlineInputBorder(),
                          ),
                          items: availableWeeks
                              .where((w) => w >= tempStartWeek)
                              .map((week) {
                            return DropdownMenuItem(
                              value: week,
                              child: Text(l10n.weekLabel(week)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => tempEndWeek = value!);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(l10n.allWeeksFilter),
                            selected: !tempIsOddWeek && !tempIsEvenWeek,
                            showCheckmark: false,
                            selectedColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            onSelected: (_) {
                              setDialogState(() {
                                tempIsOddWeek = false;
                                tempIsEvenWeek = false;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text(l10n.oddWeeksFilter),
                            selected: tempIsOddWeek,
                            showCheckmark: false,
                            selectedColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            onSelected: (_) {
                              setDialogState(() {
                                tempIsOddWeek = true;
                                tempIsEvenWeek = false;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text(l10n.evenWeeksFilter),
                            selected: tempIsEvenWeek,
                            showCheckmark: false,
                            selectedColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            onSelected: (_) {
                              setDialogState(() {
                                tempIsOddWeek = false;
                                tempIsEvenWeek = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final theme = Theme.of(context);
                          final colorScheme = theme.colorScheme;
                          final width = constraints.maxWidth;
                          final crossAxisCount =
                              width < 340 ? 4 : width < 420 ? 5 : 6;
                          final availableWidth =
                              width - (crossAxisCount - 1) * 8;
                          final tileWidth = availableWidth / crossAxisCount;
                          final targetMinHeight = width < 340 ? 46.0 : 44.0;
                          final childAspectRatio = tileWidth / targetMinHeight;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
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
                              final isSelected =
                                  tempCustomWeeks.contains(week);
                              return FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 44),
                                  tapTargetSize:
                                      MaterialTapTargetSize.padded,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 10),
                                  backgroundColor: isSelected
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  foregroundColor: isSelected
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                  side: BorderSide(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
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
                                  style: theme.textTheme.titleSmall?.copyWith(
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
                                tempCustomWeeks = availableWeeks.toSet();
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
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                bottomNavigationBar: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.cancelAction),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.confirmAction),
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

    if (_isGroupEditing) {
      await _saveGroup(provider, settings, l10n);
    } else {
      await _saveSingle(provider, settings, l10n);
    }
  }

  Future<void> _saveGroup(
    TimetableProvider provider,
    TimetableSettings settings,
    AppLocalizations l10n,
  ) async {
    final name = _nameController.text;
    final shortName =
        _shortNameController.text.isEmpty ? null : _shortNameController.text;
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

      courses.add(entry.toCourse(
        name: name,
        shortName: shortName,
        color: _selectedColor,
        courseNature: _courseNature,
        description: description,
        startTime: startTime,
        endTime: endTime,
      ));
    }

    try {
      if (widget.courseGroup != null) {
        // Editing existing group: replace all entries.
        await provider.updateCourseGroup(
          widget.courseGroup!.name,
          courses,
        );
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

  Future<void> _saveSingle(
    TimetableProvider provider,
    TimetableSettings settings,
    AppLocalizations l10n,
  ) async {
    final validationMessage = provider.validateCourseTimeSchemeOverride(
      timeSchemeId: _selectedTimeSchemeOverrideId,
      startSection: _startSection,
      endSection: _endSection,
    );
    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationMessage)),
      );
      return;
    }

    List<int>? customWeeks;
    if (_editorMode == CourseEditorMode.singleLesson) {
      customWeeks = [_singleWeek];
    } else if (_weekSelectionMode == _WeekSelectionMode.custom) {
      final selectedWeeks = _selectedCustomWeeks.toList()..sort();
      if (selectedWeeks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.selectAtLeastOneWeek)),
        );
        return;
      }
      customWeeks = selectedWeeks;
    }

    final selectedScheme = _resolveSelectedTimeScheme(provider);
    final startTime = selectedScheme == null
        ? settings.sectionAt(_startSection).startTime
        : selectedScheme.sections[_startSection - 1].startTime;
    final endTime = selectedScheme == null
        ? settings.sectionAt(_endSection).endTime
        : selectedScheme.sections[_endSection - 1].endTime;

    final course = Course(
      id: widget.course?.id ?? const Uuid().v4(),
      name: _nameController.text,
      shortName:
          _shortNameController.text.isEmpty ? null : _shortNameController.text,
      teacher: _teacherController.text,
      location: _locationController.text,
      dayOfWeek: _selectedDayOfWeek,
      startSection: _startSection,
      endSection: _endSection,
      startTime: startTime,
      endTime: endTime,
      color: _selectedColor,
      startWeek: customWeeks == null ? _startWeek : customWeeks.first,
      endWeek: customWeeks == null ? _endWeek : customWeeks.last,
      isOddWeek: customWeeks == null ? _isOddWeek : false,
      isEvenWeek: customWeeks == null ? _isEvenWeek : false,
      customWeeks: customWeeks,
      courseNature: _courseNature,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      timeSchemeIdOverride: _selectedTimeSchemeOverrideId,
    );

    try {
      if (widget.course == null) {
        await provider.addCourse(course);
      } else {
        await provider.updateCourse(
          course,
          previousSharedName: widget.course!.name,
        );
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
          widget.course == null
              ? l10n.courseAddedSuccess
              : l10n.courseUpdatedSuccess,
        ),
      ),
    );
    Navigator.pop(context);
  }
}

class _SingleLessonTemplate {
  final String id;
  final Course course;
  final String summary;

  const _SingleLessonTemplate({
    required this.id,
    required this.course,
    required this.summary,
  });
}

