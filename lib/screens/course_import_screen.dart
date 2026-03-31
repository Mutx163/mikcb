import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../providers/timetable_provider.dart';
import '../services/ai_course_import_service.dart';
import '../services/ics_import_service.dart';
import '../services/import_week_alignment_service.dart';

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

      final replaceExisting = await _askReplaceExisting(
        context,
        title: '导入课程',
        content: '导入 ${file.name} 时，是否替换现有课程？',
      );
      if (replaceExisting == null || !mounted) {
        return;
      }

      final provider = context.read<TimetableProvider>();
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
            importedCount > 0 ? '已导入 $importedCount 条课程' : '未识别到可导入课程',
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
      resizeToAvoidBottomInset: false,
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

      final replaceExisting = await _askReplaceExisting(
        context,
        title: '导入 AI 解析结果',
        content: '是否用当前这份 AI 解析结果替换现有课程？',
      );
      if (replaceExisting == null || !mounted) {
        return;
      }

      final provider = context.read<TimetableProvider>();
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
                ? '已导入 $importedCount 条课程$warningSuffix'
                : '没有可导入的课程数据',
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
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('追加导入'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('替换现有'),
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
