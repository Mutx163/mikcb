import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/qr_transfer_send_screen.dart';

import '../helpers_test_app.dart';

void main() {
  testWidgets('renders a worker-generated QR frame', (tester) async {
    final payload = Uint8List.fromList(
      List<int>.generate(700, (index) => (index * 41 + 7) & 0xff),
    );
    await tester.pumpWidget(
      TestApp(
        home: QrTransferSendScreen(payloadBytes: payload, title: 'Send backup'),
      ),
    );

    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.bySemanticsLabel('QR code').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.bySemanticsLabel('QR code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
