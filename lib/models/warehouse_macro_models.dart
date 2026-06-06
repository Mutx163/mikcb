bool _isSensitiveMacroFieldType(String? fieldType) {
  return fieldType == 'password' || fieldType == 'captcha';
}

String _manualInputReasonForFieldType(String? fieldType) {
  if (fieldType == 'captcha') {
    return '请手动输入验证码；完成后点击继续';
  }
  return '请手动输入密码；如已自动填充请直接继续';
}

String? _inferManualInputFieldType(String? reason) {
  final value = reason ?? '';
  final lower = value.toLowerCase();
  if (value.contains('验证码') ||
      value.contains('校验码') ||
      lower.contains('captcha') ||
      lower.contains('verification')) {
    return 'captcha';
  }
  if (value.contains('密码') ||
      lower.contains('password') ||
      lower.contains('pwd')) {
    return 'password';
  }
  return null;
}

/// 宏录制中的每一步操作类型
enum MacroStepType {
  /// 导航到指定 URL
  navigate,

  /// 填充表单字段（selector + value + fieldType）
  fillField,

  /// 点击元素
  click,

  /// 等待当前 URL 匹配某个模式
  waitForUrl,

  /// 等待某个 DOM 元素出现
  waitForSelector,

  /// 等待用户手动操作（如验证码）
  waitForManualInput,

  /// 执行教务导入脚本
  executeScript,

  /// 纯粹等待一段时间（毫秒）
  delay,
}

/// 宏录制中的单步操作
class MacroStep {
  final MacroStepType type;

  /// 字段类型：username / password / captcha / other
  final String? fieldType;

  /// CSS 选择器或 URL 模式
  final String? selector;

  /// 填充的值
  final String? value;

  /// 等待时长（毫秒），用于 delay / waitForUrl / waitForSelector 的超时
  final int waitMs;

  const MacroStep({
    required this.type,
    this.fieldType,
    this.selector,
    this.value,
    this.waitMs = 0,
  });

  Map<String, dynamic> toJson() {
    final shouldOmitValue =
        type == MacroStepType.fillField &&
        _isSensitiveMacroFieldType(fieldType);
    return {
      'type': type.name,
      if (fieldType != null && fieldType!.isNotEmpty) 'fieldType': fieldType,
      if (selector != null && selector!.isNotEmpty) 'selector': selector,
      if (!shouldOmitValue && value != null && value!.isNotEmpty)
        'value': value,
      if (waitMs > 0) 'waitMs': waitMs,
    };
  }

