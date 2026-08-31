import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 从系统相册挑选一张图片并复制到应用文档目录，返回新文件的绝对路径。
///
/// 返回 null 表示用户取消选择或读取失败。相册选择走系统 Photo Picker /
/// 系统相册界面，无需申请存储权限。
typedef ManagedImagePicker = Future<XFile?> Function();

Future<String?> pickAndStoreManagedImage({
  required String directoryName,
  required String filePrefix,
  bool cleanupArtifacts = true,
  ManagedImagePicker? imagePicker,
}) async {
  final XFile? pickedImage;
  try {
    pickedImage =
        await (imagePicker ??
            () => ImagePicker().pickImage(source: ImageSource.gallery))();
  } on Exception {
    return null;
  }
  if (pickedImage == null) {
    return null;
  }
  final bytes = await pickedImage.readAsBytes();
  if (bytes.isEmpty) {
    return null;
  }
  final ext = _extensionOf(pickedImage);
  final dir = await getApplicationDocumentsDirectory();
  final targetDir = Directory(
    '${dir.path}${Platform.pathSeparator}$directoryName',
  );
  if (!targetDir.existsSync()) {
    await targetDir.create(recursive: true);
  }
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final targetPath =
      '${targetDir.path}${Platform.pathSeparator}${filePrefix}_$stamp.$ext';
  await File(targetPath).writeAsBytes(bytes, flush: true);
  if (cleanupArtifacts) {
    await _deleteManagedImageArtifacts(
      directoryName: directoryName,
      filePrefix: filePrefix,
      preservePath: targetPath,
    );
  }
  PaintingBinding.instance.imageCache.evict(FileImage(File(targetPath)));
  return targetPath;
}

/// 删除一张受管图片。
///
/// 防误删双保险：路径必须位于 [directoryName] 目录内、且文件名以
/// [filePrefix] 开头才会动手；不满足时静默跳过。文件不存在视为成功，
/// 方便「恢复默认」等幂等清理路径直接调用。
Future<void> deleteManagedImage(
  String? path, {
  required String directoryName,
  required String filePrefix,
}) async {
  if (path == null || path.isEmpty) {
    return;
  }
  try {
    final dir = await getApplicationDocumentsDirectory();
    final managedDirPrefix =
        '${dir.path}${Platform.pathSeparator}$directoryName${Platform.pathSeparator}';
    final absolute = File(path).absolute.path;
    if (!absolute.startsWith(managedDirPrefix)) {
      return;
    }
    final name = absolute.split(Platform.pathSeparator).last;
    if (!name.startsWith(filePrefix)) {
      return;
    }
    final file = File(absolute);
    if (file.existsSync()) {
      await file.delete();
    }
  } on Exception {
    // 清理失败不阻断主流程：孤儿文件不影响功能，可下次再清。
  }
}

/// 从所选文件的文件名或路径中提取小写扩展名，取不到时回退为 png。
String _extensionOf(XFile pickedImage) {
  for (final fileName in [pickedImage.name, pickedImage.path]) {
    if (fileName.isEmpty) {
      continue;
    }
    final baseName = fileName.split('/').last.split('\\').last;
    if (!baseName.contains('.')) {
      continue;
    }
    final candidate = baseName.split('.').last.toLowerCase();
    if (candidate.isNotEmpty && candidate.length <= 5) {
      return candidate;
    }
  }
  return 'png';
}

Future<void> _deleteManagedImageArtifacts({
  required String directoryName,
  required String filePrefix,
  String? preservePath,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final targetDir = Directory(
    '${dir.path}${Platform.pathSeparator}$directoryName',
  );
  if (!targetDir.existsSync()) {
    return;
  }
  final preservedAbsolutePath = preservePath == null
      ? null
      : File(preservePath).absolute.path;
  await for (final entity in targetDir.list()) {
    if (entity is! File) {
      continue;
    }
    final name = entity.uri.pathSegments.last;
    if (!name.startsWith(filePrefix)) {
      continue;
    }
    if (preservedAbsolutePath != null &&
        entity.absolute.path == preservedAbsolutePath) {
      continue;
    }
    await entity.delete();
  }
}
