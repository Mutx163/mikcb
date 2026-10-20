import 'package:flutter/material.dart';

/// 一条页面路由描述符：路由目录（widgets 层）只认识「id + 怎么造这个页面」，
/// **不认识页面类型本身**。
///
/// 页面构造器由 screens 层在统一注册点注入（见
/// `screens/home_menu_route_registry.dart` 的 `kHomeMenuRouteRegistry`）。
/// 本文件因此不再 import 任何 `screens/*`：路由中心对页面的依赖从「编译期
/// 直接引用」变成「运行期查表」，`widgets → screens` 那条反向依赖边随之消失
/// （不是搬到免检目录藏起来，见泳道计划裁定 R1）。
///
/// 条目的**标题与图标**不在这里：它们绑着 l10n、住 `HomeMenuEntry`
/// （`home_menu_catalog.dart`），搬进路由表只会让同一份文案有两处真源。
class HomeMenuPageDescriptor {
  const HomeMenuPageDescriptor({required this.id, required this.build});

  /// 稳定 id。坞内嵌页沿用 `HomeMenuEntry.id` 的取值空间（见 `kHomeMenuCatalog`）；
  /// 目录页用 `xxxPage` 后缀，两套命名与迁移前逐字一致（持久化数据按 id 认人）。
  final String id;

  /// 页面构造器。统一**无参**：坞内嵌页与推入路由两种用法在注册时各包一层，
  /// 内嵌那份 `WidgetBuilder` 的 context 形参本来也没人用得上。
  final Widget Function() build;
}

/// 路由目录需要 screens 层提供的全部内容：两张页面表 + 更新入口的推入逻辑。
///
/// 做成一个对象而不是三个全局变量，是为了让注册点一眼看全「路由中心要什么」，
/// 且注册这件事只有一个函数、一次调用。
class HomeMenuRouteRegistry {
  const HomeMenuRouteRegistry({
    required this.inlineDockPages,
    required this.catalogPages,
    required this.pushUpdateEntry,
  });

  /// 底栏玻璃坞内嵌页：点选时不推新路由，在首页栈内切换内容区
  /// （玻璃坞保持悬浮，对齐旧「设置 Tab」的常驻体验）。
  final List<HomeMenuPageDescriptor> inlineDockPages;

  /// 八宫格/顶部菜单的目录页：点选时推入新路由。
  final List<HomeMenuPageDescriptor> catalogPages;

  /// 「软件更新」条目的推入逻辑（原 `pushHomeMenuUpdateEntry` 的本体）：
  /// 先取包信息、再进更新详情页，context 失活时静默放弃。
  final Future<void> Function(BuildContext context) pushUpdateEntry;
}

/// 已注入的路由表（screens 层在首页挂载时登记，见下方的注册函数）。
HomeMenuRouteRegistry? _registry;
Map<String, WidgetBuilder>? _inlinePages;
Map<String, Widget Function()>? _catalogPages;

/// 统一注册点：把 [registry] 装进来，并把两张描述符表摊成按 id 查的映射。
///
/// 调用点在 `screens/timetable_screen.dart` 的 `initState`（首页挂载，早于任何
/// 菜单/底栏渲染）。**必须早于取页**：未登记时 [homePage] / [kInlineDockPages]
/// 直接抛 StateError，而不是静默给空表——后者会让底栏内嵌页悄悄退化成推入
/// 路由，看起来只是「点一下就换了页面」，比直接报错难查得多。
///
/// 幂等：测试会在同一进程里多次挂首页，重复登记以最后一次为准。
void registerHomeMenuRoutes(HomeMenuRouteRegistry registry) {
  _registry = registry;
  // 设置首页 / 设置子页仍走 `registerSettingsPages` 那套依赖倒置（那个环
  // 2026-10 就拆过了，设置首页由 main() 登记），这里把它并进两张表，
  // 保持对外语义（`settings` / `settingsPage` 仍是可用条目）不变。
  _inlinePages = {
    'settings': (context) => _buildSettingsScreen(),
    for (final page in registry.inlineDockPages)
      page.id: (context) => page.build(),
  };
  _catalogPages = {
    'settingsPage': _buildSettingsScreen,
    for (final page in registry.catalogPages) page.id: page.build,
  };
}

