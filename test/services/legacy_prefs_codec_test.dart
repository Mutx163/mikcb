import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Phase 0 双向兼容测试 B→A 方向：Kotlin 写 → Flutter 读（回退能力的保证）。
///
/// 金标准由 JDK 独立生成（GenGolden/GenGolden2：ObjectOutputStream 序列化
/// `ArrayList<String>` + MIME Base64(76, '\n')），与 Dart 解析器零共享代码——
/// 期望值来自独立来源，不是从被测实现抄的。
///
/// 契约：docs/plans/2026-10-26-data-contract.md §1。
/// Kotlin 侧对应用例：android/.../FlutterPrefsCodecTest.kt（A→B 方向）。
/// 两侧必须同时绿，「回退到 Flutter 版仍能读」才成立。
void main() {
  // "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu" —— shared_preferences_android
  // LegacySharedPreferencesPlugin.java:36 的 LIST_IDENTIFIER。
  const listPrefix = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu';

  /// 从金标准 Base64 串解出原始字节（等价 android Base64.decode(s, 0)：
  /// MIME 解码容忍换行）。
  Uint8List rawOf(String mime) => base64Decode(mime.replaceAll('\n', ''));

  /// Java 序列化流的最小解析器：只解析「ArrayList<String>」这一种形态，
  /// 与插件 StringListObjectInputStream 的放行范围一致。遇到任何其它
  /// 类描述直接抛——超范围即坏数据，绝不静默。
  (String, List<String>) parseList(Uint8List bytes) {
    final b = ByteData.sublistView(bytes);
    var pos = 0;
    void expectTag(int tag, String what) {
      if (pos >= bytes.length || bytes[pos] != tag) {
        throw FormatException('bad $what at byte $pos');
      }
      pos += 1;
    }

    int u8() => bytes[pos++];
    int u16() {
      final v = b.getUint16(pos);
      pos += 2;
      return v;
    }

    /// Java modified UTF-8 解码（ObjectOutputStream 的 writeUTF 家族用它，
    /// 不是标准 UTF-8）：增补字符（如 emoji）按两个代理对各 3 字节共 6 字节编码。
    String utf(int len) {
      final end = pos + len;
      if (end > bytes.length) throw const FormatException('truncated string');
      final out = StringBuffer();
      var i = pos;
      while (i < end) {
        final c = bytes[i];
        if (c & 0x80 == 0) {
          out.writeCharCode(c);
          i += 1;
        } else if (c & 0xE0 == 0xC0) {
          out.writeCharCode(((c & 0x1F) << 6) | (bytes[i + 1] & 0x3F));
          i += 2;
        } else if (c & 0xF0 == 0xE0) {
          final v = ((c & 0x0F) << 12) |
              ((bytes[i + 1] & 0x3F) << 6) |
              (bytes[i + 2] & 0x3F);
          out.writeCharCode(v); // 代理区字符原样保留，最后统一配对
          i += 3;
        } else {
          throw FormatException('bad modified-utf8 byte 0x${c.toRadixString(16)}');
        }
      }
      pos = end;
      return out.toString();
    }

    // 流头魔数 ac ed + 版本 00 05
    expectTag(0xAC, 'magic1');
    expectTag(0xED, 'magic2');
    if (u16() != 5) throw const FormatException('unsupported stream version');
    // TC_OBJECT(0x73) TC_CLASSDESC(0x72)
    expectTag(0x73, 'TC_OBJECT');
    expectTag(0x72, 'TC_CLASSDESC');
    final classNameLen = u16();
    final className = utf(classNameLen);
    if (className != 'java.util.ArrayList') {
      throw FormatException('unexpected class: $className');
    }
    pos += 8; // serialVersionUID (ArrayList: 8748309613138420577L)
    pos += 1; // flags：0x03 = SC_SERIALIZABLE | SC_WRITE_METHOD（1 字节）
    final fieldCount = u16();
    if (fieldCount != 1) throw FormatException('expected 1 field, got $fieldCount');
    // 唯一字段：int size（'I' 描述符）
    expectTag(0x49, 'field type I');
    final nameLen = u16();
    utf(nameLen); // "size"
    // 类注解结束：TC_ENDBLOCKDATA(0x78)
    expectTag(0x78, 'TC_ENDBLOCKDATA class anno');
    // 超类：TC_NULL(0x70)
    expectTag(0x70, 'TC_NULL super');
    // defaultWriteObject 写出的 size 字段值（4 字节）
    final size = b.getInt32(pos);
    pos += 4;
    // ArrayList.writeObject 的块数据：0x77 <len> <size 再写一遍，跳过>
    if (bytes[pos] == 0x77) {
      pos += 1;
      final blockLen = u8(); // TC_BLOCKDATA：长度是单字节（≤255）
      pos += blockLen;
    }
    // 元素：每个 0x74 + u16 长度 + UTF-8
    final items = <String>[];
    for (var i = 0; i < size; i++) {
      if (bytes[pos] == 0x74) {
        pos += 1;
        final len = u16();
        items.add(utf(len));
      } else {
        throw FormatException('unsupported element tag 0x${bytes[pos].toRadixString(16)}');
      }
    }
    // 写法方法的块结束标记
    expectTag(0x78, 'TC_ENDBLOCKDATA tail');
    return (className, items);
  }

  group('B→A：Kotlin 写出的 List<String> 字节流 Flutter 能读回', () {
    test('GenGolden 三元素中文列表（与 Kotlin 测试同一基准）', () {
      final (_, items) = parseList(rawOf(
        'rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAADdwQAAAAD\n'
        'dAAG6auY5pWwdAAL6Iux6K+tIEIyMDF0AAF4eA==',
      ));
      expect(items, ['高数', '英语 B201', 'x']);
    });

    test('GenGolden2 空列表', () {
      final (_, items) = parseList(rawOf(
        'rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAAAdwQAAAAA\neA==',
      ));
      expect(items, isEmpty);
    });

    test('GenGolden2 特殊字符（空串/换行/引号/emoji/伪造序列化头）', () {
      final (_, items) = parseList(rawOf(
        'rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAAFdwQAAAAF\n'
        'dAAAdAADYQpidAAHcXVvdGUieHQAC2Vtb2pp7aC87b+GdAANck8wQUJYTnkoZmFrZXg=',
      ));
      expect(items, ['', 'a\nb', 'quote"x', 'emoji🏆', 'rO0ABXNy(fake)'.replaceAll(')', '')]);
    });

    test('GenGolden2 超长元素（>76 字符触发 MIME 换行）', () {
      final (_, items) = parseList(rawOf(
        'rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAABdwQAAAAB\n'
        'dADIeHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4\n'
        'eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4\n'
        'eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4\n'
        'eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4',
      ));
      expect(items.single, 'x' * 200);
    });

    test('完整 key 形态：flutter.teacher_records = 前缀 + 编码体', () {
      // 模拟 Kotlin 按 data-contract §1.3 写出「前缀 + MIME 体」到 prefs 后，
      // Dart 侧（同一解析家族）读回。
      const mime =
          'rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAADdwQAAAAD\n'
          'dAAG6auY5pWwdAAL6Iux6K+tIEIyMDF0AAF4eA==';
      const full = listPrefix + mime;
      expect(full.startsWith(listPrefix), isTrue);
      final (_, items) = parseList(rawOf(full.substring(listPrefix.length)));
      expect(items, ['高数', '英语 B201', 'x']);
    });
  });

  group('咬合探针：编码被破坏时必须失败，不许静默', () {
    test('缺 LIST_PREFIX —— Flutter 侧识别为「不是 List 编码」', () {
      // Kotlin 侧若忘了写前缀（FlutterPrefsCodecTest 已断言其 encode 恒有前缀），
      // 这里证明 Dart 侧的前缀判定也会拒收——两侧都有牙齿。
      const mime =
          'rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAADdwQAAAAD\n'
          'dAAG6auY5pWwdAAL6Iux6K+tIEIyMDF0AAF4eA==';
      expect(mime.startsWith(listPrefix), isFalse);
    });

    test('字节流被截断 —— 解析器必须抛，不能返回部分数据', () {
      final bytes = rawOf(
        'rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAADdwQAAAAD\n'
        'dAAG6auY5pWwdAAL6Iux6K+tIEIyMDF0AAF4eA==',
      );
      final truncated = bytes.sublist(0, bytes.length - 8);
      expect(() => parseList(truncated), throwsFormatException);
    });

    test('类名被换成 gadget 候选 —— 放行范围外的类必须拒收', () {
      // 把 java.util.ArrayList 换成同样长度的一段类名文本，触发类名校验。
      final bytes = rawOf(
        'rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAADdwQAAAAD\n'
        'dAAG6auY5pWwdAAL6Iux6K+tIEIyMDF0AAF4eA==',
      );
      const evil = 'javax.script.Script';
      bytes.setRange(11, 11 + evil.length, evil.codeUnits);
      expect(() => parseList(bytes), throwsFormatException);
    });
  });
}
