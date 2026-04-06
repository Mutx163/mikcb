import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../models/warehouse_repository_models.dart';
import '../providers/timetable_provider.dart';
import '../services/ai_course_import_service.dart';
import '../services/ics_import_service.dart';
import '../services/import_week_alignment_service.dart';
import '../services/warehouse_import_preferences_service.dart';
import '../services/warehouse_repository_service.dart';

class CourseImportScreen extends StatelessWidget {
  const CourseImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入课程'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择导入方式',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '现在支持传统 .ics 日历导入，也支持把课表截图发给 AI 识别后再粘贴回来导入。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ImportEntryCard(
            icon: Icons.event_note_rounded,
            title: '.ics 日历导入',
            subtitle: '适合从 WakeUp 等课表应用导出的日历文件，流程最短。',
            footer: '进入后直接选择 .ics 文件，可追加导入或替换现有课程。',
            onTap: () => _openImportPage<bool>(
              context,
              builder: (_) => const IcsCourseImportScreen(),
            ),
          ),
          const SizedBox(height: 16),
          _ImportEntryCard(
            icon: Icons.auto_awesome_rounded,
            title: '识图导入',
            subtitle: '适合直接从课表截图导入，支持 1 张或多张连续截图。',
            footer: '先复制提示词，再到豆包专家模式发送截图和提示词，把返回的 JSON 复制回来导入，最后选择开学日期。',
            onTap: () => _openImportPage<bool>(
              context,
              builder: (_) => const AiImageCourseImportScreen(),
            ),
          ),
          const SizedBox(height: 16),
          _ImportEntryCard(
            icon: Icons.school_outlined,
            title: '教务系统导入',
            subtitle: '从 qingyu_warehouse 读取学校与适配器，支持网页登录导入课程。',
            footer: '进入后选择学校和适配器，可直接打开教务网页登录并执行导入。',
            onTap: () => _openImportPage<bool>(
              context,
              builder: (_) => const WarehouseCourseImportScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openImportPage<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) async {
    final imported = await Navigator.of(context).push<T>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/courses/import/detail'),
        builder: builder,
      ),
    );
    if (context.mounted && imported == true) {
      Navigator.of(context).pop(true);
    }
  }
}

class IcsCourseImportScreen extends StatefulWidget {
  const IcsCourseImportScreen({super.key});

  @override
  State<IcsCourseImportScreen> createState() => _IcsCourseImportScreenState();
}

class _IcsCourseImportScreenState extends State<IcsCourseImportScreen> {
  final IcsImportService _icsImportService = IcsImportService();
  final ImportWeekAlignmentService _weekAlignmentService =
      const ImportWeekAlignmentService();

  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('.ics 日历导入'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '适用场景',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '如果你已经能在 WakeUp 等课表应用里导入教务系统课程，再导出为 .ics 文件，这条路最稳。',
                  ),
                  const SizedBox(height: 14),
                  _GuideLine(
                    title: '步骤 1',
                    subtitle: '先在其他课表应用里导出 .ics 日历文件。',
                  ),
                  const SizedBox(height: 10),
                  _GuideLine(
                    title: '步骤 2',
                    subtitle: '回到这里选择文件，可选“追加导入”或“替换现有”。',
                  ),
                  const SizedBox(height: 10),
                  _GuideLine(
                    title: '步骤 3',
                    subtitle: '导入前还会让你确认开学日期，以及课表第 1 周对应校历第几周。',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '支持的文件',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('文件后缀必须是 .ics。'),
                const SizedBox(height: 4),
                const Text('如果你手里只有截图，不要走这里，请返回上一页选择“识图导入”。'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: FilledButton.icon(
          onPressed: _isImporting ? null : _importIcsFile,
          icon: _isImporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_open_rounded),
          label: Text(_isImporting ? '导入中...' : '选择 .ics 文件'),
        ),
      ),
    );
  }

  Future<void> _importIcsFile() async {
    setState(() {
      _isImporting = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['ics'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取所选文件')),
        );
        return;
      }

      final provider = context.read<TimetableProvider>();
      final replaceExisting = provider.courses.isEmpty
          ? true
          : await _askReplaceExisting(
              context,
              title: '导入课程',
              content: '导入 ${file.name} 时，是否替换现有课程？',
            );
      if (replaceExisting == null || !mounted) {
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final parsedResult = _icsImportService.parseWakeUpSchedule(content);
      if (parsedResult.courses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未识别到可导入课程')),
        );
        return;
      }

      final semesterConfig = await _pickImportSemesterConfig(
        context,
        initialSemesterStartDate:
            provider.settings.semesterStartDate ?? parsedResult.semesterStart,
        initialFirstCourseWeek: _weekAlignmentService.inferFirstCourseWeek(
          semesterStartDate:
              provider.settings.semesterStartDate ?? parsedResult.semesterStart,
          firstCourseDate: parsedResult.semesterStart,
        ),
        inferredFirstCourseDate: parsedResult.semesterStart,
        title: '确认开学日期和周次对应',
        subtitle: '请选择学校校历的开学日期。系统已根据文件里最早的上课日期给出默认周次对应，你也可以手动调整。',
      );
      if (semesterConfig == null || !mounted) {
        return;
      }

      final alignedCourses = _weekAlignmentService.shiftCoursesToSemesterWeeks(
        parsedResult.courses,
        firstCourseWeek: semesterConfig.firstCourseWeek,
      );
      final requiredSectionCount =
          provider.previewImportedCourseRequiredSectionCount(
        alignedCourses,
        replaceExisting: replaceExisting,
      );
      final capacityReady = await _ensureSectionCapacity(
        context,
        requiredSectionCount: requiredSectionCount,
        provider: provider,
      );
      if (!capacityReady || !mounted) {
        return;
      }

      final importedCount = await provider.importParsedCourses(
        alignedCourses,
        replaceExisting: replaceExisting,
        semesterStart: semesterConfig.semesterStartDate,
        source: 'ics',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            importedCount > 0
                ? (replaceExisting
                    ? '已覆盖导入 $importedCount 条课程'
                    : '已更新课表：新增或更新 $importedCount 条课程')
                : '没有需要新增或更新的课程',
          ),
        ),
      );
      if (importedCount > 0) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
}

class AiImageCourseImportScreen extends StatefulWidget {
  const AiImageCourseImportScreen({super.key});

  @override
  State<AiImageCourseImportScreen> createState() =>
      _AiImageCourseImportScreenState();
}

class _AiImageCourseImportScreenState extends State<AiImageCourseImportScreen> {
  final TextEditingController _aiController = TextEditingController();
  final FocusNode _aiFocusNode = FocusNode();
  final AiCourseImportService _aiImportService = AiCourseImportService();
  final ImportWeekAlignmentService _weekAlignmentService =
      const ImportWeekAlignmentService();

  AiCourseImportParseResult? _aiParsedResult;
  String? _aiParseError;
  bool _isImporting = false;

