import 'dart:io';

/// 外部分享导入的副本路径判定与清理。
///
/// 别的 App（微信 / QQ 的「用其他应用打开」）把表格递进来时，原生侧
/// `MainActivity.kt:1546-1548` 会先把它复制成
/// `<cacheDir>/external_imports/<millis>_<safeName>` 再把绝对路径交给 Dart
/// （`MainActivity.kt:1358-1362`，`getPendingExternalImport` 在 :797-799 交接时
/// 就把内存里那条 pending 清空了，所以交接之后只有 Dart 这一份引用）。
///
/// 问题在于两侧都不删：全仓 `external_imports` 只有这一个写入口，
/// 而消费方 `course_import_screen.dart:_importFromExternalFile` 读完字节就结束了。
/// 于是**含课程·教师·教室的明文副本**长期留在应用缓存里，每次分享还多一份
/// （毫秒前缀不覆盖），只有系统存储紧张清缓存或用户手动「清除缓存」才会消失。

/// 是否是我们自己落到缓存里的那份外部导入副本。
///
/// 必须限定这个目录：同一条导入链也可能拿到**用户自己挑的文件**
/// （`_importSpreadsheetFile` 走 FilePicker），那种路径一律不许删。
bool isExternalImportCacheCopy(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return normalized.contains('/cache/external_imports/');
}

/// 消费完之后删除那份副本；返回是否真的删掉了一个文件。
///
/// 删除失败（文件已被系统清掉、没有写权限）不外抛：导入本身已经结束了，
/// 不能因为清理失败把成功报成失败。
Future<bool> deleteExternalImportCopy(String path) async {
  if (!isExternalImportCacheCopy(path)) {
    return false;
  }
  try {
    final file = File(path);
    // existsSync 而不是 await exists()：analyze 的 avoid_slow_async_io 会判异步版本，
    // 而这里的调用点已经在导入结束的 finally 里，不需要再排一次微任务。
    if (!file.existsSync()) {
      return false;
    }
    await file.delete();
    return true;
  } catch (_) {
    return false;
  }
}
