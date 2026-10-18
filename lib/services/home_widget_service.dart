import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/app_debug_log.dart';
import '../logging/app_log_messages.dart';
import '../utils/timed_method_channel.dart';
import 'app_log_service.dart';
import 'home_widget_snapshot_service.dart';

enum HomeWidgetPinTarget {
  compact22('compact'),
  miniList22('mini_list'),
  medium24('medium'),
  large44('large'),
  stats22('stats_compact'),
  stats24('stats_medium'),
  todayStrip41('today_strip'),
  statsStrip41('stats_strip'),
  examCard22('exam_card'),
  todayWide42('today_wide');

  const HomeWidgetPinTarget(this.value);

  final String value;
}

/// 一张桌面卡片在设置页预览时的**真实格位尺寸**。
///
/// 尺寸不取 `widget_*_info.xml` 里的 `minWidth` / `minHeight`：那是 Android 4.x
/// 时代的「最小可用尺寸」（2×2 只声明 110×110dp），而现代启动器实际分配的是
/// 「跨几格 × 单格宽 + 格间距」——2×2 在 360dp 宽的屏上有一百五十多 dp。
/// 按 110 渲染会整整小一圈，而且连字号档都会跟着选错：卡片渲染里的
/// `isShort` / `isWide` / `isNarrow` 全由宽高决定，尺寸给小了，字体也会被当成小卡。
///
/// 所以这里只声明「跨几格」，具体 dp 由 [buildHomeWidgetPreviewSpecs] 按当前
/// 屏幕宽度换算——同一张卡片换到更大的手机上，桌面上占的格数不变，比例也不变。
class HomeWidgetPreviewSpec {
  const HomeWidgetPreviewSpec({
    required this.target,
    required this.cellWidth,
    required this.cellHeight,
    required this.widthDp,
    required this.heightDp,
  });

  final HomeWidgetPinTarget target;

  /// 横向跨几格、纵向跨几格，与 `widget_*_info.xml` 的
  /// `targetCellWidth` / `targetCellHeight` 一致。
  final int cellWidth;
  final int cellHeight;

  final double widthDp;
  final double heightDp;

  String get cellLabel => '$cellWidth×$cellHeight';

  /// 预览下方那行物理尺寸，如 `156×156dp`。
  ///
  /// 只放 dp、不再带格数：格数已经在卡片名里了（「主卡 2×2」「列表 4×4」），
  /// 两行都写 `2×2` 就是重复。
  String get sizeLabel =>
      '${widthDp.round()}×${heightDp.round()}dp';
}

/// 桌面网格推算参数：绝大多数手机桌面是 4 列、格间距 8dp、屏幕左右各留 20dp。
/// 只影响预览的物理尺寸感，不参与任何渲染判断。
const double _kDesktopSideInsetDp = 20;
const double _kDesktopCellGapDp = 8;
const int _kDesktopColumns = 4;

/// 一张已渲染好的预览图。
///
/// [png] 已经裁到卡片的可见边界，[widthDp] / [heightDp] 是这张图对应的物理尺寸。
///
/// 为什么不直接用 [HomeWidgetPreviewSpec] 的格位尺寸：卡片背景（`widget_card`）
/// 在 `widget_root` 的垂直内边距之内，所以它的可见尺寸比格位小一圈
/// （2×2 的格位是 173dp，卡片背景只有约 155dp 高）。格位尺寸只用于「渲染」，
/// 显示和尺寸行必须用这里裁出来的真实尺寸，否则就会出现
/// 「写着 173×173、看着却是扁的」——用户报的就是这个。
class HomeWidgetPreviewBitmap {
  const HomeWidgetPreviewBitmap({
    required this.png,
    required this.widthDp,
    required this.heightDp,
  });

  final Uint8List png;
  final double widthDp;
  final double heightDp;

  String get sizeLabel => '${widthDp.round()}×${heightDp.round()}dp';
}

/// 按当前屏幕逻辑宽度，换算每张卡片在桌面上占的真实格位尺寸。
///
/// 单格 = (屏宽 − 左右留白 − 格间距 ×(列数−1)) / 列数；
/// 横向跨 n 格 = n × 单格 + (n−1) × 间距，纵向同理。
///
/// 顺序：先今日课程系（含两种横条与宽卡），再统计系，最后考试卡；
/// 相邻两张格位接近，左右滑动时大小变化是连续的，不会忽大忽小。
List<HomeWidgetPreviewSpec> buildHomeWidgetPreviewSpecs(double screenWidth) {
  final usable = screenWidth - _kDesktopSideInsetDp * 2;
  final rawCell =
      (usable - _kDesktopCellGapDp * (_kDesktopColumns - 1)) / _kDesktopColumns;
  // 极窄屏兜底：格宽不应小于 56dp，否则卡片会被压到看不出内容。
  final cell = rawCell < 56 ? 56.0 : rawCell;

  double span(int cells) => cells * cell + (cells - 1) * _kDesktopCellGapDp;

  HomeWidgetPreviewSpec spec(HomeWidgetPinTarget target, int w, int h) {
    return HomeWidgetPreviewSpec(
      target: target,
      cellWidth: w,
      cellHeight: h,
      widthDp: span(w),
      heightDp: span(h),
    );
  }

  return <HomeWidgetPreviewSpec>[
    spec(HomeWidgetPinTarget.compact22, 2, 2),
    spec(HomeWidgetPinTarget.miniList22, 2, 2),
    spec(HomeWidgetPinTarget.medium24, 2, 4),
    spec(HomeWidgetPinTarget.large44, 4, 4),
    spec(HomeWidgetPinTarget.todayStrip41, 4, 1),
    spec(HomeWidgetPinTarget.todayWide42, 4, 2),
    spec(HomeWidgetPinTarget.stats22, 2, 2),
    spec(HomeWidgetPinTarget.stats24, 2, 4),
    spec(HomeWidgetPinTarget.statsStrip41, 4, 1),
    spec(HomeWidgetPinTarget.examCard22, 2, 2),
  ];
}

