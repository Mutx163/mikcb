import 'dart:io';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../logging/app_debug_log.dart';

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

/// 下载失败的原因。
///
/// 分这么细不是为了好看，而是因为「下载失败」这四个字**本身不可诊断**：2026-10-06
/// 用户报「点大图下载失败」，而当时所有分支都只回一个 null，日志又写进了默认关闭的
/// `AppLogService`，于是四种完全不同的失败长一模一样，只能靠猜。
enum ManagedImageDownloadFailure {
  /// 网络层异常（断网 / 超时 / DNS / 证书）。
  network,

  /// 服务端回了非 2xx。
  status,

  /// 响应体是空的。
  emptyBody,

  /// 响应体不是图片（多半是 HTML 错误页）。
  notImage,

  /// 拿到了合法响应，但写文件失败（磁盘满 / 无权限）。
  write,
}

/// 一次下载的结果：成功给 [path]，失败给 [failure] 与可诊断的细节。
///
/// [statusCode] / [contentType] 只在拿得到响应时有值，正是它们把「Bing 说这张图没有」
/// （404）和「返回了 HTML」区分开。
class ManagedImageDownloadResult {
  const ManagedImageDownloadResult.success(String this.path)
    : failure = null,
      statusCode = null,
      contentType = null,
      detail = null;

  const ManagedImageDownloadResult.failed(
    ManagedImageDownloadFailure this.failure, {
    this.statusCode,
    this.contentType,
    this.detail,
  }) : path = null;

  final String? path;
  final ManagedImageDownloadFailure? failure;
  final int? statusCode;
  final String? contentType;

  /// 失败现场的原文（异常类型 + message，或状态码 / content-type）。
  ///
  /// 「下载失败」这句话本身不可诊断：2026-10-06 真凶是「上一段代码把共享 client
  /// 关了」，日志里只有 `failed=network` 时完全看不出这一点，必须靠这一行。
  final String? detail;

  bool get succeeded => path != null;

  /// 一行可直接进日志的描述（不翻译，给排障看）。
  String describe() => succeeded
      ? 'ok path=$path'
      : 'failed=${failure?.name} status=$statusCode '
            'contentType=$contentType detail=$detail';
}

