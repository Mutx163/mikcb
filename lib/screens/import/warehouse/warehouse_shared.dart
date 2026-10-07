// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 仓库导入共享 UI 与工具
// 学校列表分组、适配器行、菜单动作等仓库侧共享零件。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import 'dart:async';
import 'dart:math' as math;
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

/// 名称含「通用」的都是通用教务/工具类学校（超星/正方/青果/URP/通用工具），
/// 与 schoolsToBeans/schoolsToSections 的置顶分组共用同一判定。
bool isGenericWarehouseSchool(String name) => name.contains('通用');

/// 学校在列表里的 suspension tag：最近使用 → ★，通用置顶 → 通，
/// 其余按首字母大写（空记 #）。
///
/// 通用学校必须用独立 tag，不能沿用自己的首字母（C/Q/T/U/Z）：否则
/// 通用块（置顶在最前）与正常学校的同字母块会形成重复 tag，AzListView
/// 点索引只跳到第一个（_getIndex 取首个相等），就会出现「点下面的 C
/// （重庆）却跳到上面的 C（超星）」。
String warehouseSchoolTag(
  WarehouseSchoolEntry school, {
  required bool isRecent,
}) {
  if (isRecent) return '★';
  if (isGenericWarehouseSchool(school.name)) return '通';
  final normalized = school.initial.trim().toUpperCase();
  if (normalized.isEmpty) return '#';
  return normalized;
}

int _warehouseSchoolTagRank(String tag) {
  if (tag == '★') return 0;
  if (tag == '通') return 1;
  if (tag == '#') return 1000;
  return 10;
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
  // 通用学校单独成块置顶（tag 通），不能散在 A-Z 里，否则置顶块与正常
  // 同字母块重复，索引条出现两个 C，点第二个会跳到第一个。
  final genericRemaining = remaining
      .where((school) => isGenericWarehouseSchool(school.name))
      .toList(growable: false);
  final normalRemaining = remaining
      .where((school) => !isGenericWarehouseSchool(school.name))
      .toList(growable: false);
  final beans = <WarehouseSchoolBean>[
    ...recentOrdered.map(
      (school) => WarehouseSchoolBean(
        school: school,
        tag: warehouseSchoolTag(school, isRecent: true),
        isRecent: true,
      ),
    ),
    ...genericRemaining.map(
      (school) => WarehouseSchoolBean(
        school: school,
        tag: warehouseSchoolTag(school, isRecent: false),
        isRecent: false,
      ),
    ),
    ...normalRemaining.map(
      (school) => WarehouseSchoolBean(
        school: school,
        tag: warehouseSchoolTag(school, isRecent: false),
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

  // 按 tag 合并（而非仅合并连续相同 tag）：调用方排序一旦把同 tag 拆开
  // （历史教训：通用置顶按原首字母排就会把 C 拆成两段），连续合并会产出
  // 重复 tag，AzListView 点第二个永远跳到第一个。这里按 ★→通→A-Z→#
  // 排 tag，同 tag 的学校保持传入顺序，保证 tag 唯一、索引一一对应。
  final grouped = <String, List<WarehouseSchoolBean>>{};
  for (final bean in beans) {
    grouped.putIfAbsent(bean.tag, () => []).add(bean);
  }
  final tags = grouped.keys.toList(growable: false)
    ..sort((left, right) {
      final rankCompare = _warehouseSchoolTagRank(
        left,
      ).compareTo(_warehouseSchoolTagRank(right));
      if (rankCompare != 0) return rankCompare;
      return left.compareTo(right);
    });

  final sections = <WarehouseSchoolSection>[
    for (final tag in tags)
      WarehouseSchoolSection(tag: tag, items: grouped[tag]!),
  ];
  SuspensionUtil.setShowSuspensionStatus(sections);
  return sections;
}

/// 字母条的版面尺寸。
typedef WarehouseIndexBarGeometry = ({
  double itemHeight,
  double height,
  double width,
});

/// 字母条最多占列表视口高度的比例（≈ 82%，与真机观感一致）。
const double warehouseIndexBarMaxHeightRatio = 0.82;

/// 字母行高下限：低于这个高度拇指很难稳定命中（行高即命中盒高度）。
const double warehouseIndexBarMinItemHeight = 10;

/// 字母条按可用高度封顶的尺寸。
///
/// 上游 [IndexBar] 的行高是固定 `itemHeight`、总高由 `height` 决定，字母数一
/// 多就 `RenderFlex overflow`（Column 高度超过父盒），而且超出父盒的首尾字母
/// 命中不到。真实 `root_index.yaml` 是 20~21 组 × 16px = 320~336px，竖屏够用、
/// 横屏视口（约 360px）已在边缘，再多几个首字母或分屏小窗就会翻车。
///
/// 行高取 `min(默认行高, 可用高度×比例/组数)`，再夹到
/// [warehouseIndexBarMinItemHeight]；组数少时与原行为完全一致，只有组多或
/// 视口矮才等比收窄。硬上限是「视口 × 比例」——超出父盒的字母既看不见也点
/// 不到，所以视口矮到连下限都放不下时，宁可破下限也不溢出。`itemHeight` 恒
/// > 0：上游 `_getIndex` 用 `offset ~/ itemHeight` 定位字母，传 0 会除零。
WarehouseIndexBarGeometry warehouseIndexBarGeometry({
  required int tagCount,
  required double availableHeight,
}) {
  if (tagCount <= 0) {
    return (itemHeight: kIndexBarItemHeight, height: 0, width: kIndexBarWidth);
  }
  final maxHeight = availableHeight * warehouseIndexBarMaxHeightRatio;
  final maxItemHeight = maxHeight / tagCount;
  final minItemHeight = math.min(warehouseIndexBarMinItemHeight, maxItemHeight);
  final itemHeight = maxItemHeight.clamp(minItemHeight, kIndexBarItemHeight);
  return (
    itemHeight: itemHeight,
    height: itemHeight * tagCount,
    width: kIndexBarWidth,
  );
}

/// 学校列表的右边距：字母条可见时把它占的宽度让出来。
///
/// 上游 `BaseIndexBar` 的手势是 `HitTestBehavior.translucent`，条子从
/// `W-30` 起铺到右边缘；右边距只有 16px 时，条子会压住每行最右 14px，点
/// 那一竖不会打开学校而是跳到某个字母组（行根本收不到指针，Stack 从上往
/// 下第一个命中就是条子）。行的箭头不受影响（实测右缘在 W-32）。
/// 搜索态字母条是空数据、不渲染，不占位。
double warehouseSchoolListRightInset({
  double baseInset = 16,
  double indexBarWidth = kIndexBarWidth,
  required bool indexBarVisible,
}) {
  return baseInset + (indexBarVisible ? indexBarWidth : 0);
}
