/// 顶栏（标题栏玻璃带）的模糊材质风格。
///
/// 两档都由 `inspire_blur` 的自定义 GPU shader 提供渐进（变量）模糊，
/// 区别只在过渡方向与作用范围：
///
/// - [gaussian]：经典「高斯模糊」档。整条玻璃带保持均匀强度，只在底边
///   留一小段渐隐收边（等价于过去的 `BackdropFilter` 均匀模糊观感），
///   向下滚动的内容从玻璃带下沿自然淡出。
/// - [inspire]：Inspire 渐进模糊档。模糊强度自顶边（状态栏）向下连续
///   衰减到 0，顶栏越靠上越朦胧、贴近内容处完全清晰——这是 iOS 系统栏
///   式的顶栏观感，也是本档的默认值。
///
/// 取值会写进设置（[value]），未知/缺失值一律回落到 [inspire]。
enum HeaderBlurStyle {
  /// 均匀强度 + 底边渐隐收边（经典高斯模糊观感）。
  gaussian,

  /// 自顶边向下连续衰减的渐进模糊（Inspire 档，默认）。
  inspire,
}

extension HeaderBlurStyleX on HeaderBlurStyle {
  String get value => name;

  static HeaderBlurStyle fromValue(String? value) {
    return HeaderBlurStyle.values.firstWhere(
      (item) => item.value == value,
      orElse: () => HeaderBlurStyle.inspire,
    );
  }
}
