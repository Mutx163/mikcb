import 'app_localizations.dart';

/// Maps persisted holiday display names to localized labels.
String localizedHolidayName(AppLocalizations l10n, String name) {
  return switch (name) {
    'holiday_name:makeup_workday' || '调休上班' => l10n.holidayMakeupWorkday,
    'holiday_name:new_year' || '元旦' => l10n.holidayNameNewYear,
    'holiday_name:labor_day' || '劳动节' => l10n.holidayNameLaborDay,
    'holiday_name:national_day' || '国庆节' => l10n.holidayNameNationalDay,
    'holiday_name:spring_festival' || '春节' => l10n.holidayNameSpringFestival,
    'holiday_name:qingming' || '清明节' => l10n.holidayNameQingming,
    'holiday_name:dragon_boat' || '端午节' => l10n.holidayNameDragonBoat,
    'holiday_name:mid_autumn' || '中秋节' => l10n.holidayNameMidAutumn,
    'holiday_name:statutory' || '法定假日' => l10n.holidayStatutoryLabel,
    _ => name,
  };
}
