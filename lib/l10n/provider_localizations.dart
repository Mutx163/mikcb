import 'package:flutter/material.dart';

import 'app_localizations.dart';

/// Resolves [AppLocalizations] from persisted [appLocaleTag] (provider / storage).
AppLocalizations providerLocalizations(String appLocaleTag) {
  return lookupAppLocalizations(_localeFromAppLocaleTag(appLocaleTag));
}

Locale _localeFromAppLocaleTag(String rawTag) {
  final normalized = rawTag.trim();
  if (normalized.isEmpty) {
    return const Locale('zh');
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
