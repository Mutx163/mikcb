/// 渲染性能设置快照（**只在调试版 / 性能版生效**）。
///
/// 存在的理由：调性能时反复出现同一个困境 —— 「现在到底是柔光还是液态」「档位是
/// 标准还是浓雾」「转场速度被系统动画缩放压掉了没有」这些只能靠翻三层设置页去
/// 回忆，而回忆错一次就会把两种完全不同的开销当成同一件事来比较。一条快照把
/// 当前所有会影响帧率的档位一次性写进日志，读数（`[frame-perf]`、
/// `[glass-cap]`、`[glass-state]`）与配置就能对上。
///
/// ## 口径：只读「有效值」，不重新推导
///
/// 本文件刻意**不**自己算「柔光档该是多少模糊半径」这类问题 —— 那等于把渲染
/// 侧的推导抄一遍，抄错或漂移之后日志会写出一个「看起来对、实际不是这样」的
/// 值，比没有日志更误导人。所以每一项都取自渲染侧自己在用的那个来源：
///
/// * 材质参数 → `TimetableSettings.frostedAppearance`（设置到渲染外观的**唯一**
///   转换点，各种回落已经在那里做完了）；
/// * 各表面实际材质 → `lib/models/surface_material.dart` 的工厂函数（与渲染侧
///   门控同口径，设置页「各表面当前材质」卡用的也是它们）；
/// * 液态玻璃的光学参数 → `LiquidGlassTuning`（非空即用户调过的档，空则回落
///   `LiquidGlassTuning.defaults`），因此「用户没进过高级材质页」时也照样读得到；
/// * 档位名 → `glassModeChoiceOf`。
///
/// ## 刻意不收集的东西
///
/// * **超级岛 / 桌面小组件的渲染质量开关**：它们在原生侧画，不影响 App 帧率，
///   混进来只会稀释「哪些项真的会掉帧」这个信号。
/// * **课程列表 / 壁纸历史 / 已存主题**：单条日志会到几十 KB，撞上日志文件
///   512KB 的裁剪线（`app_log_service.dart` 的 `_maxLogBytes`）并淹没日志页。
/// * **首页顶栏 / 星期栏那两个模糊开关**（`homePageHeaderBlurEnabled`、
///   `homePageWeekdayBarBlurEnabled`）：两者在反序列化时被无条件写回 true，
///   是已下线的僵尸字段。不收集是有意的 —— 把它们写进快照会让人以为还能调。
///
/// ## 语言
///
/// 本文件的字符串一律英文：`message` 与 [kPerformanceSnapshotTag] 沿用
/// `[frame-perf]` / `[glass-cap]` 那批诊断件的口径（中文硬编码审计按行计数，
/// 诊断日志串不该混进去）；日志分类走的是 `debug_snapshot`，在日志页显示为
/// 本地化的「调试快照」，读者不会因此看不懂。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/course_glass_tuning.dart';
import '../models/glass_mode_choice.dart';
import '../models/liquid_glass_tuning.dart';
import '../models/surface_material.dart';
import '../models/timetable_settings.dart';
import '../services/android_animation_scale_service.dart';
import '../services/app_log_service.dart';
import '../services/memory_stats_service.dart';
import '../ui/hyperos/hyperos_miuix_spec.dart';
import '../utils/home_page_background.dart';

/// 日志分类：复用已注册的 `debug_snapshot`（日志页显示「调试快照」）。
///
/// 这个分类在 `app_log_messages.dart` 的分类映射、localizer 与六个语言文件里
/// 早就齐了，只是一直没有调用点 —— 不必新增任何本地化条目。
const String kPerformanceSnapshotCategory = 'debug_snapshot';

/// logcat 里用来 grep 的前缀。落盘那条走 `AppLogService`，这条走 logcat。
const String kPerformanceSnapshotTag = '[settings-snapshot]';

/// 当前构建要不要打快照（调试版 `.debug` / 性能版 `.profile`）。
///
/// 同步、零成本（读一个启动期预热好的缓存布尔）。给调用方做**最便宜的前置
/// 门控**用：快照本身要跑一次约 90 个键的 JSON 编码，正式包里不该为一条永远
/// 不会输出的日志白付那笔 —— 尤其 `TimetableProvider.updateTimetableSettings`
/// 是所有设置写入的唯一收口，调用次数不低。
bool get performanceSnapshotEnabled =>
    MemoryStatsService.isDiagnosticsBuildCached;

