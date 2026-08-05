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
  if (!await targetDir.exists()) {
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
  if (!await targetDir.exists()) {
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
