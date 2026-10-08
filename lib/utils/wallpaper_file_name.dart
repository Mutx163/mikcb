/// 壁纸落盘文件名的安全拼接（2026-10-08）。
///
/// ## 为什么需要它
///
/// 壁纸文件名里有一半是**外部数据**：Wallhaven 的 `id`、Bing 的 `dateKey`
/// 都直接来自服务端响应 / 同步下来的图库台账。原实现把它们原样插进
/// `wallpaper_wh_$id.jpg`（`wallhaven_wallpaper.dart`）与
/// `wallpaper_bing_${dateKey}_…jpg`（`bing_wallpaper.dart`），
/// 落盘时靠字符串拼接（`managed_image_storage.dart` 的
/// `'$targetDir.path${sep}$fileName'`），**没有任何净化**。
///
/// 实测（`dart run` 探针）过一遍就知道后果分两面：
///
/// - **删除面几乎打不中**：文件名尾部固定追加 `.jpg`，所以 `..` 解析出来的
///   目标几乎总是一个不存在的路径 ⇒ `existsSync()` 为 false、不删。
///   （探针里 3 个金丝雀文件全部存活。）
/// - **写入面是真的**：Windows 也接受正斜杠作分隔符，于是
///   `id = '/../../planted.txt'` 会让 `writeAsBytes` + `rename` 把文件
///   **写到壁纸目录之外**（实测 `escaped candidate …/planted.txt.jpg: true`）。
///   危害比删除小得多（内容是图片），但仍能在应用私有目录里任意落点，
///   而且路径会进台账、被清理逻辑反复喂回。
///
/// 所以在**拼进文件名之前**把外部标识符收敛成「一段安全片段」，
/// 而不是等落盘后再去检查路径 —— 后者要跟平台的路径归一规则较劲
/// （`File.absolute` 就不规范化 `..`，见该文件注释）。
///
/// ## 口径
///
/// 只保留 `[A-Za-z0-9._-]`，其余（含 `/` `\` `..` 空格、任何控制字符）
/// 一律替换成 `_`；再截断到 [_maxSegmentLength]，避免超长名在部分
/// 文件系统上失败。
///
/// - **不做**「清洗后为空就拒收」：那会把一条合法图库记录变成「打不开」。
///   清洗后为空时退回一个固定的占位段（见 [safeWallpaperNameSegment]），
///   宁可让两张图撞名（后者覆盖前者，用户看到的只是换了一张图），
///   也不要让整条记录消失。
const int _maxSegmentLength = 48;

/// 把一段外部标识符收敛成能安全进文件名的片段。
///
/// [fallback] 是清洗后为空时的占位（不含扩展名部分）。
String safeWallpaperNameSegment(String raw, {String fallback = 'item'}) {
  final buffer = StringBuffer();
  for (final unit in raw.runes) {
    final ch = String.fromCharCode(unit);
    final isSafe =
        (unit >= 0x30 && unit <= 0x39) || // 0-9
        (unit >= 0x41 && unit <= 0x5A) || // A-Z
        (unit >= 0x61 && unit <= 0x7A) || // a-z
        ch == '.' ||
        ch == '_' ||
        ch == '-';
    buffer.write(isSafe ? ch : '_');
    if (buffer.length >= _maxSegmentLength) {
      break;
    }
  }
  final cleaned = buffer.toString();
  // `.` / `..` 这两个名字虽然本身不含分隔符，但它们是路径语义上的特例；
  // 一律当作「清洗后为空」处理，退回占位。
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return fallback;
  }
  return cleaned;
}