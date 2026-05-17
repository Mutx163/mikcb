import 'package:flutter/material.dart';

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