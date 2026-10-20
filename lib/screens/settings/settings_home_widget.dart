import 'dart:async';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:provider/provider.dart';
import '../../models/timetable_settings.dart';
import '../../providers/timetable_provider.dart';
import '../../ui/hyperos/hyperos_motion.dart';
import '../../utils/widget_course_accent.dart';
import '../../services/home_widget_service.dart';
import '../../services/home_widget_binding_service.dart';
import '../../utils/app_toast.dart';
import '../../ui/hyperos/hyperos.dart';
import 'settings_shared.dart';
import 'settings_reset.dart';

String _homeWidgetTargetLabel(
  BuildContext context,
  HomeWidgetPinTarget target,
) {
  final l10n = AppLocalizations.of(context)!;
  return switch (target) {
    HomeWidgetPinTarget.compact22 => l10n.homeWidgetTargetCompact22,
    HomeWidgetPinTarget.miniList22 => l10n.homeWidgetTargetMiniList22,
    HomeWidgetPinTarget.medium24 => l10n.homeWidgetTargetMedium24,
    HomeWidgetPinTarget.large44 => l10n.homeWidgetTargetLarge44,
    HomeWidgetPinTarget.stats22 => l10n.homeWidgetTargetStats22,
    HomeWidgetPinTarget.stats24 => l10n.homeWidgetTargetStats24,
    HomeWidgetPinTarget.todayStrip41 => l10n.homeWidgetTargetTodayStrip41,
    HomeWidgetPinTarget.statsStrip41 => l10n.homeWidgetTargetStatsStrip41,
    HomeWidgetPinTarget.examCard22 => l10n.homeWidgetTargetExamCard22,
    HomeWidgetPinTarget.todayWide42 => l10n.homeWidgetTargetTodayWide42,
  };
}

class HomeWidgetSettingsScreen extends StatefulWidget {
  const HomeWidgetSettingsScreen({super.key});

  @override
  State<HomeWidgetSettingsScreen> createState() =>
      HomeWidgetSettingsScreenState();
}

