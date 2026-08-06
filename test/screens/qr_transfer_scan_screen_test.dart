import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/qr_transfer_scan_screen.dart';

void main() {
  test(
    'maps adjacency edge budget failures to the same resource error key',
    () {
      expect(
        qrTransferErrorKeyFor('qr_transfer_adjacency_edge_budget_exceeded'),
        'qr_transfer_adjacency_edge_budget_exceeded',
      );
    },
  );
}
