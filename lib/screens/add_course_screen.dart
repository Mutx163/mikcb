import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';

enum _WeekSelectionMode { range, custom }

class AddCourseScreen extends StatefulWidget {
  final Course? course;
  final int? initialDayOfWeek;
  final int? initialStartSection;

  const AddCourseScreen({
    super.key,
    this.course,
    this.initialDayOfWeek,
    this.initialStartSection,
  });

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
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
  bool _isOddWeek = false;
  bool _isEvenWeek = false;
  _WeekSelectionMode _weekSelectionMode = _WeekSelectionMode.range;
  Set<int> _selectedCustomWeeks = <int>{};
  CourseNature _courseNature = CourseNature.required;
  String _selectedColor = '#2196F3';
  String? _selectedTimeSchemeOverrideId;

  static const String _followProfileTimeSchemeValue = '__follow_profile__';

  final List<String> _weekDays = const [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日'
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
    return Color(
      int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16),
    );
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
    if (widget.course != null) {
      _loadCourseData(widget.course!);
    } else {
      _selectedDayOfWeek = widget.initialDayOfWeek ?? 1;
      _startSection = widget.initialStartSection ?? 1;
      _endSection = _startSection + 1;
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
    final provider = context.watch<TimetableProvider>();
    final settings = provider.settings;
    _normalizeSections(settings);
    _normalizeWeeks(settings);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course == null ? '添加课程' : '编辑课程'),
        actions: [
          if (widget.course != null)
            IconButton(
              tooltip: '删除课程',
              onPressed: _confirmDeleteCourse,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          TextButton(
            onPressed: () => _saveCourse(provider, settings),
            child: Text(
              '保存',
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
            _buildBasicInfoSection(),
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
        title: const Text('删除课程'),
        content: Text('确定删除课程“${course.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
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
      const SnackBar(content: Text('课程已删除')),
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

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '共享信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '课程名、简称、老师、课程简介、课程性质和颜色会同步到同名课程的其他排课。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '课程名称',
                helperText: '超级岛建议 3 个字以内，显示效果最好',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入课程名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shortNameController,
              decoration: const InputDecoration(
                labelText: '课程简称 (可选)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.short_text),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: '授课教师',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CourseNature>(
              value: _courseNature,
              decoration: const InputDecoration(
                labelText: '课程性质',
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
              decoration: const InputDecoration(
                labelText: '课程简介 (可选)',
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

  Widget _buildTimeSection(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
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
    final followLabel = provider.activeTimeScheme?.name ?? '当前课表时间';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前排课',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '这里的星期、节次、教室、周次和单双周只影响当前这一条排课。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTimeSchemeOverrideId ??
                  _followProfileTimeSchemeValue,
              decoration: const InputDecoration(
                labelText: '上课时间方案',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              items: [
                DropdownMenuItem(
                  value: _followProfileTimeSchemeValue,
                  child: Text('跟随当前课表（$followLabel）'),
                ),
                ...provider.timeSchemes.map(
                  (scheme) => DropdownMenuItem(
                    value: scheme.id,
                    child: Text(scheme.name),
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
                  ? '默认跟随当前课表主时间模板，适合大多数课程。'
                  : '这门课会单独使用所选时间模板，不跟随当前课表主时间模板。',
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
              value: _selectedDayOfWeek,
              decoration: const InputDecoration(
                labelText: '星期',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: List.generate(_weekDays.length, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(_weekDays[index]),
                );
              }),
              onChanged: (value) {
                setState(() {
                  _selectedDayOfWeek = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _startSection,
                    decoration: const InputDecoration(
                      labelText: '开始节次',
                      border: OutlineInputBorder(),
                    ),
                    items: sectionNumbers.map((section) {
                      return DropdownMenuItem(
                        value: section,
                        child: Text('第 $section 节'),
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
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _endSection,
                    decoration: const InputDecoration(
                      labelText: '结束节次',
                      border: OutlineInputBorder(),
                    ),
                    items: sectionNumbers
                        .where((section) => section >= _startSection)
                        .map((section) {
                      return DropdownMenuItem(
                        value: section,
                        child: Text('第 $section 节'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _endSection = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '时间: $startTime - $endTime',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '上课地点',
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
    final availableWeeks = settings.availableWeeks;
    final selectedWeeks = _selectedCustomWeeks.toList()..sort();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '周次设置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_WeekSelectionMode>(
              segments: const [
                ButtonSegment(
                  value: _WeekSelectionMode.range,
                  label: Text('连续周'),
                  icon: Icon(Icons.linear_scale_rounded),
                ),
                ButtonSegment(
                  value: _WeekSelectionMode.custom,
                  label: Text('自定义周'),
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _startWeek,
                      decoration: const InputDecoration(
                        labelText: '开始周',
                        border: OutlineInputBorder(),
                      ),
                      items: availableWeeks.map((week) {
                        return DropdownMenuItem(
                          value: week,
                          child: Text('第 $week 周'),
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _endWeek,
                      decoration: const InputDecoration(
                        labelText: '结束周',
                        border: OutlineInputBorder(),
                      ),
                      items: availableWeeks
                          .where((week) => week >= _startWeek)
                          .map((week) {
                        return DropdownMenuItem(
                          value: week,
                          child: Text('第 $week 周'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _endWeek = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('单周'),
                      value: _isOddWeek,
                      onChanged: (value) {
                        setState(() {
                          _isOddWeek = value!;
                          if (_isOddWeek) _isEvenWeek = false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('双周'),
                      value: _isEvenWeek,
                      onChanged: (value) {
                        setState(() {
                          _isEvenWeek = value!;
                          if (_isEvenWeek) _isOddWeek = false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ] else ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableWeeks.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.7,
                ),
                itemBuilder: (context, index) {
                  final week = availableWeeks[index];
                  final isSelected = _selectedCustomWeeks.contains(week);
                  return FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      foregroundColor: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('全选'),
                    onPressed: () {
                      setState(() {
                        _selectedCustomWeeks = availableWeeks.toSet();
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('单周'),
                    onPressed: () {
                      setState(() {
                        _selectedCustomWeeks =
                            availableWeeks.where((week) => week.isOdd).toSet();
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('双周'),
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
                '已选 ${selectedWeeks.length} 周：第${_formatWeekList(selectedWeeks)}周',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '课程颜色',
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
              label: const Text('调色盘自定义颜色'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomColorPicker() async {
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
              title: const Text('调色盘'),
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
                      decoration: const InputDecoration(
                        labelText: '颜色 Hex',
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
                    Text('色相 ${hsv.hue.round()}'),
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
                    Text('饱和度 ${(hsv.saturation * 100).round()}%'),
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
                    Text('明度 ${(hsv.value * 100).round()}%'),
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
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _toHex(selected)),
                  child: const Text('使用这个颜色'),
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
    if (_weekSelectionMode == _WeekSelectionMode.custom) {
      final selectedWeeks = _selectedCustomWeeks.toList()..sort();
      if (selectedWeeks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少选择一个上课周次')),
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
        SnackBar(content: Text(error.message?.toString() ?? '保存失败')),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.course == null ? '课程添加成功' : '课程更新成功')),
    );
  }
}
