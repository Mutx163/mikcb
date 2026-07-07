import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> pickAndStoreManagedImage({
  required String directoryName,
  required String filePrefix,
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  final file = result.files.single;
  final bytes =
      file.bytes ??
      (file.path == null ? null : await File(file.path!).readAsBytes());
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  final ext = (file.extension?.isNotEmpty ?? false)
      ? file.extension!.toLowerCase()
      : 'png';
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
  await _deleteManagedImageArtifacts(
    directoryName: directoryName,
    filePrefix: filePrefix,
    preservePath: targetPath,
  );
  PaintingBinding.instance.imageCache.evict(FileImage(File(targetPath)));
  return targetPath;
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