class HomeWidgetSettingsScreenState extends State<HomeWidgetSettingsScreen>
    with WidgetsBindingObserver {
  static const double _defaultWidgetHeightAdjustment = -11;
  static const double _defaultWidgetCornerRadius = 22;

  /// 「跟随当前课表」的哨兵值：绑定语义是 null（未登记），但
  /// HyperosSelectTile 对 null 值不渲染值标签（hyperosSelectLabelFor 对
  /// null 直接返回空），用空串占位才能把「跟随当前课表」显示出来。
  static const String _followActiveValue = '';

  final HomeWidgetService _homeWidgetService = HomeWidgetService();
  static const HomeWidgetBindingService _homeWidgetBindingService =
      HomeWidgetBindingService();
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  List<HomeWidgetInstance> _widgetInstances = const <HomeWidgetInstance>[];
  Timer? _autoSaveTimer;
  bool _isPersisting = false;
  bool _isCheckingPinSupport = true;
  bool _canRequestPinWidget = false;
  /// 「闹钟和提醒」权限检测状态：null 表示尚未查到，避免未授权用户
  /// 首帧横幅闪烁；false 才展示引导横幅。
  bool? _canScheduleExactAlarms;
  TimetableSettings? _pendingPersist;
  final Set<HomeWidgetPinTarget> _pinningTargets = <HomeWidgetPinTarget>{};

  // ── 效果预览轮播 ────────────────────────────────────────────────────
  // viewportFraction 保持 1.0：当前页占满整个视口，滑动的边界就是屏幕边界。
  // 之前用 0.90 想露出半张邻页，实际观感是「屏幕中间一块卡片、左右各一条留白」。
  final PageController _previewController = PageController();
  int _previewIndex = 0;

  /// 已渲染好的预览图（PNG 字节），按卡片类型缓存。
  /// 存字节而不是 ImageProvider：清缓存重出图时直接换字节，
  /// `Image.memory` 会自己按 gaplessPlayback 过渡，不会闪白。
  final Map<HomeWidgetPinTarget, HomeWidgetPreviewBitmap> _previewBytes =
      <HomeWidgetPinTarget, HomeWidgetPreviewBitmap>{};
  final Set<HomeWidgetPinTarget> _previewRendering = <HomeWidgetPinTarget>{};
  final Set<HomeWidgetPinTarget> _previewFailed = <HomeWidgetPinTarget>{};
  /// 失败发生的时间，用来给「失败后重试」做退避，避免偶发失败把这一页钉死。
  final Map<HomeWidgetPinTarget, DateTime> _previewFailedAt =
      <HomeWidgetPinTarget, DateTime>{};

  /// 预览所用的深浅档与应用内语言。
  /// 卡片渲染在原生侧完成，必须显式告诉它这两件事，否则会按系统档出图：
  /// App 设了强制深色而系统是浅色时，就会出现「深色页面里贴一张白卡片」。
  Brightness? _previewBrightness;
  String? _previewLanguageTag;
  Timer? _previewRefreshTimer;

  /// 预览代次。设置改动会让已发出的渲染请求过期，回来时按代次丢弃，
  /// 免得旧档位的图覆盖掉新档位的结果。
  int _previewGeneration = 0;

  /// 当前屏幕宽度下换算出来的 10 张卡片格位尺寸（真实桌面格位，不是声明的最小值）。
  /// 屏宽变化（横竖屏、折叠屏展开、分屏）会重算，已缓存的图随之作废。
  List<HomeWidgetPreviewSpec> _previewSpecs = const <HomeWidgetPreviewSpec>[];
  double _previewSpecsWidth = 0;

  /// 视口比卡片本身多留的高度：上下各 28dp。
  /// 投影向下占用 = offset 5 + blur 18 + |spread| 2 = 25dp，留 28 刚好装下
  /// 再加一点呼吸空间；改阴影参数时这里要同步改，否则阴影又被切出直线。
  static const double _previewViewportExtraDp = 56;

  /// 轮播视口高度跟着当前页卡片的实际高度走，只额外留出投影与呼吸空间。
  /// 固定成最大卡的高度会让 4×1 横条上下空出一大片，反而显得更小。
  double get _previewViewportHeight {
    if (_previewSpecs.isEmpty) {
      return 200;
    }
    final index = _previewIndex.clamp(0, _previewSpecs.length - 1);
    return _previewSpecs[index].heightDp + _previewViewportExtraDp;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
    _previewController.addListener(_syncPreviewIndexFromController);
    _loadPinWidgetSupport();
    unawaited(_loadExactAlarmPermission());
    _loadWidgetInstances();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 预览图在原生侧渲染，深浅、语言、物理尺寸都必须显式传下去；
    // 任一项变了，之前缓存的图就整批作废重出——尺寸变了图本身也得重画。
    final brightness = Theme.of(context).brightness;
    final languageTag = Localizations.localeOf(context).toLanguageTag();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sizeChanged = _previewSpecsWidth != screenWidth;
    if (!sizeChanged &&
        _previewBrightness == brightness &&
        _previewLanguageTag == languageTag) {
      return;
    }
    if (sizeChanged) {
      _previewSpecsWidth = screenWidth;
      _previewSpecs = buildHomeWidgetPreviewSpecs(screenWidth);
    }
    _previewBrightness = brightness;
    _previewLanguageTag = languageTag;
    // 代次自增：已经飞在路上的请求回来时按新档位对不上，直接丢弃，
    // 不会把旧明暗/旧语言的图写回缓存。
    _previewGeneration++;
    _previewBytes.clear();
    _previewFailed.clear();
    _previewRendering.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prefetchPreviewAround(_previewIndex);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    // 从桌面/系统弹窗回到前台：桌面小组件集合可能已变化（用户去桌面加了
    // 或删了卡片，系统不会通知 App 界面），稍候重查——pin 确认后启动器
    // 需要一拍才完成绑定，立即查可能拿到旧集合。
    unawaited(_loadExactAlarmPermission());
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadWidgetInstances();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewRefreshTimer?.cancel();
    _previewController.dispose();
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeWidgetSettingsTitle),
      child: HyperosListView(
        itemCount: _homeWidgetSectionCount,
        itemBuilder: _buildHomeWidgetSection,
      ),
    );
  }

  /// 未授权（已查到且为 false）时多一个「精确闹钟权限」引导分区。
  int get _exactAlarmBannerSections =>
      _canScheduleExactAlarms == false ? 1 : 0;

  int get _homeWidgetSectionCount =>
      (_draft.widgetShowCountdown ? 4 : 3) + 2 + _exactAlarmBannerSections;

  Widget _buildHomeWidgetSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    final hasBanner = _exactAlarmBannerSections > 0;
    // 权限引导横幅固定在第 1 位，未展示时跳过；未展示倒计时分区时再偏移。
    if (hasBanner && index == 0) {
      return _buildExactAlarmBannerSection(l10n);
    }
    var section = hasBanner ? index - 1 : index;
    if (!_draft.widgetShowCountdown && section >= 2) {
      section += 1;
    }

    final Widget content = switch (section) {
      0 => _buildPreviewSection(l10n),
      1 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.homeWidgetTodayCourseTitle),
          HyperosListGroup(
            children: [
              HyperosSelectTile<WidgetBackgroundStyle>(
                label: l10n.homeWidgetBackgroundStyleLabel,
                items: {
                  for (final v in WidgetBackgroundStyle.values)
                    widgetBackgroundStyleLabel(l10n, v): v,
                },
                value: _draft.widgetBackgroundStyle,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(widgetBackgroundStyle: value));
                },
              ),
              // 课程色贯穿：一个三档总开关（关闭 / 仅色条 / 色条+文字），
              // 不做成多个独立开关——「回到之前的样子」必须一次点到位。
              HyperosSelectTile<WidgetCourseAccentMode>(
                label: l10n.homeWidgetCourseAccentTitle,
                subtitle: l10n.homeWidgetCourseAccentSubtitle,
                items: {
                  for (final v in WidgetCourseAccentMode.values)
                    widgetCourseAccentModeLabel(l10n, v): v,
                },
                value: _draft.widgetCourseAccentMode,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(widgetCourseAccentMode: value));
                },
              ),
              HyperosSwitchTile(
                title: l10n.homeWidgetShowLocationTitle,
                subtitle: l10n.homeWidgetShowLocationSubtitle,
                value: _draft.widgetShowLocation,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(widgetShowLocation: value));
                },
              ),
              HyperosSwitchTile(
                title: l10n.homeWidgetShowCountdownTitle,
                subtitle: l10n.homeWidgetShowCountdownSubtitle,
                value: _draft.widgetShowCountdown,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(widgetShowCountdown: value));
                },
              ),
              HyperosSwitchTile(
                title: l10n.homeWidgetHideCompletedTitle,
                subtitle: l10n.homeWidgetHideCompletedSubtitle,
                value: _draft.widgetHideCompletedCourses,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(widgetHideCompletedCourses: value),
                  );
                },
              ),
              HyperosSwitchTile(
                title: l10n.homeWidgetShowTomorrowTitle,
                subtitle: l10n.homeWidgetShowTomorrowSubtitle,
                value: _draft.widgetShowTomorrowCourses,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(widgetShowTomorrowCourses: value),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      2 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.homeWidgetCountdownLeadTitle),
          HyperosListGroup(
            children: [
              HyperosSelectTile<int>(
                label: l10n.homeWidgetCountdownLeadTitle,
                items: {
                  l10n.homeWidgetCountdownLeadAlways: 0,
                  for (final m in const [1, 5, 10, 15, 20, 30, 40, 50, 60])
                    l10n.beforeClassMinutesOption(m): m,
                },
                value: _draft.widgetCountdownLeadMinutes,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(widgetCountdownLeadMinutes: value),
                  );
                },
              ),
              HyperosSelectTile<LiveCountdownTextStyle>(
                label: l10n.widgetCountdownStyleTitle,
                items: {
                  for (final v in LiveCountdownTextStyle.values)
                    liveCountdownTextStyleLabel(l10n, v): v,
                },
                value: _draft.widgetCountdownTextStyle,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(widgetCountdownTextStyle: value),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      3 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.homeWidgetAppearanceTitle),
          HyperosListGroup(
            children: [
              // 滑条与点开后的输入框共用同一参照系：相对默认档（-11）的
              // 偏移，-16~+16，0 = 默认；存储值仍是绝对档位。行标题固定，
              // 值标签（默认/更高 Ndp/更矮 Ndp）与输入框数字一一对应。
              HyperosSliderTile(
                title: l10n.homeWidgetHeightAdjustTitle,
                valueLabel: _widgetHeightAdjustmentLabel(l10n),
                value: _draft.widgetHeightAdjustment -
                    _defaultWidgetHeightAdjustment,
                min: -16,
                max: 16,
                divisions: 32,
                dialogHelper: l10n.homeWidgetHeightAdjustHint,
                onChanged: (offset) => _updateDraft(
                  _draft.copyWith(
                    widgetHeightAdjustment:
                        _defaultWidgetHeightAdjustment + offset,
                  ),
                  debounce: true,
                ),
              ),
              HyperosSliderTile(
                title: l10n.homeWidgetCornerRadiusTitle,
                valueLabel: '${_draft.widgetCornerRadius.toStringAsFixed(0)}dp',
                value: _draft.widgetCornerRadius,
                min: _defaultWidgetCornerRadius - 14,
                max: _defaultWidgetCornerRadius + 14,
                divisions: 28,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(widgetCornerRadius: value),
                  debounce: true,
                ),
              ),
            ],
          ),
        ],
      ),
      4 => _buildWidgetBindingSection(l10n),
      _ => SettingsResetTile(
        scope: SettingsResetScope.homeWidget,
        onReset: _updateDraft,
      ),
    };

    if (index == 0) {
      // 预览区保活：设置页是懒加载列表，滚出视口会回收整块 subtree，
      // 滚回来再重建。PageView / Scrollable / 已渲染的图全要重来一遍，
      // 任何一个环节出岔子就是「下滑再上滑，预览空白」。
      // 这里让它常驻，回收重建这条路径从根本上不存在了。
      return _PreviewKeepAlive(child: content);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const HyperosSectionGap(), content],
    );
  }

  // ── 效果预览 ──────────────────────────────────────────────────────────
  //
  // 预览图不是用 Flutter 重画的，是原生把真实卡片的 RemoteViews 就地渲染成
  // PNG 传回来的（同一份 layout、同一段填数据的代码），所以和贴到桌面上的是
  // 同一张图；改卡片样式也只改一处，两边同时生效。

  Widget _buildPreviewSection(AppLocalizations l10n) {
    if (_previewSpecs.isEmpty) {
      // 首帧还没拿到屏幕宽度：先不占位，didChangeDependencies 之后就有。
      return const SizedBox.shrink();
    }
    final index = _previewIndex.clamp(0, _previewSpecs.length - 1);
    final spec = _previewSpecs[index];
    // 兜底自愈：只要当前页没有图、也没在渲染、更不是渲染失败，就补一次请求。
    // 列表回收重建、缓存被清、上一次请求被代次作废——任何一条路丢了图，
    // 都会在这里自动回来，不会一直空着。
    _schedulePreviewLoad(index);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    return Column(
      // 稳定 key：列表重建时复用同一棵子树，避免新旧两棵同时挂在树上
      // ——后者会让同一个 PageController 短暂 attach 两个 Scrollable，
      // 触发 "_positions.length == 1" 断言。
      key: const ValueKey<String>('homeWidgetPreviewSection'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosSectionLabel(text: l10n.homeWidgetPreviewTitle),
        // OverflowBox 必须套在有界高度里。它在高度无界的父级（ListView 的
        // item 正是如此）会把自身高度算成 Infinity，直接抛
        // “given an infinite size during layout”，连带后面的兄弟节点整块不布局——
        // 表现就是整页只剩预览、下面的设置项全部消失。
        AnimatedContainer(
          duration: 220.scaledMs,
          curve: Curves.easeOutCubic,
          height: _previewViewportHeight,
          child: OverflowBox(
            // 列表左右各有 16dp 内边距，让预览溢出到那 16dp 里：
            // 视口宽度 = 屏幕宽度，滑动的边界就是屏幕边界。
            maxWidth: double.infinity,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: viewportWidth,
              child: PageView.builder(
                // 故意不挂 PageStorageKey：预览是「看效果」，不是「编辑状态」，
                // 每次进来都从第一张（主卡 2×2）开始，比对比例时才不会因为
                // 上次停在第 N 张（比如 4×2 横宽）而误以为「默认卡片是扁的」。
                // 回收重建后的错位由 _syncPreviewIndexFromController 兜底校正。
                controller: _previewController,
                itemCount: _previewSpecs.length,
                physics: const PageScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _previewIndex = index;
                  });
                  _prefetchPreviewAround(index);
                },
                itemBuilder: _buildPreviewPage,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildPreviewDots(context),
        const SizedBox(height: 12),
        Text(
          _homeWidgetTargetLabel(context, spec.target),
          textAlign: TextAlign.center,
          style: HyperosTypography.listTitle(context),
        ),
        const SizedBox(height: 3),
        // 还没出图时不显示尺寸：那时只能报格位尺寸，出图后会跳成卡片尺寸，
        // 数字变一次反而让人以为哪里错了。留固定高度占位，出图时不跳版。
        SizedBox(
          height: 16,
          child: Text(
            _previewBytes[spec.target]?.sizeLabel ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: HyperosColors.secondaryText(context),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildPinWidgetButton(
          spec.target,
          label: l10n.homeWidgetPreviewAddAction,
        ),
      ],
    );
  }

  Widget _buildPreviewPage(BuildContext context, int index) {
    final spec = _previewSpecs[index];
    // 按「这一页真的被构建」来补图，而不是只补 _previewIndex。
    // 列表回收后滚回来，PageView 会退到第 0 页，而 _previewIndex 可能还停在
    // 第 N 页；只补 N 的话，屏幕上的第 0 页永远没有图——
    // 这就是「下拉再回来预览空白」的直接原因。
    _schedulePreviewLoad(index);
    return AnimatedBuilder(
      animation: _previewController,
      // 缩放与淡化由滚动位置连续驱动，而不是等 onPageChanged 再切状态：
      // 手指还没松开就已经在过渡，翻页时不会出现"先滑过去、再跳一下"的断层。
      builder: (context, child) {
        // 读不到滚动位置（controller 还没挂上 Scrollable、或首帧还没完成布局）
        // 时必须原样返回 child，绝不能拿 _previewIndex 去当基准。
        //
        // 这里的场景很具体：设置页是懒加载列表，预览区滚出屏幕后会被回收，
        // 滚回来重建的第一帧还没有真实滚动位置；若此时用 _previewIndex 去算
        // 距离，正显示在屏幕上的那一页就会被算成 0.48 透明度——浅色主题下
        // 白卡片压在 #F2F2F2 背景上等于直接消失（用户反馈的「滑回来卡片没了」）。
        // positions.length != 1 时不能碰 position / page：一帧内新旧两个
        // Scrollable 同时挂着的瞬间（列表重建、热重载）会触发
        // "_positions.length == 1" 断言，直接把整个页面崩掉。
        if (_previewController.positions.length != 1) {
          // `AnimatedBuilder` 的 `child` 静态类型是 `Widget?`（这里一定传了），
          // 兜底只是为了保持「原样不动」的语义。
          return child ?? const SizedBox.shrink();
        }
        final position = _previewController.position;
        if (!position.hasContentDimensions || position.viewportDimension <= 0) {
          return child ?? const SizedBox.shrink();
        }
        // 用 position 直接换算页号，不走 controller.page：后者带同一条断言。
        final page = position.pixels / position.viewportDimension;
        final distance = (index - page).abs().clamp(0.0, 1.0);
        // 只做极轻的缩放，不做透明度：卡片贴边滑动时再叠加淡化，会让边缘那块
        // 发虚；浅色卡片淡下去还容易直接看不见（之前"滑回来消失"就是这条）。
        return Transform.scale(
          scale: 1 - 0.03 * distance,
          child: child,
        );
      },
      child: _buildPreviewStage(context, spec),
    );
  }

  /// 以 controller 的真实滚动位置为准校正当前页。
  ///
  /// 预览区故意不挂 `PageStorageKey`，所以列表回收重建后横向位置会退回第 0 页；
  /// 此时 `_previewIndex` 可能还停在第 N 页，导致标题、按钮、视口高度与画面里的
  /// 卡片对不上。这里以 controller 的真实位置为准校正；只在页面停稳
  /// （离整数格足够近）时动，避免和 [PageView.onPageChanged] 互相打架。
  void _syncPreviewIndexFromController() {
    if (!mounted || _previewController.positions.length != 1) {
      return;
    }
    final position = _previewController.position;
    if (!position.hasContentDimensions || position.viewportDimension <= 0) {
      return;
    }
    final page = position.pixels / position.viewportDimension;
    final rounded = page.round();
    if ((page - rounded).abs() > 0.02 || rounded == _previewIndex) {
      return;
    }
    if (rounded < 0 || rounded >= _previewSpecs.length) {
      return;
    }
    // 这个 listener 会在 PageView attach / 布局阶段就被调用（列表回收重建时
    // 尤其明显），直接 setState 会撞上 "setState() called during build"，
    // 整个预览区可能就此不再重建。排到帧后再改，差一帧，观感无影响。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _previewIndex == rounded) {
        return;
      }
      setState(() {
        _previewIndex = rounded;
      });
    });
  }

  /// 卡片直接放在设置页自己的背景上（不模拟桌面壁纸、不垫底板）。
  ///
  /// 唯一的修饰是 [HomeWidgetPreviewSpec] 外面那层跟随圆角的淡投影：
  /// 浅色主题下卡片底色接近 `#F8FAFC`、页面背景是 `#F2F2F2`，
  /// 不补投影几乎看不出边界。投影画在卡片透明圆角之外，卡片本身像素不改。
  Widget _buildPreviewStage(
    BuildContext context,
    HomeWidgetPreviewSpec spec,
  ) {
    // 不额外加内边距：卡片在 PageView 视口里居中即可，上下留白由
    // _previewViewportHeight 统一给（阴影需要的那一截也算在里面）。
    // 这里若再塞 vertical padding，会挤掉阴影的下半截，
    // 被 PageView 的硬裁剪切成一条直线。
    return Center(child: _buildPreviewImage(context, spec));
  }

  Widget _buildPreviewImage(
    BuildContext context,
    HomeWidgetPreviewSpec spec,
  ) {
    final target = spec.target;
    final image = _previewBytes[target];
    // 占位尺寸用格位尺寸：出图前先按格位撑开，出图后换成卡片本身的尺寸。
    final width = spec.widthDp.toDouble();
    final height = spec.heightDp.toDouble();

    if (image != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      // 用图片自带的尺寸而不是格位尺寸：卡片背景在格位里上下留了一圈内边距，
      // 按格位显示会让图被拉伸，视觉上就是「扁的」。
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: image.widthDp,
          height: image.heightDp,
          decoration: BoxDecoration(
            // 圆角用当前设置值，与原生按同一档渲染出来的卡片圆角对齐；
            // 投影因此只出现在卡片轮廓之外，不会盖住卡片本身。
            borderRadius: BorderRadius.circular(_draft.widgetCornerRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                // 阴影必须完整落在 PageView 视口内，否则会被硬裁成一条直线。
                // 向下占用 = offset.dy + blurRadius + |spreadRadius| = 25dp，
                // 视口上下各留 28dp（_previewViewportHeight 里 +56）。
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Image.memory(
            image.png,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
        ),
      );
    }

    if (_previewFailed.contains(target)) {
      final l10n = AppLocalizations.of(context)!;
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(
            l10n.homeWidgetPreviewUnavailable,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: HyperosColors.secondaryText(context),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildPreviewDots(BuildContext context) {
    final active = HyperosColors.primary(context);
    final inactive = HyperosColors.dividerLine(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _previewSpecs.length; i++)
          AnimatedContainer(
            duration: 220.scaledMs,
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _previewIndex ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == _previewIndex ? active : inactive,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }

  /// 预取当前页左右各一张：翻到相邻页时图已经在了，不会停在转圈上。
  void _prefetchPreviewAround(int index) {
    for (final offset in const [-1, 0, 1]) {
      unawaited(_ensurePreview(index + offset));
    }
  }

  /// 在 build 期间排一次「当前页补图」，真正的请求放到这一帧画完之后。
  ///
  /// 不能直接在 build 里调 [_ensurePreview]（它会 setState）；也不能只依赖
  /// [didChangeDependencies] 与 [PageView.onPageChanged] —— 预览区被列表回收
  /// 后重建时这两者都不一定触发，图就可能一直空着。
  void _schedulePreviewLoad(int index) {
    if (index < 0 || index >= _previewSpecs.length) {
      return;
    }
    final target = _previewSpecs[index].target;
    if (_previewBytes.containsKey(target) ||
        _previewRendering.contains(target)) {
      return;
    }
    if (_previewFailed.contains(target)) {
      // 失败不要永久钉死：5 秒后允许再试一次。一次偶发失败（原生还没就绪、
      // 热重载期间通道短暂不可用）不该让这一页永远空着。
      final failedAt = _previewFailedAt[target];
      if (failedAt != null &&
          DateTime.now().difference(failedAt).inMilliseconds < 5000) {
        return;
      }
      _previewFailed.remove(target);
      _previewFailedAt.remove(target);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_ensurePreview(index));
    });
  }

  Future<void> _ensurePreview(int index) async {
    if (index < 0 || index >= _previewSpecs.length) {
      return;
    }
    final spec = _previewSpecs[index];
    final target = spec.target;
    if (_previewBytes.containsKey(target) ||
        _previewRendering.contains(target)) {
      return;
    }
    final brightness = _previewBrightness;
    final languageTag = _previewLanguageTag;
    if (brightness == null || languageTag == null || !mounted) {
      return;
    }

    final generation = _previewGeneration;
    setState(() {
      _previewRendering.add(target);
      _previewFailed.remove(target);
    });

    // 超时兜底：通道若因主线程繁忙迟迟不回复，这个 Future 会一直挂着，
    // _previewRendering 里那条记录就永远出不来，这一页从此再也补不了图。
    final bitmap = await _homeWidgetService
        .renderPreview(
          spec: spec,
          nightMode: brightness == Brightness.dark,
          languageTag: languageTag,
        )
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (!mounted) {
      return;
    }
    setState(() {
      _previewRendering.remove(target);
      // 出图期间设置被改动过：这张图对应的是旧档位，直接丢弃。
      if (generation != _previewGeneration) {
        return;
      }
      if (bitmap == null) {
        _previewFailed.add(target);
        _previewFailedAt[target] = DateTime.now();
      } else {
        _previewBytes[target] = bitmap;
      }
    });
  }

  /// 外观设置变了：本页即将落盘，落盘后再让预览重出图。
  ///
  /// 预览读的是原生侧 SharedPreferences 里的课表设置，落盘前出图拿到的还是
  /// 旧档位，看起来就是「改了没反应」。所以只在 [_persistDraft] 成功之后调用。
  void _invalidatePreview() {
    _previewGeneration++;
    _previewRefreshTimer?.cancel();
    _previewRefreshTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }
      _previewBytes.clear();
      _previewFailed.clear();
      _prefetchPreviewAround(_previewIndex);
    });
  }

  /// 「各卡片绑定管理」：列出桌面上真实存在的今日课程卡片，
  /// 逐张选择显示哪个课表（跟随当前课表 / 我的课表 / 情侣课表 / TA的课表）。
  Widget _buildWidgetBindingSection(AppLocalizations l10n) {
    if (_widgetInstances.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.homeWidgetBindingSectionTitle),
          HyperosListGroup(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  l10n.homeWidgetBindingEmpty,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final normalProfiles = _timetableProvider.profiles
        .where((profile) => !profile.isPartnerImported)
        .toList(growable: false);
    final partnerProfile = _timetableProvider.partnerProfile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosSectionLabel(text: l10n.homeWidgetBindingSectionTitle),
        HyperosListGroup(
          children: [
            for (final instance in _widgetInstances)
              HyperosSelectTile<String>(
                label: _homeWidgetTargetLabel(
                  context,
                  _pinTargetForType(instance.widgetType),
                ),
                items: {
                  l10n.homeWidgetBindingFollowActive: _followActiveValue,
                  for (final profile in normalProfiles) profile.name: profile.id,
                  // 情侣课表（我的+TA 合并视图）排在 TA 课表前面：它是情侣
                  // 功能的主视图；两者都只在已导入 TA 课表时出现。
                  if (partnerProfile != null) ...{
                    l10n.homeWidgetBindingCoupleMerged:
                        kHomeWidgetCoupleMergedBindingId,
                    partnerProfile.name: partnerProfile.id,
                  },
                },
                value: instance.boundProfileId ?? _followActiveValue,
                onChanged: (profileId) => _setWidgetBinding(
                  instance.appWidgetId,
                  profileId == _followActiveValue ? null : profileId,
                ),
              ),
          ],
        ),
      ],
    );
  }

  HomeWidgetPinTarget _pinTargetForType(HomeWidgetType? type) {
    return switch (type) {
      HomeWidgetType.compact => HomeWidgetPinTarget.compact22,
      HomeWidgetType.miniList => HomeWidgetPinTarget.miniList22,
      HomeWidgetType.medium => HomeWidgetPinTarget.medium24,
      HomeWidgetType.large => HomeWidgetPinTarget.large44,
      HomeWidgetType.todayStrip => HomeWidgetPinTarget.todayStrip41,
      HomeWidgetType.todayWide => HomeWidgetPinTarget.todayWide42,
      null => HomeWidgetPinTarget.compact22,
    };
  }

  Future<void> _loadWidgetInstances() async {
    final instances = await _homeWidgetBindingService.listTodayWidgetInstances();
    if (!mounted) {
      return;
    }
    setState(() {
      _widgetInstances = instances;
    });
  }

  Future<void> _setWidgetBinding(int appWidgetId, String? profileId) async {
    final ok = await _homeWidgetBindingService.setWidgetBinding(
      appWidgetId,
      profileId,
    );
    if (!mounted) {
      return;
    }
    await _loadWidgetInstances();
    if (!mounted) {
      return;
    }
    if (!ok) {
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.homeWidgetBindingSaveFailed,
      );
    }
  }

  /// 「卡片高度」的值标签：与滑条/输入框同一参照系——相对默认档
  /// （-11）的偏移，0 = 默认，正数比默认更高、负数更矮，带 dp 单位。
  String _widgetHeightAdjustmentLabel(AppLocalizations l10n) {
    final offset =
        _draft.widgetHeightAdjustment - _defaultWidgetHeightAdjustment;
    if (offset == 0) {
      return l10n.defaultLabel;
    }
    final dpText = '${offset.abs().toStringAsFixed(0)}dp';
    return offset > 0 ? l10n.higherByValue(dpText) : l10n.lowerByValue(dpText);
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _pendingPersist = next;
    if (_isPersisting) {
      return;
    }
    _drainPersistQueue();
  }

  Future<void> _drainPersistQueue() async {
    _isPersisting = true;
    try {
      while (_pendingPersist != null) {
        final next = _pendingPersist!;
        _pendingPersist = null;
        await _persistDraft(next);
      }
    } finally {
      _isPersisting = false;
    }
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = _timetableProvider;
    try {
      // 草稿快照可能比真源旧：节次表与激活作息一律回灌（见
      // TimetableSettings.withLiveScheduleFieldsFrom）。
      final message = await provider.updateTimetableSettings(
        next.withLiveScheduleFieldsFrom(provider.settings),
      );
      if (!mounted) {
        return;
      }
      if (message != null) {
        reportSettingsPersistRejected(this, message);
        setState(() {
          _draft = provider.settings;
        });
        return;
      }
      // 落盘成功：预览读的就是这份设置，此刻重出图才拿得到新档位。
      _invalidatePreview();
    } catch (_) {
      // 落盘失败：provider 已回滚内存与课表镜像并 rethrow，不接就没人提示。
      reportSettingsPersistFailure(this, resetDraft: () {
        setState(() {
          _draft = provider.settings;
        });
      });
    }
  }

  Future<void> _loadExactAlarmPermission() async {
    final wasDetected = _canScheduleExactAlarms != null;
    final wasGranted = _canScheduleExactAlarms == true;
    final granted = await _homeWidgetService.canScheduleExactAlarms();
    if (!mounted) {
      return;
    }
    if (_canScheduleExactAlarms != granted) {
      setState(() {
        _canScheduleExactAlarms = granted;
      });
    }
    // 从未授权升级为已授权时，原刷新闹钟仍是非精确档，主动重排一次。
    if (granted && wasDetected && !wasGranted) {
      await _homeWidgetService.rescheduleRefresh();
    }
  }

  Future<void> _requestExactAlarmPermission() async {
    final result = await _homeWidgetService.requestScheduleExactAlarm();
    if (!mounted) {
      return;
    }
    switch (result) {
      case HomeWidgetExactAlarmRequestResult.launched:
      case HomeWidgetExactAlarmRequestResult.notRequired:
        break;
      case HomeWidgetExactAlarmRequestResult.fallback:
        // 已回退到应用详情页，提示用户在其中开启权限即可。
        showAppToast(
          context,
          message: AppLocalizations.of(context)!.homeWidgetExactAlarmFallbackHint,
        );
      case HomeWidgetExactAlarmRequestResult.failed:
        // 未能打开任何设置页，引导用户手动前往系统设置。
        showAppToast(
          context,
          message: AppLocalizations.of(context)!.homeWidgetExactAlarmOpenFailed,
        );
    }
    // 回到前台时 didChangeAppLifecycleState 会重查授权状态。
  }

  /// 「精确闹钟权限」引导分区：Android 12+ 未授予时提示并一键跳系统授权页。
  Widget _buildExactAlarmBannerSection(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosHintBanner(
          icon: Icon(
            Icons.alarm_rounded,
            size: 18,
            color: HyperosColors.primary(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeWidgetExactAlarmBannerTitle,
                style: HyperosTypography.listTitle(context),
              ),
              const SizedBox(height: 4),
              Text(l10n.homeWidgetExactAlarmBannerText),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: HyperosButton(
                  label: l10n.homeWidgetExactAlarmGrantAction,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: _requestExactAlarmPermission,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadPinWidgetSupport() async {
    final supported = await _homeWidgetService.canRequestPinWidget();
    if (!mounted) {
      return;
    }
    setState(() {
      _canRequestPinWidget = supported;
      _isCheckingPinSupport = false;
    });
  }

  Widget _buildPinWidgetButton(HomeWidgetPinTarget target, {String? label}) {
    final isLoading = _pinningTargets.contains(target);
    final canPin = !_isCheckingPinSupport && _canRequestPinWidget && !isLoading;
    return SizedBox(
      width: double.infinity,
      child: HyperosButton(
        // 默认用卡片名（如「2×2 紧凑」）；预览区那一个按钮用「添加到桌面」，
        // 卡片身份改由上方标题与尺寸行说明，按钮只表达动作。
        label: label ?? _homeWidgetTargetLabel(context, target),
        variant: HyperosButtonVariant.secondary,
        expand: true,
        loading: isLoading || _isCheckingPinSupport,
        onPressed: canPin ? () => _requestPinWidget(target) : null,
      ),
    );
  }

  Future<void> _requestPinWidget(HomeWidgetPinTarget target) async {
    setState(() {
      _pinningTargets.add(target);
    });
    final result = await _homeWidgetService.requestPinWidget(target);
    if (!mounted) {
      return;
    }
    setState(() {
      _pinningTargets.remove(target);
    });

    final message = switch (result) {
      HomeWidgetPinRequestResult.requested => AppLocalizations.of(
        context,
      )!.homeWidgetPinRequested(_homeWidgetTargetLabel(context, target)),
      HomeWidgetPinRequestResult.unsupported =>
        AppLocalizations.of(context)!.homeWidgetPinUnsupportedManual(
          _homeWidgetTargetLabel(context, target),
        ),
      HomeWidgetPinRequestResult.invalidWidgetType => AppLocalizations.of(
        context,
      )!.homeWidgetInvalidType,
      HomeWidgetPinRequestResult.failed => AppLocalizations.of(
        context,
      )!.homeWidgetPinFailedManual(_homeWidgetTargetLabel(context, target)),
    };
    showAppToast(context, message: message);
    // 请求未受理（unsupported/failed）时集合不变、重查无害；真正「已确认
    // 添加」发生在系统弹窗之后，由 resumed 刷新兜底，这里即时重查一次。
    unawaited(_loadWidgetInstances());
  }
}

/// 只做一件事：让子树在懒加载列表里不被回收。
///
/// [HyperosListView] 的 itemBuilder 模式用的是 `ListView.builder`，滚出视口的
/// item 会被 dispose。预览轮播一旦被回收，`PageView` 的 `Scrollable`、已渲染的
/// 图片和滚动位置全要重建；重建路径上任何一环出问题，用户看到的就是
/// 「下滑再上滑，预览空白」。保活后这条路径不存在，代价只是这块 subtree 常驻。
class _PreviewKeepAlive extends StatefulWidget {
  const _PreviewKeepAlive({required this.child});

  final Widget child;

  @override
  State<_PreviewKeepAlive> createState() => _PreviewKeepAliveState();
}

class _PreviewKeepAliveState extends State<_PreviewKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