/// 从网络下载一张图片并写入应用文档目录。
///
/// 与 [pickAndStoreManagedImage] 的差别只有「字节从哪来」，其余（目录、前缀校验、
/// 写完 evict 图片缓存）刻意保持同一套，于是网络来的图与相册来的图**共用同一条清理链**
/// （见 `deleteEvictedWallpaperFiles`）。
///
/// ## 为什么先写临时文件再改名
///
/// 直接往最终路径写，中途断网会留下一个**半张 JPEG 停在最终路径上**：
/// `homePageBackdropKey` 只查「文件在不在」（不校验能否解码），于是它会被当成
/// 合法壁纸交给首页渲染，最后只表现为「壁纸裂了 / 加载不出来」，很难定位。
/// 改名是同目录内的原子操作，所以最终路径要么不存在，要么就是完整的一张。
///
/// ## 失败给的是**原因**，不是一个 null
///
/// 五种失败（见 [ManagedImageDownloadFailure]）各有各的修法，混成一个 null 就只能靠猜。
/// 调用方负责把它落到用户看得见的地方（见 `BingWallpaperService`）。
///
/// 其中「响应体不是图片」那条不能省：Bing 的图片接口偶尔会对异常参数回一个 HTML 错误页
/// 而状态码仍是 200（实测任意尺寸如 `_2560x1440` 是 404，但错误页仍可能以 200 出现）。
/// 不验类型就会把一段 HTML 存成 `.jpg` 并当壁纸用上。
Future<ManagedImageDownloadResult> downloadToManagedImage({
  required Uri url,
  required String directoryName,
  required String fileName,
  http.Client? client,
  Duration? timeout,
}) async {
  final httpClient = client ?? http.Client();
  final ownsClient = client == null;
  http.Response response;
  try {
    response = await httpClient.get(url).timeout(
      timeout ?? const Duration(seconds: 20),
    );
  } on Object catch (error) {
    // 网络层异常（断网 / 超时 / DNS / 证书 / **client 已被关闭**）在此一律吞掉：
    // 调用方在启动路径上，一次壁纸下载失败不该波及主流程。原因照样带出去。
    //
    // ⚠️ 异常**类型与原文**必须进日志：2026-10-06 用户报「下载失败」而四条分支都只
    // 回一个 null，只能靠猜；后来真凶是「上一段代码把共享 client 关了」，那条异常是
    // `ClientException`，不带原文就永远看不出是「网络不通」还是「client 已被关闭」。
    appDebugLog(
      'ManagedImage',
      'download network error on $url: ${error.runtimeType}: $error',
    );
    return ManagedImageDownloadResult.failed(
      ManagedImageDownloadFailure.network,
      detail: '${error.runtimeType}: $error',
    );
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return ManagedImageDownloadResult.failed(
      ManagedImageDownloadFailure.status,
      statusCode: response.statusCode,
      contentType: response.headers['content-type'],
    );
  }
  final bytes = response.bodyBytes;
  if (bytes.isEmpty) {
    return ManagedImageDownloadResult.failed(
      ManagedImageDownloadFailure.emptyBody,
      statusCode: response.statusCode,
    );
  }
  final contentType = response.headers['content-type']?.trim().toLowerCase();
  if (contentType == null || !contentType.startsWith('image/')) {
    return ManagedImageDownloadResult.failed(
      ManagedImageDownloadFailure.notImage,
      statusCode: response.statusCode,
      contentType: contentType,
    );
  }
  final dir = await getApplicationDocumentsDirectory();
  final targetDir = Directory(
    '${dir.path}${Platform.pathSeparator}$directoryName',
  );
  if (!targetDir.existsSync()) {
    await targetDir.create(recursive: true);
  }
  final target = File(
    '${targetDir.path}${Platform.pathSeparator}$fileName',
  );
  // 临时名与最终名同目录，保证 [File.rename] 不跨卷；`.part` 后缀同时让人工翻目录时
  // 一眼看出「这是没写完的残留」，不会误当成一张可用壁纸。
  //
  // ⚠️ 临时名必须**每次尝试都不同**，且**不许靠「看文件在不在」来挑**。
  //
  // 同一张图同一档位可能被并发下两次 —— 冷启动的「每天自动换」与用户在图库里手动点
  // 同一张能撞在一起（`maybeApplyDaily` 与图库的 `_pick` 各走各的，谁都不知道对方在
  // 下载）。共用一个临时名时两个 writer 往同一路径交错写，`rename` 出来的 .jpg 就是
  // **坏图**，而它随后会被当成合法壁纸交给首页。
  //
  // ⚠️ 早先的实现是「序号 + `existsSync()` 跳过已存在的名字」，那**看着安全、其实不
  // 安全**：`existsSync()` 是同步的，而它与 `writeAsBytes` 真正建文件之间隔着 await，
  // 两个并发下载完全可能都看到 `.0.part` 不存在、然后都往它身上写。这不是纸上推演
  // —— `test/services/bing_wallpaper_service_test.dart` 里那条并发用例**独立跑 4 次
  // 全过、跟着 780 例的整目录跑就挂过一次**，正是这条竞态（2026-10-06）。
  //
  // 所以改成**不依赖任何观察**的唯一名：Dart 单 isolate 的同步代码不会被抢占，
  // 进程内自增计数器足以区分并发者；再拼一段随机数覆盖「多 isolate / 上次崩溃留下的
  // 残留」这两种情况。谁先 `rename` 谁生效，字节完整的那份胜出（rename 在同卷内原子）。
  final temp = File('${target.path}.${_nextTempToken()}.part');
  try {
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  } on Object {
    try {
      if (temp.existsSync()) {
        await temp.delete();
      }
    } on Object {
      // 临时文件删不掉不阻断：它仍以 `filePrefix` 开头，被当成壁纸目录里的残留扫掉，
      // 而下次下载不会再挑中同一个名字（名字每次都不一样）。
    }
    return const ManagedImageDownloadResult.failed(
      ManagedImageDownloadFailure.write,
    );
  }
  PaintingBinding.instance.imageCache.evict(FileImage(target));
  return ManagedImageDownloadResult.success(target.path);
}

/// 拼一段保证「同一 isolate 内互不相同」的临时名后缀。
///
/// 见 [downloadToManagedImage] 里那段⚠️：这里**不能**退回「看文件在不在再决定序号」，
/// 那个做法本身就有竞态。计数器走同步代码，而同步代码在 Dart 单 isolate 里不会被抢占，
/// 所以 `++` 本身就是原子的；随机数那半段只用来躲开「上次崩溃留下的同号残留」。
String _nextTempToken() {
  final seq = _tempSeq++;
  final salt = _tempSalt.nextInt(1 << 32);
  return '$seq-$salt';
}

int _tempSeq = 0;

final Random _tempSalt = Random();

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
