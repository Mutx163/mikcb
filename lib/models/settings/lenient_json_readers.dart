/// JSON 容错读取（设置解析专用）。
///
/// 2026-10-19 从 `timetable_settings.dart` 抽出：该文件的 fromJson 里约 185 处
/// `json['x'] as String?` 这类硬转换，任一字段类型不符（手改备份 / 旧版本存档 /
/// 云同步 / 局域网传输包）都会抛 TypeError，冒到 `TimetableProfile.fromJsonLenient`
/// 的顶层 catch，把**整份**设置重置为 defaults。
///
/// 口径（与 2026-10-08 Course 容错、parseNestedObject 一致）：**有值就收，
/// 收不下按缺键处理（null）**，由调用方的 `?? 默认值` 兜底；绝不猜值 ——
/// bool 不认 '1'/1，字符串数字转 int/double 走 tryParse。
library;

List<String>? lenientStringList(dynamic raw) {
  if (raw is! List) return null;
  final out = <String>[];
  for (final item in raw) {
    if (item is String) out.add(item);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 下面是各字段类型的读取口径。
//
// 原 timetable_settings.dart 的 fromJson 此前大量使用 `json['x'] as String?` 这类硬转换：任一字段
// 类型不符（手改备份 / 旧版本存档 / 云同步 / 局域网传输包）都会抛 TypeError，
// 冒到 `TimetableProfile.fromJsonLenient` 的顶层 catch，把**整份**设置重置为
// defaults —— 学期起始日、节次表、主题、超级岛开关一起清零，再经
// `AppGlobalSettingsService.syncFrom` 扩散成设备级全局键。
//
// 口径（与 2026-10-08 Course 解析容错、d0d2cb1b / b0f3589f 的 parseNestedObject
// 口径一致）：**有值就收，收不下按缺键处理（null）**，由调用方的 `?? 默认值`
// 兜底；绝不猜值——bool 不认 '1'/1，字符串数字转 int/double 走 tryParse。
// 只在解析侧使用，toJson / copyWith / 构造函数不受影响，合法输入逐字节不变。
// ---------------------------------------------------------------------------

/// 有值就收：非字符串按 `toString()` 转（数字 1 → '1'，颜色/路径类字段常见
/// 的跨端类型漂移都能救回来）。null 原样返回。
String? lenientString(Object? v) => v is String ? v : v?.toString();

/// **不猜**：只有真 bool 与 'true' / 'false'（任意大小写）算数；
/// '1' / 1 / 0 都不是 bool，按缺键处理交给调用方默认值。
bool? lenientBool(Object? v) {
  if (v is bool) return v;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
  }
  return null;
}

/// int：数字直接收（double 会截断，2.7 → 2，等价于旧口径 `(num)?.toInt()`）；
/// 数字字符串走 `int.tryParse`（去首尾空白），'20.5' 这类解析失败按缺键。
int? lenientInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// double：数字直接收；数字字符串走 `double.tryParse`（去首尾空白）。
double? lenientDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// 列表：浅拷成 `List<Object?>`，元素类型错误留给下游逐项兜底；
/// 非 List 按缺键处理（旧代码的 `as List<Object?>?` 遇到 Map 会抛）。
List<Object?>? lenientList(Object? v) =>
    v is List ? List<Object?>.of(v) : null;

