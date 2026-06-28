import 'dart:convert';

import 'package:table_parser/table_parser.dart';
import 'package:uuid/uuid.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import 'week_expression_parser.dart';

class SpreadsheetImportResult {
  final List<Course> courses;
  final List<String> warnings;
  final String format;

  const SpreadsheetImportResult({
    required this.courses,
    required this.warnings,
    required this.format,
  });

  int get requiredSectionCount => courses.isEmpty
      ? 0
      : courses
          .map((course) => course.endSection)
          .reduce((left, right) => left > right ? left : right);
}

class _SpreadsheetColumnMap {
  final Map<String, int> _indices;

  _SpreadsheetColumnMap(List<String> headers)
      : _indices = {
          for (var i = 0; i < headers.length; i++)
            if (headers[i].trim().isNotEmpty) headers[i].trim(): i,
        };

  int? indexOf(String canonical, List<String> aliases) {
    final idx = _indices[canonical];
    if (idx != null) {
      return idx;
    }
    for (final alias in aliases) {
      final aliasIdx = _indices[alias];
      if (aliasIdx != null) {
        return aliasIdx;
      }
    }
    return null;
  }

  bool hasColumn(String canonical, List<String> aliases) =>
      indexOf(canonical, aliases) != null;

  String cell(
    List<String> row,
    String canonical,
    List<String> aliases, {
    String defaultValue = '',
  }) {
    final idx = indexOf(canonical, aliases);
    if (idx == null || idx >= row.length) {
      return defaultValue;
    }
    return row[idx];
  }
}

class SpreadsheetImportService {
  static const String formatMikcb = 'mikcb_course_v1';
  static const String formatWakeUp = 'wakeup_compatible';
  static const String formatUnknown = 'unknown';

  static const String _mikcbMetadataMarker = '# mikcb-course-import-v1';
  static const String _defaultColor = '#2196F3';

  static const List<String> _nameAliases = ['课程名称'];
  static const List<String> _startSectionAliases = ['开始节数'];
  static const List<String> _endSectionAliases = ['结束节数'];
  static const List<String> _customWeeksAliases = ['周数'];
  static const List<String> _teacherAliases = ['老师'];
  static const List<String> _locationAliases = ['地点', '上课地点'];
  static const List<String> _courseNatureAliases = ['课程性质'];
  static const List<String> _timeSchemeAliases = ['时间模板ID'];

  static const List<String> _wakeUpHeaders = [
    '课程名称',
    '星期',
    '开始节数',
    '结束节数',
    '老师',
    '地点',
    '周数',
  ];

  final Uuid _uuid;

