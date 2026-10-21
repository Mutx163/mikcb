import 'package:flutter/foundation.dart';

/// 壁纸**逐行**亮度剖面：解码后每一像素行（按 cover 裁剪出的可见列范围）的
/// 平均 WCAG 相对亮度，直接对应屏幕上一条水平像素带。
///
/// ## 为什么不能只要三带
///
/// 旧实现只留三条带（top / weekday / body），每条只给一个平均值。真实照片的
/// 竖直亮度跨度可以到 100 倍以上——同一张日落江面图，顶部 0.33、卡片区平均
/// 0.10，而第三张议程卡实际压着的那片水面只有 0.005。三带平均值描述不了
/// 「这张卡坐在哪一行」，于是同一屏上的三张卡只能共用一个数：
///
/// * 2026-10-21 真机：日视图第三张卡（坐在近黑水面上）被当成中等偏亮背景，
///   保留了导入时写入的深色字，实测对比度 1.5:1，读不出来；
/// * 另一张壁纸：日期卡与作业带本该是白字，却被判成亮底给了黑字。
///
/// 本类保留**逐行**数据（解码宽 128 时约 277 行，每行一个 double），调用方可以
/// 按任意屏幕竖直区间（一张卡的实际矩形）取那一段的平均亮度。
///
/// ## 与旧三带的关系
///
/// [bands] 用**与旧实现完全相同的行范围与取整公式**从同一份逐行数据算出来，
/// 所以三带口径逐位不变：已有测试与所有 chrome（顶栏 / 星期栏 / 时间轴）的
/// 判墨行为不受影响，新增的只是「更细的查询能力」。
@immutable
class WallpaperLuminanceProfile {
  const WallpaperLuminanceProfile({required this.rowLuminances});

  /// 解码图每一像素行的平均相对亮度（已按 cover 可见列范围裁剪）。
  ///
  /// 索引 0 = 图像最上一行。空表示不可用（调用方应按「未知亮度」处理）。
  final List<double> rowLuminances;

  static const WallpaperLuminanceProfile empty = WallpaperLuminanceProfile(
    rowLuminances: <double>[],
  );

  bool get isEmpty => rowLuminances.isEmpty;
  bool get isNotEmpty => rowLuminances.isNotEmpty;

  /// 可见区域的整体平均亮度（旧 `body` 带之外的用途：底栏、整屏兜底）。
  double? get average {
    if (rowLuminances.isEmpty) {
      return null;
    }
    var total = 0.0;
    for (final value in rowLuminances) {
      total += value;
    }
    return total / rowLuminances.length;
  }

  /// 屏幕竖直区间 `[fromFraction, toFraction)`（0~1，从上往下）的平均亮度。
  ///
  /// 这是一张卡片「背后那块壁纸」的亮度：卡片多高、压在哪一段，就查哪一段。
  /// 区间会被收口到 `[0, 1]`，并按旧三带同一套 floor/ceil 取整，保证
  /// 0~0.09 这类区间与 [bands] 里的 top 逐位一致。
  ///
  /// 返回 null 表示剖面不可用（还没采到 / 采样失败），调用方应回落到
  /// 「按主题猜」的旧行为，而不是猜一个亮度出来。
  double? luminanceForVerticalRange(double fromFraction, double toFraction) {
    final count = rowLuminances.length;
    if (count == 0) {
      return null;
    }
    final from = fromFraction.clamp(0.0, 1.0);
    final to = toFraction.clamp(0.0, 1.0);
    final low = from <= to ? from : to;
    final high = from <= to ? to : from;
    final fromRow = (count * low).floor().clamp(0, count - 1);
    final toRow = (count * high).ceil().clamp(fromRow + 1, count);
    var total = 0.0;
    for (var row = fromRow; row < toRow; row++) {
      total += rowLuminances[row];
    }
    return total / (toRow - fromRow);
  }

  /// 三条 chrome 亮度带，口径与 `sampleHomePageWallpaperLuminanceBands` 完全一致。
  ({double top, double weekday, double body})? get bands {
    final top = luminanceForVerticalRange(0, 0.09);
    final weekday = luminanceForVerticalRange(0.07, 0.20);
    final body = luminanceForVerticalRange(0.22, 0.72);
    if (top == null || weekday == null || body == null) {
      return null;
    }
    return (top: top, weekday: weekday, body: body);
  }

  /// 同值判断（采样结果没变时不要通知重建）。
  bool sameValuesAs(WallpaperLuminanceProfile? other) {
    if (identical(this, other)) {
      return true;
    }
    if (other == null || other.rowLuminances.length != rowLuminances.length) {
      return false;
    }
    for (var i = 0; i < rowLuminances.length; i++) {
      if ((rowLuminances[i] - other.rowLuminances[i]).abs() > 1e-9) {
        return false;
      }
    }
    return true;
  }

  /// 存档 / 进程间共享用：行数会随壁纸长宽比变化，必须一起序列化。
  List<double> toJson() => List<double>.of(rowLuminances);

  static WallpaperLuminanceProfile? fromJson(Object? json) {
    if (json is! List) {
      return null;
    }
    final rows = <double>[];
    for (final value in json) {
      if (value is! num) {
        return null;
      }
      rows.add(value.toDouble());
    }
    return rows.isEmpty
        ? WallpaperLuminanceProfile.empty
        : WallpaperLuminanceProfile(rowLuminances: List<double>.unmodifiable(rows));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WallpaperLuminanceProfile && sameValuesAs(other);

  @override
  int get hashCode => Object.hashAll(rowLuminances);
}
