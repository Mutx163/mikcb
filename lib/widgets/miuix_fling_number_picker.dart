// 带惯性衰减的 Miuix 数字滚轮（flutter_miuix MiuixNumberPicker 的临时替代）。
//
// flutter_miuix 1.0.9 的 MiuixNumberPicker 松手后直接用弹簧吸附到最近一格，
// 丢失了 Compose 原版（compose-miuix-ui/miuix NumberPicker.kt）的惯性衰减段，
// 表现为"猛甩立刻停"。已向上游报告（ChuxinNeko/flutter_miuix#2）；在上游修复
// 发版前，应用侧滚轮统一使用本组件。上游修复后可整体切回并删除本文件。
//
// 与原版对齐的两段式松手动画：
// ① animateDecay：指数衰减惯性（exponentialDecay(frictionMultiplier = 2f)，
//    即速度按 e^(-8.4t) 衰减；-4.2 为 Compose 衰减基准常数），非循环模式下
//    位移钳在可选区间边界；
// ② 衰减停止后 spring(dampingRatio = 1, stiffness = 400) 吸附到最近一格。
// 惯性途中每过一格触发一次 selectionClick 触感（复用偏移监听）。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

/// API 与 [MiuixNumberPicker] 完全一致，可原位替换。
class MiuixFlingNumberPicker extends StatefulWidget {
  const MiuixFlingNumberPicker({
    super.key,
    required this.value,
    required this.onValueChanged,
    this.enabled = true,
    this.min = 0,
    this.max = 10,
    this.label,
    this.visibleItemCount = 5,
    this.wrapAround = false,
    this.colors,
    this.textStyle,
    this.itemHeight = MiuixNumberPickerDefaults.itemHeight,
  })  : assert(
            visibleItemCount % 2 == 1 && visibleItemCount >= 3,
            'visibleItemCount must be odd and at least 3'),
        assert(min <= max, 'range must not be empty');

  final int value;
  final ValueChanged<int>? onValueChanged;
  final bool enabled;
  final int min;
  final int max;
  final String Function(int)? label;
  final int visibleItemCount;
  final bool wrapAround;
  final MiuixNumberPickerColors? colors;
  final TextStyle? textStyle;
  final double itemHeight;

  @override
  State<MiuixFlingNumberPicker> createState() => _MiuixFlingNumberPickerState();
}