  SpreadsheetImportService({
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  SpreadsheetImportResult parseBytes(
    List<int> bytes, {
    required String fileName,
    required TimetableSettings settings,
  }) {
    final lowerName = fileName.toLowerCase();
    final rows = lowerName.endsWith('.xlsx')
        ? _decodeXlsxRows(bytes)
        : _decodeCsvRows(bytes);

    if (rows.isEmpty) {
      return const SpreadsheetImportResult(
        courses: [],
        warnings: [],
        format: formatUnknown,
      );
    }

    final detected = _detectFormat(rows);
    if (detected == null) {
      throw FormatException(
        '未识别表格格式。请使用轻屿课表模板（必填列：课程名、星期、开始节、结束节，'
        '以及上课周或开始周+结束周）；也兼容 WakeUp 7 列格式。',
      );
    }

    final courses = <Course>[];
    final warnings = <String>[];
    final dataStartIndex = detected.headerRowIndex + 1;
    final columnMap = detected.format == formatMikcb
        ? _SpreadsheetColumnMap(rows[detected.headerRowIndex])
        : null;

    for (var rowIndex = dataStartIndex; rowIndex < rows.length; rowIndex++) {
      final rowNumber = rowIndex + 1;
      final row = rows[rowIndex];
      if (_isEmptyRow(row)) {
        continue;
      }

      try {
        final course = detected.format == formatWakeUp
            ? _parseWakeUpDataRow(
                row,
                rowNumber: rowNumber,
                settings: settings,
              )
            : _parseMikcbDataRow(
                row,
                rowNumber: rowNumber,
                settings: settings,
                columns: columnMap!,
              );
        if (course != null) {
          courses.add(course);
        }
      } on FormatException catch (error) {
        warnings.add('第 $rowNumber 行：${error.message}');
      }
    }

    return SpreadsheetImportResult(
      courses: courses,
      warnings: warnings,
      format: detected.format,
    );
  }

  ({int headerRowIndex, String format})? _detectFormat(
    List<List<String>> rows,
  ) {
    var headerRowIndex = 0;
    if (_isMetadataRow(rows.first)) {
      if (rows.length < 2) {
        return null;
      }
      headerRowIndex = 1;
    }

    final headerRow = rows[headerRowIndex];
    if (_isHeaderRow(headerRow, _wakeUpHeaders)) {
      return (headerRowIndex: headerRowIndex, format: formatWakeUp);
    }
    if (_isMikcbFormat(headerRow)) {
      return (headerRowIndex: headerRowIndex, format: formatMikcb);
    }
    return null;
  }

  bool _isMikcbFormat(List<String> headerRow) {
    final columns = _SpreadsheetColumnMap(headerRow);
    if (!columns.hasColumn('课程名', _nameAliases)) {
      return false;
    }
    if (!columns.hasColumn('星期', const [])) {
      return false;
    }
    if (!columns.hasColumn('开始节', _startSectionAliases)) {
      return false;
    }
    if (!columns.hasColumn('结束节', _endSectionAliases)) {
      return false;
    }

    final hasCustomWeeks =
        columns.hasColumn('上课周', _customWeeksAliases);
    final hasRangeWeeks = columns.hasColumn('开始周', const []) &&
        columns.hasColumn('结束周', const []);
    return hasCustomWeeks || hasRangeWeeks;
  }

  List<List<String>> _decodeCsvRows(List<int> bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final decoder = TableParser.decodeCsv(content);
    return _tableToStringRows(decoder.tables.values.first);
  }

  List<List<String>> _decodeXlsxRows(List<int> bytes) {
    final decoder = TableParser.decodeBytes(bytes);
    if (decoder.tables.isEmpty) {
      return const [];
    }
    return _tableToStringRows(decoder.tables.values.first);
  }

  List<List<String>> _tableToStringRows(TableSheet table) {
    final rows = <List<String>>[];
    for (var rowIndex = 0; rowIndex < table.maxRows; rowIndex++) {
      final row = table.rows[rowIndex];
      rows.add(
        List<String>.generate(
          row.length,
          (colIndex) => _cellToString(row[colIndex]),
        ),
      );
    }
    return rows;
  }

  bool _isMetadataRow(List<String> row) {
    if (row.isEmpty) {
      return false;
    }
    return row.first.trim() == _mikcbMetadataMarker;
  }

  bool _isHeaderRow(List<String> row, List<String> expectedHeaders) {
    if (row.length < expectedHeaders.length) {
      return false;
    }
    for (var i = 0; i < expectedHeaders.length; i++) {
      if (row[i].trim() != expectedHeaders[i]) {
        return false;
      }
    }
    return true;
  }

  bool _isEmptyRow(List<String> row) {
    return row.every((cell) => cell.trim().isEmpty);
  }

  Course? _parseWakeUpDataRow(
    List<String> row, {
    required int rowNumber,
    required TimetableSettings settings,
  }) {
    final name = row[0].trim();
    if (name.isEmpty) {
      throw FormatException('课程名称 不能为空');
    }

    final dayOfWeek = _readRequiredInt(row[1], fieldName: '星期');
    if (dayOfWeek < 1 || dayOfWeek > 7) {
      throw FormatException('星期必须是 1-7');
    }

    final startSection =
        _readRequiredInt(row[2], fieldName: '开始节数');
    final endSection = _readRequiredInt(row[3], fieldName: '结束节数');
    _validateSections(startSection, endSection, '开始节数', '结束节数');

    final teacher = _normalizeOptionalField(row[4]);
    final location = _normalizeOptionalField(row[5]);

    final customWeeks = WeekExpressionParser.parse(
      row[6],
      itemName: '第 $rowNumber 行周数',
    );
    if (customWeeks.isEmpty) {
      throw FormatException('周数 不能为空');
    }

    final startTime = _timeFromSection(settings, startSection, isStart: true);
    final endTime = _timeFromSection(settings, endSection, isStart: false);

    return Course(
      id: 'spreadsheet-${_uuid.v4()}',
      name: name,
      teacher: teacher,
      location: location,
      dayOfWeek: dayOfWeek,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
      startWeek: customWeeks.first,
      endWeek: customWeeks.last,
      customWeeks: customWeeks,
    );
  }

  Course? _parseMikcbDataRow(
    List<String> row, {
    required int rowNumber,
    required TimetableSettings settings,
    required _SpreadsheetColumnMap columns,
  }) {
    final nameField =
        columns.indexOf('课程名', const []) != null ? '课程名' : '课程名称';
    final name = columns.cell(row, '课程名', _nameAliases).trim();
    if (name.isEmpty) {
      throw FormatException('$nameField 不能为空');
    }

    final dayOfWeek =
        _readRequiredInt(columns.cell(row, '星期', const []), fieldName: '星期');
    if (dayOfWeek < 1 || dayOfWeek > 7) {
      throw FormatException('星期必须是 1-7');
    }

    final startSectionField =
        columns.hasColumn('开始节', const []) ? '开始节' : '开始节数';
    final endSectionField =
        columns.hasColumn('结束节', const []) ? '结束节' : '结束节数';
    final startSection = _readRequiredInt(
      columns.cell(row, '开始节', _startSectionAliases),
      fieldName: startSectionField,
    );
    final endSection = _readRequiredInt(
      columns.cell(row, '结束节', _endSectionAliases),
      fieldName: endSectionField,
    );
    _validateSections(
      startSection,
      endSection,
      startSectionField,
      endSectionField,
    );

    final teacher = columns.hasColumn('教师', _teacherAliases)
        ? _normalizeOptionalField(columns.cell(row, '教师', _teacherAliases))
        : '';
    final location = columns.hasColumn('教室', _locationAliases)
        ? _normalizeOptionalField(columns.cell(row, '教室', _locationAliases))
        : '';

    final customWeeksRaw =
        columns.cell(row, '上课周', _customWeeksAliases).trim();
    final hasRangeWeekColumns = columns.hasColumn('开始周', const []) &&
        columns.hasColumn('结束周', const []);

    List<int>? customWeeks;
    var startWeek = 1;
    var endWeek = 16;
    var isOddWeek = false;
    var isEvenWeek = false;

    if (customWeeksRaw.isNotEmpty) {
      customWeeks = WeekExpressionParser.parse(
        customWeeksRaw,
        itemName: '第 $rowNumber 行上课周',
      );
      if (customWeeks.isEmpty) {
        throw FormatException('上课周 不能为空');
      }
      startWeek = customWeeks.first;
      endWeek = customWeeks.last;
    } else if (hasRangeWeekColumns) {
      startWeek = _readRequiredInt(
        columns.cell(row, '开始周', const []),
        fieldName: '开始周',
      );
      endWeek = _readRequiredInt(
        columns.cell(row, '结束周', const []),
        fieldName: '结束周',
      );
      if (startWeek < 1) {
        throw FormatException('开始周 必须大于等于 1');
      }
      if (endWeek < startWeek) {
        throw FormatException('结束周 不能小于开始周');
      }
      if (columns.hasColumn('单周', const [])) {
        isOddWeek = _readOptionalBool(columns.cell(row, '单周', const []));
      }
      if (columns.hasColumn('双周', const [])) {
        isEvenWeek = _readOptionalBool(columns.cell(row, '双周', const []));
      }
    } else {
      throw FormatException('上课周 或 开始周+结束周 必须填写');
    }

    final startTime = columns.hasColumn('开始时间', const [])
        ? _normalizeTimeOrDefault(
            columns.cell(row, '开始时间', const []),
            _timeFromSection(settings, startSection, isStart: true),
          )
        : _timeFromSection(settings, startSection, isStart: true);
    final endTime = columns.hasColumn('结束时间', const [])
        ? _normalizeTimeOrDefault(
            columns.cell(row, '结束时间', const []),
            _timeFromSection(settings, endSection, isStart: false),
          )
        : _timeFromSection(settings, endSection, isStart: false);

    final color = columns.hasColumn('颜色', const [])
        ? _normalizeColor(columns.cell(row, '颜色', const []))
        : _defaultColor;

    List<int>? suspendedWeeks;
    if (columns.hasColumn('停课周', const [])) {
      final suspendedRaw = columns.cell(row, '停课周', const []).trim();
      if (suspendedRaw.isNotEmpty &&
          suspendedRaw != '无' &&
          suspendedRaw != '-') {
        suspendedWeeks = WeekExpressionParser.parse(
          suspendedRaw,
          itemName: '第 $rowNumber 行停课周',
        );
      }
    }

    final courseNature = columns.hasColumn('性质', _courseNatureAliases)
        ? _parseCourseNature(columns.cell(row, '性质', _courseNatureAliases))
        : CourseNature.required;

    final shortName = columns.hasColumn('简称', const [])
        ? _normalizeNullableField(columns.cell(row, '简称', const []))
        : null;
    final description = columns.hasColumn('简介', const [])
        ? _normalizeNullableField(columns.cell(row, '简介', const []))
        : null;
    final note = columns.hasColumn('备注', const [])
        ? _normalizeNullableField(columns.cell(row, '备注', const []))
        : null;
    final timeSchemeIdOverride = columns.hasColumn('时间模板', _timeSchemeAliases)
        ? _normalizeNullableField(
            columns.cell(row, '时间模板', _timeSchemeAliases),
          )
        : null;

    return Course(
      id: 'spreadsheet-${_uuid.v4()}',
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
      startWeek: startWeek,
      endWeek: endWeek,
      isOddWeek: isOddWeek,
      isEvenWeek: isEvenWeek,
      customWeeks: customWeeks,
      suspendedWeeks: suspendedWeeks,
      courseNature: courseNature,
      description: description,
      note: note,
      timeSchemeIdOverride: timeSchemeIdOverride,
    );
  }

  void _validateSections(
    int startSection,
    int endSection,
    String startField,
    String endField,
  ) {
    if (startSection < 1) {
      throw FormatException('$startField 必须大于等于 1');
    }
    if (endSection < startSection) {
      throw FormatException('$endField 不能小于$startField');
    }
  }

  String _timeFromSection(
    TimetableSettings settings,
    int section, {
    required bool isStart,
  }) {
    if (section < 1 || section > settings.sectionCount) {
      return '00:00';
    }
    final sectionInfo = settings.sections[section - 1];
    return isStart ? sectionInfo.startTime : sectionInfo.endTime;
  }

  String _normalizeTimeOrDefault(String raw, String fallback) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '无' || trimmed == '-') {
      return fallback;
    }
    return trimmed;
  }