  factory MacroStep.fromJson(Map<String, dynamic> json) {
    final type = MacroStepType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => MacroStepType.delay,
    );
    final fieldType = json['fieldType'] as String?;
    if (type == MacroStepType.fillField &&
        _isSensitiveMacroFieldType(fieldType)) {
      return MacroStep.waitForManualInput(
        _manualInputReasonForFieldType(fieldType),
        selector: json['selector'] as String?,
        fieldType: fieldType,
      );
    }
    final value = json['value'] as String?;
    final repairedFieldType = type == MacroStepType.waitForManualInput
        ? fieldType ?? _inferManualInputFieldType(value)
        : fieldType;
    return MacroStep(
      type: type,
      fieldType: repairedFieldType,
      selector: json['selector'] as String?,
      value: value,
      waitMs: (json['waitMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// 构建器辅助方法
  static MacroStep navigate(String url) =>
      MacroStep(type: MacroStepType.navigate, value: url);

  static MacroStep fillField({
    required String selector,
    required String value,
    String? fieldType,
  }) => MacroStep(
    type: MacroStepType.fillField,
    selector: selector,
    value: value,
    fieldType: fieldType,
  );

  static MacroStep click(String selector) =>
      MacroStep(type: MacroStepType.click, selector: selector);

  static MacroStep waitForUrl(String pattern) =>
      MacroStep(type: MacroStepType.waitForUrl, value: pattern, waitMs: 15000);

  static MacroStep waitForSelector(String selector) => MacroStep(
    type: MacroStepType.waitForSelector,
    selector: selector,
    waitMs: 15000,
  );

  static MacroStep waitForManualInput(
    String reason, {
    String? selector,
    String? fieldType,
  }) => MacroStep(
    type: MacroStepType.waitForManualInput,
    selector: selector,
    fieldType: fieldType,
    value: reason,
  );

  static const MacroStep executeScript = MacroStep(
    type: MacroStepType.executeScript,
  );

  static MacroStep delay(int ms) =>
      MacroStep(type: MacroStepType.delay, waitMs: ms);
}

/// 与学校+适配器关联的宏录制记录
class WarehouseMacroRecord {
  final String schoolId;
  final String adapterId;
  final String schoolName;
  final String adapterName;
  final String importUrl;
  final String schoolResourceFolder;
  final String adapterAssetJsPath;
  final List<MacroStep> steps;
  final Map<String, dynamic> dialogResponses;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int successfulImportCount;

  const WarehouseMacroRecord({
    required this.schoolId,
    required this.adapterId,
    required this.schoolName,
    required this.adapterName,
    required this.importUrl,
    required this.schoolResourceFolder,
    required this.adapterAssetJsPath,
    required this.steps,
    this.dialogResponses = const {},
    required this.createdAt,
    required this.updatedAt,
    this.successfulImportCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'schoolId': schoolId,
    'adapterId': adapterId,
    'schoolName': schoolName,
    'adapterName': adapterName,
    'importUrl': importUrl,
    'schoolResourceFolder': schoolResourceFolder,
    'adapterAssetJsPath': adapterAssetJsPath,
    'steps': steps.map((s) => s.toJson()).toList(),
    'dialogResponses': dialogResponses,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'successfulImportCount': successfulImportCount,
  };

  factory WarehouseMacroRecord.fromJson(Map<String, dynamic> json) {
    return WarehouseMacroRecord(
      schoolId: json['schoolId'] as String? ?? '',
      adapterId: json['adapterId'] as String? ?? '',
      schoolName: json['schoolName'] as String? ?? '',
      adapterName: json['adapterName'] as String? ?? '',
      importUrl: json['importUrl'] as String? ?? '',
      schoolResourceFolder:
          json['schoolResourceFolder'] as String? ??
          json['schoolId'] as String? ??
          '',
      adapterAssetJsPath: json['adapterAssetJsPath'] as String? ?? '',
      steps: ((json['steps'] as List<dynamic>?) ?? [])
          .map((s) => MacroStep.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
      dialogResponses: Map<String, dynamic>.from(
        json['dialogResponses'] as Map<String, dynamic>? ?? {},
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      successfulImportCount:
          (json['successfulImportCount'] as num?)?.toInt() ?? 0,
    );
  }

  WarehouseMacroRecord copyWith({
    String? schoolId,
    String? adapterId,
    String? schoolName,
    String? adapterName,
    String? importUrl,
    String? schoolResourceFolder,
    String? adapterAssetJsPath,
    List<MacroStep>? steps,
    Map<String, dynamic>? dialogResponses,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? successfulImportCount,
  }) {
    return WarehouseMacroRecord(
      schoolId: schoolId ?? this.schoolId,
      adapterId: adapterId ?? this.adapterId,
      schoolName: schoolName ?? this.schoolName,
      adapterName: adapterName ?? this.adapterName,
      importUrl: importUrl ?? this.importUrl,
      schoolResourceFolder: schoolResourceFolder ?? this.schoolResourceFolder,
      adapterAssetJsPath: adapterAssetJsPath ?? this.adapterAssetJsPath,
      steps: steps ?? this.steps,
      dialogResponses: dialogResponses ?? this.dialogResponses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      successfulImportCount:
          successfulImportCount ?? this.successfulImportCount,
    );
  }

  /// 用于 SharedPreferences 的存储 key
  static String storageKey(String schoolId, String adapterId) =>
      'warehouse_macro_record_${schoolId}_$adapterId';

  /// 所有宏记录索引的 key
  static const String indexKey = 'warehouse_macro_record_index';
}

/// 录制状态
enum MacroRecordingState { idle, recording, stopped }
