// 从 timetable_settings.dart 拆出的设置枚举与默认常量（2026-10-19，行为零变化）。
// 只放不依赖 TimetableSettings 的类型；宿主通过 export 保持原导入路径可用。

enum AppUpdateDownloadSource { original, mirror }

enum AppUpdateDownloadChannel { pgyer, github, gitcode }

enum AppUpdateMirrorPreset { ghfast, ghLlkk, ghProxyCom, ghproxyNet, custom }

enum WidgetBackgroundStyle { glass, solid, gradient }

enum AppThemeMode { system, light, dark }

enum AppFontMode {
  system,
  sansSerif,
  miSans,
  harmonyOS,
  oppoSans,
  pingFang,
  notoSans,
  serif,
  songti,
  monospace,
}

/// 默认全局字重（Material w400）。等于该值时不覆盖 Theme / Miuix 字重。
const int kAppFontWeightDefault = 400;
const int kAppFontWeightMin = 100;
const int kAppFontWeightMax = 900;
const int kAppFontWeightDivisions = 16;

/// 默认全局字号缩放。等于 1.0 时跟随系统 textScaler。
const double kAppTextScaleDefault = 1;
const double kAppTextScaleMin = 0.85;
const double kAppTextScaleMax = 1.6;
const int kAppTextScaleDivisions = 15;

/// 把用户字重钳到合法区间，并归一非法/缺失值为默认。
int normalizeAppFontWeight(num? value) {
  if (value == null) return kAppFontWeightDefault;
  return value.round().clamp(kAppFontWeightMin, kAppFontWeightMax);
}

/// 把用户字号缩放钳到合法区间，并归一非法/缺失值为默认。
double normalizeAppTextScale(num? value) {
  if (value == null) return kAppTextScaleDefault;
  final clamped = value.toDouble().clamp(kAppTextScaleMin, kAppTextScaleMax);
  return double.parse(clamped.toStringAsFixed(2));
}

enum ForuiTheme {
  /// 小米原色（HyperOS/Miuix 规范主蓝 #3482FF）：App 原本的开箱配色，
  /// 作为预设之一保留，同时是默认值。
  miui,
  neutral,
  zinc,
  slate,
  blue,
  green,
  orange,
  red,
  rose,
  violet,
  yellow,
}

extension ForuiThemeX on ForuiTheme {
  String get value => name;

  /// Representative brand hex for this forui theme; synced into [TimetableSettings.themeSeedColor]
  /// and used to seed the Material ColorScheme so Material accents follow the forui theme.
  String get seedHex => switch (this) {
    ForuiTheme.miui => '#3482FF',
    ForuiTheme.neutral => '#171717',
    ForuiTheme.zinc => '#18181B',
    ForuiTheme.slate => '#0F172B',
    ForuiTheme.blue => '#1447E6',
    ForuiTheme.green => '#5EA500',
    ForuiTheme.orange => '#F54A00',
    ForuiTheme.red => '#E7000B',
    ForuiTheme.rose => '#EC003F',
    ForuiTheme.violet => '#7F22FE',
    ForuiTheme.yellow => '#FCC800',
  };

  static ForuiTheme fromValue(String? value) {
    return ForuiTheme.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ForuiTheme.blue,
    );
  }
}

enum HomeTitleStyle { classic, brand }

enum HomePageBackgroundFill { color, image }

extension HomePageBackgroundFillX on HomePageBackgroundFill {
  String get value => name;

  static HomePageBackgroundFill fromValue(String? value) {
    return HomePageBackgroundFill.values.firstWhere(
      (item) => item.value == value,
      orElse: () => HomePageBackgroundFill.color,
    );
  }
}

/// Bit flags for home page background display regions.
abstract final class HomePageBackgroundScope {
  static const int timetable = 1;
  static const int weekdayBar = 2;
  static const int header = 4;
  static const int statusBar = 8;

  /// 默认铺满状态栏、顶栏、信息栏与课表区域（无壁纸时无感知）。
  static const int defaultValue = timetable | weekdayBar | header | statusBar;

  static bool includes(int scope, int region) => (scope & region) != 0;

  static int toggle(int scope, int region, {required bool enabled}) {
    return enabled ? (scope | region) : (scope & ~region);
  }
}

enum TimetableHomeViewMode { week, day }

/// 首页导航形态：经典形态保持原样；玻璃坞形态在底部提供液态玻璃
/// 药丸导航，滑动/点击即可切换周课表、日课表与设置。
enum HomeNavigationForm { classic, glassDock }

/// 首页右上角「更多」菜单形态：
/// - [list] 锚定在按钮下方的列表弹窗（当前设计）；
/// - [grid] 底部弹出的八宫格图标瓷贴（v2.0.5.5 已发布版本的样式）。
enum HomeMenuStyle { list, grid }

extension HomeMenuStyleX on HomeMenuStyle {
  String get value => switch (this) {
    HomeMenuStyle.list => 'list',
    HomeMenuStyle.grid => 'grid',
  };