  String _normalizeColor(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '无' || trimmed == '-') {
      return _defaultColor;
    }
    return trimmed.startsWith('#') ? trimmed : '#$trimmed';
  }

  CourseNature _parseCourseNature(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == '无' || trimmed == '-') {
      return CourseNature.required;
    }
    if (trimmed == '选修' || trimmed == 'elective') {
      return CourseNature.elective;
    }
    return CourseNature.required;
  }

  bool _readOptionalBool(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == '无' || trimmed == '-') {
      return false;
    }
    return trimmed == '是' ||
        trimmed == '1' ||
        trimmed == '单' ||
        trimmed == 'true' ||
        trimmed == 'yes';
  }

  String? _normalizeNullableField(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '无' || trimmed == '-') {
      return null;
    }
    return trimmed;
  }

  String _normalizeOptionalField(String raw) {
    final trimmed = raw.trim();
    if (trimmed == '无' || trimmed == '-') {
      return '';
    }
    return trimmed;
  }

  int _readRequiredInt(String raw, {required String fieldName}) {
    final parsed = _readInt(raw);
    if (parsed == null) {
      throw FormatException('$fieldName 必须是整数');
    }
    return parsed;
  }

  int? _readInt(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final direct = int.tryParse(trimmed);
    if (direct != null) {
      return direct;
    }
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null && asDouble == asDouble.roundToDouble()) {
      return asDouble.round();
    }
    return null;
  }

  String _cellToString(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value.trim();
    }
    if (value is int) {
      return value.toString();
    }
    if (value is double) {
      if (value == value.roundToDouble()) {
        return value.round().toString();
      }
      return value.toString();
    }
    if (value is DateTime) {
      return '${value.month}月${value.day}日';
    }
    return value.toString().trim();
  }
}
