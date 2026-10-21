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

  test('MainActivity 真的注册了这条通道（名字对了但没注册，结果一样是「不支持」）', () {
    // 为什么这条单独存在：上面那条只比两处**字符串常量**。通道名对齐了，但如果
    // MainActivity 里没挂 MethodChannel、或者 object 改了名没跟着改调用点，
    // 运行期照样抛 MissingPluginException —— Dart 侧把它归成 `unsupported`，
    // 界面显示「当前平台不支持跳到其它应用」，看着像设备能力问题，实际是漏接线。
    final launcher = File(
      'android/app/src/main/kotlin/com/mutx163/qingyu/PickupCodeLauncher.kt',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/com/mutx163/qingyu/MainActivity.kt',
    ).readAsStringSync();
    // object 名从 Kotlin 文件里读出来，不在这里再写死一遍 —— 写死就是第三处
    // 需要人工同步的名字，正是这次出问题的方式。
    final objectMatch = RegExp(r'object\s+(\w+)\s*\{').firstMatch(launcher);
    expect(objectMatch, isNotNull, reason: 'PickupCodeLauncher.kt 里找不到 object 声明');
    final objectName = objectMatch!.group(1)!;
    expect(
      mainActivity.contains(', $objectName.CHANNEL)'),
      isTrue,
      reason: 'MainActivity 没有注册 $objectName.CHANNEL：'
          'Dart 侧每次调用都会抛 MissingPluginException，'
          '整页入口都会提示「当前平台不支持跳到其它应用」',
    );
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

  test('入口用横条列表，不是网格（奇偶不产生空格，也不会让某块显大）', () {
    final source = File('lib/screens/pickup_codes_screen.dart').readAsStringSync();
    // 不许出现网格/跨列：7 个入口排两列必然奇偶不均，跨列又会显得那块更重要
    // （用户原话：「显得你把拼多多放得比其他重要多了」）
    expect(
      RegExp(r'static const int columns').hasMatch(source),
      isFalse,
      reason: '不该再有「每行几列」的概念：入口是横条列表',
    );
    expect(
      source.contains('chunk.length == 1'),
      isFalse,
      reason: '不该再有「末砖跨两列」分支：那是网格时代的补洞手法',
    );
    expect(
      source.contains('SizedBox.shrink'),
      isFalse,
      reason: '列表布局不该有任何空占位符',
    );
    // 行高自适应（吃满屏幕，底部不许空旷），且留白从 scope 读
    expect(source.contains('LayoutBuilder'), isTrue);
    expect(
      source.contains('HyperosBlurredHeaderScope.insetOf(context)') &&
          source.contains('GlassDockScrollReliefScope.insetOf(context)'),
      isTrue,
      reason: '行高计算必须读 HyperosBlurredHeaderScope / '
              'GlassDockScrollReliefScope，不许手算头部高度',
    );
    expect(
      source.contains('minRowHeight') && source.contains('maxRowHeight'),
      isTrue,
      reason: '行高要有上下限：太薄不像能点的行，太厚在平板上变形',
    );
    // 滚动必须走 HyperosListView（裸 SingleChildScrollView 会漏头部留白）
    expect(
      RegExp(r'(?<!/// )SingleChildScrollView\(').hasMatch(source),
      isFalse,
      reason: '禁用裸 SingleChildScrollView：它会绕开大标题留白机制',
    );
    expect(source.contains('HyperosListView('), isTrue);
    // 每行等权：同一组里所有行用同一个高度常量，不许逐条差异
    expect(
      RegExp(r'SizedBox\(\s*height: rowHeight,').hasMatch(source),
      isTrue,
      reason: '所有行必须共用同一个 rowHeight，不能有「某条特别大」',
    );
    // 两张表都要登记（底栏内嵌 + 目录推入），缺一张就是「底栏消失」的回归
    final registry = File(
      'lib/screens/home_menu_route_registry.dart',
    ).readAsStringSync();
    expect(
      RegExp(r"_inlineDockPageDescriptors = \[[\s\S]*?id: 'pickupCode'").hasMatch(
        registry,
      ),
      isTrue,
      reason: '内嵌表里没有 pickupCode：底栏点它会推新页面、底栏消失',
    );
  });

  test('砖上的说明行必须是新信息（跳过去具体到哪），不许重复分组标题', () {
    final l10nZh = File('lib/l10n/app_zh.arb').readAsStringSync();
    final presets = File('lib/domain/pickup_code_presets.dart').readAsStringSync();
    // 每条预置都带 hint
    expect(
      RegExp(r"hint: 'pickupCodePreset\w+Hint',").allMatches(presets).length,
      7,
      reason: '7 条预置每条都要有 hint 键',
    );
    // 说明里不许出现「打开」「进入」这类动词开头 —— 那是重复分组标题的废话
    for (final key in const [
      'pickupCodePresetCainiaoHint',
      'pickupCodePresetTaobaoHint',
      'pickupCodePresetPinduoduoHint',
      'pickupCodePresetTaobaoParcelsHint',
      'pickupCodePresetPinduoduoParcelsHint',
      'pickupCodePresetJdParcelsHint',
      'pickupCodePresetDouyinParcelsHint',
    ]) {
      final match = RegExp('"$key": "([^"]*)"').firstMatch(l10nZh);
      expect(match, isNotNull, reason: '$key 缺失');
      final text = match!.group(1)!;
      expect(
        text.startsWith('打开') || text.startsWith('进入') || text.startsWith('查看'),
        isFalse,
        reason: '$key 的文案「$text」是重复分组标题的废话（用户点过名：灰字太多）',
      );
    }
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
