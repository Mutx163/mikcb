import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../providers/timetable_provider.dart';
import '../services/live_testing_fixture_service.dart';
import '../services/live_testing_trigger.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';

/// 临时测试课程页：安装 24 时段测试课表并一键触发超级岛。
///
/// 入口仅挂在诊断包（测试版 `.debug` / 性能版 `.profile`），正式版不展示。
class LiveTestingFixtureScreen extends StatefulWidget {
  const LiveTestingFixtureScreen({super.key});

  @override
  State<LiveTestingFixtureScreen> createState() =>
      _LiveTestingFixtureScreenState();
}

class _LiveTestingFixtureScreenState extends State<LiveTestingFixtureScreen> {
  int _fixtureLeadMinutes = 1;
  bool _installingFixtureGrid = false;
  bool _clearingFixtureGrid = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final now = DateTime.now();
    final sections = provider.settings.sections;
    final sectionCount = sections.length;
    final currentSection = LiveTestingFixtureService.sectionNumberForTime(
      now,
      sections,
    );
    final nextSection = LiveTestingFixtureService.nextSectionNumberForTime(
      now,
      sections,
    );
    final fixtureCount = provider.courses
        .where(LiveTestingFixtureService.isFixtureCourse)
        .length;
    final hasFixtures = fixtureCount > 0;
    final canTrigger = sectionCount > 0;
    final activeSchemeName = provider.activeTimeScheme?.name ?? l10n.unsetLabel;
    const leadOptions = LiveTestingFixtureService.supportedLeadMinutes;
    final leadIndex = leadOptions
        .indexOf(_fixtureLeadMinutes)
        .clamp(0, leadOptions.length - 1);
    final currentStart = canTrigger
        ? sections[currentSection - 1].startTime
        : '--:--';
    final nextStart = canTrigger
        ? sections[nextSection - 1].startTime
        : '--:--';

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: const Text('临时测试课程'),
      child: HyperosListView(
        children: [
          const HyperosSectionLabel(text: '快捷测试课表'),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.download_outlined,
                iconAccent: HyperosIconColors.indigo,
                title: _installingFixtureGrid ? '正在安装…' : '安装 24 时段测试课表',
                details: _installingFixtureGrid
                    ? null
                    : (canTrigger ? '$fixtureCount/$sectionCount' : '未安装'),
                onTap: _installingFixtureGrid
                    ? null
                    : () => _installQuickFixtureGrid(context),
              ),
              HyperosListTile(
                icon: Icons.delete_outline,
                iconAccent: HyperosIconColors.orange,
                title: _clearingFixtureGrid ? '正在清除…' : '清除测试课表',
                details: hasFixtures ? '$fixtureCount 门' : null,
                onTap: _clearingFixtureGrid || !hasFixtures
                    ? null
                    : () => _clearQuickFixtureGrid(context),
              ),
            ],
          ),
          HyperosSectionDescription(
            text:
                '当前方案：$activeSchemeName。安装会创建并自动套用「超级岛测试24时段」，按第 1～24 节生成普通课程数据'
                '（写入当前课表、周次/放假/选课规则与正式课完全一致）。'
                '一键发送只会改该节的起止时间，然后走正式超级岛刷新路径，不会强制弹岛。'
                '测完请先「清除测试课表」再切回自己的时间方案；若仍有第 11 节及以后的课，系统会拒绝切到更短的方案。',
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: '课前提醒',
            subtitle: '发送超级岛测试时，提前多久进入课前态',
            child: HyperosControlCardInset(
              child: HyperosSegmentedControl(
                tabs: [for (final minutes in leadOptions) '$minutes 分钟'],
                selectedIndex: leadIndex,
                onChanged: (index) {
                  setState(() => _fixtureLeadMinutes = leadOptions[index]);
                },
              ),
            ),
          ),
          const HyperosSectionGap(),
          const HyperosSectionLabel(text: '一键发送'),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.play_circle_outline,
                iconAccent: HyperosIconColors.blue,
                title: '当前节次 · 第$currentSection节',
                details: currentStart,
                onTap: !canTrigger
                    ? null
                    : () => _triggerQuickFixtureSlot(
                        context,
                        sectionNumber: currentSection,
                        source: 'quick_fixture_current_slot',
                      ),
              ),
              HyperosListTile(
                icon: Icons.skip_next_outlined,
                iconAccent: HyperosIconColors.purple,
                title: '下一节次 · 第$nextSection节',
                details: nextStart,
                onTap: !canTrigger
                    ? null
                    : () => _triggerQuickFixtureSlot(
                        context,
                        sectionNumber: nextSection,
                        source: 'quick_fixture_next_slot',
                      ),
              ),
            ],
          ),
          HyperosSectionDescription(
            text:
                '将对应节次改为 $_fixtureLeadMinutes 分钟后上课，再按正式逻辑刷新超级岛。'
                '若当前日历周超过课程 endWeek、放假或未到课前窗口，会提示无课而不是硬弹出岛。',
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: '按节次发送',
            subtitle: canTrigger ? '点选某一节：改时间后走正式超级岛刷新' : '请先安装 24 时段测试课表',
            child: HyperosControlCardInset(
              child: canTrigger
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sectionCount,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.15,
                          ),
                      itemBuilder: (context, index) {
                        final sectionNumber = index + 1;
                        final section = sections[index];
                        final installed =
                            LiveTestingFixtureService.findFixtureForSection(
                              provider,
                              sectionNumber,
                            ) !=
                            null;
                        final isCurrent = sectionNumber == currentSection;
                        return _QuickFixtureSectionCell(
                          sectionNumber: sectionNumber,
                          startTime: section.startTime,
                          installed: installed,
                          isCurrent: isCurrent,
                          onTap: () => _triggerQuickFixtureSlot(
                            context,
                            sectionNumber: sectionNumber,
                            source: 'quick_fixture_grid',
                          ),
                        );
                      },
                    )
                  : Text(
                      '安装后这里会列出全部节次',
                      style: HyperosTypography.sectionDescription(context),
                    ),
            ),
          ),
          const HyperosSectionGap(),
        ],
      ),
    );
  }

  Future<void> _installQuickFixtureGrid(BuildContext context) async {
    if (_installingFixtureGrid) {
      return;
    }
    setState(() => _installingFixtureGrid = true);
    try {
      final provider = context.read<TimetableProvider>();
      final count = await LiveTestingFixtureService.installSectionGrid(
        provider,
      );
      if (!context.mounted) {
        return;
      }
      final schemeName =
          provider.activeTimeScheme?.name ??
          LiveTestingFixtureService.timeSchemeName;
      showAppToast(
        context,
        message:
            '已套用「$schemeName」并安装 $count 门测试课（今天星期${DateTime.now().weekday}）',
        kind: AppToastKind.success,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: '安装测试课表失败：$error',
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _installingFixtureGrid = false);
      }
    }
  }

  Future<void> _clearQuickFixtureGrid(BuildContext context) async {
    if (_clearingFixtureGrid) {
      return;
    }
    setState(() => _clearingFixtureGrid = true);
    try {
      final provider = context.read<TimetableProvider>();
      final count = await LiveTestingFixtureService.removeAllFixtureCourses(
        provider,
      );
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: '已清除 $count 门测试课',
        kind: AppToastKind.success,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: '清除测试课表失败：$error',
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _clearingFixtureGrid = false);
      }
    }
  }

  Future<void> _triggerQuickFixtureSlot(
    BuildContext context, {
    required int sectionNumber,
    required String source,
  }) async {
    final provider = context.read<TimetableProvider>();
    final lead = Duration(minutes: _fixtureLeadMinutes);
    final result = await triggerLiveUpdateTestForSectionSlot(
      context: context,
      provider: provider,
      sectionNumber: sectionNumber,
      lead: lead,
      source: source,
    );
    if (!context.mounted || result.message == null) {
      return;
    }
    showAppToast(
      context,
      message: result.message!,
      kind: switch (result.status) {
        LiveTestingTriggerStatus.success => AppToastKind.success,
        LiveTestingTriggerStatus.inFlight => AppToastKind.warning,
        LiveTestingTriggerStatus.error => AppToastKind.error,
      },
    );
  }
}

