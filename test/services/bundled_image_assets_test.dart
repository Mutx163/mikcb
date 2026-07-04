import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('branding and donate bitmaps are bundled', () async {
    for (final path in [
      'assets/branding/launcher_icon.png',
      'assets/donate/wechatpay.png',
      'assets/donate/alipay.png',
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(100), reason: path);
    }
  });
}