  static HomeMenuStyle fromValue(String? value) {
    return HomeMenuStyle.values.firstWhere(
      (item) => item.value == value,
      orElse: () => HomeMenuStyle.list,
    );
  }
}

/// 八宫格菜单的槽位约束与默认排列。
///
/// id 是稳定持久化主键（内置九项沿用旧 HomeTopMenuAction.name，其余
/// 来自 UI 目录 kHomeMenuCatalog）；模型层不感知具体条目含义（避免
/// 反向依赖 widgets），未知 id 由 UI 层解析时丢弃。
abstract final class HomeGridMenu {
  /// 八宫格最多容纳的按钮数量（4 列 × 2 行）。
  static const int maxSlots = 8;

  /// 钉死的「课表设置」入口 id。
  ///
  /// 它是回到八宫格自定义编辑器的唯一稳定路径（设置 → 外观 → 自定义
  /// 八宫格按钮）。若允许移除，用户把可达设置的入口删光后就再也进不了
  /// 编辑器重新加回——先有鸡还是先有蛋的死锁。因此任何持久化排列都
  /// 强制包含它（仍可拖动排序，只是不可移除）。
  static const String pinnedActionId = 'settings';

  /// v2.0.5.5 已发布版本的默认排列（不含后来新增的任务入口）。
  static const List<String> defaultActions = [
    'update',
    'overview',
    'statistics',
    'addCourse',
    'exams',
    'importCourses',
    pinnedActionId,
    'support',
  ];

  /// 去重、剔除非字符串项并截断到 [maxSlots]，最后保证钉住项在场。
  /// 空输入保持空表——渲染层会把空表回退成 [defaultActions]（本身
  /// 含钉住项），缺 key 与脏数据走同一条路。
  static List<String> normalize(Iterable<Object?>? raw) {
    if (raw == null) {
      return const <String>[];
    }
    final unique = <String>[];
    for (final item in raw) {
      if (item is String && item.isNotEmpty && !unique.contains(item)) {
        unique.add(item);
      }
    }
    if (unique.length > maxSlots) {
      unique.removeRange(maxSlots, unique.length);
    }
    if (!unique.contains(pinnedActionId)) {
      if (unique.length >= maxSlots) {
        unique.removeLast();
      }
      unique.add(pinnedActionId);
    }
    return List<String>.unmodifiable(unique);
  }
}

/// 玻璃坞底栏按钮的槽位约束与默认排列。
///
/// id 语义：'day' / 'week' 是视图切换动作，其余 id 走八宫格目录
/// （kHomeMenuCatalog，含 'settings'）。空排列合法——渲染层回退到
/// [defaultActions]，因此不做钉住补位（区别于八宫格的 normalize）。
abstract final class HomeDockMenu {
  /// 底栏最多容纳的按钮数量（含视图切换与页面入口）。
  static const int maxSlots = 5;

  static const List<String> defaultActions = <String>['day', 'week'];

  static List<String> normalize(Iterable<Object?>? raw) {
    if (raw == null) {
      return const <String>[];
    }
    final unique = <String>[];
    for (final item in raw) {
      if (item is String && item.isNotEmpty && !unique.contains(item)) {
        unique.add(item);
      }
    }
    if (unique.length > maxSlots) {
      unique.removeRange(maxSlots, unique.length);
    }
    return List<String>.unmodifiable(unique);
  }
}

enum BackToCurrentWeekButtonStyle { inline, floating }

enum SectionTimeDisplayMode { hidden, startOnly, startAndEnd }

enum LiveDuringClassTimeDisplayMode { nearest, total }

enum LiveCountdownTextStyle {
  smart,
  smartMinS,
  minuteSecondCn,
  minuteSecondColon,
  minuteSecondMinS,
  minuteSecondMinSlashS,
  minuteOnlyCn,
  minuteOnlyMin,
  minuteOnlySlash,
  secondOnlyCn,
  secondOnlyShort,
  secondOnlySlash,
}

enum MiuiIslandLabelStyle { textOnly, iconAndText }

enum MiuiIslandLabelContent { courseName, location, courseNameAndLocation }

enum MiuiIslandLabelFontWeight { regular, medium, bold }

enum MiuiIslandLabelRenderQuality { standard, high, ultra }

enum MiuiIslandExpandedIconMode { appIcon, customImage, hidden }

/// 上课前通知里能一键执行的系统静音动作。
///
/// [priorityOnly] 是「仅允许优先通知」档（INTERRUPTION_FILTER_PRIORITY）：
/// 只放行星标联系人，闹钟照响。比 [doNotDisturb]（完全勿扰）温和，
/// 适合「想屏蔽普通通知但别漏掉家人来电」的场景。
enum LiveBeforeClassQuickAction {
  none,
  silent,
  doNotDisturb,
  priorityOnly,
  both,
}

const String defaultAppUpdateMirrorUrlPrefix = 'https://ghfast.top/';
const String ghLlkkMirrorUrlPrefix = 'https://gh.llkk.cc/';
const String ghProxyComMirrorUrlPrefix = 'https://gh-proxy.com/';
const String ghproxyNetMirrorUrlPrefix = 'https://ghproxy.net/';
