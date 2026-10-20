import 'package:flutter/material.dart';

import '../models/campus_tool_entry.dart';

/// 入口图标注册表：**持久化里只存名字**，`IconData` 归 UI 层。
///
/// 为什么不对用户开放任意图标：图标名要能跨版本稳定、能进 JSON、且不依赖
/// `IconData` 的 tree-shake 例外配置（动态构造 `IconData` 会在 release 构建里
/// 被图标裁剪器抹掉，显示成方块）。这张小表就是「可用图标」的全部。
const Map<String, IconData> kCampusToolIcons = <String, IconData>{
  'parcel': Icons.inventory_2_outlined,
  'cainiao': Icons.local_shipping_outlined,
  'taobao': Icons.shopping_bag_outlined,
  'pinduoduo': Icons.storefront_outlined,
  'jd': Icons.local_mall_outlined,
  'douyin': Icons.music_note_outlined,
  'link': Icons.link_rounded,
  'wifi': Icons.wifi_rounded,
  'school': Icons.school_outlined,
  'card': Icons.badge_outlined,
  'library': Icons.local_library_outlined,
  'canteen': Icons.restaurant_outlined,
  'bus': Icons.directions_bus_outlined,
  'print': Icons.print_outlined,
  'sports': Icons.sports_basketball_outlined,
  'calendar': Icons.event_note_outlined,
};

/// 名字 → 图标；未知名字（旧版本 / 手改 JSON）回落默认图标，不抛。
IconData campusToolIconFor(String name) {
  return kCampusToolIcons[name] ??
      kCampusToolIcons[kCampusToolDefaultIconName] ??
      Icons.link_rounded;
}
