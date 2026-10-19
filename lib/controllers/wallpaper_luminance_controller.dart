import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../utils/home_page_background.dart';
import '../utils/home_wallpaper_luminance_share.dart';
import '../utils/home_startup_visual_primer.dart';
import '../utils/luminance_sample_gate.dart';

/// 首页壁纸亮度采样控制器（2026-10-20 从 `TimetableScreen` State 搬出）。
///
/// 持有顶栏/星期栏/卡片三条亮度带、采样 key 与失败闸门；采样成功/失败/文件
/// 丢失时 `notifyListeners()`，由外层 `setState` 重绘。不读 UI，不依赖 State。
class WallpaperLuminanceController extends ChangeNotifier {
  double? _top;
  double? _weekday;
  double? _body;
  String? _sampleKey;
  String? _requestedKey;
  bool _fileExists = false;
  bool _disposed = false;
  final LuminanceSampleGate _gate = LuminanceSampleGate();

  double? get top => _top;
  double? get weekday => _weekday;
  double? get body => _body;

  /// 顶栏/星期栏/卡片实际用于判墨的星期栏亮度。
  double? weekdayInk(TimetableSettings settings) {
    return settings.homePageWeekdayBarBlurEnabled ? _top : _weekday ?? _top;
  }

  /// 首帧从启动预热器/进程内共享值直接采用，避免「按主题猜再翻面」的闪变。
  void seedFromPrimerOrShare(
    TimetableSettings settings, {
    required Size viewportSize,
  }) {
    if (_top != null ||
        _weekday != null ||
        _body != null ||
        _requestedKey != null) {
      return;
    }
    final path = homePageBackdropKey(settings);
    if (path == null || path.isEmpty) {
      return;
    }
    final key = _key(
      path: path,
      viewportSize: viewportSize,
      alignX: settings.homePageWallpaperAlignX,
      alignY: settings.homePageWallpaperAlignY,
      scale: settings.homePageWallpaperScale,
    );
    final bands =
        HomeWallpaperLuminanceShare.resolve(key) ??
        HomeStartupVisualPrimer.seededBandsFor(path);
    if (bands == null) {
      return;
    }
    _top = bands.top;
    _weekday = bands.weekday;
    _body = bands.body;
  }

  void schedule(
    TimetableSettings settings, {
    required Size viewportSize,
  }) {
    // 统一用「背景身份键」（背景图绝对路径）做采样缓存 key。
    final path = homePageBackdropKey(settings);
    if (path == null || path.isEmpty) {
      if (_top != null ||
          _weekday != null ||
          _body != null ||
          _sampleKey != null ||
          _requestedKey != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_disposed) {
            return;
          }
          _top = null;
          _weekday = null;
          _body = null;
          _sampleKey = null;
          _requestedKey = null;
          _fileExists = false;
          notifyListeners();
          // 背景整个没了：失败配额一并清掉，下次换回壁纸要重新采（否则会带着
          // "同一份 key 已经试满"的旧账直接认输）。
          _gate.reset();
        });
      }
      return;
    }
    final key = _key(
      path: path,
      viewportSize: viewportSize,
      alignX: settings.homePageWallpaperAlignX,
      alignY: settings.homePageWallpaperAlignY,
      scale: settings.homePageWallpaperScale,
    );
    if (_requestedKey == key && (_sampleKey == key || !_fileExists)) {
      return;
    }
    // 本方法在 build 期间被调用，而 ensure 首段（existsSync 结果分流）含同步
    // 状态变更：直接调用会在 build 期标脏，触发 "setState() called during
    // build" 并中断采样链。统一推迟到帧后首跑，重复进入由 requestedKey 幂等
    // 去重。
    unawaited(
      Future<void>.sync(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_disposed) {
            return;
          }
          _ensure(
            settings,
            viewportSize: viewportSize,
            alignX: settings.homePageWallpaperAlignX,
            alignY: settings.homePageWallpaperAlignY,
            key: key,
          );
        });
      }),
    );
  }

  /// 采样缓存 key：`路径|视口宽x高|alignX|alignY|scale`。
  String _key({
    required String path,
    required Size viewportSize,
    required double alignX,
    required double alignY,
    required double scale,
  }) {
    return homePageBackdropSampleKey(
      path: path,
      viewportKey: homePageBackdropViewportKey(viewportSize),
      alignX: alignX,
      alignY: alignY,
      scale: scale,
    );
  }

  Future<void> _ensure(
    TimetableSettings settings, {
    required Size viewportSize,
    required double alignX,
    required double alignY,
    required String key,
  }) async {
    if (_requestedKey == key && _sampleKey == key && _top != null) {
      return;
    }
    _requestedKey = key;
    // 背景图文件丢失时清空亮度采样，让顶栏/星期栏墨色回落到主题默认。
    final filePath = resolveHomePageBackdropImagePath(settings);
    final fileExists = filePath == null || filePath.isEmpty
        ? true
        : File(filePath).existsSync();
    if (_disposed || _requestedKey != key) {
      return;
    }
    if (!fileExists) {
      if (_top != null ||
          _weekday != null ||
          _body != null ||
          _sampleKey != null ||
          _fileExists) {
        _top = null;
        _weekday = null;
        _body = null;
        _sampleKey = null;
        _fileExists = false;
        notifyListeners();
      }
      return;
    }
    _fileExists = true;
    _sampleKey = key;
    await _load(
      settings,
      viewportSize: viewportSize,
      alignX: alignX,
      alignY: alignY,
      key: key,
    );
  }

  Future<void> _load(
    TimetableSettings settings, {
    required Size viewportSize,
    required double alignX,
    required double alignY,
    required String key,
  }) async {
    final bands = await sampleHomePageBackdropLuminanceBands(
      settings,
      viewportSize: viewportSize,
      alignX: alignX,
      alignY: alignY,
    );
    if (_disposed || _sampleKey != key) {
      return;
    }
    if (bands == null) {
      // 采样失败不能继续装着「已采过」——守卫看到 sampleKey == key 会每帧
      // 早退，墨色此后停在主题默认色；也不能无条件重试（每帧重解码大图），
      // 交给闸门按 key 限次决定要不要放行下一次。
      _gate.record(key, succeeded: false);
      if (_gate.needsSample(key)) {
        _sampleKey = null;
        notifyListeners();
      }
      return;
    }
    // 采到了：这一份 key 永久命中，失败配额归零。
    _gate.record(key, succeeded: true);
    // 登记给同进程里此后新建的首页实例（缩尺预览），让它首帧直接用这份极性。
    HomeWallpaperLuminanceShare.publish(key, bands);
    if (_top == bands.top &&
        _weekday == bands.weekday &&
        _body == bands.body) {
      return;
    }
    _top = bands.top;
    _weekday = bands.weekday;
    _body = bands.body;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