/// 快照里「由设置推导」的那部分。
///
/// 与 [buildPerformanceSettingsSnapshot] 分开是为了指纹：环境量（系统动画缩放、
/// 壁纸文件是否还在）会随设置之外的原因变化，拿它们参与「设置变没变」的比较会
/// 产生假触发。
Map<String, Object?> _settingsDerivedSnapshot(TimetableSettings s) {
  final appearance = s.frostedAppearance;
  // 液态玻璃全 app 只有一套参数（[LiquidGlassTuning]）：取「已回落」的那份，
  // 所以内置兜底档（用户没进过高级材质页）也读得到同样的值。
  final liquid = appearance.liquidGlassTuning ?? LiquidGlassTuning.defaults;
  // 深色下渲染器真正会用的那份（走 toStyle 同一套选档 + 配方）。`borderRadius`
  // 与这里要读的三个标量无关，给 0 即可。
  final darkResolved = liquid.toStyle(
    borderRadius: 0,
    brightness: Brightness.dark,
    dark: appearance.liquidGlassTuningDark,
    link: appearance.linkLiquidGlassTuning,
    darkBoost: appearance.darkGlassBoostEnabled,
  );
  final soft = appearance.softGlassTuning;
  final progressive = appearance.progressiveBlurTuning;
  // 卡片那套同款「已回落」取法：内置兜底档也读得到同样的值。
  final card = appearance.courseCardGlassTuning ?? CourseGlassTuning.courseCard;

  return <String, Object?>{
    // —— 一句话档位 ——
    'glassMode': glassModeChoiceOf(s).name,
    'glassModeRaw': s.frostedGlassMode.name,
    'blurEnabled': s.frostedBlurEnabled,

    // —— 各表面此刻实际是什么材质（渲染侧同口径）——
    'surfaceHomeBand': homeBandSurfaceMaterial(s).name,
    'surfaceSubpageHeader': subpageHeaderSurfaceMaterial(s).name,
    'surfaceDock': dockSurfaceMaterial(s).name,
    // 弹窗家族锁标准档：这四个读数恒为液态玻璃（唯一能让它变的是设备级
    // shader / 系统降级，不在本推导范围内）。
    'surfaceSheetDialog': pinnedChromeSurfaceMaterial().name,
    'surfaceSelectSheet': pinnedChromeSurfaceMaterial().name,
    'surfacePopup': pinnedChromeSurfaceMaterial().name,
    'surfacePickerButtons': pinnedChromeSurfaceMaterial().name,
    'surfaceCourseCard': courseCardSurfaceMaterial(s).name,
    // 课卡的真实门控比 `courseCardSurfaceMaterial` 多一条「有没有可用壁纸」：
    // 没有壁纸时高斯档没有可采样的背景，渲染侧会回落实体卡。两个值不一致
    // 本身就是有用的读数（说明「设了高斯却看着是实体」不是 bug）。
    'courseCardEffective': effectiveCourseCardSurfaceStyle(
      s,
      gaussianBlurAvailable: s.frostedBlurEnabled,
    ).name,

    // —— 高级材质作用范围（2026-09-19 起只剩底栏一项）——
    'lgDock': s.liquidGlassDockEnabled,

    // —— 柔光玻璃参数（已回落，非空）——
    'softPreset': s.softGlassPreset.name,
    'softBlurMul': soft.blurRadiusMultiplier,
    'softTintMul': soft.tintAlphaMultiplier,
    'softEdgeHighlight': soft.edgeHighlight,

    // —— 液态玻璃光学参数：取「解析后」的值，所以内置兜底档也读得到 ——
    'lgPreset': s.liquidGlassPreset.name,
    'lgTuningSource': appearance.liquidGlassTuning == null
        ? 'builtin'
        : 'custom',
    'lgRefraction': liquid.refraction,
    'lgRefractionBand': liquid.refractionBand,
    'lgRefractionEdgePow': liquid.refractionEdgePow,
    'lgDispersion': liquid.dispersion,
    'lgRimStrength': liquid.rimStrength,
    'lgRimWidth': liquid.rimWidth,
    'lgBlurSigma': liquid.blurSigma,
    'lgTintAlpha': liquid.tintAlpha,
    // —— 液态玻璃的浅/深成对（2026-09-21）——
    // 不加这几行的话，日志会**说谎**：深色下的实际底色/模糊/边光是配方后的值，
    // 而上面那几行报的是浅色档原值，排查时会把「配方没生效」和「配方生效了」读成一样。
    'lgDarkTuningSource':
        appearance.liquidGlassTuningDark == null ? 'linked' : 'custom',
    'lgLinkDark': appearance.linkLiquidGlassTuning,
    'lgDarkBoost': appearance.darkGlassBoostEnabled,
    'lgDarkBlurSigma': darkResolved.blurSigma,
    'lgDarkRimStrength': darkResolved.rimStrength,
    'lgDarkDispersion': darkResolved.dispersion,
    'lgDarkTintAlpha': darkResolved.tint.a,

    // —— 课程卡片自己那套（2026-09-21）——
    // 卡片不再跟随上面那份，所以这几行是排查「卡片玻璃不对」的唯一读数来源。
    'ccTuningSource': appearance.courseCardGlassTuning == null
        ? 'builtin'
        : 'custom',
    'ccRefraction': card.refraction,
    'ccRefractionBand': card.refractionBand,
    'ccRefractionEdgePow': card.refractionEdgePow,
    'ccDispersion': card.dispersion,
    'ccRimStrength': card.rimStrength,
    'ccRimWidth': card.rimWidth,
    'ccBlurSigma': card.blurSigma,
    'ccTintAlpha': card.tintAlpha,

    // —— 渐进（顶栏）模糊参数 ——
    'pbPreset': s.progressiveBlurPreset.name,
    'pbSigma': progressive.sigma,
    'pbExtent': progressive.extent,
    'pbTintBottomScale': progressive.tintBottomScale,

    // —— 材质常量（用户看不到但直接决定开销）——
    'sheetBlurSigma': appearance.sheetBlurSigma,
    'sheetTintAlpha': appearance.sheetTintAlpha,
    'sheetBarrierAlpha': appearance.sheetBarrierAlpha,

    // —— 顶栏与背景带 ——
    'homeBandGlassMaterial': appearance.homeBandGlassMaterial,
    'subpageBlurStyle': appearance.subpageHeaderBlurStyle.name,
    'timeColumnBlur': s.homePageTimeColumnBlurEnabled,
    'backdropFollowsWeekPager': s.homePageBackdropFollowsWeekPager,

    // —— 外观 ——
    'themeMode': s.appThemeMode.value,
    'foruiTheme': s.foruiTheme.name,
    'seedColor': s.themeSeedColor,
    'fontMode': s.appFontMode.value,
    'fontWeight': s.appFontWeight,
    'textScale': s.appTextScale,
    'pageTransitionSpeed': s.pageTransitionSpeed,
    'localeTag': s.appLocaleTag,

    // —— 背景 / 壁纸 ——
    'backgroundFill': s.homePageBackgroundFill.name,
    'pageBackgroundColor': s.timetablePageBackgroundColor,
    'wallpaperAlignX': s.homePageWallpaperAlignX,
    'wallpaperAlignY': s.homePageWallpaperAlignY,
    'wallpaperScale': s.homePageWallpaperScale,
    'backgroundScope': s.homePageBackgroundScope,
    'backgroundScopeRegions': _backgroundScopeRegions(s.homePageBackgroundScope),
    'courseCardStyle': s.courseCardSurfaceStyle.name,
    'useUnifiedCardColor': s.timetableUseUnifiedCardColor,
    'unifiedCardColor': s.timetableUnifiedCardColor,

    // —— 课表密度（直接决定整页布局与滚动成本）——
    'sectionHeight': s.sectionHeight,
    'sectionCount': s.sectionCount,
    'autoFitSectionHeight': s.timetableAutoFitSectionHeight,
    'compactFontSize': s.compactFontSize,
    'courseCardFontSize': s.courseCardFontSize,
    'courseCardGap': s.timetableCourseCardGap,
    'timeColumnWidthMode': s.timetableTimeColumnWidthMode.name,
    'courseSpacingMode': s.timetableCourseSpacingMode.name,
    'hideWeekends': s.timetableHideWeekends,
    'showConflictBadge': s.showConflictBadgeOnTimetable,
    'conflictCardOpacity': s.timetableConflictCourseOpacity,
    'floatButtonOpacity': s.timetableFloatingBackToCurrentWeekButtonOpacity,
    'cardTextFields': _cardTextFields(s),

    // —— 导航形态 ——
    'navigationForm': s.homeNavigationForm.name,
    'menuStyle': s.homeMenuStyle.name,
  };
}

