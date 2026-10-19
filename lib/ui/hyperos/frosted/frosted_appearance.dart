// 毛玻璃 / 液态玻璃外观的**注入层**：`FrostedAppearance` 值对象本体已下沉到
// models（`models/frosted_appearance.dart`，不依赖 material）。这里既 import
// （供本文件的 InheritedWidget 使用）又 export（保持既有调用点的 import 路径
// 不变）；本文件只留 `FrostedAppearanceScope`。
import 'package:flutter/material.dart';

import 'package:university_timetable/models/frosted_appearance.dart';

export 'package:university_timetable/models/frosted_appearance.dart';
/// Provides [FrostedAppearance] to frosted HyperOS widgets.
class FrostedAppearanceScope extends InheritedWidget {
  const FrostedAppearanceScope({
    required this.appearance,
    required super.child,
    super.key,
  });

  final FrostedAppearance appearance;

  static FrostedAppearance of(BuildContext context) {
    return maybeOf(context)?.appearance ?? FrostedAppearance.defaults;
  }

  static FrostedAppearanceScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FrostedAppearanceScope>();
  }

  /// Reads the scope **without** registering an inherited dependency.
  ///
  /// For callers that sit high in the tree (e.g. the page shell) and only need
  /// the current value as a paint hint — a tracked read there would rebuild the
  /// whole open page every time the user changes an appearance setting.
  static FrostedAppearanceScope? maybeOfUntracked(BuildContext context) {
    return context.getInheritedWidgetOfExactType<FrostedAppearanceScope>();
  }

  @override
  bool updateShouldNotify(covariant FrostedAppearanceScope oldWidget) {
    return appearance != oldWidget.appearance;
  }
}
