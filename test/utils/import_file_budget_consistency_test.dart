import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/ics_import_service.dart';
import 'package:university_timetable/services/spreadsheet_import_service.dart';
import 'package:university_timetable/services/unified_transfer_service.dart';

/// Every file the user can pick for import must agree on one size ceiling.
///
/// Divergent ceilings are worse than no ceiling at all: the same file is
/// accepted on one screen and rejected on another, and the user has no way to
/// tell which rule applied.
///
/// This exists because the ceiling was originally added to two entry points
/// and then missed on three more that had an identical shape
/// (`FilePicker` + `withData: true` + no limit) — the .ics picker, the couple
/// timetable import, and the debug-script picker. Adding a new picker will not
/// fail CI by itself, so the current set is pinned explicitly here; when a new
/// import path is added, extend this list.
void main() {
  test('日历 / 表格 / 备份 / 情侣课表用同一个 20MB 预算', () {
    const twentyMb = 20 * 1024 * 1024;
    expect(IcsImportService.maxFileBytes, twentyMb);
    expect(SpreadsheetImportService.maxFileBytes, twentyMb);
    expect(UnifiedTransferService.maxImportFileBytes, twentyMb);
  });

  test('每个上限都必须是正数且在合理量级（防止被改成 0 或 1）', () {
    for (final budget in <int>[
      IcsImportService.maxFileBytes,
      SpreadsheetImportService.maxFileBytes,
      UnifiedTransferService.maxImportFileBytes,
    ]) {
      expect(budget, greaterThan(0));
      expect(budget, lessThanOrEqualTo(1024 * 1024 * 1024));
    }
  });
}
