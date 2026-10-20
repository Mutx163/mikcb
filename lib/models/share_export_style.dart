import 'package:flutter/material.dart';

/// 分享图（离屏导出）的固定视觉常量。
///
/// **这是业务规则，不是 UI 令牌。** 两个分享链路（课程统计长图、课表图片）
/// 都恒用亮色底：离屏捕获宿主采不到背后的内容，文档里的透明区域只能靠这个
/// 底色填实，否则分享出去的 PNG 上那些孔洞会变成黑块。
///
/// 它刻意**不**引用 `ui/hyperos/hyperos_tokens.dart` 的 `HyperosTokens.background`：
/// * 语义不同 —— 那是屏内的设置页灰底，这是「发到微信等外部浅底场景后仍然
///   看得清」的产物口径，将来主题或屏内灰度改版时两者没有理由一起动；
/// * 层向不同 —— 服务层（`services/*_share_service.dart`）要知道这个值，
///   而服务层不认识界面层（services → ui 是反向依赖）。
///
/// 值是用户可见产物的一部分：改它等于改分享出去的图。口径钉在
/// `test/models/share_export_style_test.dart`。
abstract final class ShareExportStyle {
  /// 分享图底色（必须不透明）。
  ///
  /// 与历史取值逐位相同（`0xFFF2F2F2`）——本次只是把它的家从 UI 令牌搬到
  /// 业务常量，像素不变。
  static const Color background = Color(0xFFF2F2F2);
}
