// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 课程导入入口页
// 从菜单进四种导入方式的选择页。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import '../../widgets/import_random_color_toggle.dart';
import 'ics_course_import_screen.dart';
import 'spreadsheet_course_import_screen.dart';
import 'ai_image_course_import_screen.dart';
import 'warehouse/warehouse_course_import_screen.dart';

class CourseImportScreen extends StatelessWidget {
  const CourseImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.courseImportTitle),
      // Standard list path (header inset inside the scrollable + notification
      // bubbling) so the large title collapses with scroll; the old
      // BodyInset + includeHeaderInset:false combo swallowed vertical scroll
      // notifications and froze the large title.
      child: HyperosListView(
        children: [
          const ImportRandomColorToggle(),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.chooseImportMethodTitle),
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              HyperosNavTile(
                icon: Icons.event_note_rounded,
                iconAccent: HyperosIconColors.blue,
                title: l10n.importMethodIcsTitle,
                subtitle: l10n.importMethodIcsSubtitle,
                onTap: () => _openImportPage<bool>(
                  context,
                  builder: (_) => const IcsCourseImportScreen(),
                ),
              ),
              HyperosNavTile(
                icon: Icons.auto_awesome_rounded,
                iconAccent: HyperosIconColors.purple,
                title: l10n.importMethodAiTitle,
                subtitle: l10n.importMethodAiSubtitle,
                onTap: () => _openImportPage<bool>(
                  context,
                  builder: (_) => const AiImageCourseImportScreen(),
                ),
              ),
              HyperosNavTile(
                icon: Icons.school_outlined,
                iconAccent: HyperosIconColors.green,
                title: l10n.importMethodWarehouseTitle,
                subtitle: l10n.importMethodWarehouseSubtitle,
                onTap: () => _openImportPage<bool>(
                  context,
                  builder: (_) => const WarehouseCourseImportScreen(),
                ),
              ),
              HyperosNavTile(
                icon: Icons.table_chart_outlined,
                iconAccent: HyperosIconColors.orange,
                title: l10n.importMethodSpreadsheetTitle,
                subtitle: l10n.importMethodSpreadsheetSubtitle,
                onTap: () => _openImportPage<bool>(
                  context,
                  builder: (_) => const SpreadsheetCourseImportScreen(),
                ),
              ),
            ],
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
      HyperosPageRoute(
        settings: const RouteSettings(name: '/courses/import/detail'),
        builder: builder,
      ),
    );
    if (context.mounted && imported == true) {
      Navigator.of(context).pop(true);
    }
  }
}