/// 快照里「当前环境」的那部分：不看你设置、但同样决定掉帧。
///
/// 单列出来是因为这些是最容易被忽略的排障项 —— 例如系统开发者选项里把动画
/// 缩放调成 0.5 之后，300ms 的转场只剩 150ms、120Hz 上只有十几帧，任何一帧
/// 稍重都会读作「卡」。
Map<String, Object?> _environmentSnapshot(TimetableSettings s) {
  return <String, Object?>{
    // 一眼看出这份日志来自调试版还是性能版。
    'buildMode': kReleaseMode
        ? 'release'
        : (kProfileMode ? 'profile' : 'debug'),
    // 转场的系统侧与用户侧倍率，以及两者合成后真正生效的时长。
    'systemTransitionScale': AndroidAnimationScaleService.transitionScale,
    'userTransitionSpeed': AndroidAnimationScaleService.userTransitionSpeed,
    'transitionDurationMs': AndroidAnimationScaleService.scaledDuration(
      HyperosMiuixNavigation.transitionDurationMs,
    ).inMilliseconds,
    // 壁纸单独拆两个布尔：`configured` 是设置里填了路径，`usable` 是文件真的
    // 还在。只报一个的话，「设了壁纸但文件丢了（重装 / 跨设备同步）」这条
    // 最常见的「材质莫名变实底」会被误读成设置问题。
    'wallpaperConfigured': _hasConfiguredWallpaper(s),
    'wallpaperUsable': hasHomePageBackdrop(s),
  };
}

