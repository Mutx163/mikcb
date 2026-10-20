/// 页面级壁纸亮度采样（2026-10-20 立）。
///
/// ## 为什么独立页面要自己有一份
///
/// 首页那份亮度带住在 `WallpaperLuminanceController`（首页 State 的字段），
/// 负责首帧预热、去抖、失败闸门、跨实例共享。月视图这类独立页面拿不到那份状态，
/// 而**判墨**又必须知道壁纸亮度：顶栏软件名字、工具行、卡面文字的黑白极性全按它
/// 定。没有它就只能按主题猜 —— 在暗壁纸上猜成深墨，字直接看不见。
///
/// 所以这里做一份极薄的等价物：按「壁纸路径 + 对齐 / 缩放 + 视口」为键采一次
/// （键不变就不重采），把顶部带与主体带两个读数交给页面。
///
/// ## 为什么复用 [sampleHomePageWallpaperLuminanceBands]
///
/// 那是首页、启动预热器、外观编辑页预览三条路共用的**唯一**采样实现，它同时出了
/// top / weekday / body 三条带，且把 `cover` 的取景几何算进去了。自己另写一份
/// 采样等于制造第二套「同一条壁纸算出不同亮度」的来源 —— 本仓在外观编辑页上已经
/// 为这类漂移付过代价（见 `HomeWallpaperLuminanceShare` 的类注释）。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/timetable_settings.dart';
import 'home_page_background.dart';

/// 独立页面的壁纸亮度快照（不可变；变化时由页面 setState 换一份新的）。
@immutable
class PageWallpaperLuminance {
  const PageWallpaperLuminance({
    required this.key,
    required this.top,
    required this.body,
  });

  /// 采样键：`壁纸路径 | 对齐X | 对齐Y | 缩放 | 视口`。
  ///
  /// 键里**必须**含取景三自由度（alignX / alignY / scale）：用户拖动过壁纸之后
  /// 同一条路径上的亮度会变，只按路径去重会把旧取景的极性塞给新取景，而且不会
  /// 自愈（`WallpaperLuminanceController._key` 的注释是同一套口径）。
  final String key;

  /// 顶部带（状态栏 + 标题行）亮度。
  final double top;

  /// 主体带（正文 / 卡片区）亮度。
  final double body;
}

/// 采样器：一个页面实例一个，随 State 一起释放。
///
/// 用法是一个「喂当前状态、拿最新读数」的循环：
///
/// ```dart
/// final _luminance = PageWallpaperLuminanceSampler();
/// // didChangeDependencies 里：
/// _luminance.pull(context.read<TimetableProvider>().settings, () => setState(() {}));
/// ```
class PageWallpaperLuminanceSampler {
  PageWallpaperLuminance? _value;
  String? _inFlight;
  bool _disposed = false;

  /// 最近一次采到的读数；null = 没有壁纸 / 还没采到。
  PageWallpaperLuminance? get value => _value;

  /// 按当前设置与视口补采一次；键没变就直接返回。
  ///
  /// [onChanged] 在**真的拿到新读数**时调用（页面在里面 `setState`）。异步、
  /// 永不抛：解码失败只是保持 null（墨色回落主题），不能把页面拖崩。
  void pull(TimetableSettings settings, VoidCallback onChanged) {
    if (_disposed) {
      return;
    }
    final path = homePageBackdropKey(settings);
    if (path == null || path.isEmpty) {
      if (_value != null) {
        _value = null;
        onChanged();
      }
      return;
    }
    final key = _keyFor(settings, path);
    if (key == _value?.key || key == _inFlight) {
      return;
    }
    _inFlight = key;
    unawaited(_sample(settings, path: path, key: key, onChanged: onChanged));
  }

  Future<void> _sample(
    TimetableSettings settings, {
    required String path,
    required String key,
    required VoidCallback onChanged,
  }) async {
    try {
      final bands = await sampleHomePageBackdropLuminanceBands(settings);
      if (_disposed || _inFlight != key) {
        return;
      }
      _inFlight = null;
      if (bands == null) {
        // 解码失败 / 文件正在写：保持现状（沿用上一份或 null），不重试。
        // 页面上重试的代价是每帧重解码一张大图 —— 宁可这一屏按主题判墨。
        return;
      }
      _value = PageWallpaperLuminance(
        key: key,
        top: bands.top,
        body: bands.body,
      );
      onChanged();
    } catch (_) {
      if (_disposed || _inFlight != key) {
        return;
      }
      _inFlight = null;
    }
  }

  /// 采样键。与 `WallpaperLuminanceController` 同构，只多带视口一维。
  ///
  /// [viewportSize] 由 [pull] 调用方通过 settings 之外传入是不行的（设置里没有
  /// 视口），所以这里省掉视口：整屏 cover 的取景只由 align / scale 决定，视口变化
  /// （进出页面时状态栏 inset 变化）对三带平均亮度的影响可以忽略
  /// —— 这也是 `HomeWallpaperLuminanceShare.resolve` 忽略视口的同一条理由。
  String _keyFor(TimetableSettings settings, String path) {
    return '$path|${settings.homePageWallpaperAlignX}|'
        '${settings.homePageWallpaperAlignY}|${settings.homePageWallpaperScale}';
  }

  void dispose() {
    _disposed = true;
    _value = null;
    _inFlight = null;
  }
}
