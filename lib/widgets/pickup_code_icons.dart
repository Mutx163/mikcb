import 'package:flutter/material.dart';

/// 图标注册表：图标表达**功能**（出示码 / 查包裹），不表达品牌。
///
/// 为什么不对每个品牌各配一个图标：这仓可用的图标都在 Material 图标集里
/// （`Icons.inventory_2_outlined` 这种），没有淘宝 / 拼多多的官方图标；用
/// 近似的购物袋给四个平台各画一个，用户反而分不清谁是谁。改用「功能图标 +
/// 品牌色」两个维度：形状说明「这是出示码还是查包裹」，颜色说明「哪个平台」。
const Map<String, IconData> kPickupCodeIcons = <String, IconData>{
  'qrCode': Icons.qr_code_2_rounded,
  'parcel': Icons.inventory_2_rounded,
  'link': Icons.link_rounded,
};

/// 名字 → 图标；未知名字回落默认图标，不抛。
IconData pickupCodeIconFor(String name) {
  return kPickupCodeIcons[name] ?? kPickupCodeIcons['link']!;
}

/// 品牌色：按入口 id 取，**只用于图标与强调细节**，不刷整张卡片 ——
/// 多个平台各刷一种底色会变成调色盘，视觉上反而更乱。
///
/// 取色口径：各平台图标主色（菜鸟橙、淘宝橙红、拼多多红、京东枚红、抖音黑），
/// 同色系之间靠明度拉开，暗色模式整体提亮保对比度。
Color pickupCodeAccentFor(BuildContext context, String entryId) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final (Color light, Color dark) = switch (entryId) {
    'pickupCodePresetCainiao' => (
      const Color(0xFFF97316),
      const Color(0xFFFFA24D),
    ),
    'pickupCodePresetTaobao' => (
      const Color(0xFFEF4444),
      const Color(0xFFFF7A6E),
    ),
    'pickupCodePresetPinduoduo' => (
      const Color(0xFFDC2626),
      const Color(0xFFF87171),
    ),
    'pickupCodePresetJdParcels' => (
      const Color(0xFFE11D48),
      const Color(0xFFFB7185),
    ),
    'pickupCodePresetDouyinParcels' => (
      const Color(0xFF18181B),
      const Color(0xFFE4E4E7),
    ),
    _ => (const Color(0xFF3482FF), const Color(0xFF7EB0FF)),
  };
  return isDark ? dark : light;
}

/// 这条入口是「出示身份码」还是「查待取包裹」。
///
/// 这不只是图标选择：身份码与待取快递点进去是两个不同页面，用户需要在点之前
/// 就知道区别，所以界面上要有一行字说明。
bool pickupCodeIsIdentityCode(String iconName) => iconName == 'qrCode';