/// Compact section cell for the live-testing fixture grid (HyperOS surface style).
class _QuickFixtureSectionCell extends StatelessWidget {
  const _QuickFixtureSectionCell({
    required this.sectionNumber,
    required this.startTime,
    required this.installed,
    required this.isCurrent,
    required this.onTap,
  });

  final int sectionNumber;
  final String startTime;
  final bool installed;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = HyperosColors.primary(context);
    final onPrimary = HyperosColors.onPrimary(context);
    final surface = HyperosColors.surface(context);
    final onSurface = HyperosColors.onSurface(context);
    final muted = HyperosColors.onSurfaceVariantSummary(context);
    final background = isCurrent ? primary : surface;
    final titleColor = isCurrent ? onPrimary : onSurface;
    final captionColor = isCurrent ? onPrimary.withValues(alpha: 0.86) : muted;
    final radius = BorderRadius.circular(HyperosTokens.cardRadius * 0.55);

    return MiuixPressable(
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: radius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(color: background, borderRadius: radius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '第$sectionNumber节',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                color: titleColor,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              startTime,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: captionColor,
                height: 1.1,
              ),
            ),
            if (installed || isCurrent) ...[
              const SizedBox(height: 3),
              Text(
                isCurrent ? '现在' : '已装',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: captionColor,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