  @override
  void dispose() {
    _aiFocusNode.dispose();
    _aiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('识图导入'),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dense = constraints.maxHeight < 760;
            final ultraDense = constraints.maxHeight < 520;
            final sectionGap = ultraDense
                ? 4.0
                : dense
                    ? 8.0
                    : 12.0;
            final outerPadding = ultraDense
                ? 10.0
                : dense
                    ? 12.0
                    : 16.0;
            final cardRadius = ultraDense
                ? 16.0
                : dense
                    ? 18.0
                    : 20.0;
            final compactButtonStyle = ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(
                  horizontal: ultraDense
                      ? 8
                      : dense
                          ? 10
                          : 12,
                  vertical: ultraDense
                      ? 6
                      : dense
                          ? 8
                          : 10,
                ),
              ),
            );
            final compactBottomButtonStyle = ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(
                  horizontal: ultraDense ? 8 : 12,
                  vertical: ultraDense ? 8 : 10,
                ),
              ),
            );
            final previewSummary = _aiParsedResult == null
                ? null
                : '识别到 ${_aiParsedResult!.courses.length} 门课，最高到第 ${_aiParsedResult!.requiredSectionCount} 节'
                    '${_aiParsedResult!.warnings.isEmpty ? "" : '，${_aiParsedResult!.warnings.length} 条提醒'}';

            return Padding(
              padding: EdgeInsets.fromLTRB(
                outerPadding,
                12,
                outerPadding,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      ultraDense
                          ? 10
                          : dense
                              ? 14
                              : 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.surfaceContainerHighest,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(cardRadius + 2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ultraDense
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '复制提示词 -> 豆包识图 -> 导入',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '豆包专家模式 -> 复制 JSON -> 选择开学日期',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '复制提示词 -> 豆包识图 -> 粘贴 JSON -> 导入',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: dense ? 4 : 6),
                                    Text(
                                      '先复制提示词，再到豆包左下角切换为专家模式，把课表截图和提示词一起发过去。把豆包返回的 JSON 复制回这里，点击导入后再选择开学日期。',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        SizedBox(width: ultraDense ? 8 : 12),
                        if (ultraDense)
                          TextButton(
                            onPressed: _showPromptSheet,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                            child: const Text('提示词'),
                          )
                        else
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: dense ? 30 : 34,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  if (ultraDense)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '建议豆包专家模式，支持多图，截图需带星期表头。',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CompactHintChip(
                          icon: Icons.smart_toy_outlined,
                          label: '先切到豆包专家模式',
                        ),
                        _CompactHintChip(
                          icon: Icons.photo_library_outlined,
                          label: '截图和提示词一起发',
                        ),
                        _CompactHintChip(
                          icon: Icons.content_copy_rounded,
                          label: '返回结果复制 JSON',
                        ),
                        _CompactHintChip(
                          icon: Icons.event_available_rounded,
                          label: '导入后再选开学日期',
                        ),
                      ],
                    ),
                  SizedBox(height: sectionGap),
                  if (ultraDense)
                    Row(
                      children: [
                        Expanded(
                          child: _CompactActionButton(
                            icon: Icons.copy_all_rounded,
                            label: '复制',
                            onPressed: _copyAiPrompt,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _CompactActionButton(
                            icon: Icons.article_outlined,
                            label: '提示词',
                            onPressed: _showPromptSheet,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _CompactActionButton(
                            icon: Icons.content_paste_rounded,
                            label: '粘贴',
                            onPressed: _pasteFromClipboard,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _CompactActionButton(
                            icon: Icons.clear_rounded,
                            label: '清空',
                            onPressed: _clearInput,
                          ),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _copyAiPrompt,
                          style: compactButtonStyle,
                          icon: const Icon(Icons.copy_all_rounded, size: 18),
                          label: const Text('复制提示词'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showPromptSheet,
                          style: compactButtonStyle,
                          icon: const Icon(Icons.article_outlined, size: 18),
                          label: const Text('查看提示词'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _pasteFromClipboard,
                          style: compactButtonStyle,
                          icon:
                              const Icon(Icons.content_paste_rounded, size: 18),
                          label: const Text('粘贴'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _clearInput,
                          style: compactButtonStyle,
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          label: const Text('清空'),
                        ),
                      ],
                    ),
                  SizedBox(height: sectionGap),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ultraDense ? 'JSON' : '粘贴 AI 返回的 JSON',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_aiParsedResult != null)
                        _CompactStatusChip(
                          label: '${_aiParsedResult!.courses.length} 门课',
                        ),
                      if (_aiParseError != null)
                        const _CompactStatusChip(
                          label: '解析失败',
                          isError: true,
                        ),
                    ],
                  ),
                  SizedBox(
                    height: ultraDense
                        ? 4
                        : dense
                            ? 6
                            : 8,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      child: TextField(
                        key: const ValueKey('ai_import_json_input'),
                        controller: _aiController,
                        focusNode: _aiFocusNode,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (_) {
                          if (_aiParsedResult != null ||
                              _aiParseError != null) {
                            setState(() {
                              _aiParsedResult = null;
                              _aiParseError = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(ultraDense ? 10 : 14),
                          hintText: ultraDense
                              ? '粘贴 AI 返回的 JSON'
                              : '把豆包返回的 JSON 原样粘贴到这里，然后点击导入。支持纯 JSON，也兼容 ```json 代码块。',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  if (_aiParseError != null)
                    _CompactNoticeCard(
                      icon: Icons.error_outline_rounded,
                      message: _aiParseError!,
                      isError: true,
                      actionLabel: '详情',
                      onAction: () => _showMessageSheet(
                        title: '解析错误',
                        content: _aiParseError!,
                      ),
                    )
                  else if (_aiParsedResult != null)
                    _CompactNoticeCard(
                      icon: Icons.check_circle_outline_rounded,
                      message: previewSummary!,
                      actionLabel: '查看详情',
                      onAction: () => _showPreviewSheet(_aiParsedResult!),
                    )
                  else if (!ultraDense)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '复制提示词 -> 豆包发送截图和提示词 -> 把 JSON 贴回这里 -> 点击导入 -> 选择开学日期。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  SizedBox(height: sectionGap),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _previewAiResult,
                          style: compactBottomButtonStyle,
                          icon: const Icon(Icons.preview_rounded),
                          label: const Text('预览'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isImporting ? null : _importAiResult,
                          style: compactBottomButtonStyle,
                          icon: _isImporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload_rounded),
                          label: Text(_isImporting ? '导入中...' : '确认导入'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _copyAiPrompt() async {
    await Clipboard.setData(
      const ClipboardData(text: AiCourseImportService.prompt),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('提示词已复制，去豆包发送截图和提示词')),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板里没有可用文本')),
      );
      return;
    }
    _aiController.text = text;
    if (!mounted) {
      return;
    }
    setState(() {
      _aiParsedResult = null;
      _aiParseError = null;
    });
  }

  void _clearInput() {
    _aiController.clear();
    setState(() {
      _aiParsedResult = null;
      _aiParseError = null;
    });
  }

  void _showPromptSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '识图提示词',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '建议使用豆包。先把豆包左下角切换为专家模式，再把下面整段提示词和课表截图一起发过去，让它只返回 JSON。生成后把 JSON 复制回本页，点击导入后再选择开学日期。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          AiCourseImportService.prompt.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPreviewSheet(AiCourseImportParseResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(
                  '解析预览',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                _AiPreviewCard(result: result),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessageSheet({
    required String title,
    required String content,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(content),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _previewAiResult() {
    final result = _parseAiResult(showError: true);
    if (result != null) {
      _showPreviewSheet(result);
    }
  }

  AiCourseImportParseResult? _parseAiResult({
    required bool showError,
  }) {
    final content = _aiController.text.trim();
    if (content.isEmpty) {
      const message = '请先粘贴 AI 返回的 JSON';
      if (mounted) {
        setState(() {
          _aiParsedResult = null;
          _aiParseError = message;
        });
        if (showError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(message)),
          );
        }
      }
      return null;
    }

    try {
      final result = _aiImportService.parse(
        content,
        settings: context.read<TimetableProvider>().settings,
      );
      if (mounted) {
        setState(() {
          _aiParsedResult = result;
          _aiParseError = null;
        });
      }
      return result;
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _aiParsedResult = null;
          _aiParseError = error.message;
        });
        if (showError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      }
      return null;
    } catch (_) {
      const message = '解析失败，请确认粘贴的是完整 JSON';
      if (mounted) {
        setState(() {
          _aiParsedResult = null;
          _aiParseError = message;
        });
        if (showError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(message)),
          );
        }
      }
      return null;
    }
  }

  Future<void> _importAiResult() async {
    setState(() {
      _isImporting = true;
    });
    try {
      final result = _parseAiResult(showError: true);
      if (result == null || !mounted) {
        return;
      }

      final provider = context.read<TimetableProvider>();
      final replaceExisting = provider.courses.isEmpty
          ? true
          : await _askReplaceExisting(
              context,
              title: '导入 AI 解析结果',
              content: '是否用当前这份 AI 解析结果替换现有课程？',
            );
      if (replaceExisting == null || !mounted) {
        return;
      }

      final semesterConfig = await _pickImportSemesterConfig(
        context,
        initialSemesterStartDate: provider.settings.semesterStartDate ??
            _weekAlignmentService.startOfWeek(DateTime.now()),
        initialFirstCourseWeek: 1,
        title: '确认开学日期和周次对应',
        subtitle: '请选择学校校历的开学日期，再确认课表里的第 1 周对应校历第几周。如果学校第一周没课，这里通常要改成第 2 周。',
      );
      if (semesterConfig == null || !mounted) {
        return;
      }

      final alignedCourses = _weekAlignmentService.shiftCoursesToSemesterWeeks(
        result.courses,
        firstCourseWeek: semesterConfig.firstCourseWeek,
      );
      final requiredSectionCount =
          provider.previewImportedCourseRequiredSectionCount(
        alignedCourses,
        replaceExisting: replaceExisting,
      );
      final capacityReady = await _ensureSectionCapacity(
        context,
        requiredSectionCount: requiredSectionCount,
        provider: provider,
      );
      if (!capacityReady || !mounted) {
        return;
      }

      final importedCount = await provider.importParsedCourses(
        alignedCourses,
        replaceExisting: replaceExisting,
        semesterStart: semesterConfig.semesterStartDate,
        source: 'ai',
      );
      if (!mounted) {
        return;
      }

      final warningSuffix =
          result.warnings.isEmpty ? '' : '，另有 ${result.warnings.length} 条识别提醒';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            importedCount > 0
                ? (replaceExisting
                    ? '已覆盖导入 $importedCount 条课程$warningSuffix'
                    : '已更新课表：新增或更新 $importedCount 条课程$warningSuffix')
                : '没有需要新增或更新的课程',
          ),
        ),
      );
      if (importedCount > 0) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
}

class WarehouseCourseImportScreen extends StatefulWidget {
  const WarehouseCourseImportScreen({super.key});

  @override
  State<WarehouseCourseImportScreen> createState() =>
      _WarehouseCourseImportScreenState();
}

class _WarehouseCourseImportScreenState extends State<WarehouseCourseImportScreen> {
  static final WarehouseRepositorySource _defaultSource =
      WarehouseRepositorySource.fromGitHubUrl(
    'https://github.com/Mutx163/qingyu_warehouse',
  );

  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  final TextEditingController _searchController = TextEditingController();
  late Future<WarehouseRootIndex> _rootIndexFuture;
  List<String> _recentSchoolIds = const [];
  String _searchQuery = '';
  WarehouseFetchOptions _currentFetchOptions() {
    final settings = context.read<TimetableProvider>().settings;
    return WarehouseFetchOptions.fromSettings(settings);
  }

  @override
  void initState() {
    super.initState();
    _rootIndexFuture = _repositoryService.fetchRootIndex(
      _defaultSource,
      options: _currentFetchOptions(),
    );
    _loadRecentSchoolIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSchoolIds() async {
    final ids = await _preferencesService.getRecentSchoolIds();
    if (!mounted) return;
    setState(() {
      _recentSchoolIds = ids;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('教务系统导入'),
      ),
      body: FutureBuilder<WarehouseRootIndex>(
        future: _rootIndexFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '暂时无法读取适配仓',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _rootIndexFuture = _repositoryService.fetchRootIndex(
                                _defaultSource,
                                options: _currentFetchOptions(),
                              );
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('重新读取'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final allSchools = [...?snapshot.data?.schools]
            ..sort((left, right) {
              final initialCompare = left.initial.compareTo(right.initial);
              if (initialCompare != 0) return initialCompare;
              return left.name.compareTo(right.name);
            });
          final filteredSchools = _filterSchools(allSchools, _searchQuery);
          final beans = _schoolsToBeans(filteredSchools, _recentSchoolIds);
          final indexTags = beans
              .map((bean) => bean.getSuspensionTag())
              .toSet()
              .toList(growable: false);
          final isSearching = _searchQuery.trim().isNotEmpty;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索学校名称、首字母或代码',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                  ),
                ),
              ),
              Expanded(
                child: beans.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 36,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isSearching ? '没有找到匹配的学校' : '暂无可用学校',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (isSearching) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '试试学校全称、首字母或仓库里的学校代码。',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : AzListView(
                        data: beans,
                        itemCount: beans.length,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        indexBarData: isSearching ? const [] : indexTags,
                        indexBarOptions: IndexBarOptions(
                          needRebuild: true,
                          hapticFeedback: true,
                          textStyle: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ) ??
                              const TextStyle(fontSize: 11),
                          selectTextStyle: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ) ??
                              const TextStyle(fontSize: 11),
                          selectItemDecoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          indexHintDecoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          indexHintTextStyle:
                              theme.textTheme.headlineMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ) ??
                                  const TextStyle(fontSize: 28),
                        ),
                        indexHintBuilder: (context, tag) => Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            tag,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final bean = beans[index];
                          return _WarehouseSchoolCard(
                            school: bean.school,
                            isRecent: bean.isRecent,
                            onTap: () async {
                              final imported =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  settings: RouteSettings(
                                    name: '/courses/import/warehouse/${bean.school.id}',
                                  ),
                                  builder: (_) => WarehouseSchoolAdaptersScreen(
                                    source: _defaultSource,
                                    school: bean.school,
                                    fetchOptions: _currentFetchOptions(),
                                  ),
                                ),
                              );
                              if (imported == true && context.mounted) {
                                Navigator.of(context).pop(true);
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<WarehouseSchoolEntry> _filterSchools(
    List<WarehouseSchoolEntry> schools,
    String query,
  ) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return schools;
    }
    return schools.where((school) {
      return school.name.toLowerCase().contains(keyword) ||
          school.id.toLowerCase().contains(keyword) ||
          school.initial.toLowerCase().contains(keyword) ||
          school.resourceFolder.toLowerCase().contains(keyword);
    }).toList(growable: false);
  }
}

class WarehouseSchoolAdaptersScreen extends StatefulWidget {
  final WarehouseRepositorySource source;
  final WarehouseSchoolEntry school;
  final WarehouseFetchOptions fetchOptions;

  const WarehouseSchoolAdaptersScreen({
    super.key,
    required this.source,
    required this.school,
    required this.fetchOptions,
  });

  @override
  State<WarehouseSchoolAdaptersScreen> createState() =>
      _WarehouseSchoolAdaptersScreenState();
}

class _WarehouseSchoolAdaptersScreenState
    extends State<WarehouseSchoolAdaptersScreen> {
  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  late Future<WarehouseAdaptersIndex> _adaptersFuture;

  @override
  void initState() {
    super.initState();
    _adaptersFuture = _repositoryService.fetchAdaptersIndex(
      widget.source,
      widget.school,
      options: widget.fetchOptions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.school.name),
      ),
      body: FutureBuilder<WarehouseAdaptersIndex>(
        future: _adaptersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snapshot.error}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final adapters = snapshot.data?.adapters ?? const <WarehouseAdapterEntry>[];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: adapters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final adapter = adapters[index];
              return _WarehouseAdapterCard(
                adapter: adapter,
                importButtonLabel: adapter.importUrl.isEmpty
                    ? '填写网址后导入'
                    : '网页登录导入',
                onImport: () => _openAdapterImport(adapter),
                onInfo: () async {
                  final imported = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      settings: RouteSettings(
                        name:
                            '/courses/import/warehouse/${widget.school.id}/${adapter.adapterId}',
                      ),
                      builder: (_) => WarehouseAdapterDetailScreen(
                        source: widget.source,
                        school: widget.school,
                        adapter: adapter,
                        fetchOptions: widget.fetchOptions,
                      ),
                    ),
                  );
                  if (imported == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openAdapterImport(WarehouseAdapterEntry adapter) async {
    final initialUrl = await _resolveAdapterImportUrl(adapter);
    if (initialUrl == null || !mounted) {
      return;
    }
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/courses/import/warehouse/login'),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: adapter.adapterName,
          initialUrl: initialUrl,
          source: widget.source,
          school: widget.school,
          adapter: adapter,
          fetchOptions: widget.fetchOptions,
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<String?> _resolveAdapterImportUrl(WarehouseAdapterEntry adapter) async {
    final custom = await _preferencesService.getCustomImportUrl(
      adapter.adapterId,
    );
    final effectiveUrl = (custom ?? '').trim().isNotEmpty
        ? custom!.trim()
        : adapter.importUrl.trim();
    if (effectiveUrl.isNotEmpty) {
      return effectiveUrl;
    }
    if (!mounted) {
      return null;
    }
    final manualUrl = await _promptWarehouseImportUrl(
      context,
      schoolName: widget.school.name,
      adapterName: adapter.adapterName,
    );
    if (manualUrl == null) {
      return null;
    }
    await _preferencesService.setCustomImportUrl(adapter.adapterId, manualUrl);
    if (mounted) {
      _showLightTip(context, '已保存教务网址，下次可直接导入');
    }
    return manualUrl;
  }
}

class WarehouseAdapterDetailScreen extends StatefulWidget {
  final WarehouseRepositorySource source;
  final WarehouseSchoolEntry school;
  final WarehouseAdapterEntry adapter;
  final WarehouseFetchOptions fetchOptions;

  const WarehouseAdapterDetailScreen({
    super.key,
    required this.source,
    required this.school,
    required this.adapter,
    required this.fetchOptions,
  });

  @override
  State<WarehouseAdapterDetailScreen> createState() =>
      _WarehouseAdapterDetailScreenState();
}

class _WarehouseAdapterDetailScreenState extends State<WarehouseAdapterDetailScreen> {
  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  late Future<String> _scriptFuture;
  String? _customImportUrl;

  @override
  void initState() {
    super.initState();
    _scriptFuture = _repositoryService.fetchAdapterScript(
      widget.source,
      school: widget.school,
      adapter: widget.adapter,
      options: widget.fetchOptions,
    );
    _loadCustomImportUrl();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final adapter = widget.adapter;
    return Scaffold(
      appBar: AppBar(
        title: Text(adapter.adapterName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WarehouseIntroCard(
            title: adapter.adapterName,
            subtitle: adapter.description.isEmpty
                ? '可查看适配器信息、登录入口与脚本状态。'
                : '',
            chips: [
              '学校：${widget.school.name}',
              '类别：${adapter.category}',
              '维护者：${adapter.maintainer}',
            ],
            markdown: adapter.description.isEmpty ? null : adapter.description,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '适配器信息',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailLine(label: 'adapter_id', value: adapter.adapterId),
                  _DetailLine(label: '脚本路径', value: adapter.assetJsPath),
                  _DetailLine(
                    label: '登录入口',
                    value: _effectiveImportUrl.isEmpty ? '未配置' : _effectiveImportUrl,
                  ),
                  if ((_customImportUrl ?? '').isNotEmpty)
                    const _DetailLine(label: '说明', value: '当前使用你手动覆盖的登录地址'),
                  _DetailLine(label: '仓库', value: widget.source.repositoryUrl),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<String>(
            future: _scriptFuture,
            builder: (context, snapshot) {
              final readable = snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasError &&
                  (snapshot.data?.trim().isNotEmpty ?? false);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '脚本状态',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const LinearProgressIndicator(minHeight: 3)
                      else if (readable)
                        Text(
                          '脚本已成功读取，长度 ${snapshot.data!.length} 字符。',
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        Text(
                          snapshot.hasError ? '${snapshot.error}' : '脚本为空',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openInAppLogin,
            icon: const Icon(Icons.web_rounded),
            label: Text(
              _effectiveImportUrl.isEmpty ? '填写网址后导入' : '应用内打开登录入口',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _effectiveImportUrl.isEmpty
                    ? null
                    : () => _openImportUrl(_effectiveImportUrl),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('系统浏览器打开'),
              ),
              OutlinedButton.icon(
                onPressed: _effectiveImportUrl.isEmpty
                    ? null
                    : () => _copyText(
                          _effectiveImportUrl,
                          successMessage: '已复制教务登录地址',
                        ),
                icon: const Icon(Icons.link_rounded),
                label: const Text('复制登录地址'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyText(
                  widget.source
                      .buildRawFileUri(
                        'resources/${widget.school.resourceFolder}/${adapter.assetJsPath}',
                      )
                      .toString(),
                  successMessage: '已复制脚本原始地址',
                ),
                icon: const Icon(Icons.code_rounded),
                label: const Text('复制脚本地址'),
              ),
              OutlinedButton.icon(
                onPressed: _editCustomImportUrl,
                icon: const Icon(Icons.edit_road_rounded),
                label: Text(
                  (_customImportUrl ?? '').isEmpty ? '自定义登录地址' : '修改自定义地址',
                ),
              ),
              if ((_customImportUrl ?? '').isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _clearCustomImportUrl,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(
                    adapter.importUrl.isEmpty ? '清除自定义地址' : '恢复仓库地址',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String get _effectiveImportUrl =>
      (_customImportUrl ?? '').trim().isNotEmpty
          ? _customImportUrl!.trim()
          : widget.adapter.importUrl;

  Future<void> _loadCustomImportUrl() async {
    final custom = await _preferencesService.getCustomImportUrl(
      widget.adapter.adapterId,
    );
    if (!mounted) return;
    setState(() {
      _customImportUrl = custom;
    });
  }

  Future<void> _openImportUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      _showLightTip(context, '登录入口地址无效');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openInAppLogin() async {
    var targetUrl = _effectiveImportUrl.trim();
    if (targetUrl.isEmpty) {
      final manualUrl = await _promptWarehouseImportUrl(
        context,
        schoolName: widget.school.name,
        adapterName: widget.adapter.adapterName,
      );
      if (manualUrl == null) {
        return;
      }
      await _preferencesService.setCustomImportUrl(
        widget.adapter.adapterId,
        manualUrl,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _customImportUrl = manualUrl;
      });
      _showLightTip(context, '已保存教务网址，下次可直接导入');
      targetUrl = manualUrl;
    }
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      _showLightTip(context, '登录入口地址无效');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/courses/import/warehouse/login'),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: widget.adapter.adapterName,
          initialUrl: targetUrl,
          source: widget.source,
          school: widget.school,
          adapter: widget.adapter,
          fetchOptions: widget.fetchOptions,
        ),
      ),
    ).then((imported) {
      if (imported == true && mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _editCustomImportUrl() async {
    final result = await _promptWarehouseImportUrl(
      context,
      schoolName: widget.school.name,
      adapterName: widget.adapter.adapterName,
      initialValue: _effectiveImportUrl,
    );
    if (result == null) return;
    await _preferencesService.setCustomImportUrl(
      widget.adapter.adapterId,
      result,
    );
    if (!mounted) return;
    setState(() {
      _customImportUrl = result;
    });
    _showLightTip(context, '已保存自定义登录地址');
  }

  Future<void> _clearCustomImportUrl() async {
    await _preferencesService.clearCustomImportUrl(widget.adapter.adapterId);
    if (!mounted) return;
    setState(() {
      _customImportUrl = null;
    });
    _showLightTip(
      context,
      widget.adapter.importUrl.isEmpty ? '已清除自定义登录地址' : '已恢复仓库里的登录地址',
    );
  }

  Future<void> _copyText(
    String value, {
    required String successMessage,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    _showLightTip(context, successMessage);
  }
}

class WarehouseAdapterWebLoginScreen extends StatefulWidget {
  final String title;
  final String initialUrl;
  final WarehouseRepositorySource source;
  final WarehouseSchoolEntry school;
  final WarehouseAdapterEntry adapter;
  final WarehouseFetchOptions fetchOptions;

  const WarehouseAdapterWebLoginScreen({
    super.key,
    required this.title,
    required this.initialUrl,
    required this.source,
    required this.school,
    required this.adapter,
    required this.fetchOptions,
  });

  @override
  State<WarehouseAdapterWebLoginScreen> createState() =>
      _WarehouseAdapterWebLoginScreenState();
}

class _WarehouseAdapterWebLoginScreenState
    extends State<WarehouseAdapterWebLoginScreen> {
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  static const String _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; 25060RK16C) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  final ImportWeekAlignmentService _weekAlignmentService =
      const ImportWeekAlignmentService();
  late final WebViewController _controller;
  late final TextEditingController _addressController;
  final FocusNode _addressFocusNode = FocusNode();
  int _loadingProgress = 0;
  String? _currentUrl;
  bool _isExecutingImport = false;
  String? _lastScriptStatus;
  WarehouseRememberedLogin? _rememberedLogin;
  WarehouseRememberedLogin? _latestLoginCandidate;
  bool _hasPromptedAutofill = false;
  bool _hasPromptedSave = false;
  bool _isPromptShowing = false;
  bool _useDesktopMode = true;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _addressController = TextEditingController(text: widget.initialUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setUserAgent(_desktopUserAgent)
      ..addJavaScriptChannel(
        'QingyuBridge',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentUrl = url;
              if (!_addressFocusNode.hasFocus) {
                _addressController.text = url;
              }
            });
          },
          onPageFinished: (url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentUrl = url;
              _loadingProgress = 100;
              if (!_addressFocusNode.hasFocus) {
                _addressController.text = url;
              }
            });
            _installLoginWatcher();
            _autofillRememberedLoginIfNeeded();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
    _loadRememberedLogin();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '执行导入脚本',
            onPressed: _isExecutingImport ? null : _executeImportScript,
            icon: _isExecutingImport
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: _useDesktopMode ? '切换到手机网页' : '切换到电脑网页',
            onPressed: _toggleWebPageMode,
            icon: Icon(
              _useDesktopMode
                  ? Icons.smartphone_rounded
                  : Icons.desktop_windows_rounded,
            ),
          ),
          IconButton(
            tooltip: '记住当前输入',
            onPressed: _rememberCurrentLogin,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: '填入已记住',
            onPressed:
                _rememberedLogin == null ? null : _autofillRememberedLogin,
            icon: const Icon(Icons.password_rounded),
          ),
          IconButton(
            tooltip: '清除记住',
            onPressed: _rememberedLogin == null ? null : _clearRememberedLogin,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _controller.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: '复制当前地址',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final value = _currentUrl ?? widget.initialUrl;
              await Clipboard.setData(ClipboardData(text: value));
              if (!mounted) {
                return;
              }
              messenger.showSnackBar(
                const SnackBar(content: Text('已复制当前地址')),
              );
            },
            icon: const Icon(Icons.link_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: colorScheme.surfaceContainerLowest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '先在这里完成登录，脚本会在当前网页内继续执行导入。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _useDesktopMode ? '当前：电脑网页' : '当前：手机网页',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addressController,
                        focusNode: _addressFocusNode,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '输入或修改网页地址',
                          prefixIcon: const Icon(Icons.language_rounded, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _loadAddressBarUrl(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loadAddressBarUrl,
                      child: const Text('前往'),
                    ),
                  ],
                ),
                if ((_lastScriptStatus ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _lastScriptStatus!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ] else if (_rememberedLogin != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '已记住账号：${_rememberedLogin!.username}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_loadingProgress < 100)
            LinearProgressIndicator(value: _loadingProgress / 100),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: FilledButton.icon(
                onPressed: _isExecutingImport ? null : _executeImportScript,
                icon: _isExecutingImport
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_isExecutingImport ? '导入中...' : '执行导入脚本'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAddressBarUrl() async {
    final text = _addressController.text.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      if (!mounted) return;
      _showLightTip(context, '网页地址格式不正确');
      return;
    }
    _addressFocusNode.unfocus();
    setState(() {
      _currentUrl = uri.toString();
      _loadingProgress = 0;
    });
    await _controller.loadRequest(uri);
  }

  Future<void> _toggleWebPageMode() async {
    final nextDesktopMode = !_useDesktopMode;
    setState(() {
      _useDesktopMode = nextDesktopMode;
      _loadingProgress = 0;
    });
    await _controller.setUserAgent(
      nextDesktopMode ? _desktopUserAgent : _mobileUserAgent,
    );
    final target = Uri.tryParse(_currentUrl ?? widget.initialUrl);
    if (target != null) {
      await _controller.loadRequest(target);
    }
  }

  Future<void> _installLoginWatcher() async {
    try {
      await _controller.runJavaScript('''
(() => {
  const collect = () => {
    const textInputs = Array.from(document.querySelectorAll('input')).filter((input) => {
      const type = (input.type || 'text').toLowerCase();
      return ['text','email','tel','number'].includes(type) && !input.disabled;
    });
    const passwordInput = Array.from(document.querySelectorAll('input[type="password"]')).find((input) => !input.disabled);
    QingyuBridge.postMessage(JSON.stringify({
      type: 'loginState',
      username: textInputs[0] ? String(textInputs[0].value || '') : '',
      password: passwordInput ? String(passwordInput.value || '') : '',
      hasPasswordField: !!passwordInput
    }));
  };
  if (!window.__qingyuLoginWatcherInstalled) {
    window.__qingyuLoginWatcherInstalled = true;
    document.addEventListener('input', (event) => {
      if (event.target && event.target.tagName === 'INPUT') collect();
    }, true);
    document.addEventListener('change', (event) => {
      if (event.target && event.target.tagName === 'INPUT') collect();
    }, true);
    document.addEventListener('click', (event) => {
      const target = event.target;
      if (!(target instanceof HTMLElement)) return;
      const text = (target.innerText || target.textContent || target.value || '').trim().toLowerCase();
      if (/登录|login|sign in|signin|进入教务|提交/.test(text)) {
        collect();
        QingyuBridge.postMessage(JSON.stringify({ type: 'loginAttempt' }));
      }
    }, true);
    document.addEventListener('submit', () => {
      collect();
      QingyuBridge.postMessage(JSON.stringify({ type: 'loginAttempt' }));
    }, true);
  }
  collect();
})();
''');
    } catch (_) {}
  }

  Future<void> _executeImportScript() async {
    setState(() {
      _isExecutingImport = true;
      _lastScriptStatus = '正在读取并注入适配脚本…';
    });
    try {
      final script = await _repositoryService.fetchAdapterScript(
        widget.source,
        school: widget.school,
        adapter: widget.adapter,
        options: widget.fetchOptions,
      );
      final wrappedScript = '''
(() => {
  window.__qingyuResolvers = window.__qingyuResolvers || {};
  window.AndroidBridge = {
    showToast: (msg) => QingyuBridge.postMessage(JSON.stringify({type: 'toast', message: String(msg ?? '')})),
    notifyTaskCompletion: () => QingyuBridge.postMessage(JSON.stringify({type: 'complete'}))
  };
  window.AndroidBridgePromise = {
    showAlert: async (title, message, confirmText) => {
      const requestId = 'confirm_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'confirm',
          requestId,
          title: String(title ?? ''),
          message: String(message ?? ''),
          confirmText: String(confirmText ?? '确认')
        }));
      });
    },
    showPrompt: async (title, message, defaultValue, validatorName) => {
      const requestId = 'prompt_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'prompt',
          requestId,
          title: String(title ?? ''),
          message: String(message ?? ''),
          defaultValue: String(defaultValue ?? ''),
          validatorName: String(validatorName ?? '')
        }));
      });
    },
    showSingleSelection: async (title, optionsJson, selectedIndex) => {
      const requestId = 'single_selection_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'singleSelection',
          requestId,
          title: String(title ?? ''),
          optionsJson: String(optionsJson ?? '[]'),
          selectedIndex: Number(selectedIndex ?? 0)
        }));
      });
    },
    saveCourseConfig: async (json) => {
      const requestId = 'course_config_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'saveCourseConfig',
          requestId,
          payload: String(json ?? '{}')
        }));
      });
    },
    savePresetTimeSlots: async (json) => {
      const requestId = 'preset_time_slots_' + Date.now() + '_' + Math.random().toString(36).slice(2);
      return await new Promise((resolve) => {
        window.__qingyuResolvers[requestId] = resolve;
        QingyuBridge.postMessage(JSON.stringify({
          type: 'savePresetTimeSlots',
          requestId,
          payload: String(json ?? '[]')
        }));
      });
    },
    saveImportedCourses: async (json) => {
      QingyuBridge.postMessage(JSON.stringify({type: 'courses', payload: String(json ?? '[]')}));
      return true;
    }
  };
  try {
    $script
  } catch (error) {
    QingyuBridge.postMessage(JSON.stringify({type: 'error', message: String(error)}));
  }
})();
''';
      await _controller.runJavaScript(wrappedScript);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastScriptStatus = '脚本已注入，等待页面解析返回课程。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExecutingImport = false;
        _lastScriptStatus = '脚本注入失败';
      });
      _showLightTip(context, '执行失败：$error');
    }
  }

  Future<void> _handleBridgeMessage(String rawMessage) async {
    Map<String, dynamic>? message;
    try {
      message = jsonDecode(rawMessage) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = message['type'] as String? ?? '';
    switch (type) {
      case 'loginState':
        await _handleLoginStateMessage(message);
        break;
      case 'loginAttempt':
        await _handleLoginAttempt();
        break;
      case 'toast':
        if (!mounted) return;
        _showLightTip(context, (message['message'] as String?) ?? '');
        break;
      case 'confirm':
        await _showScriptConfirmDialog(message);
        break;
      case 'prompt':
        await _showScriptPromptDialog(message);
        break;
      case 'singleSelection':
        await _showScriptSingleSelectionDialog(message);
        break;
      case 'saveCourseConfig':
        await _handleSaveCourseConfig(message);
        break;
      case 'savePresetTimeSlots':
        await _handleSavePresetTimeSlots(message);
        break;
      case 'error':
        if (!mounted) return;
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = '脚本执行失败';
        });
        _showLightTip(context, (message['message'] as String?) ?? '脚本执行失败');
        break;
      case 'courses':
        await _handleImportedCoursesJson((message['payload'] as String?) ?? '[]');
        break;
      case 'complete':
        if (!mounted) return;
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = '导入流程已结束';
        });
        break;
    }
  }

  Future<void> _showScriptConfirmDialog(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((message['title'] as String?)?.trim().isNotEmpty == true
            ? (message['title'] as String)
            : '确认导入'),
        content: Text((message['message'] as String?) ?? '是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text((message['confirmText'] as String?) ?? '确认'),
          ),
        ],
      ),
    );
    await _resolveJavaScriptRequest(requestId, confirmed == true);
  }

  Future<void> _showScriptPromptDialog(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    final validatorName = (message['validatorName'] as String?) ?? '';
    final controller = TextEditingController(
      text: (message['defaultValue'] as String?) ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((message['title'] as String?) ?? '请输入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((message['message'] as String?) ?? ''),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (validatorName == 'validateYearInput' &&
                  !RegExp(r'^[0-9]{4}$').hasMatch(text)) {
                _showLightTip(context, '请输入四位数字的学年');
                return;
              }
              Navigator.pop(context, text);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    await _resolveJavaScriptRequest(requestId, result);
  }

  Future<void> _showScriptSingleSelectionDialog(
    Map<String, dynamic> message,
  ) async {
    final requestId = (message['requestId'] as String?) ?? '';
    final optionsRaw = (message['optionsJson'] as String?) ?? '[]';
    final selectedIndex = (message['selectedIndex'] as num?)?.toInt() ?? 0;
    List<String> options = const [];
    try {
      final decoded = jsonDecode(optionsRaw);
      if (decoded is List) {
        options = decoded.map((item) => item.toString()).toList(growable: false);
      }
    } catch (_) {}
    var currentSelection =
        selectedIndex.clamp(0, options.isEmpty ? 0 : options.length - 1);
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((message['title'] as String?) ?? '请选择'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(options.length, (index) {
              return RadioListTile<int>(
                value: index,
                groupValue: currentSelection,
                title: Text(options[index]),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    currentSelection = value;
                  });
                },
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, currentSelection),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    await _resolveJavaScriptRequest(requestId, result);
  }

  Future<void> _handleSaveCourseConfig(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    try {
      final decoded = jsonDecode((message['payload'] as String?) ?? '{}');
      if (decoded is! Map) {
        throw const FormatException('课程配置格式不正确');
      }
      final provider = context.read<TimetableProvider>();
      final semesterTotalWeeks =
          (decoded['semesterTotalWeeks'] as num?)?.toInt();
      if (semesterTotalWeeks != null && semesterTotalWeeks > 0) {
        final result = await provider.updateTimetableSettings(
          provider.settings.copyWith(
            semesterWeekCount: semesterTotalWeeks,
          ),
        );
        if (result != null) {
          throw FormatException(result);
        }
      }
      await _resolveJavaScriptRequest(requestId, true);
    } catch (error) {
      if (!mounted) return;
      _showLightTip(context, '保存课程配置失败：$error');
      await _resolveJavaScriptRequest(requestId, false);
    }
  }

  Future<void> _handleSavePresetTimeSlots(Map<String, dynamic> message) async {
    final requestId = (message['requestId'] as String?) ?? '';
    try {
      final decoded = jsonDecode((message['payload'] as String?) ?? '[]');
      if (decoded is! List) {
        throw const FormatException('节次时间格式不正确');
      }
      final sections = decoded
          .whereType<Map>()
          .map(
            (item) => SectionTime(
              startTime: item['startTime']?.toString() ?? '',
              endTime: item['endTime']?.toString() ?? '',
            ),
          )
          .where((item) => item.startTime.isNotEmpty && item.endTime.isNotEmpty)
          .toList(growable: false);
      if (sections.isEmpty) {
        throw const FormatException('没有可保存的节次时间');
      }
      final provider = context.read<TimetableProvider>();
      final schemeName = '${widget.school.name} 教务导入时间';
      TimeScheme? existingScheme;
      for (final scheme in provider.timeSchemes) {
        if (scheme.name == schemeName) {
          existingScheme = scheme;
          break;
        }
      }
      if (existingScheme == null) {
        final created = await provider.createTimeScheme(
          name: schemeName,
          sections: sections,
          applyToActiveProfile: true,
        );
        await provider.applyTimeScheme(created.id);
      } else {
        final result = await provider.updateTimeScheme(
          schemeId: existingScheme.id,
          name: existingScheme.name,
          sections: sections,
        );
        if (result != null) {
          throw FormatException(result);
        }
        await provider.applyTimeScheme(existingScheme.id);
      }
      await _resolveJavaScriptRequest(requestId, true);
    } catch (error) {
      if (!mounted) return;
      _showLightTip(context, '保存节次时间失败：$error');
      await _resolveJavaScriptRequest(requestId, false);
    }
  }

  Future<void> _resolveJavaScriptRequest(String requestId, Object? value) async {
    final encoded = jsonEncode(value);
    await _controller.runJavaScript(
      "window.__qingyuResolvers = window.__qingyuResolvers || {}; "
      "window.__qingyuResolvers['$requestId']?.($encoded); "
      "delete window.__qingyuResolvers['$requestId'];",
    );
  }

  Future<void> _handleImportedCoursesJson(String payload) async {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) {
        throw const FormatException('课程数据格式不正确');
      }
      final parsedCourses = _parseWarehouseCourses(decoded);
      if (parsedCourses.isEmpty) {
        throw const FormatException('脚本没有返回可导入课程');
      }

      final provider = context.read<TimetableProvider>();
      final replaceExisting = provider.courses.isEmpty
          ? true
          : await _askReplaceExisting(
              context,
              title: '导入课程',
              content: '检测到 ${parsedCourses.length} 条课程，是否替换现有课程？',
            );
      if (replaceExisting == null || !mounted) {
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = '已取消导入';
        });
        return;
      }

      final semesterConfig = await _pickImportSemesterConfig(
        context,
        initialSemesterStartDate:
            provider.settings.semesterStartDate ?? DateTime.now(),
        initialFirstCourseWeek: 1,
        title: '确认开学日期和周次对应',
        subtitle: '教务脚本已返回课程周次，请确认校历开学日期；如果学校前几周没有课，可把“课表第 1 周”对应到校历后面的周次。',
      );
      if (semesterConfig == null || !mounted) {
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = '已取消导入';
        });
        return;
      }

      final alignedCourses = _weekAlignmentService.shiftCoursesToSemesterWeeks(
        parsedCourses,
        firstCourseWeek: semesterConfig.firstCourseWeek,
      );
      final requiredSectionCount =
          provider.previewImportedCourseRequiredSectionCount(
        alignedCourses,
        replaceExisting: replaceExisting,
      );
      final capacityReady = await _ensureSectionCapacity(
        context,
        requiredSectionCount: requiredSectionCount,
        provider: provider,
      );
      if (!capacityReady || !mounted) {
        setState(() {
          _isExecutingImport = false;
          _lastScriptStatus = '导入已中止';
        });
        return;
      }

      final importedCount = await provider.importParsedCourses(
        alignedCourses,
        replaceExisting: replaceExisting,
        semesterStart: semesterConfig.semesterStartDate,
        source: 'warehouse',
      );
      if (!mounted) {
        return;
      }
      await _preferencesService.addRecentSchool(widget.school.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastScriptStatus = importedCount > 0
            ? '已更新课表：新增或更新 $importedCount 条课程'
            : '没有需要新增或更新的课程';
      });
      final navigator = Navigator.of(context);
      _showLightTip(
        context,
        importedCount > 0
            ? '已更新课表：新增或更新 $importedCount 条课程'
            : '没有需要新增或更新的课程',
      );
      if (importedCount > 0) {
        navigator.pop(true);
      } else {
        setState(() {
          _isExecutingImport = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isExecutingImport = false;
        _lastScriptStatus = '导入失败';
      });
      _showLightTip(context, '导入失败：$error');
    }
  }

  List<Course> _parseWarehouseCourses(List<dynamic> rawCourses) {
    final courses = <Course>[];
    for (final item in rawCourses) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
      final name = (map['name'] as String? ?? '').trim();
      final teacher = (map['teacher'] as String? ?? '').trim();
      final location =
          (map['position'] as String? ?? map['location'] as String? ?? '').trim();
      final day = (map['day'] as num?)?.toInt();
      final startSection = (map['startSection'] as num?)?.toInt();
      final endSection = (map['endSection'] as num?)?.toInt();
      final weeks = (map['weeks'] as List<dynamic>?)
          ?.map((item) => (item as num).toInt())
          .where((item) => item > 0)
          .toSet()
          .toList()
        ?..sort();
      if (name.isEmpty ||
          day == null ||
          startSection == null ||
          endSection == null ||
          weeks == null ||
          weeks.isEmpty) {
        continue;
      }
      courses.add(
        Course(
          id: const Uuid().v4(),
          name: name,
          teacher: teacher.isEmpty ? '未知' : teacher,
          location: location.isEmpty ? '未知地点' : location,
          dayOfWeek: day,
          startSection: startSection,
          endSection: endSection,
          startTime: '',
          endTime: '',
          customWeeks: weeks,
        ),
      );
    }
    return courses;
  }

  Future<void> _handleLoginStateMessage(Map<String, dynamic> message) async {
    final hasPasswordField = message['hasPasswordField'] == true;
    if (!hasPasswordField || _isPromptShowing) {
      return;
    }
    final candidate = WarehouseRememberedLogin(
      username: (message['username'] as String? ?? '').trim(),
      password: (message['password'] as String? ?? '').trim(),
    );
    _latestLoginCandidate = candidate;

    if (_rememberedLogin != null &&
        !_hasPromptedAutofill &&
        candidate.username.isEmpty &&
        candidate.password.isEmpty) {
      _hasPromptedAutofill = true;
      _isPromptShowing = true;
      final shouldAutofill = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('自动填入账号密码？'),
          content: Text('检测到你之前保存过账号：${_rememberedLogin!.username}。是否自动填入？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂不'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('自动填入'),
            ),
          ],
        ),
      );
      _isPromptShowing = false;
      if (shouldAutofill == true) {
        await _autofillRememberedLogin();
      }
      return;
    }

  }

  Future<void> _handleLoginAttempt() async {
    final candidate = _latestLoginCandidate;
    if (candidate == null ||
        _rememberedLogin != null ||
        _hasPromptedSave ||
        _isPromptShowing ||
        candidate.username.isEmpty ||
        candidate.password.isEmpty) {
      return;
    }
    _hasPromptedSave = true;
    _isPromptShowing = true;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记住密码？'),
        content: Text('检测到你正在登录账号 ${candidate.username}。是否记住账号密码，下次自动填入？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('不记住'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('记住并自动填入'),
          ),
        ],
      ),
    );
    _isPromptShowing = false;
    if (shouldSave == true) {
      await _preferencesService.setRememberedLogin(
        widget.adapter.adapterId,
        candidate,
      );
      if (!mounted) return;
      setState(() {
        _rememberedLogin = candidate;
        _lastScriptStatus = '已记住账号密码，下次可自动填入';
      });
    }
  }

  Future<void> _loadRememberedLogin() async {
    final login = await _preferencesService.getRememberedLogin(
      widget.adapter.adapterId,
    );
    if (!mounted) return;
    setState(() {
      _rememberedLogin = login;
    });
  }

  Future<void> _autofillRememberedLoginIfNeeded() async {
    if (_rememberedLogin == null || _hasPromptedAutofill || _isPromptShowing) {
      return;
    }
  }

  Future<void> _autofillRememberedLogin() async {
    final login = _rememberedLogin;
    if (login == null) return;
    final js = '''
(() => {
  const textInputs = Array.from(document.querySelectorAll('input')).filter((input) => {
    const type = (input.type || 'text').toLowerCase();
    return ['text','email','tel','number'].includes(type) && !input.disabled;
  });
  const passwordInput = Array.from(document.querySelectorAll('input[type="password"]')).find((input) => !input.disabled);
  if (textInputs[0]) {
    textInputs[0].focus();
    textInputs[0].value = ${jsonEncode(login.username)};
    textInputs[0].dispatchEvent(new Event('input', { bubbles: true }));
    textInputs[0].dispatchEvent(new Event('change', { bubbles: true }));
  }
  if (passwordInput) {
    passwordInput.focus();
    passwordInput.value = ${jsonEncode(login.password)};
    passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
    passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
  }
})();
''';
    await _controller.runJavaScript(js);
    if (!mounted) return;
    setState(() {
      _lastScriptStatus = '已自动填入记住的账号密码';
    });
  }

  Future<void> _rememberCurrentLogin() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult('''
(() => {
  const textInputs = Array.from(document.querySelectorAll('input')).filter((input) => {
    const type = (input.type || 'text').toLowerCase();
    return ['text','email','tel','number'].includes(type) && !input.disabled;
  });
  const passwordInput = Array.from(document.querySelectorAll('input[type="password"]')).find((input) => !input.disabled);
  return JSON.stringify({
    username: textInputs[0] ? String(textInputs[0].value || '') : '',
    password: passwordInput ? String(passwordInput.value || '') : ''
  });
})();
''');
      final normalized = _normalizeJavaScriptResult(raw);
      final decoded = jsonDecode(normalized);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('当前页面没有可识别的登录输入框');
      }
      final login = WarehouseRememberedLogin.fromJson(decoded);
      if (login.username.isEmpty && login.password.isEmpty) {
        if (!mounted) return;
        _showLightTip(context, '当前页面没有识别到账号或密码输入内容');
        return;
      }
      await _preferencesService.setRememberedLogin(
        widget.adapter.adapterId,
        login,
      );
      if (!mounted) return;
      setState(() {
        _rememberedLogin = login;
        _lastScriptStatus = '已记住当前输入的账号密码';
      });
      _showLightTip(context, '已记住当前输入的账号密码');
    } catch (error) {
      if (!mounted) return;
      _showLightTip(context, '记住失败：$error');
    }
  }

  Future<void> _clearRememberedLogin() async {
    await _preferencesService.clearRememberedLogin(widget.adapter.adapterId);
    if (!mounted) return;
    setState(() {
      _rememberedLogin = null;
      _lastScriptStatus = '已清除记住的账号密码';
    });
    _showLightTip(context, '已清除记住的账号密码');
  }
}

