import 'package:flutter/material.dart';

/// Marks descendants as sitting on a frosted (blur + milky tint) panel.
///
/// Used by [HyperosButton] secondary fill so cancel / neutral actions stay
/// readable against glass instead of blending into white-on-white.
///
/// ## 为什么单独一个文件（2026-10-20）
///
/// 它原先住在 `hyperos_sheet.dart` 里。但它的使用者跨了三个方向：
/// `frosted_header_background`（判断本格是否浮在玻璃弹窗面板上）、
/// `miuix_bottom_sheet`、`widgets/adaptive_card`，以及 sheet 自己。
/// 其中 `frosted_header_background → hyperos_sheet` 这条**只为一个
/// InheritedWidget 而存在**的 import，和 `hyperos_sheet → frosted_header_background`
/// （要 `FrostedHeaderBackground`）正好互指，玻璃族的 2 节点环与 3 节点环
/// 都从这里过。
///
/// 抽出来之后两边都依赖这个叶子文件，互指消失。这不是「把一个类拆成两个
/// 互相转发的东西」——抽的是一整个**自包含的 InheritedWidget**（零依赖、
/// 零逻辑），两边用的是同一个类，没有多一层间接。
///
/// 原位置保留 re-export（`hyperos_sheet.dart` 里），既有 import 不受影响。
class HyperosFrostedPanelScope extends InheritedWidget {
  const HyperosFrostedPanelScope({required super.child, super.key});

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<HyperosFrostedPanelScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(covariant HyperosFrostedPanelScope oldWidget) {
    return false;
  }
}
