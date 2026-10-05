import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/external_import_cleanup.dart';

/// 回归钉（第 28 轮，外部分享进来的表格副本两侧都不清理）。
///
/// `MainActivity.kt:1546-1548` 把别的 App「用其他应用打开」递进来的表格复制成
/// `<cacheDir>/external_imports/<millis>_<safeName>`，:1358-1362 交出绝对路径，
/// `getPendingExternalImport`（:797-799）交接时就把内存里那条 pending 清空了 ——
/// 也就是说交接之后**只有 Dart 这一份引用**，而消费方
/// `course_import_screen.dart:_importFromExternalFile` 读完字节就结束了，
/// 全仓 `external_imports` 只有这一个写入口、没有任何删除点。
/// 结果：一份含课程·教师·教室的明文副本长期躺在应用缓存里，用户每分享一次
/// 就多一份（毫秒前缀不会覆盖），只有系统清缓存或用户手动「清除缓存」才消失。
///
/// 测试把文件放在 `<tmp>/cache/external_imports/` 下，模拟 Android 上
/// `/data/user/0/<包名>/cache/external_imports/` 的形状。
void main() {
  late Directory rootDir;

  String copyPath(String name) =>
      '${rootDir.path}/cache/external_imports/$name';

  Future<File> writeCopy(String name) async {
    final target = Directory('${rootDir.path}/cache/external_imports');
    await target.create(recursive: true);
    final file = File('${target.path}/$name');
    await file.writeAsString('课程,教师,教室');
    return file;
  }

  setUp(() async {
    rootDir = await Directory.systemTemp.createTemp('qingyu_external_import');
  });

  tearDown(() async {
    if (rootDir.existsSync()) {
      await rootDir.delete(recursive: true);
    }
  });

  test('副本路径被识别、消费完就删掉', () async {
    final file = await writeCopy('1727900000000_course.xlsx');
    expect(isExternalImportCacheCopy(file.path), isTrue);

    expect(await deleteExternalImportCopy(file.path), isTrue);
    expect(file.existsSync(), isFalse);
  });

  test('反斜杠路径同样识别（Windows 调试与国产 ROM 的写法差异）', () {
    expect(
      isExternalImportCacheCopy(copyPath('a.xlsx').replaceAll('/', r'\')),
      isTrue,
    );
    expect(
      isExternalImportCacheCopy(
        r'C:\data\user\0\com.mutx163.qingyu\cache\external_imports\1_x.xlsx',
      ),
      isTrue,
    );
  });

  test('用户自己挑的文件一律不删', () async {
    final outside = File('${rootDir.path}/Downloads/我的课表.xlsx');
    await outside.create(recursive: true);
    await outside.writeAsString('课程,教师,教室');

    expect(isExternalImportCacheCopy(outside.path), isFalse);
    expect(await deleteExternalImportCopy(outside.path), isFalse);
    expect(outside.existsSync(), isTrue, reason: 'FilePicker 那条路进来的文件不许动');
  });

  test('名字里带 external_imports 但不在缓存目录下，也不算副本', () async {
    final decoy = File('${rootDir.path}/external_imports/x.csv');
    await decoy.create(recursive: true);
    await decoy.writeAsString('a');

    expect(isExternalImportCacheCopy(decoy.path), isFalse);
    expect(await deleteExternalImportCopy(decoy.path), isFalse);
    expect(decoy.existsSync(), isTrue);
  });

  test('文件已经不在（系统先清了缓存）时静默返回 false', () async {
    final file = await writeCopy('1727900000001_gone.csv');
    final path = file.path;
    await file.delete();

    expect(await deleteExternalImportCopy(path), isFalse);
  });
}