/// 收集当前所有会影响渲染开销的设置，返回扁平 Map（键即日志 extras 的键）。
///
/// 纯函数，便于单测：同样的设置一定得到同样的推导部分（环境量除外，它们本来
/// 也不参与「设置变没变」的判定）。
Map<String, Object?> buildPerformanceSettingsSnapshot(TimetableSettings s) {
  return <String, Object?>{
    ..._settingsDerivedSnapshot(s),
    ..._environmentSnapshot(s),
  };
}

/// 「会影响帧率的那些项」是否真的变了。
///
/// 拖材质滑杆自带 250ms 防抖，但快速连拖仍会触发多次保存；没有这道守卫，
/// 一次调参会往日志里灌进一屏一模一样的快照。指纹直接取推导后的快照本身：
/// 以后往 [_settingsDerivedSnapshot] 加字段，守卫自动跟着覆盖，不会漏。
bool shouldLogPerformanceSettingsChange(
  TimetableSettings previous,
  TimetableSettings next,
) {
  return jsonEncode(_settingsDerivedSnapshot(previous)) !=
      jsonEncode(_settingsDerivedSnapshot(next));
}

/// 打一条快照。`reason` 说明这次是谁触发的，便于事后按来源分组比对。
///
/// 只对调试版 / 性能版生效（[MemoryStatsService.isDiagnosticsBuildCached]）。
/// 两条输出**都要**，不是二选一：
///
/// * 落盘那条走 [AppLogService]，但它是被门控的 —— 只有「已接受隐私政策」且
///   打开了「记录应用日志」才写得进去，刚装上的包往往一条都留不下；
/// * logcat 那条因此不可省。注意不能用 `appDebugLog()`：它在 `!kDebugMode`
///   时直接 return，而性能版（`.profile`）恰好就是 `kDebugMode == false`。
Future<void> logPerformanceSettingsSnapshot(
  TimetableSettings settings, {
  required String reason,
}) async {
  if (!performanceSnapshotEnabled) {
    return;
  }
  final extras = buildPerformanceSettingsSnapshot(settings)
    ..['reason'] = reason;
  unawaited(
    AppLogService.instance.info(
      kPerformanceSnapshotCategory,
      'render performance settings snapshot',
      extras: extras,
    ),
  );
  if (kReleaseMode) {
    return;
  }
  // wrapWidth: null —— 几十个键的单行 JSON 会被默认折行，折出来的续行没有
  // 前缀，grep 时只捞到第一行。
  debugPrint('$kPerformanceSnapshotTag ${jsonEncode(extras)}', wrapWidth: null);
}

/// 壁纸透出范围的可读形式（位标志原始值另有一份，出问题时能直接对数字）。
String _backgroundScopeRegions(int scope) {
  const regions = <int, String>{
    HomePageBackgroundScope.statusBar: 'statusBar',
    HomePageBackgroundScope.header: 'header',
    HomePageBackgroundScope.weekdayBar: 'weekdayBar',
    HomePageBackgroundScope.timetable: 'timetable',
  };
  final enabled = <String>[
    for (final entry in regions.entries)
      if (HomePageBackgroundScope.includes(scope, entry.key)) entry.value,
  ];
  return enabled.isEmpty ? 'none' : enabled.join(',');
}

/// 课卡此刻显示哪几行文本 —— 行数直接决定每张卡的布局与绘制成本。
String _cardTextFields(TimetableSettings s) {
  final enabled = <String>[
    if (s.courseCardShowName) 'name',
    if (s.courseCardShowTeacher) 'teacher',
    if (s.courseCardShowLocation) 'location',
    if (s.courseCardShowTime) 'time',
    if (s.courseCardShowTimeLabels) 'timeLabels',
    if (s.courseCardShowWeeks) 'weeks',
    if (s.courseCardShowDescription) 'description',
    if (s.weatherShowOnWeekCard) 'weather',
  ];
  return enabled.isEmpty ? 'none' : enabled.join(',');
}

bool _hasConfiguredWallpaper(TimetableSettings s) {
  final path = s.homePageWallpaperPath;
  return path != null && path.isNotEmpty;
}
