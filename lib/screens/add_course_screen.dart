import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';

enum _WeekSelectionMode { range, custom }

enum _RangeWeekFilter { all, odd, even }

enum CourseEditorMode { singleLesson, recurring }

class AddCourseScreen extends StatefulWidget {
  final Course? course;
  final int? initialDayOfWeek;
  final int? initialStartSection;
  final int? initialWeek;
  final CourseEditorMode mode;

  const AddCourseScreen({
    super.key,
    this.course,
    this.initialDayOfWeek,
    this.initialStartSection,
    this.initialWeek,
    this.mode = CourseEditorMode.recurring,
  });

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
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

  static const String _followProfileTimeSchemeValue = '__follow_profile__';

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
    if (widget.course != null) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final settings = provider.settings;
    _normalizeSections(settings);
    _normalizeWeeks(settings);
    _normalizeSingleWeek(settings);

    return Scaffold(
      appBar: AppBar(
        title: Text(_resolveTitle()),
        actions: [
          if (widget.course != null)
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.course == null) ...[
              _buildModeSection(settings),
              const SizedBox(height: 16),
            ],
            _buildBasicInfoSection(provider),
            const SizedBox(height: 16),
            _buildTimeSection(provider, settings),
            const SizedBox(height: 16),
            _buildWeekSection(settings),
            const SizedBox(height: 16),
            _buildColorSection(),
          ],
        ),
      ),
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
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.courseDeleted)),
    );
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
    if (widget.course != null) {
      return _editorMode == CourseEditorMode.singleLesson
          ? AppLocalizations.of(context)!.editSingleLessonTitle
          : AppLocalizations.of(context)!.editCourseTitle;
    }
    return _editorMode == CourseEditorMode.singleLesson
        ? AppLocalizations.of(context)!.addSingleLessonTitle
        : AppLocalizations.of(context)!.addCourseTitle;
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sharedInfoTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sharedInfoHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.course == null &&
                _editorMode == CourseEditorMode.singleLesson) ...[
              const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.courseNameLabel,
                helperText: l10n.courseNameHelper,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterCourseName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shortNameController,
              decoration: InputDecoration(
                labelText: l10n.courseShortNameOptional,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.short_text),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _teacherController,
              decoration: InputDecoration(
                labelText: l10n.teacherLabel,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CourseNature>(
              initialValue: _courseNature,
              decoration: InputDecoration(
                labelText: l10n.courseNatureLabel,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bookmark_added_outlined),
              ),
              items: CourseNature.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _courseNature = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.courseDescriptionOptional,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_rounded),
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

  void _setRangeWeekFilter(_RangeWeekFilter filter) {
    setState(() {
      _isOddWeek = filter == _RangeWeekFilter.odd;
      _isEvenWeek = filter == _RangeWeekFilter.even;
    });
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.currentScheduleTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.currentScheduleSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedTimeSchemeOverrideId ??
                  _followProfileTimeSchemeValue,
              decoration: InputDecoration(
                labelText: l10n.timeSchemeLabel,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              items: [
                DropdownMenuItem(
                  value: _followProfileTimeSchemeValue,
                  child: Text(
                    l10n.followCurrentTimetableWithName(followLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...provider.timeSchemes.map(
                  (scheme) => DropdownMenuItem(
                    value: scheme.id,
                    child: Text(
                      scheme.name,
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
                    l10n.followCurrentTimetableWithName(followLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...provider.timeSchemes.map(
                  (scheme) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      scheme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTimeSchemeOverrideId =
                      value == null || value == _followProfileTimeSchemeValue
                          ? null
                          : value;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTimeSchemeOverrideId == null
                  ? l10n.followCurrentTimetableDescription
                  : l10n.overrideTimeSchemeDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                validationMessage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedDayOfWeek,
              decoration: InputDecoration(
                labelText: l10n.weekdayLabel,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: List.generate(weekDays.length, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(weekDays[index]),
                );
              }),
              onChanged: (value) {
                setState(() {
                  _selectedDayOfWeek = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildResponsiveFieldPair(
              leading: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _startSection,
                decoration: InputDecoration(
                  labelText: l10n.startSectionLabel,
                  border: OutlineInputBorder(),
                ),
                items: sectionNumbers.map((section) {
                  return DropdownMenuItem(
                    value: section,
                    child: Text(l10n.sectionLabel(section)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _startSection = value!;
                    if (_endSection < _startSection) {
                      _endSection = _startSection;
                    }
                  });
                },
              ),
              trailing: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _endSection,
                decoration: InputDecoration(
                  labelText: l10n.endSectionLabel,
                  border: OutlineInputBorder(),
                ),
                items: sectionNumbers
                    .where((section) => section >= _startSection)
                    .map((section) {
                  return DropdownMenuItem(
                    value: section,
                    child: Text(l10n.sectionLabel(section)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _endSection = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.timeRangeLabel(startTime, endTime),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.locationLabel,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSection(TimetableSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    final availableWeeks = settings.availableWeeks;
    final selectedWeeks = _selectedCustomWeeks.toList()..sort();
    if (_editorMode == CourseEditorMode.singleLesson) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.singleLessonWeekTitle,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.singleLessonWeekSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _singleWeek,
                decoration: InputDecoration(
                  labelText: l10n.selectWeekLabel,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event_note_rounded),
                ),
                items: availableWeeks
                    .map(
                      (week) => DropdownMenuItem(
                        value: week,
                        child: Text(l10n.weekLabel(week)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _singleWeek = value;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.weekSettingsTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
              selected: {_weekSelectionMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                final nextMode = selection.first;
                setState(() {
                  if (nextMode == _WeekSelectionMode.custom &&
                      _selectedCustomWeeks.isEmpty) {
                    _selectedCustomWeeks = _buildWeeksFromRange().toSet();
                    if (_selectedCustomWeeks.isEmpty) {
                      _selectedCustomWeeks = {_startWeek};
                    }
                  }
                  if (nextMode == _WeekSelectionMode.range &&
                      _selectedCustomWeeks.isNotEmpty) {
                    final sortedWeeks = _selectedCustomWeeks.toList()..sort();
                    _startWeek = sortedWeeks.first;
                    _endWeek = sortedWeeks.last;
                    _isOddWeek = false;
                    _isEvenWeek = false;
                  }
                  _weekSelectionMode = nextMode;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_weekSelectionMode == _WeekSelectionMode.range) ...[
              _buildResponsiveFieldPair(
                leading: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _startWeek,
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
                    setState(() {
                      _startWeek = value!;
                      if (_endWeek < _startWeek) {
                        _endWeek = _startWeek;
                      }
                    });
                  },
                ),
                trailing: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _endWeek,
                  decoration: InputDecoration(
                    labelText: l10n.endWeekLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: availableWeeks
                      .where((week) => week >= _startWeek)
                      .map((week) {
                    return DropdownMenuItem(
                      value: week,
                      child: Text(l10n.weekLabel(week)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _endWeek = value!;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildResponsiveFieldPair(
                leading: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildRangeWeekFilterChip(
                      label: l10n.allWeeksFilter,
                      selected: _rangeWeekFilter == _RangeWeekFilter.all,
                      onPressed: () => _setRangeWeekFilter(_RangeWeekFilter.all),
                    ),
                    _buildRangeWeekFilterChip(
                      label: l10n.oddWeeksFilter,
                      selected: _rangeWeekFilter == _RangeWeekFilter.odd,
                      onPressed: () => _setRangeWeekFilter(_RangeWeekFilter.odd),
                    ),
                    _buildRangeWeekFilterChip(
                      label: l10n.evenWeeksFilter,
                      selected: _rangeWeekFilter == _RangeWeekFilter.even,
                      onPressed: () => _setRangeWeekFilter(_RangeWeekFilter.even),
                    ),
                  ],
                ),
                trailing: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _rangeWeekFilter == _RangeWeekFilter.all
                        ? l10n.rangeWeeksAllHint
                        : _rangeWeekFilter == _RangeWeekFilter.odd
                            ? l10n.rangeWeeksOddHint
                            : l10n.rangeWeeksEvenHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ] else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final theme = Theme.of(context);
                  final colorScheme = theme.colorScheme;
                  final width = constraints.maxWidth;
                  final crossAxisCount = width < 340
                      ? 4
                      : width < 420
                          ? 5
                          : 6;
                  final availableWidth = width - (crossAxisCount - 1) * 8;
                  final tileWidth = availableWidth / crossAxisCount;
                  final targetMinHeight = width < 340 ? 46.0 : 44.0;
                  final childAspectRatio = tileWidth / targetMinHeight;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: availableWeeks.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final week = availableWeeks[index];
                      final isSelected = _selectedCustomWeeks.contains(week);
                      return FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 44),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
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
                          setState(() {
                            if (isSelected) {
                              if (_selectedCustomWeeks.length > 1) {
                                _selectedCustomWeeks.remove(week);
                              }
                            } else {
                              _selectedCustomWeeks.add(week);
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
                      setState(() {
                        _selectedCustomWeeks = availableWeeks.toSet();
                      });
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.selectOddWeeksAction),
                    onPressed: () {
                      setState(() {
                        _selectedCustomWeeks =
                            availableWeeks.where((week) => week.isOdd).toSet();
                      });
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.selectEvenWeeksAction),
                    onPressed: () {
                      setState(() {
                        _selectedCustomWeeks =
                            availableWeeks.where((week) => week.isEven).toSet();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.selectedWeeksSummary(
                  selectedWeeks.length,
                  _formatWeekList(selectedWeeks),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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

  Future<void> _saveCourse(
    TimetableProvider provider,
    TimetableSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 16));

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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? l10n.saveFailed)),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.course == null
              ? l10n.courseAddedSuccess
              : l10n.courseUpdatedSuccess,
        ),
      ),
    );
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