class _WarehouseIntroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> chips;
  final String? markdown;

  const _WarehouseIntroCard({
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.markdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if ((markdown ?? '').trim().isNotEmpty) ...[
            if (subtitle.isNotEmpty) const SizedBox(height: 8),
            MarkdownBody(
              data: markdown!,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _WarehouseAdapterCard extends StatelessWidget {
  final WarehouseAdapterEntry adapter;
  final Future<void> Function()? onImport;
  final Future<void> Function() onInfo;
  final String importButtonLabel;

  const _WarehouseAdapterCard({
    required this.adapter,
    required this.onImport,
    required this.onInfo,
    required this.importButtonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.extension_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adapter.adapterName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '类别：${adapter.category} · 维护者：${adapter.maintainer}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (adapter.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              MarkdownBody(
                data: adapter.description,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.web_rounded),
                    label: Text(importButtonLabel),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onInfo,
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('查看信息'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseSchoolCard extends StatelessWidget {
  final WarehouseSchoolEntry school;
  final bool isRecent;
  final VoidCallback onTap;

  const _WarehouseSchoolCard({
    required this.school,
    this.isRecent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  school.initial,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isRecent) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '最近',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            '资源目录：${school.resourceFolder}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarehouseSchoolBean extends ISuspensionBean {
  final WarehouseSchoolEntry school;
  final String tag;
  final bool isRecent;

  _WarehouseSchoolBean({
    required this.school,
    required this.tag,
    required this.isRecent,
  });

  @override
  String getSuspensionTag() => tag;
}

List<_WarehouseSchoolBean> _schoolsToBeans(
  List<WarehouseSchoolEntry> schools,
  List<String> recentSchoolIds,
) {
  final recentOrdered = recentSchoolIds
      .map((id) => schools.where((school) => school.id == id).firstOrNull)
      .whereType<WarehouseSchoolEntry>()
      .toList(growable: false);
  final remaining = schools
      .where((school) => !recentSchoolIds.contains(school.id))
      .toList(growable: false);
  final beans = <_WarehouseSchoolBean>[
    ...recentOrdered.map(
      (school) => _WarehouseSchoolBean(
        school: school,
        tag: '★',
        isRecent: true,
      ),
    ),
    ...remaining.map(
      (school) => _WarehouseSchoolBean(
        school: school,
        tag: school.initial.trim().isEmpty
            ? '#'
            : school.initial.trim().toUpperCase(),
        isRecent: false,
      ),
    ),
  ];
  SuspensionUtil.setShowSuspensionStatus(beans);
  return beans;
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ImportSemesterConfig {
  final DateTime semesterStartDate;
  final int firstCourseWeek;

  const _ImportSemesterConfig({
    required this.semesterStartDate,
    required this.firstCourseWeek,
  });
}

class _ImportEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String footer;
  final VoidCallback onTap;

  const _ImportEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle),
                    const SizedBox(height: 8),
                    Text(
                      footer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  final String title;
  final String subtitle;

  const _GuideLine({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            title.replaceAll('步骤 ', ''),
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactHintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CompactHintChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatusChip extends StatelessWidget {
  final String label;
  final bool isError;

  const _CompactStatusChip({
    required this.label,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor =
        isError ? colorScheme.errorContainer : colorScheme.primaryContainer;
    final foregroundColor =
        isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactNoticeCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const _CompactNoticeCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isError
        ? colorScheme.errorContainer.withValues(alpha: 0.92)
        : colorScheme.surfaceContainerHigh;
    final foregroundColor =
        isError ? colorScheme.onErrorContainer : colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: foregroundColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foregroundColor,
                height: 1.35,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiPreviewCard extends StatelessWidget {
  final AiCourseImportParseResult result;

  const _AiPreviewCard({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '解析预览',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text('课程数量：${result.courses.length}'),
          Text('最大节次：第 ${result.requiredSectionCount} 节'),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '识别提醒',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...result.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $warning'),
              ),
            ),
          ],
          if (result.courses.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '课程预览',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...result.courses.take(6).map(_buildCoursePreviewLine),
            if (result.courses.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '其余 ${result.courses.length - 6} 条将在导入后写入当前课表',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoursePreviewLine(Course course) {
    final weeks = course.customWeeks ?? const [];
    final weekText = weeks.isEmpty
        ? '未提供周次'
        : weeks.length <= 6
            ? weeks.join('、')
            : '${weeks.first}-${weeks.last}（共 ${weeks.length} 周）';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '周${_weekdayLabel(course.dayOfWeek)} 第${course.startSection}-${course.endSection}节  ${course.name}  ${course.location.isEmpty ? "未填写地点" : course.location}  周次：$weekText',
      ),
    );
  }
}

Future<_ImportSemesterConfig?> _pickImportSemesterConfig(
  BuildContext context, {
  required DateTime initialSemesterStartDate,
  required int initialFirstCourseWeek,
  required String title,
  required String subtitle,
  DateTime? inferredFirstCourseDate,
}) {
  final alignmentService = const ImportWeekAlignmentService();
  return showModalBottomSheet<_ImportSemesterConfig>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final colorScheme = theme.colorScheme;
      var selectedSemesterStartDate = initialSemesterStartDate;
      var selectedFirstCourseWeek = initialFirstCourseWeek < 1
          ? 1
          : initialFirstCourseWeek > 20
              ? 20
              : initialFirstCourseWeek;
      var autoTrackWeekMapping = inferredFirstCourseDate != null;

      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickStartDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedSemesterStartDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked == null || !context.mounted) {
              return;
            }
            setModalState(() {
              selectedSemesterStartDate = picked;
              if (autoTrackWeekMapping && inferredFirstCourseDate != null) {
                selectedFirstCourseWeek = alignmentService.inferFirstCourseWeek(
                  semesterStartDate: selectedSemesterStartDate,
                  firstCourseDate: inferredFirstCourseDate,
                );
              }
            });
          }

          final shiftedWeeks = selectedFirstCourseWeek - 1;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('开学日期'),
                    subtitle: Text(
                      '${_formatDate(selectedSemesterStartDate)} · 按这一天所在周作为校历第 1 周',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: pickStartDate,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedFirstCourseWeek,
                    decoration: const InputDecoration(
                      labelText: '课表第 1 周对应校历第几周',
                      border: OutlineInputBorder(),
                      helperText: '如果学校第一周没课，就选第 2 周；前两周都没课就选第 3 周。',
                    ),
                    items: List.generate(20, (index) => index + 1)
                        .map(
                          (week) => DropdownMenuItem<int>(
                            value: week,
                            child: Text('校历第 $week 周'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setModalState(() {
                        selectedFirstCourseWeek = value;
                        autoTrackWeekMapping = false;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      shiftedWeeks <= 0
                          ? '导入后会直接把课表第 1 周当作校历第 1 周。'
                          : '导入后会把所有课程周次整体顺延 $shiftedWeeks 周，让课表第 1 周落在校历第 $selectedFirstCourseWeek 周。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(
                            context,
                            _ImportSemesterConfig(
                              semesterStartDate: selectedSemesterStartDate,
                              firstCourseWeek: selectedFirstCourseWeek,
                            ),
                          ),
                          child: const Text('继续导入'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<bool?> _askReplaceExisting(
  BuildContext context, {
  required String title,
  required String content,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text('$content\n\n建议日常更新课表时优先使用“更新课表（保留本地信息）”。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('更新课表（推荐）'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('覆盖导入'),
          ),
        ],
      );
    },
  );
}

Future<bool> _ensureSectionCapacity(
  BuildContext context, {
  required int requiredSectionCount,
  required TimetableProvider provider,
}) async {
  if (requiredSectionCount <= provider.settings.sectionCount) {
    return true;
  }

  final shouldContinue = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('时间模板节次不足'),
        content: Text(
          '当前课表时间模板只有 ${provider.settings.sectionCount} 节，但导入数据需要到第 $requiredSectionCount 节。是否自动补齐后继续导入？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('自动补齐并导入'),
          ),
        ],
      );
    },
  );

  if (shouldContinue != true || !context.mounted) {
    return false;
  }

  final ensureMessage =
      await provider.ensureSectionCapacityForImport(requiredSectionCount);
  if (ensureMessage != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ensureMessage)),
      );
    }
    return false;
  }
  return true;
}

String _weekdayLabel(int dayOfWeek) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  if (dayOfWeek < 1 || dayOfWeek > 7) {
    return dayOfWeek.toString();
  }
  return labels[dayOfWeek - 1];
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _normalizeJavaScriptResult(Object? raw) {
  if (raw == null) {
    return '';
  }
  final text = raw.toString();
  try {
    final decoded = jsonDecode(text);
    if (decoded is String) {
      return decoded;
    }
  } catch (_) {}
  return text;
}

Future<String?> _promptWarehouseImportUrl(
  BuildContext context, {
  required String schoolName,
  required String adapterName,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('输入教务网址'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“$schoolName / $adapterName” 没有默认登录地址，请先输入学校教务系统网址。'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '教务网址',
              hintText: 'http(s)://...',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '保存后下次会直接使用，也可以在适配器信息页里修改。',
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('保存并继续'),
        ),
      ],
    ),
  );
  if (result == null || result.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(result.trim());
  if (uri == null || uri.host.isEmpty) {
    if (!context.mounted) {
      return null;
    }
    _showLightTip(context, '登录地址格式不正确');
    return null;
  }
  return result.trim();
}

void _showLightTip(BuildContext context, String message) {
  if (message.trim().isEmpty) {
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.inverseSurface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1500)).then((_) {
    entry.remove();
  });
}
