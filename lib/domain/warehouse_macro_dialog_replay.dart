/// 宏回放时，把录制下来的**选项文字**还原成脚本要的**序号**。
///
/// 录制与回放的契约在单选弹窗这里错位过：录制侧把用户选的那一项**按文字**存进宏
/// （这样宿主以后调整选项顺序也不会选错），回放侧却把这段文字原样喂回脚本；而上游
/// 协议里 `showSingleSelection` 回的是**序号**。脚本按序号解析时
/// `Number("2026-2027-1（当前学期）")` 得到 NaN，于是每个带单选弹窗的脚本在录制导入
/// 下都会在弹窗出现后立刻变成「导入已取消」——2026-09-29 在城科真机上复现：弹窗出现
/// 后 10 毫秒就返回了取消。
///
/// 三种回法都要认：
/// - **序号**（正常弹窗、后台自动回答）→ 原样用；
/// - **文字**（旧宏的回放）→ 在当前选项里找对应下标；
/// - 其它/找不到 → 用脚本给的 `selectedIndex`（它本来就是「默认选哪个」），
///   而不是弹窗或判成取消：录制的答案过期时退回脚本默认值，是用户能预期的行为；
///   判成取消则表现为「刚点确认就被取消」，用户完全不知道发生了什么。
///
/// 另有一处**必须小心**：文字相等的匹配不能用 `recorded == options[i]`，因为宿主在
/// 回放时可能把值包成字符串（`'$recorded'`），而 `0 == '0'` 在 Dart 里是 false。
/// 所以下标一律先 `int.tryParse` 再比。文字优先于下标：录下来的值本来就是文字，
/// 真有叫「3」的选项时它比下标 3 更可能是用户当时选的那一项。
int? resolveRecordedSelectionIndex({
  required Object? recorded,
  required List<String> options,
  required int fallbackIndex,
}) {
  final byText = _matchByText(recorded, options);
  if (byText != null) return byText;

  final byIndex = _matchByIndex(recorded, options.length);
  if (byIndex != null) return byIndex;

  if (fallbackIndex < 0 || fallbackIndex >= options.length) return null;
  return fallbackIndex;
}

int? _matchByText(Object? recorded, List<String> options) {
  if (recorded is! String) return null;
  final text = recorded.trim();
  if (text.isEmpty) return null;
  for (var i = 0; i < options.length; i++) {
    if (options[i] == text) return i;
  }
  return null;
}

int? _matchByIndex(Object? recorded, int length) {
  int? index;
  if (recorded is int) {
    index = recorded;
  } else if (recorded is num) {
    // 小数不是合法下标。
    if (recorded != recorded.roundToDouble()) return null;
    index = recorded.toInt();
  } else if (recorded is String) {
    // 宿主回放时可能把值包成字符串。必须 tryParse 后再比：`0 == '0'` 在 Dart 里是
    // false，直接比会漏掉这一路，静默掉到 fallbackIndex（答案被换掉而不自知）。
    index = int.tryParse(recorded.trim());
  }
  if (index == null || index < 0 || index >= length) return null;
  return index;
}