class _MiuixFlingNumberPickerState extends State<MiuixFlingNumberPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _offset;

  bool _isDragging = false;
  bool _isUserScrolling = false;
  int _lastHapticIndex = 0;

  /// 松手动画的代数（drag start 会 stop 动画；靠代数辨别衰减段是否被新手势
  /// 打断，避免旧回调续跑吸附段）。
  int _flingGeneration = 0;

  @override
  void initState() {
    super.initState();
    _offset = AnimationController.unbounded(vsync: this, value: 0.0);
    _offset.addListener(_onOffsetChanged);
    _lastHapticIndex = _currentIndex;
  }

  @override
  void didUpdateWidget(MiuixFlingNumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max) {
      // 外部 value 变化时，重置偏移
      if (!_isDragging) {
        _offset.value = 0.0;
      }
      _lastHapticIndex = _currentIndex;
    }
  }

  @override
  void dispose() {
    _offset.removeListener(_onOffsetChanged);
    _offset.dispose();
    super.dispose();
  }

  bool get _effectiveEnabled =>
      widget.enabled && widget.onValueChanged != null;

  int get _itemCount => widget.max - widget.min + 1;
  int get _currentIndex =>
      widget.value.clamp(widget.min, widget.max) - widget.min;
  int get _halfVisible => widget.visibleItemCount ~/ 2;

  String _labelFor(int value) => widget.label?.call(value) ?? value.toString();

  int _computeEffectiveIndex() {
    final rawIndex = _currentIndex + _offset.value.round();
    if (widget.wrapAround) {
      return ((rawIndex % _itemCount) + _itemCount) % _itemCount;
    }
    return rawIndex.clamp(0, _itemCount - 1);
  }

  void _onOffsetChanged() {
    final effectiveIndex = _computeEffectiveIndex();
    if (effectiveIndex != _lastHapticIndex) {
      if (_isUserScrolling) {
        HapticFeedback.selectionClick();
      }
      _lastHapticIndex = effectiveIndex;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_effectiveEnabled) return;
    var newOffset = _offset.value - details.delta.dy / widget.itemHeight;
    if (!widget.wrapAround) {
      newOffset = newOffset.clamp(
        -_currentIndex.toDouble(),
        (_itemCount - 1 - _currentIndex).toDouble(),
      );
    }
    _offset.value = newOffset;
  }

  /// 提交松手动画的最终落点：把偏移换算回 value 并归零。
  void _commitSettledValue() {
    final offsetInt = _offset.value.round();
    int newIndex;
    if (widget.wrapAround) {
      newIndex = ((_currentIndex + offsetInt) % _itemCount + _itemCount) %
          _itemCount;
    } else {
      newIndex = (_currentIndex + offsetInt).clamp(0, _itemCount - 1);
    }
    final newValue = widget.min + newIndex;
    _offset.value = 0.0;
    _isUserScrolling = false;
    if (newValue != widget.value) {
      widget.onValueChanged?.call(newValue);
    }
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (!_effectiveEnabled) return;
    _isDragging = false;
    final generation = ++_flingGeneration;

    // 单位换算成"格"：与原版一致（velocityInItems = -velocity / itemHeightPx）。
    final velocityItems =
        -details.velocity.pixelsPerSecond.dy / widget.itemHeight;

    // ① 惯性衰减段：exponentialDecay(frictionMultiplier = 2f) 等价的
    //    FrictionSimulation（v(t) = v0·e^(-4.2·2·t) → drag = e^(-8.4)/s）。
    //    非循环模式下位移钳在可选区间内，触边即停（对应原版 updateBounds）。
    if (velocityItems.abs() > 0.5) {
      Simulation decay = FrictionSimulation(
        math.exp(-8.4),
        _offset.value,
        velocityItems,
      );
      if (!widget.wrapAround) {
        decay = ClampedSimulation(
          decay,
          xMin: -_currentIndex.toDouble(),
          xMax: (_itemCount - 1 - _currentIndex).toDouble(),
        );
      }
      await _offset.animateWith(decay);
      // 新手势/新一轮 fling 已接管，本轮不再吸附。
      if (!mounted || generation != _flingGeneration) return;
    }

    // ② 吸附段：spring(dampingRatio = 1, stiffness = 400) 到最近一格
    //    （临界阻尼 damping = 2·√(stiffness·mass) = 40）。
    var target = _offset.value.roundToDouble();
    if (!widget.wrapAround) {
      target = target.clamp(
        -_currentIndex.toDouble(),
        (_itemCount - 1 - _currentIndex).toDouble(),
      );
    }
    await _offset.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 400, damping: 40),
        _offset.value,
        target,
        0,
      ),
    );
    if (!mounted || generation != _flingGeneration) return;
    _commitSettledValue();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? MiuixNumberPickerDefaults.colors(context);
    final theme = MiuixTheme.of(context);
    final baseStyle = widget.textStyle ?? theme.textStyles.title1;
    final textStyle = baseStyle.copyWith(fontWeight: FontWeight.w600);
    final enabled = _effectiveEnabled;
    final selectedColor = colors.selectedTextColorFor(enabled);
    final unselectedColor = colors.unselectedTextColorFor(enabled);
    final totalHeight = widget.itemHeight * widget.visibleItemCount;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: enabled
          ? (_) {
              _flingGeneration++;
              _offset.stop();
              _isDragging = true;
              _isUserScrolling = true;
            }
          : null,
      onVerticalDragUpdate: enabled ? _onDragUpdate : null,
      onVerticalDragEnd: enabled ? _onDragEnd : null,
      child: SizedBox(
        height: totalHeight,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _offset,
            builder: (context, _) {
              final totalOffset = _offset.value;
              final centerItemOffset =
                  totalOffset - totalOffset.roundToDouble();
              final roundedOffset = totalOffset.round();

              return Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = -_halfVisible - 1; i <= _halfVisible + 1; i++)
                    _buildItem(
                      i: i,
                      currentIndex: _currentIndex,
                      roundedOffset: roundedOffset,
                      centerItemOffset: centerItemOffset,
                      textStyle: textStyle,
                      selectedColor: selectedColor,
                      unselectedColor: unselectedColor,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required int i,
    required int currentIndex,
    required int roundedOffset,
    required double centerItemOffset,
    required TextStyle textStyle,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    final rawItemIndex = currentIndex + i + roundedOffset;
    int itemIndex;
    if (widget.wrapAround) {
      itemIndex = ((rawItemIndex % _itemCount) + _itemCount) % _itemCount;
    } else {
      if (rawItemIndex < 0 || rawItemIndex >= _itemCount) {
        return const SizedBox.shrink();
      }
      itemIndex = rawItemIndex;
    }

    final distanceFromCenter = i.toDouble() - centerItemOffset;
    final normalizedDistance =
        (distanceFromCenter.abs() / (_halfVisible + 0.5)).clamp(0.0, 1.0);

    final alpha = (1.0 - normalizedDistance) * (1.0 - normalizedDistance * 0.5);
    final scale = 1.0 - 0.2 * normalizedDistance;
    final yOffset = distanceFromCenter * widget.itemHeight;

    final textColor =
        Color.lerp(selectedColor, unselectedColor, normalizedDistance)!;

    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: alpha,
          child: Text(
            _labelFor(widget.min + itemIndex),
            style: textStyle.copyWith(color: textColor),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
