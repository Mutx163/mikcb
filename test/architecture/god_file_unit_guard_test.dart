import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guard_source.dart';

/// 上帝单元（一个类/文件承担多个模块职责）的「总量」棘轮（2026-10-19 立）。
///
/// 旧棘轮只量主文件行数，于是「把代码搬进同库 part」就能让门禁变绿：
/// - `timetable_screen`：2026-10-10 拆分前 10,948 行；2026-10-19 先把 460 行
///   库级类拆到 `widgets/timetable/`，再把星期栏/浮钮/玻璃坞/日议程模型、
///   build 期 chrome 解析、顶栏 chrome、弹层/sheet 族、下拉药丸/情侣空闲摘要/
///   周页滚动壳、首页栈、周网格日列、周 pager、玻璃坞外壳、周页、周网格骨架、
///   首页下拉 surface、情侣日课表组装、日视图锚点展开壳与壁纸亮度采样控制器
///   时间格、下拉/更新检查/空白槽控制器、日课表条目组装、分组圆角、玻璃坞
///   动作、标题触发器、动作页按钮、墨色守卫与新增弹层拆出，update part 转独立
///   库、周网格/首页栈装配拆出、日视图视图族再外移、布局纯函数下沉、日转场/周 pager/顶栏菜单控制器拆出；主文件 1,844 + day part 942 = 2,786 行；build() 114 行。
/// - `timetable_provider`：拆分前主文件 4,362 + 10 个 part 3,479 = 7,841 行
///   （主题/考试/节假日/情侣/提醒族已抽到 `services/`）；
///   part 里当时有 573 处直接访问 `host._私有字段` —— 那是同一个类的 11 个抽屉，
///   不是 11 个模块。拆分那一轮收尾后 part 归零、主文件 3,837 行，逻辑单元与
///   主文件同值，`host._` 访问数归零（每个抽屉都变成了带显式端口的 service）。
///
/// **注意本守卫的盲区**（2026-10-20 复核确认）：逻辑单元只量 `lib/providers/`，
/// 实现搬到 `lib/services/` 就落在计量之外。因此「单元行数下降」不等于「代码变少」，
/// 那一轮全仓实为净增 1,545 行。这条棘轮只防「往 provider 里继续堆」，
/// **不能当解耦或减重的成绩单**。
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
    const baselineLines = 2786;
    const unit = [
      'lib/screens/timetable_screen.dart',
      'lib/screens/timetable_day_view_part.dart',
    ];
    final lines = unit.fold<int>(0, (sum, path) => sum + _lineCount(path));
    expect(
      lines,
      lessThanOrEqualTo(baselineLines),
      reason:
          'timetable_screen 逻辑单元继续膨胀（当前 $lines > 基线 $baselineLines）。'
          '新功能请放进独立 widget/controller；不要靠新增 part 摊薄主文件。',
    );

    final partCount = Directory(GuardSource.resolve('lib/screens'))
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
      lessThanOrEqualTo(1),
      reason:
          '课表页 part 数量涨到 $partCount（基线 1）。part 只作零行为搬迁的过渡，'
          '新拆分请直接产出独立 widget/controller。',
    );
  });

  test('timetable_provider 逻辑单元总行数棘轮：只减不增', () {
    // 7841→6879：解耦方案 A 的 K1/K3/F1/F2 四刀把「写入管线」「日程项」「地点规则」
    // 三族实现整体搬到 `lib/services/`（含端口与假端口单测），逻辑单元缩小 962 行。
    // 6879→6440：F3 把课程/作业族（`TimetableCourseService`）也搬走，分片删一个。
    // 6440→6262：F4 把课程组（同名多课次）那 178 行并进同一个服务，分片再删一个.
    // 6262→5956：F5 作息族（TimetableTimeSchemeService）出库，分片再删一个。
    // 5956→5771：F6 日期规则批量套用出库，分片再删一个。
    // 5771→4616：F7 实时活动族（`TimetableLiveActivityService`）出库 —— 1149 行分片
    // 清零，主库只长出端口接线（净 +17），逻辑单元整体回落 1155 行。
    // 4616→3837：F8 导入导出族（`TimetableImportExportService`）出库 —— 最后一个
    // 分片删除，`lib/providers/timetable/` 目录随之消失，逻辑单元 = 主文件。
    // 基线取**已提交快照**的实测值；提交当日工作区若有并行会话在途的修改，
    // 实测会略高于基线——棘轮只衡量已落库的代码。
    const baselineLines = 3837;
    final parts = _providerParts();
    final lines =
        _lineCount('lib/providers/timetable_provider.dart') +
        parts.fold<int>(0, (sum, path) => sum + _lineCount(path));
    // 分片归零是「provider 按文件拆开」这件事的完成判据：上限 0 = 不允许再建 part。
    // 它**只证明文件被切开了**，不证明状态与实现已分离（见文件头盲区说明）。
    // 目录被重新建出来时 `_providerParts()` 会读到非空列表，这里直接红。
    expect(
      parts,
      isEmpty,
      reason:
          'provider part 数量涨到 ${parts.length}（基线 0）。'
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
    // 573→529：F1/F2 两族出库后，日程项与地点规则相关的 `host._` 访问直接消失
    // （实现已搬到 `lib/services/`，适配器在主库）；K1/K3 的写入管线同样如此。
    // 529→454：F3 课程/作业族出库，写作纪律那几段（含作业重算）整体搬走。
    // 454→402：F4 课程组整组写入口并入同一个服务。
    // 402→326：F5 作息族出库。
    // 326→291：F6 日期规则批量套用出库。
    // 291→181：F7 实时活动族出库；这一族原本整片都是 `host._私有字段`（`_settings`
    // 26 处、`_holidayData` 8 处、两份信号签名与心跳各自一串），搬进服务后端口成员
    // 是显式的，分片里只剩导入导出那一个 part 的读数。
    // 181→0：F8 导入导出族出库，最后一个分片删除 —— 分片归零，这个数随之归零。
    // 注意：`extension on TimetableProvider` 里的成员不写 `host.`，不进本棘轮数字，
    // F2 就因此少算了若干处；后续以「part 归零」为准，这个数字只作兜底。
    const baselineHits = 0;
    final hostPrivateAccess = RegExp(r'host\._');
    var hits = 0;
    for (final path in _providerParts()) {
      hits += hostPrivateAccess
          .allMatches(File(GuardSource.resolve(path)).readAsStringSync())
          .length;
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
    // 2621→2633 / 3661→3673：周网格「考试/日程卡」两个开关
    // （weekGridShowExams / weekGridShowSchedules，2026-10-20）入主文件——
    // 字段声明 / 构造默认 / toJson / fromJson / copyWith 五处 +12 行，
    // 是同一个类的必要增长（TimetableSettings 的字段无法拆出类外，
    // settings/ 下只放枚举与扩展）；提交信息同步说明。
    const baselineMain = 2633;
    const baselineUnit = 3673;
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
    // 13629→13639：settings_weather.dart 转正为独立库（_WeatherSettingsScreen
    // 公开化为 WeatherSettingsScreen，主文件两处 push 点改公开名），
    // +10 全为文件头/import，零行为搬迁。
    // 13639→13650：settings_general.dart 转正（_GeneralSettingsScreen 公开化），
    // buildLocaleMenuMap 随之从 appearance 分身搬入 settings_shared（general
    // 转正后跨库取用），+11 全为文件头/import/文档，零行为搬迁。
    // 13650→13660：settings_diagnostics.dart 转正（_DiagnosticsScreen 公开化），
    // +10 全为文件头/import，零行为搬迁。
    // 13660→13668：settings_holiday.dart 转正（HolidaySettingsScreen/
    // HolidayAdvancedSettingsScreen 公开化），差值全为文件头/import，零行为搬迁。
    // 13668→13680：settings_live.dart 转正（LiveSettingsScreen/
    // LiveTestingSettingsScreen 公开化），差值全为文件头/import，零行为搬迁。
    // 13680→13690：settings_home_widget.dart 转正（HomeWidgetSettingsScreen
    // 公开化），差值全为文件头/import，零行为搬迁。
    // 13690→13703：settings_timetable_page.dart 转正（TimetablePageSettingsScreen
    // 公开化），差值全为文件头/import，零行为搬迁。
    // 13703→13713：settings_appearance.dart 转正（AppearanceSettingsScreen/
    // ThemeManageScreen 公开化，_HomeTitleStylePreview 随 home_navigation 的
    // 使用改公开 HomeTitleStylePreview），差值全为文件头/import，零行为搬迁。
    // 13713→13724：settings_course_card.dart 转正（CourseCardSettingsScreen
    // 公开化），差值全为文件头/import，零行为搬迁。
    // 13724→13731：glass_dock_editor / glass_dock_icon_editor 两分身同批转正
    // （GlassDockEditorScreen / GlassDockIconPickerScreen 公开化），差值全为
    // 文件头/import，零行为搬迁。
    // 13731→13735：settings_home_menu_editor.dart 转正（HomeGridMenuEditorScreen
    // 公开化），差值全为文件头/import，零行为搬迁。
    // 13735→13743：settings_home_navigation.dart 转正（HomeNavigationSettingsScreen
    // 公开化）——设置域 16 个分身全部转正完毕，设置页 part 数上限收到 0；
    // 全仓 part 总数 28→11（剩 provider 10 + 课表页 2）。
    // 13743→13764：周网格「考试/日程卡」两个开关（2026-10-20）入课表页面
    // 设置的「行列与密度」组（两行 HyperosSwitchTile + 注释 +19 行）+
    // settings_reset.dart 的 timetablePage 作用域 +2——用户可见的功能增长，
    // 两行开关抽成独立文件属过度碎片化；提交信息同步说明。
    const baselineLines = 13764;
    final domainFiles = <String>[
      'lib/screens/timetable_settings_screen.dart',
      ...Directory(GuardSource.resolve('lib/screens/settings'))
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

    // part 数量：设置域 16 个分身已全部转正，上限 0 = 不允许任何新增。
    final settingsMain = File(
      GuardSource.resolve('lib/screens/timetable_settings_screen.dart'),
    );
    final partCount = RegExp(
      r"^part\s+'",
      multiLine: true,
    ).allMatches(settingsMain.readAsStringSync()).length;
    expect(
      partCount,
      lessThanOrEqualTo(0),
      reason:
          '设置页 part 数量涨到 $partCount（基线 16）。16 个分身将逐个转正为'
          '独立库文件；part 只作零行为搬迁的过渡，不要新增。',
    );
  });

  test('全仓 part 指令总数棘轮：只减不增', () {
    // 11→1：解耦方案 A 收尾，`lib/providers/timetable/` 的 10 个分片全部转成
    // `lib/services/timetable_*_service.dart`；只剩课表页那 1 个 part。
    const baselineParts = 1;
    final partDirective = RegExp(r"^part\s+'", multiLine: true);
    var total = 0;
    for (final file in Directory(GuardSource.resolve('lib')).listSync(
      recursive: true,
    )) {
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
  final file = File(GuardSource.resolve(path));
  expect(file.existsSync(), isTrue, reason: '$path 不存在，棘已空转');
  return file.readAsLinesSync().length;
}

List<String> _providerParts() {
  final dir = Directory(GuardSource.resolve('lib/providers/timetable'));
  // F8 之后该目录应不存在（分片归零是解耦方案的完成判据）。目录缺失 = 0 个分片，
  // 这是合法终态；若目录被重新建出来并放了 part，下面的列表非空会让棘轮红。
  if (!dir.existsSync()) {
    return const <String>[];
  }
  final parts =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path.replaceAll('\\', '/'))
          .toList()
        ..sort();
  return parts;
}
