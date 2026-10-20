/// 一条直达链接：URI 加上可选的限定目标应用包名。
///
/// 包名不是必填：`cainiao://` 这类私有 scheme 在多数机型上要靠 `setPackage`
/// 才不会被别的 App 抢走，而 https 兜底链接不需要限定。
class PickupCodeLink {
  const PickupCodeLink({required this.uri, this.package});

  /// 完整 URI（含 scheme 与 query）。
  final String uri;

  /// 限定投递的目标应用包名；null / 空串表示不限定。
  final String? package;
}

/// 校园小工具里的一条固定入口。
///
/// 结构照 QuickJump（github.com/chuhe0719/QuickJump）的多级回退：一串按顺序
/// 尝试的直达链接（[links]）、直达失败时只拉起官方 App 的包名（[appPackages]）、
/// 最后是网页兜底（[webUri]）。执行顺序见 `PickupCodeRunner`。
///
/// 本类是**只读数据**：入口由 `domain/pickup_code_presets.dart` 写死，界面不做
/// 增删改，因此不需要序列化、也不需要 id 之外的稳定键。
class PickupCodeEntry {
  const PickupCodeEntry({
    required this.id,
    required this.icon,
    required this.links,
    this.hint,
    this.appPackages = const <String>[],
    this.webUri,
    this.clearTask = false,
  });

  /// 稳定 id：标题与应用名按它反查 l10n（见 `l10n/pickup_code_localizer.dart`）。
  final String id;

  /// 图标注册名（见 `widgets/pickup_code_icons.dart`）。图标表达**功能**
  /// （身份码 / 待取），品牌色由界面按 id 赋，两者不混。
  final String icon;

  /// 砖上的说明键（l10n）：跳过去具体到哪。
  ///
  /// 必须是**新信息**（「驿站自提 / 快递柜」「淘宝的包裹列表」这种帮用户在几颗
  /// 砖之间做选择的内容），不许写「打开取件码」这类重复分组标题的废话 ——
  /// 用户明确说过灰字太多不简洁。null = 不显示说明行。
  final String? hint;

  final List<PickupCodeLink> links;
  final List<String> appPackages;

  /// 网页兜底链接（https / http）；null 表示没有兜底。
  final String? webUri;

  /// 是否强制新开目标页（FLAG_ACTIVITY_CLEAR_TASK）。
  ///
  /// QuickJump 用它修「淘宝在后台时跳不动」的机型；默认关闭。
  final bool clearTask;
}
