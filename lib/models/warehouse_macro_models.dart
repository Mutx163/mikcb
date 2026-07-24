bool isSensitiveMacroFieldType(String? fieldType) {
  return fieldType == 'password' || fieldType == 'captcha';
}

String manualInputReasonForFieldType(String? fieldType) {
  if (fieldType == 'captcha') {
    return 'manual_input_captcha';
  }
  return 'manual_input_password';
}

/// Builds a stable key for matching script dialog responses during macro replay.
/// Prefer [dialogId] when the adapter script provides one.
String warehouseDialogResponseKey(String type, Map<String, dynamic> message) {
  final dialogId = (message['dialogId'] as String?)?.trim();
  if (dialogId != null && dialogId.isNotEmpty) {
    return '$type|id:$dialogId';
  }
  final title = (message['title'] as String? ?? '').trim();
  final body =
      (message['message'] as String? ?? message['optionsJson'] as String? ?? '')
          .trim();
  return '$type|$title|$body';
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
        type == MacroStepType.fillField && isSensitiveMacroFieldType(fieldType);
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
        isSensitiveMacroFieldType(fieldType)) {
      return MacroStep.waitForManualInput(
        manualInputReasonForFieldType(fieldType),
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

  /// Page URL when the import script was executed successfully.
  /// Used by accelerated replay: after login, navigate here and skip
  /// intermediate menu clicks. Null for legacy macros.
  final String? scriptPageUrl;

  /// WebView desktop UA mode used during recording; null defaults to desktop.
  final bool? useDesktopMode;

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
    this.scriptPageUrl,
    this.useDesktopMode,
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
    if (scriptPageUrl != null && scriptPageUrl!.isNotEmpty)
      'scriptPageUrl': scriptPageUrl,
    if (useDesktopMode != null) 'useDesktopMode': useDesktopMode,
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
      scriptPageUrl: sanitizeWarehouseScriptPageUrl(
        json['scriptPageUrl'] as String?,
      ),
      useDesktopMode: json['useDesktopMode'] as bool?,
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
    String? scriptPageUrl,
    bool clearScriptPageUrl = false,
    bool? useDesktopMode,
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
      scriptPageUrl: clearScriptPageUrl
          ? null
          : (scriptPageUrl ?? this.scriptPageUrl),
      useDesktopMode: useDesktopMode ?? this.useDesktopMode,
    );
  }

  /// 用于 SharedPreferences 的存储 key
  static String storageKey(String schoolId, String adapterId) =>
      'warehouse_macro_record_${schoolId}_$adapterId';

  /// 所有宏记录索引的 key
  static const String indexKey = 'warehouse_macro_record_index';
}

/// Strips one-time / session query params so a saved script page URL can be
/// reused across sessions. Returns null when the URL is not a usable absolute
/// http(s) location.
String? sanitizeWarehouseScriptPageUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }

  const volatileQueryKeys = <String>{
    'jsessionid',
    'jsessionId',
    'JSESSIONID',
    'ticket',
    'token',
    'access_token',
    'refresh_token',
    'state',
    'nonce',
    'timestamp',
    'ts',
    't',
    'random',
    'rnd',
    'sid',
    'sessionid',
    'sessionId',
  };

  final keptQueryParameters = <String, String>{};
  uri.queryParameters.forEach((key, value) {
    final lowerKey = key.toLowerCase();
    if (volatileQueryKeys.contains(key) ||
        volatileQueryKeys.contains(lowerKey) ||
        lowerKey.contains('token') ||
        lowerKey.contains('ticket') ||
        lowerKey.contains('jsession')) {
      return;
    }
    keptQueryParameters[key] = value;
  });

  // Drop path-embedded ;jsessionid=...
  final cleanedPath = uri.path.replaceAll(
    RegExp(r';jsessionid=[^;/]+', caseSensitive: false),
    '',
  );

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: cleanedPath.isEmpty ? '/' : cleanedPath,
    queryParameters: keptQueryParameters.isEmpty ? null : keptQueryParameters,
  ).toString();
}

/// Builds a shorter replay path for quick import:
/// login-related steps + navigate(scriptPageUrl), dropping intermediate menu
/// clicks after authentication. Returns [originalSteps] when acceleration is
/// not beneficial or [scriptPageUrl] is missing.
List<MacroStep> buildAcceleratedMacroSteps(
  List<MacroStep> originalSteps, {
  String? scriptPageUrl,
  String? importUrl,
}) {
  if (originalSteps.isEmpty) {
    return originalSteps;
  }

  final authPrefix = _macroAuthPrefixSteps(originalSteps);
  // No identifiable login prefix → cannot safely skip anything.
  if (authPrefix.isEmpty) {
    return originalSteps;
  }
  final droppedStepCount = originalSteps.length - authPrefix.length;
  // Need at least two post-auth steps to make skipping worthwhile.
  if (droppedStepCount < 2) {
    return originalSteps;
  }

  final sanitizedScriptPageUrl = sanitizeWarehouseScriptPageUrl(scriptPageUrl);
  final sanitizedImportUrl = sanitizeWarehouseScriptPageUrl(importUrl);

  // Prefer an explicit script page (e.g. schedule HTML). Fall back to dropping
  // post-login menu clicks only — many API adapters can run on any logged-in page.
  if (sanitizedScriptPageUrl != null) {
    if (sanitizedImportUrl != null &&
        sanitizedImportUrl == sanitizedScriptPageUrl) {
      // Entry page already is the script page: still skip redundant post-login
      // clicks when the full recording has extra navigation.
      return authPrefix;
    }
    return <MacroStep>[
      ...authPrefix,
      MacroStep.navigate(sanitizedScriptPageUrl),
      MacroStep.delay(1000),
    ];
  }

  // Legacy macros without scriptPageUrl: keep login, drop the rest.
  return authPrefix;
}

/// Steps up to and including login submit after the last fill / password wait.
List<MacroStep> _macroAuthPrefixSteps(List<MacroStep> originalSteps) {
  var lastAuthStepIndex = -1;
  for (var index = 0; index < originalSteps.length; index++) {
    final stepType = originalSteps[index].type;
    if (stepType == MacroStepType.fillField ||
        stepType == MacroStepType.waitForManualInput) {
      lastAuthStepIndex = index;
    }
  }

  if (lastAuthStepIndex < 0) {
    return const <MacroStep>[];
  }

  var authPrefixEndIndex = lastAuthStepIndex;
  for (
    var index = lastAuthStepIndex + 1;
    index < originalSteps.length && index <= lastAuthStepIndex + 3;
    index++
  ) {
    final stepType = originalSteps[index].type;
    if (stepType == MacroStepType.click) {
      authPrefixEndIndex = index;
      if (index + 1 < originalSteps.length &&
          originalSteps[index + 1].type == MacroStepType.delay) {
        authPrefixEndIndex = index + 1;
      }
      break;
    }
    if (stepType == MacroStepType.delay) {
      authPrefixEndIndex = index;
      continue;
    }
    break;
  }

  return originalSteps.sublist(0, authPrefixEndIndex + 1);
}

/// 录制状态
enum MacroRecordingState { idle, recording, stopped }