/// 底栏内嵌页注册表：id → 页面构造器。
///
/// 这些 id 点选时不再推入新路由，而是在首页栈内切换内容区；未登记的 id
/// （表单类/需要上下文的流程页）仍走普通推入，见 [inlineDockPageFor]。
Map<String, WidgetBuilder> get kInlineDockPages {
  final pages = _inlinePages;
  if (pages == null) {
    throw StateError(
      'home_menu_route_catalog: 页面路由表尚未注册（registerHomeMenuRoutes）。'
      '生产侧由 TimetableScreen.initState 登记，早于任何菜单/底栏渲染；'
      '若在首页挂载之前就取页，请检查调用时序。',
    );
  }
  return pages;
}

/// id 对应的内嵌页构建器；未登记返回 null（调用方回退为推入路由）。
WidgetBuilder? inlineDockPageFor(String id) => kInlineDockPages[id];

/// 目录页构造器注册表：id → 页面实例。
Map<String, Widget Function()> get kHomeCatalogPages {
  final pages = _catalogPages;
  if (pages == null) {
    throw StateError(
      'home_menu_route_catalog: 页面路由表尚未注册（registerHomeMenuRoutes）。'
      '生产侧由 TimetableScreen.initState 登记，早于任何菜单渲染；'
      '若在首页挂载之前就取页，请检查调用时序。',
    );
  }
  return pages;
}

/// 按注册表 key 取目录页；key 必然存在（目录与注册表同步维护），
/// 缺失视为编程错误，抛出而不是静默返回 null。
Widget homePage(String key) {
  final builder = kHomeCatalogPages[key];
  if (builder == null) {
    throw StateError('home_menu_route_catalog: unknown page key "$key"');
  }
  return builder();
}

/// 「软件更新」条目的 open 逻辑：先取包信息再进更新详情页，
/// context 失活时静默放弃（本体在 screens 层的路由表里，见
/// [HomeMenuRouteRegistry.pushUpdateEntry]）。
Future<void> pushHomeMenuUpdateEntry(BuildContext context) {
  final registry = _registry;
  if (registry == null) {
    throw StateError(
      'home_menu_route_catalog: 页面路由表尚未注册（registerHomeMenuRoutes），'
      '无法打开软件更新页。',
    );
  }
  return registry.pushUpdateEntry(context);
}

/// 设置页注册表（依赖倒置）：timetable_settings_screen.dart 在库加载即
/// 登记设置首页构造器与私有子页工厂，八宫格/玻璃坞目录经此回调取页，
/// 避免本文件反向 import 设置页构成目录 ↔ 设置页的循环依赖。
Widget? Function(String id)? _settingsSubpageResolver;
Widget Function()? _settingsScreenBuilderOverride;

/// 由 timetable_settings_screen.dart 调用：登记设置首页构造器与子页工厂。
void registerSettingsPages({
  required Widget Function() settingsScreen,
  required Widget? Function(String id) subpageById,
}) {
  _settingsScreenBuilderOverride = settingsScreen;
  _settingsSubpageResolver = subpageById;
}

/// 按稳定 id 取设置库私有子页；未登记或未知 id 返回 null。
///（命名避开设置库公开的 settingsSubpageById，防止双 import 歧义。）
Widget? resolveSettingsSubpage(String id) => _settingsSubpageResolver?.call(id);

/// 取设置首页；未登记视为编程错误（main 未完成启动登记）。
Widget _buildSettingsScreen() {
  final builder = _settingsScreenBuilderOverride;
  if (builder == null) {
    throw StateError(
      'home_menu_route_catalog: settings screen not registered; '
      'main() must call registerSettingsPages at startup',
    );
  }
  return builder();
}
