import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 上帝单元（一个类/文件承担多个模块职责）的「总量」棘轮（2026-10-19 立）。
///
/// 旧棘轮只量主文件行数，于是「把代码搬进同库 part」就能让门禁变绿：
/// - `timetable_screen`：2026-10-10 拆分前 10,948 行；2026-10-19 先把 460 行
///   库级类拆到 `widgets/timetable/`，再把星期栏/浮钮/玻璃坞/日议程模型、
///   build 期 chrome 解析、顶栏 chrome、弹层/sheet 族、下拉药丸/情侣空闲摘要/
///   周页滚动壳、首页栈、周网格日列、周 pager、玻璃坞外壳、周页、周网格骨架、
///   首页下拉 surface、情侣日课表组装、日视图锚点展开壳与壁纸亮度采样控制器
///   时间格与下拉控制器拆出，主文件 4,057 + 两个 part 2,806 = 6,863 行；
///   build() 109 行。
/// - `timetable_provider`：主文件 4,362 + 10 个 part 3,479 = 7,841 行
///   （主题/考试/节假日/情侣/提醒族已抽到 `services/`）；
///   part 里仍有 573 处直接访问 `host._私有字段` —— 这是同一个类的 11 个抽屉，
///   不是 11 个模块。
///
/// 本守卫按「逻辑单元」计量（主文件 + 同族 part），并给 part 数量、provider
/// part 对宿主私有字段的访问数设上限。三者都只减不增。
///
/// 正当增长的处理顺序：先把这个功能域抽成独立 widget/service（真边界，不是新
/// part），做不到就先停下来讨论；不要抬基线换绿。
///
/// 与既有守卫的分工：
/// - `timetable_screen_size_guard_test.dart`：课表页主文件行数；
/// - `dependency_guards_test.dart`：provider 主文件行数、storage 行数等；
/// - 本文件：逻辑单元总量 + part 数量 + provider 分片的宿主私有访问数。
void main() {
  test('timetable_screen 逻辑单元总行数棘轮：只减不增', () {
    // 2026-10-19 晚：拆 models↔l10n 唯一真循环，主文件仅 +1 行 import
    // （course_week_localizations 的扩展），属换依赖方向而非功能增长，
    // 主文件与单元总量各 +1（9154 → 9155）已在提交信息说明。
    const baselineLines = 6863;
    const unit = [
      'lib/screens/timetable_screen.dart',
      'lib/screens/timetable_day_view_part.dart',
      'lib/screens/timetable_update_download_part.dart',
    ];
    final lines = unit.fold<int>(0, (sum, path) => sum + _lineCount(path));
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'timetable_screen 逻辑单元继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '新功能请放进独立 widget/controller；不要靠新增 part 摊薄主文件。',
    );

    final partCount = Directory('lib/screens')
        .listSync()
        .whereType<File>()
        .where(
          (f) => RegExp(
            r'timetable_.*_part\.dart$',
          ).hasMatch(f.path.replaceAll('\\', '/')),
        )
        .length;
    expect(
      partCount,
      lessThanOrEqualTo(2),
      reason:
          '课表页 part 数量涨到 $partCount（基线 2）。part 只作零行为搬迁的过渡，'
          '新拆分请直接产出独立 widget/controller。',
    );
  });

  test('timetable_provider 逻辑单元总行数棘轮：只减不增', () {
    const baselineLines = 7841;
    final parts = _providerParts();
    final lines =
        _lineCount('lib/providers/timetable_provider.dart') +
        parts.fold<int>(0, (sum, path) => sum + _lineCount(path));
    expect(
      parts.length,
      lessThanOrEqualTo(10),
      reason:
          'provider part 数量涨到 ${parts.length}（基线 10）。'
          '新功能请抽成独立 service，不要继续往 part 里摊。',
    );
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'timetable_provider 逻辑单元继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '先抽独立 service/仓储，再同步基线；不要靠新增 part 换绿。',
    );
  });

  test('provider 分片对宿主私有字段的访问棘轮：只减不增', () {
    const baselineHits = 573;
    final hostPrivateAccess = RegExp(r'host\._');
    var hits = 0;
    for (final path in _providerParts()) {
      hits += hostPrivateAccess.allMatches(File(path).readAsStringSync()).length;
    }
    expect(
      hits,
      lessThanOrEqualTo(baselineHits),
      reason:
          'provider part 对 `host._私有字段` 的访问涨到 $hits（基线 $baselineHits）。'
          '这个数不降，说明分片仍和宿主是同一个类；应把该功能域搬进带显式端口的 '
          'service，而不是继续加 part。',
    );
  });

  test('timetable_settings 逻辑单元行数棘轮：只减不增', () {
    const baselineMain = 2621;
    const baselineUnit = 3661;
    const unit = [
      'lib/models/timetable_settings.dart',
      'lib/models/settings/timetable_settings_enums.dart',
      'lib/models/settings/timetable_settings_extensions.dart',
      'lib/models/settings/timetable_settings_live.dart',
    ];
    final mainLines = _lineCount(unit.first);
    final unitLines = unit.fold<int>(0, (sum, path) => sum + _lineCount(path));
    expect(
      mainLines,
      lessThanOrEqualTo(baselineMain),
      reason:
          'timetable_settings.dart 继续膨胀（当前 $mainLines > 基线 $baselineMain）。'
          '新增设置项请拆到按功能域命名的文件；不要往主文件回堆。',
    );
    expect(
      unitLines,
      lessThanOrEqualTo(baselineUnit),
      reason:
          'settings 逻辑单元继续膨胀（当前 $unitLines > 基线 $baselineUnit）。'
          '2026-10-19 拆成主文件 + 3 个 settings/ 文件后总量 3,661（拆分前 3,639，'
          '+22 为文件头与 import）；此后只减不增。',
    );
  });

  test('warehouse 适配器登录页行数棘轮：只减不增', () {
    const baselineLines = 3621;
    final lines = _lineCount(
      'lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart',
    );
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'warehouse 适配器登录页继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '该页应把导入/登录/宏回放编排抽成 controller，WebView 生命周期留在 State。',
    );
  });

  test('timetable_settings screen 逻辑单元（设置域）总行数棘轮：只减不增', () {
    // 2026-10-19 立基线：设置页 screen 单元是全仓最大逻辑单元（主文件 1,458 +
    // 16 个 part 11,467 = 12,925，另有同目录独立文件 bing_wallpaper_gallery_page
    // 597），上帝单元棘轮落地时漏掉了它——当天只给 models 层立了
    // （timetable_settings 主文件/单元 2,621/3,661），页面层没有。
    // 「全仓 part 总数 28」挡得住第 17 个分身，挡不住现有 16 个任何一个长个。
    //
    // 口径 = 主文件 + lib/screens/settings/ 全部 dart 文件（13,522）。按目录计量
    // 而非「主文件 + part 名单」：后续把 16 个 part 逐个「转正」成独立库文件
    // 只改形态、不改读数（每文件新增的 import 头按仓库约定同步基线并说明）；
    // 只有真瘦身才让读数下降。16 个分身任何一个长个都会红。
    // 13522→13554：立棘采样后 gallery 页被并行提交 +32 行（他人合法改动），
    // 按测试约定同步真实值；本棘不改基线除非同步方说明。
    // 13554→13581：共享件出库（settings_shared.dart：两个 Miuix 设置行组件 +
    // 失败/拒绝提示 + 5 个 helper，16 个分身对宿主私有符号的引用 14→0），
    // 差值全为新文件头 + import + 文档注释，零行为搬迁，按约定同步真实值。
    // 13581→13621：外观簇转正——appearance_editor、home_backdrop_flow 两个
    // 分身转正为独立库，壁纸「最近使用」条抽出 settings_recent_wallpaper.dart；
    // mixin HomeBackdropFlow 的 6 个跨库成员转公开（库级私有可见性所致），
    // 差值仍为新文件头/import/文档，零行为搬迁。
    // 13621→13629：settings_reset.dart 转正为独立库（_SettingsResetTile 公开化
    // 为 SettingsResetTile，5 个分身引用点改公开名，两处测试补指向新库的
    // import），+8 全为文件头/import，零行为搬迁。
    const baselineLines = 13629;
    final domainFiles = <String>[
      'lib/screens/timetable_settings_screen.dart',
      ...Directory('lib/screens/settings')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path.replaceAll('\\', '/')),
    ];
    domainFiles.sort();
    expect(domainFiles.length, greaterThan(1), reason: '设置目录为空，棘已空转');
    final lines = domainFiles.fold<int>(0, (sum, path) => sum + _lineCount(path));
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          '设置域逻辑单元继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '这是全仓最大单元（主文件 + 16 个 part 分身）；新功能请放进独立文件'
          '并先做等量瘦身，不要抬基线换绿。',
    );

    // part 数量：只减不增，随「转正」逐格收紧（13 = reset 转正后余 13）。
    final settingsMain = File('lib/screens/timetable_settings_screen.dart');
    final partCount = RegExp(
      r"^part\s+'",
      multiLine: true,
    ).allMatches(settingsMain.readAsStringSync()).length;
    expect(
      partCount,
      lessThanOrEqualTo(13),
      reason:
          '设置页 part 数量涨到 $partCount（基线 16）。16 个分身将逐个转正为'
          '独立库文件；part 只作零行为搬迁的过渡，不要新增。',
    );
  });

  test('全仓 part 指令总数棘轮：只减不增', () {
    const baselineParts = 28;
    final partDirective = RegExp(r"^part\s+'", multiLine: true);
    var total = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      total += partDirective.allMatches(file.readAsStringSync()).length;
    }
    expect(
      total,
      lessThanOrEqualTo(baselineParts),
      reason:
          '全仓 part 指令涨到 $total（基线 $baselineParts）。'
          'part 是把同一个类摊到更多文件，不是模块边界；新拆分请产出独立类。',
    );
  });
}

int _lineCount(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path 不存在，棘已空转');
  return file.readAsLinesSync().length;
}

List<String> _providerParts() {
  final dir = Directory('lib/providers/timetable');
  expect(dir.existsSync(), isTrue, reason: 'provider part 目录不存在，棘已空转');
  final parts =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path.replaceAll('\\', '/'))
          .toList()
        ..sort();
  expect(parts, isNotEmpty, reason: 'provider part 列表为空，棘已空转');
  return parts;
}
