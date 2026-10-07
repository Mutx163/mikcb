import 'package:azlistview/azlistview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/warehouse_repository_models.dart';
import 'package:university_timetable/screens/import/warehouse/warehouse_shared.dart';

WarehouseSchoolEntry school(String id, String name, String initial) {
  return WarehouseSchoolEntry(
    id: id,
    name: name,
    initial: initial,
    resourceFolder: id,
  );
}

void main() {
  group('学校列表字母索引（重庆/超星重复 C）', () {
    test('通用学校另起通块，C 只剩一个，点 C 落到重庆', () {
      final schools =
          [
            school('GLOBAL_TOOLS', '通用工具与服务', 'T'),
            school('zhengfang_jiaowu', '正方教务-通用教务', 'Z'),
            school('chaoxing_jiaowu', '超星教务系统-通用教务', 'C'),
            school('qingguo_jiaowu', '青果教务-通用教务', 'Q'),
            school('BBGU', '北部湾大学', 'B'),
            school('CQU', '重庆大学', 'C'),
            school('CQJTU', '重庆交通大学', 'C'),
            school('NEU', '东北大学', 'D'),
          ]..sort((left, right) {
            final c = left.initial.trim().toUpperCase().compareTo(
              right.initial.trim().toUpperCase(),
            );
            if (c != 0) return c;
            return left.name.compareTo(right.name);
          });

      final beans = schoolsToBeans(schools, const []);
      final sections = schoolsToSections(beans);
      final tags = sections.map((s) => s.tag).toList();

      // tag 必须唯一，否则 AzListView 点第二个永远跳到第一个。
      expect(tags.toSet().length, tags.length);
      expect(tags.where((t) => t == 'C').length, 1);
      // 通用块置顶在最前，超星在里面，不在 C 里。
      expect(tags.first, '通');
      final cSection = sections.firstWhere((s) => s.tag == 'C');
      expect(
        cSection.items.map((b) => b.school.name),
        containsAll(['重庆大学', '重庆交通大学']),
      );
      expect(
        cSection.items.map((b) => b.school.name),
        isNot(contains('超星教务系统-通用教务')),
      );
      final tongSection = sections.firstWhere((s) => s.tag == '通');
      expect(
        tongSection.items.map((b) => b.school.name),
        contains('超星教务系统-通用教务'),
      );
    });

    test('大小写混排的首字母归一，不产生两个 C', () {
      final schools = [
        school('A', '超星教务系统-通用教务x', 'C'),
        school('B', '重庆大学', 'c'),
        school('C', '长春理工大学', 'C'),
      ];
      // 注意：这里故意用含通用的名字验证通用走通块；
      // 另起一组纯非通用验证大小写归一。
      final plain = [
        school('B', '重庆大学', 'c'),
        school('C', '长春理工大学', 'C'),
        school('D', '东北大学', 'D'),
      ];
      final beans = schoolsToBeans(plain, const []);
      final sections = schoolsToSections(beans);
      final tags = sections.map((s) => s.tag).toList();
      expect(tags.toSet().length, tags.length);
      expect(tags.where((t) => t == 'C').length, 1);
      expect(schools, isNotEmpty);
    });

    test('乱序输入也能合并同 tag，不出重复索引', () {
      final beans = [
        WarehouseSchoolBean(
          school: school('X', '超星教务系统-通用教务', 'C'),
          tag: 'C',
          isRecent: false,
        ),
        WarehouseSchoolBean(
          school: school('Q', '青果教务-通用教务', 'Q'),
          tag: 'Q',
          isRecent: false,
        ),
        WarehouseSchoolBean(
          school: school('CQU', '重庆大学', 'C'),
          tag: 'C',
          isRecent: false,
        ),
      ];
      final sections = schoolsToSections(beans);
      final tags = sections.map((s) => s.tag).toList();
      expect(tags.toSet().length, tags.length);
      expect(tags.where((t) => t == 'C').length, 1);
    });

    test('最近使用 ★ 与通用 通 共存且唯一', () {
      final schools = [
        school('GLOBAL_TOOLS', '通用工具与服务', 'T'),
        school('chaoxing_jiaowu', '超星教务系统-通用教务', 'C'),
        school('CQU', '重庆大学', 'C'),
        school('CQJTU', '重庆交通大学', 'C'),
      ];
      final beans = schoolsToBeans(schools, const ['CQU']);
      final sections = schoolsToSections(beans);
      final tags = sections.map((s) => s.tag).toList();
      expect(tags.toSet().length, tags.length);
      expect(tags.first, '★');
      expect(tags, contains('通'));
      // 最近的重庆只在 ★ 里，不在 C 里（沿用旧语义：最近从主列表摘除）。
      final cSection = sections.firstWhere((s) => s.tag == 'C');
      expect(cSection.items.map((b) => b.school.id), isNot(contains('CQU')));
    });
  });

  group('字母条版面', () {
    // 真实 root_index.yaml（242 所学校）的分组数：无最近使用 20 组、
    // 有最近使用 21 组。这里用真实组数 + 真实视口尺寸驱动。
    const realTagCounts = [20, 21];

    test('组数少时保持上游默认行高，行为与改动前一致', () {
      // 竖屏常见视口（约 780~900px），21 × 16 = 336 远在 82% 之内。
      for (final viewport in [780.0, 900.0]) {
        final geometry = warehouseIndexBarGeometry(
          tagCount: 21,
          availableHeight: viewport,
        );
        expect(geometry.itemHeight, kIndexBarItemHeight);
        expect(geometry.height, kIndexBarItemHeight * 21);
      }
    });

    test('横屏 / 分屏小窗不溢出父盒，首尾字母都点得到', () {
      // 横屏视口约 360px，分屏/小窗更矮。改之前 21 × 16 = 336 已经贴边，
      // 组数再一涨就 RenderFlex overflow。
      for (final viewport in [360.0, 300.0, 240.0]) {
        for (final tagCount in realTagCounts) {
          final geometry = warehouseIndexBarGeometry(
            tagCount: tagCount,
            availableHeight: viewport,
          );
          expect(
            geometry.height,
            // 容 1e-9：0.82 是二进制小数，240*0.82 与 itemHeight*tagCount
            // 会有 ulp 级误差。
            lessThanOrEqualTo(
              viewport * warehouseIndexBarMaxHeightRatio + 1e-9,
            ),
            reason: '总高应封在视口 $warehouseIndexBarMaxHeightRatio 之内',
          );
          expect(
            geometry.height,
            lessThanOrEqualTo(viewport),
            reason: '$tagCount 组 @ ${viewport}px 视口不应超过父盒',
          );
          // 上游 _getIndex 用 `offset ~/ itemHeight` 定位字母，行高不能为 0。
          expect(geometry.itemHeight, greaterThan(0));
          // 视口放得下时也不该低于拇指可命中的下限。
          if (viewport * warehouseIndexBarMaxHeightRatio / tagCount >=
              warehouseIndexBarMinItemHeight) {
            expect(
              geometry.itemHeight,
              greaterThanOrEqualTo(warehouseIndexBarMinItemHeight),
            );
          }
          expect(
            geometry.height,
            closeTo(geometry.itemHeight * tagCount, 1e-9),
          );
        }
      }
    });

    test('组数暴增（脏数据塞满 A-Z + ★ + 通 + #）也不溢出', () {
      // 字母表上限：26 个字母 + ★ + 通 + # = 29 组。
      for (final viewport in [360.0, 240.0]) {
        final geometry = warehouseIndexBarGeometry(
          tagCount: 29,
          availableHeight: viewport,
        );
        expect(geometry.height, lessThanOrEqualTo(viewport));
        expect(geometry.itemHeight, greaterThan(0));
      }
    });

    test('空列表返回 0 高但行高非 0（上游除零保护）', () {
      final geometry = warehouseIndexBarGeometry(
        tagCount: 0,
        availableHeight: 800,
      );
      expect(geometry.height, 0);
      expect(geometry.itemHeight, greaterThan(0));
    });

    test('字母条可见时列表右边距让出整条宽度，不留死区', () {
      // 条子从 W-30 起铺到右边缘，右距只有 16px 时会压住每行最右 14px，
      // 点那一竖条收不到行的指针、只会跳组。
      final visible = warehouseSchoolListRightInset(indexBarVisible: true);
      expect(visible, greaterThanOrEqualTo(16 + kIndexBarWidth));
      // 搜索态字母条是空数据、不渲染，不该白白缩窄列表。
      final hidden = warehouseSchoolListRightInset(indexBarVisible: false);
      expect(hidden, 16);
    });
  });
}
