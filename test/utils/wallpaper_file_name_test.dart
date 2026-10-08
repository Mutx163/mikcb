import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/wallpaper_file_name.dart';

/// 2026-10-08 审核实测：壁纸文件名里有一半是**外部数据**
/// （Wallhaven 的 `id`、Bing 的 `dateKey`，来自服务端响应与同步下来的图库台账），
/// 而落盘是纯字符串拼接（`managed_image_storage.dart`），没有任何净化。
///
/// 实测两面：
/// - 删除面几乎打不中（尾部固定 `.jpg`，`..` 解析出的目标通常不存在）；
/// - 写入面是真的：Windows 也认正斜杠作分隔符，`id = '/../../planted.txt'`
///   能把文件**写到壁纸目录之外**。
///
/// 修法是在拼进文件名**之前**净化，而不是等落盘后检查路径 ——
/// 后者要跟平台的路径归一规则较劲（`File.absolute` 就不规范化 `..`）。
void main() {
  group('真实数据：文件名必须一字不变', () {
    // 改名会让每张已下载的壁纸变成孤儿文件（台账里的路径全部对不上），
    // 所以这条比安全那几条更要紧。
    test('Wallhaven 的 id 原样通过', () {
      for (final id in ['94x4z1', 'aBcDe123', 'ml6z1q', '2xm3d4', 'p5v2jk']) {
        expect(
          safeWallpaperNameSegment(id, fallback: 'wh'),
          id,
          reason: '真实 id 改了就对不上存量文件',
        );
      }
    });

    test('Bing 的 dateKey 原样通过', () {
      for (final d in ['2026-10-08', '2026-01-01', '20251231']) {
        expect(
          safeWallpaperNameSegment(d, fallback: 'day'),
          d,
          reason: 'Bing 日期键改了会让每天自动换的台账失效',
        );
      }
    });
  });

  group('恶意输入：分隔符必须被消掉', () {
    test('正斜杠穿越', () {
      expect(
        safeWallpaperNameSegment('/../../planted.txt').contains('/'),
        isFalse,
      );
    });

    test('反斜杠穿越', () {
      expect(safeWallpaperNameSegment(r'..\..\evil').contains(r'\'), isFalse);
    });

    test('单独一段的 .. 与 . 退回占位（路径语义上的特例）', () {
      expect(safeWallpaperNameSegment('..'), 'item');
      expect(safeWallpaperNameSegment('.'), 'item');
    });

    test('空串与纯空白不会变成空文件名', () {
      expect(safeWallpaperNameSegment(''), 'item');
      expect(safeWallpaperNameSegment('   ', fallback: 'wh'), isNotEmpty);
    });

    test('超长输入被截断到安全长度', () {
      expect(safeWallpaperNameSegment('x' * 500).length, lessThanOrEqualTo(48));
    });

    test('任意输入都不会带出分隔符或路径特例', () {
      final hostile = <String>[
        '/../../planted.txt',
        '../../shared_prefs/wallpaper_x',
        r'..\..\evil',
        'a/b',
        r'a\b',
        '..',
        '.',
        '',
        '   ',
        ' ',
        '中文名',
        'x' * 500,
      ];
      for (final raw in hostile) {
        final got = safeWallpaperNameSegment(raw);
        expect(
          got.contains('/') || got.contains(r'\') || got == '.' || got == '..',
          isFalse,
          reason: '净化后仍含路径语义',
        );
        expect(got, isNotEmpty, reason: '不该产出空文件名');
      }
    });
  });
}
