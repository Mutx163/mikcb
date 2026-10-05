import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Returns the native name of a [locale] for display in language selectors.
///
/// Each language is shown in its own script (e.g. "English", "日本語",
/// "简体中文") so users can identify their language regardless of the
/// app's current UI language.
String nativeNameFor(Locale locale) {
  final tag = locale.countryCode?.isNotEmpty == true
      ? '${locale.languageCode}_${locale.countryCode}'
      : locale.languageCode;
  switch (tag) {
    case 'zh':
    case 'zh_CN':
      return '简体中文';
    case 'zh_HK':
      return '繁體中文（香港）';
    case 'zh_TW':
      return '繁體中文（台灣）';
    case 'en':
    case 'en_US':
      return 'English';
    case 'ja':
      return '日本語';
    case 'ko':
      return '한국어';
    default:
      return tag;
  }
}

/// 设置里存的 `appLocaleTag` → [Locale]；空串表示"跟随系统"，返回 null。
///
/// 从 `main.dart` 的私有 `_localeFromSettings` 原样搬来（逻辑一字未改），
/// 因为周报通知的正文也需要同一个映射：`_applyThemeWithUndo` 那类"UI 才有
/// context"的限制已经由 `lookupAppLocalizations` 解开（main.dart:460 早就这么
/// 取启动切换器标签的本地化了）。留在两处就会分叉 —— 本仓的钟点/写入规则
/// 已经反复证明"两份副本必有一份没跟着改"。
Locale? localeFromSettingsTag(String localeTag) {
  final normalized = localeTag.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final canonical = normalized.replaceAll('-', '_');
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.countryCode?.isNotEmpty == true
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    if (tag.toLowerCase() == canonical.toLowerCase()) {
      return locale;
    }
  }
  final languageCode = canonical.split('_').first.toLowerCase();
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode.toLowerCase() == languageCode) {
      return locale;
    }
  }
  return Locale(languageCode);
}
