import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/bundled_assets.dart';

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

  test('启动预热包含 App 图标', () async {
    await BundledAssets.warmUp();

    expect(
      BundledAssets.bytesFor(BundledAssets.launcherIcon),
      isNotNull,
      reason: '图标没预热时品牌条首帧只是个占位盒（Image 不在树上），'
          '离屏出图只按固定帧数等待，等不到它 —— 分享图里的 logo 就是空白。',
    );
  });
}
