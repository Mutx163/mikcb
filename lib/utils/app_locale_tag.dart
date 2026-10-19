/// 语言标签规范化（`zh-CN` / `en_US` → 应用内使用的短标签）。
///
/// 2026-10-19 从 `models/timetable_settings.dart` 抽出：这是纯字符串工具，
/// 不该占设置解析模块的体量，也不该让 models 层多背一个与本地化无关的函数。
library;

String normalizeAppLocaleTag(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty || normalized == 'system') {
    return '';
  }
  final canonical = normalized.replaceAll('-', '_');
  final lower = canonical.toLowerCase();
  if (lower == 'en_us') return 'en';
  if (lower == 'zh_cn') return 'zh';
  return canonical;
}

