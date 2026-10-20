import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 首页入口 ↔ 路由表的接线契约（**静态源码检查**）。
///
/// 为什么不用 widget 测试跑一遍「点开页面」：
/// 1. 按 TEST-POLICY，`test/widgets` / `test/screens` / `test/ui` 是冻结目录，
///    新的 UI 层测试不再新增；
/// 2. 更实际的原因：这两张表是**两个文件里的字符串**，id 对不上时
///    `homePage()` 会在点开那一刻抛 `StateError`（启动不炸、测试全绿、真机一
///    点就崩）。而 import 整棵页面树去做这件事，在共享工作区里会被别的会话
///    的在途改动顶到编译失败 —— 一个只该看两个文件字符串的检查，不该背上
///    整个 App 的编译面。
///
/// 口径：只认「目录里有 pickupCode 条目」+「路由表里有 pickupCodePage 且
/// 指向 PickupCodesScreen」。条目被删/改名时立刻红，且原因写得出来。
void main() {
  final catalogFile = File('lib/widgets/home_menu_catalog.dart');
  final registryFile = File('lib/screens/home_menu_route_registry.dart');

  test('两个接线文件都在（否则本测试空转）', () {
    expect(catalogFile.existsSync(), isTrue, reason: catalogFile.path);
    expect(registryFile.existsSync(), isTrue, reason: registryFile.path);
  });

  test('八宫格目录里有 pickupCode 条目，标题走 l10n、打开 pickupCodePage', () {
    final source = catalogFile.readAsStringSync();
    expect(
      source.contains("id: 'pickupCode'"),
      isTrue,
      reason: '目录里没有 id: pickupCode —— 用户永远看不到这个入口',
    );
    expect(
      source.contains("homePage('pickupCodePage')"),
      isTrue,
      reason: '条目没有指向 pickupCodePage（点开会在 homePage 抛 StateError）',
    );
    expect(
      source.contains('pickupCodeEntryTitle'),
      isTrue,
      reason: '标题必须走 l10n（硬编码中文会被 CJK 审计拦下）',
    );
  });

  test('路由表登记了 pickupCodePage → PickupCodesScreen', () {
    final source = registryFile.readAsStringSync();
    expect(source.contains("id: 'pickupCodePage'"), isTrue);
    expect(
      source.contains('PickupCodesScreen()'),
      isTrue,
      reason: '描述符的 build 没有造 PickupCodesScreen',
    );
    expect(
      source.contains("import 'pickup_codes_screen.dart';"),
      isTrue,
      reason: '路由表缺 import，build 会编译不过',
    );
  });

  test('页面文件与命令行通道名两侧一致（Dart 常量 ↔ Kotlin CHANNEL）', () {
    final dart = File('lib/services/pickup_code_launcher.dart').readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/mutx163/qingyu/PickupCodeLauncher.kt',
    ).readAsStringSync();
    const channel = 'com.mutx163.qingyu/pickup_code';
    expect(dart.contains("'$channel'"), isTrue, reason: 'Dart 侧通道名漂了');
    expect(kotlin.contains('"$channel"'), isTrue, reason: 'Kotlin 侧通道名漂了');
  });

  test('manifest 的 <queries> 覆盖了全部预置包名与 scheme', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    // 与 lib/domain/pickup_code_presets.dart 的数据表对应：这些是 Android 11+
    // 判断「装没装 / 有没有 App 接」的前提，漏一个就是体检里的一个假 ✗。
    const packages = <String>[
      'com.cainiao.wireless',
      'com.taobao.taobao',
      'com.xunmeng.pinduoduo',
      'com.jingdong.app.mall',
      'com.ss.android.ugc.aweme',
      'com.ss.android.ugc.aweme.lite',
    ];
    const schemes = <String>[
      'cainiao',
      'taobao',
      'tbopen',
      'pinduoduo',
      'openjd',
      'snssdk1128',
      'snssdk2329',
    ];
    for (final package in packages) {
      expect(
        manifest.contains('<package android:name="$package" />'),
        isTrue,
        reason: 'manifest <queries> 缺包名 $package（Android 11+ 查不到已安装）',
      );
    }
    for (final scheme in schemes) {
      expect(
        manifest.contains('<data android:scheme="$scheme" />'),
        isTrue,
        reason: 'manifest <queries> 缺 scheme $scheme（queryIntentActivities 永远为空）',
      );
    }
  });

  test('页面固定四列（两组格子宽度必须一致）', () {
    final source = File('lib/screens/pickup_codes_screen.dart').readAsStringSync();
    expect(
      source.contains('static const int _columns = 4;'),
      isTrue,
      reason: '列数必须写死：按「有几个分几列」会让两组格子宽度差 30%',
    );
    // 不许按 entries.length 分列（那就是「有几个几列」的写法）
    expect(
      RegExp(r'Expanded\(\s*child:\s*_PickupCodeTile').hasMatch(source),
      isFalse,
      reason: '砖必须包在固定列数的 Row 里，不能直接铺成一行 N 个',
    );
  });

  test('没装的入口在界面上有明确状态，不是静默失败', () {
    final source = File('lib/screens/pickup_codes_screen.dart').readAsStringSync();
    // 进页面就批量查一次，而不是点了才逐个试
    expect(source.contains('installedPackages('), isTrue);
    expect(source.contains('_loadInstalledPackages'), isTrue);
    // 砖上有 missing 态（弱化 + 语义标签）
    expect(source.contains('missing:'), isTrue);
    expect(source.contains('pickupCodeSemanticsNotInstalled'), isTrue);
  });

  test('每个砖都带无障碍语义标签（分组名 + 平台名）', () {
    final source = File('lib/screens/pickup_codes_screen.dart').readAsStringSync();
    expect(
      source.contains('Semantics('),
      isTrue,
      reason: '砖必须有 Semantics，否则读屏只念「菜鸟 按钮」',
    );
    expect(source.contains('pickupCodeSemanticsEntry'), isTrue);
    expect(source.contains('button: true'), isTrue);
  });

  test('点击有触觉反馈，且跟随设置开关', () {
    final source = File('lib/screens/pickup_codes_screen.dart').readAsStringSync();
    expect(source.contains('HapticFeedback.selectionClick'), isTrue);
    expect(
      source.contains('enableHaptics'),
      isTrue,
      reason: '必须读设置里的开关，不能无条件震',
    );
  });

  test('失败提示带「链接可能失效」的引导，不是干巴巴一句打不开', () {
    final source = File('lib/screens/pickup_codes_screen.dart').readAsStringSync();
    expect(source.contains('pickupCodeLaunchFailedHint'), isTrue);
  });

  test('分组标题下不再叠加额外间距（SectionLabel 自带 8dp）', () {
    final source = File('lib/screens/pickup_codes_screen.dart').readAsStringSync();
    final pattern = RegExp(
      r'HyperosSectionLabel\(text: l10n\.pickupCode\w+SectionTitle\),\s*\n\s*const SizedBox',
    );
    expect(
      pattern.hasMatch(source),
      isFalse,
      reason: 'HyperosSectionLabel 已带 bottom: 8，再叠 SizedBox 会比其它页疏',
    );
  });
}
