// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 仓库导入共享 UI 与工具
// 学校列表分组、适配器行、菜单动作等仓库侧共享零件。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/warehouse_repository_models.dart';
import '../../log_viewer_entry.dart';
import '../import_shared.dart';

enum WarehouseImportMenuAction { feedback, customDebug, executionLog }


/// 把一个已挂载控件的窗口坐标量出来（上游 OS4 玻璃弹层按它定位面板）。
///
/// 量不到（还没 layout / 已销毁）就返回 null —— 宁可这次不打开菜单，
/// 也不让面板贴到 (0,0)。
Rect? measurePopupAnchorRect(GlobalKey key) {
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  return MatrixUtils.transformRect(
    renderObject.getTransformTo(null),
    Offset.zero & renderObject.size,
  );
}

Future<void> openWarehouseImportExecutionLogViewer(BuildContext context) =>
    openLogViewer(context, AppLogSource.warehouseImport);

Widget buildWarehouseAdapterListItem({
  required BuildContext context,
  required WarehouseAdapterEntry adapter,
  required bool hasMacro,
  required Future<void> Function()? onImport,
  required Future<void> Function()? onRecord,
  required Future<void> Function() onInfo,
  required Future<void> Function()? onQuickImport,
  required String importButtonLabel,
  required String recordButtonLabel,
}) {
  final scope = HyperosListTileScope.maybeOf(context);
  return Padding(
    padding: HyperosTokens.rowPadding(
      isFirst: scope?.isFirst ?? true,
      isLast: scope?.isLast ?? true,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ImportIconBadge(icon: Icons.extension_outlined),
        const SizedBox(width: HyperosTokens.rowContentGap),
        Expanded(
          child: WarehouseAdapterTileBody(
            adapter: adapter,
            hasMacro: hasMacro,
            onImport: onImport,
            onRecord: onRecord,
            onInfo: onInfo,
            onQuickImport: onQuickImport,
            importButtonLabel: importButtonLabel,
            recordButtonLabel: recordButtonLabel,
          ),
        ),
      ],
    ),
  );
}

/// Identifies the loaded document: scheme + host + path, ignoring query and
/// fragment so same-document navigations (hash routing) compare equal.
///
/// Used to decide whether a page start really destroyed the injected script's
/// execution context (only a full document replacement does) or was just an
/// in-page tab switch that must not be mistaken for an abandoned import.
String warehouseDocumentKey(String? url) {
  final uri = Uri.tryParse((url ?? '').trim());
  if (uri == null || !uri.hasScheme) {
    return (url ?? '').trim();
  }
  return '${uri.scheme}://${uri.host}${uri.path}'.toLowerCase();
}

class WarehouseIntroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> chips;
  final String? markdown;

  const WarehouseIntroCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.markdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HyperosControlCard(
      title: title,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((markdown ?? '').trim().isNotEmpty)
              MarkdownBody(
                data: markdown!,
                styleSheet: MarkdownStyleSheet.fromTheme(
                  theme,
                ).copyWith(p: HyperosTypography.sectionDescription(context)),
              ),
            if (chips.isNotEmpty) ...[
              if ((markdown ?? '').trim().isNotEmpty)
                const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips
                    .map((item) => HyperosTag(label: item))
                    .toList(growable: false),
              ),
            ],
            if ((markdown ?? '').trim().isEmpty && chips.isEmpty)
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class WarehouseAdapterTileBody extends StatelessWidget {
  final WarehouseAdapterEntry adapter;
  final bool hasMacro;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onRecord;
  final Future<void> Function() onInfo;
  final Future<void> Function()? onQuickImport;
  final String importButtonLabel;
  final String recordButtonLabel;

  const WarehouseAdapterTileBody({
    super.key,
    required this.adapter,
    required this.hasMacro,
    required this.onImport,
    required this.onRecord,
    required this.onInfo,
    required this.onQuickImport,
    required this.importButtonLabel,
    required this.recordButtonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        importListTitle(context, adapter.adapterName),
        const SizedBox(height: 4),
        importListDetail(
          context,
          '${l10n.categoryLabel}：${adapter.category} · ${l10n.maintainerLabel}：${adapter.maintainer}',
        ),
        if (adapter.description.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          MarkdownBody(
            data: adapter.description,
            styleSheet: MarkdownStyleSheet.fromTheme(
              theme,
            ).copyWith(p: HyperosTypography.sectionDescription(context)),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: HyperosButton(
                label: importButtonLabel,
                expand: true,
                fitLabel: true,
                onPressed: onImport,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HyperosButton(
                label: recordButtonLabel,
                variant: HyperosButtonVariant.secondary,
                expand: true,
                fitLabel: true,
                onPressed: onRecord,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: HyperosButton(
            label: l10n.viewDetailsAction,
            variant: HyperosButtonVariant.secondary,
            onPressed: onInfo,
          ),
        ),
        if (hasMacro) ...[
          const SizedBox(height: 10),
          HyperosButton(
            label: l10n.quickImportAction,
            expand: true,
            onPressed: onQuickImport,
          ),
        ],
      ],
    );
  }
}

class WarehouseSchoolSection extends ISuspensionBean {
  WarehouseSchoolSection({required this.tag, required this.items});

  final String tag;
  final List<WarehouseSchoolBean> items;

  @override
  String getSuspensionTag() => tag;
}

class WarehouseSchoolBean extends ISuspensionBean {
  final WarehouseSchoolEntry school;
  final String tag;
  final bool isRecent;

  WarehouseSchoolBean({
    required this.school,
    required this.tag,
    required this.isRecent,
  });

  @override
  String getSuspensionTag() => tag;
}

List<WarehouseSchoolBean> schoolsToBeans(
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
  final beans = <WarehouseSchoolBean>[
    ...recentOrdered.map(
      (school) =>
          WarehouseSchoolBean(school: school, tag: '★', isRecent: true),
    ),
    ...remaining.map(
      (school) => WarehouseSchoolBean(
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

List<WarehouseSchoolSection> schoolsToSections(
  List<WarehouseSchoolBean> beans,
) {
  if (beans.isEmpty) {
    return const [];
  }

  final sections = <WarehouseSchoolSection>[];
  var currentTag = beans.first.tag;
  var currentItems = <WarehouseSchoolBean>[];

  for (final bean in beans) {
    if (bean.tag != currentTag) {
      sections.add(
        WarehouseSchoolSection(tag: currentTag, items: currentItems),
      );
      currentTag = bean.tag;
      currentItems = [bean];
    } else {
      currentItems.add(bean);
    }
  }
  sections.add(WarehouseSchoolSection(tag: currentTag, items: currentItems));
  SuspensionUtil.setShowSuspensionStatus(sections);
  return sections;
}