enum HomeWidgetPinRequestResult {
  requested,
  unsupported,
  invalidWidgetType,
  failed,
}

/// 「闹钟和提醒」授权页跳转结果。
enum HomeWidgetExactAlarmRequestResult {
  /// 已跳转系统授权页。
  launched,

  /// ROM 未处理授权 action，已回退应用详情页（含闹钟和提醒开关）。
  fallback,

  /// Android 12 以下无需授权。
  notRequired,

  /// 跳转失败（如平台通道不可用）。
  failed,
}

class HomeWidgetService {
  static const MethodChannel _channel = TimedMethodChannel(
    'com.mutx163.qingyu/home_widget',
  );

  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  Future<bool> canRequestPinWidget() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final supported = await _channel.invokeMethod<bool>(
        'canRequestPinWidget',
      );
      return supported ?? false;
    } on MissingPluginException {
      if (kDebugMode) {
        return false;
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_pin_support_failed',
          AppLogMessages.homeWidgetPinSupportFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '检查固定支持失败：$e');
    }
    return false;
  }

  /// 把一张桌面卡片就地渲染成 PNG，供设置页做 1:1 预览。
  ///
  /// 原生侧复用真实卡片的布局与填充逻辑（同一份 `widget_*.xml`、同一段
  /// 渲染代码），只是不交给系统下发，所以在应用内看到的和贴到桌面上的是同一张图。
  ///
  /// [nightMode] 取 App 当前主题的明暗、[languageTag] 取应用内语言，而不是
  /// 系统的值：预览贴在设置页自己的背景上，深浅与文案必须和页面同档，
  /// 否则会出现「深色页面里贴一张亮色卡片」或「中文界面里冒出英文卡片」。
  ///
  /// 返回 null 表示这张图这次没渲染出来（类型不支持、布局解析失败等），
  /// 调用方应显示占位而不是一直转圈。
  Future<HomeWidgetPreviewBitmap?> renderPreview({
    required HomeWidgetPreviewSpec spec,
    required bool nightMode,
    required String languageTag,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      // 用 Object? 接而不是 invokeMapMethod：原生侧存在新旧两种返回
      // （旧包只回 PNG 字节，新包回 {png, widthDp, heightDp}）。
      // 直接按 Map 读，装了旧包时每次都会抛类型转换异常，预览整片失败。
      final raw = await _channel.invokeMethod<Object?>(
        'renderWidgetPreview',
        <String, Object?>{
          'widgetType': spec.target.value,
          'widthDp': spec.widthDp,
          'heightDp': spec.heightDp,
          'nightMode': nightMode,
          'languageTag': languageTag,
        },
      );
      if (raw is Uint8List) {
        // 旧原生：没裁切、也没回传卡片尺寸，按格位尺寸显示兜底。
        return HomeWidgetPreviewBitmap(
          png: raw,
          widthDp: spec.widthDp,
          heightDp: spec.heightDp,
        );
      }
      if (raw is Map) {
        final png = raw['png'];
        if (png is! Uint8List) {
          return null;
        }
        final rawWidth = raw['widthDp'];
        final rawHeight = raw['heightDp'];
        return HomeWidgetPreviewBitmap(
          png: png,
          widthDp: rawWidth is num ? rawWidth.toDouble() : spec.widthDp,
          heightDp: rawHeight is num ? rawHeight.toDouble() : spec.heightDp,
        );
      }
      return null;
    } on MissingPluginException {
      return null;
    } catch (e) {
      // 预览渲染失败是用户可见的（设置页会显示「预览暂不可用」），落一条结构化
      // 日志便于排查；文案走 l10n 键，不在这里内联中文——lib/ 的中文硬编码
      // 审计是棘轮（只降不升），内联一行就会让 CI 红。
      unawaited(
        AppLogService.instance.warn(
          'home_widget_preview_render_failed',
          AppLogMessages.homeWidgetPreviewRenderFailed,
          error: e,
          extras: {'target': spec.target.value},
        ),
      );
      return null;
    }
  }

  Future<HomeWidgetPinRequestResult> requestPinWidget(
    HomeWidgetPinTarget target,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return HomeWidgetPinRequestResult.unsupported;
    }
    try {
      final status = await _channel.invokeMethod<String>('requestPinWidget', {
        'widgetType': target.value,
      });
      return switch (status) {
        'requested' => HomeWidgetPinRequestResult.requested,
        'unsupported' => HomeWidgetPinRequestResult.unsupported,
        'invalid_widget_type' => HomeWidgetPinRequestResult.invalidWidgetType,
        _ => HomeWidgetPinRequestResult.failed,
      };
    } on MissingPluginException {
      if (kDebugMode) {
        return HomeWidgetPinRequestResult.unsupported;
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_pin_request_failed',
          AppLogMessages.homeWidgetPinRequestFailed,
          extras: {'error': '$e', 'target': target.value},
        ),
      );
      appDebugLog('HomeWidget', '请求固定小组件失败：$e');
    }
    return HomeWidgetPinRequestResult.failed;
  }

  /// Android 12+（S）需要「闹钟和提醒」权限才能用精确闹钟按课程边界
  /// 刷新小组件；低于 S 或无法读取时视为已授权。
  Future<bool> canScheduleExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final granted = await _channel.invokeMethod<bool>(
        'canScheduleExactAlarms',
      );
      return granted ?? true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
      unawaited(
        AppLogService.instance.warn(
          'home_widget_exact_alarm_check_failed',
          AppLogMessages.homeWidgetExactAlarmCheckFailed,
          extras: {'error': 'MissingPluginException'},
        ),
      );
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_exact_alarm_check_failed',
          AppLogMessages.homeWidgetExactAlarmCheckFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '检查精确闹钟权限失败：$e');
    }
    return true;
  }

  /// 跳转系统「闹钟和提醒」授权页（ACTION_REQUEST_SCHEDULE_EXACT_ALARM）。
  ///
  /// 返回跳转结果；ROM 回退应用详情页时为 [HomeWidgetExactAlarmRequestResult.fallback]，
  /// 调用方可据此给出与实际画面一致的提示。
  Future<HomeWidgetExactAlarmRequestResult> requestScheduleExactAlarm() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return HomeWidgetExactAlarmRequestResult.notRequired;
    }
    try {
      final status = await _channel.invokeMethod<String>(
        'requestScheduleExactAlarm',
      );
      return switch (status) {
        'launched' => HomeWidgetExactAlarmRequestResult.launched,
        'fallback' => HomeWidgetExactAlarmRequestResult.fallback,
        'not_required' => HomeWidgetExactAlarmRequestResult.notRequired,
        _ => HomeWidgetExactAlarmRequestResult.failed,
      };
    } on MissingPluginException {
      if (kDebugMode) {
        return HomeWidgetExactAlarmRequestResult.failed;
      }
      unawaited(
        AppLogService.instance.warn(
          'home_widget_exact_alarm_request_failed',
          AppLogMessages.homeWidgetExactAlarmRequestFailed,
          extras: {'error': 'MissingPluginException'},
        ),
      );
      return HomeWidgetExactAlarmRequestResult.failed;
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_exact_alarm_request_failed',
          AppLogMessages.homeWidgetExactAlarmRequestFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '请求精确闹钟权限失败：$e');
      return HomeWidgetExactAlarmRequestResult.failed;
    }
  }

  /// 按最新「闹钟和提醒」权限档位重排小组件刷新闹钟。
  ///
  /// 用户授权返回后调用，使非精确刷新立即升级为精确刷新。
  Future<bool> rescheduleRefresh() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('rescheduleRefresh');
      return ok ?? false;
    } on MissingPluginException {
      if (kDebugMode) {
        return false;
      }
      unawaited(
        AppLogService.instance.warn(
          'home_widget_schedule_failed',
          AppLogMessages.homeWidgetScheduleFailed,
          extras: {'error': 'MissingPluginException'},
        ),
      );
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_schedule_failed',
          AppLogMessages.homeWidgetScheduleFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', 'reschedule refresh failed: $e');
    }
    return false;
  }

  Future<bool> syncSnapshot(HomeWidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod('syncSnapshot', snapshot.toJson());
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_sync_failed',
          AppLogMessages.homeWidgetSyncFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '同步快照失败：$e');
    }
    return false;
  }

  Future<bool> clearSnapshot() async {
    try {
      await _channel.invokeMethod('clearSnapshot');
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_clear_failed',
          AppLogMessages.homeWidgetClearFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '清空快照失败：$e');
    }
    return false;
  }

  Future<void> scheduleRefresh(List<int> triggerAtMillis) async {
    try {
      await _channel.invokeMethod('scheduleRefresh', {
        'triggerAtMillis': triggerAtMillis,
      });
    } on MissingPluginException {
      if (kDebugMode) {
        return;
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_schedule_failed',
          AppLogMessages.homeWidgetScheduleFailed,
          extras: {'error': '$e', 'count': triggerAtMillis.length},
        ),
      );
      appDebugLog('HomeWidget', '调度刷新失败：$e');
    }
  }
}
