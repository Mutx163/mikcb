// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 仓库导入判定策略
// 仓库导入链路的纯判定函数：无 UI 副作用，供页面与测试共用。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import 'package:flutter/material.dart';
import '../../../domain/warehouse_session_probe.dart';
import '../../../services/warehouse_import_preferences_service.dart';

bool shouldPromptRememberedLoginAutofill({
  required bool hasPasswordField,
  required WarehouseRememberedLogin? rememberedLogin,
  required WarehouseRememberedLogin candidate,
  required bool hasPromptedAutofill,
  required bool isPromptShowing,
  bool sessionActive = false,
}) {
  // sessionActive：探针已确认教务会话还在。此时屏幕上那张登录框是假的（强智登录页
  // 不看会话，无条件返回登录表单），弹「要不要帮你填密码」纯属噪音——用户点了也
  // 没地方填，填了也不会被用到。判据见 domain/warehouse_session_probe.dart。
  return hasPasswordField &&
      !sessionActive &&
      rememberedLogin != null &&
      rememberedLogin.password.isNotEmpty &&
      candidate.password.isEmpty &&
      !hasPromptedAutofill &&
      !isPromptShowing;
}

/// 登录尝试后是否应弹「记住密码？」。
/// 只有「已记住且密码完整」的条目才抑制提示；用户名-only 的残缺条目
/// （密码丢失的历史遗留）必须放行，否则凭据丢密码后就没有任何自动补录
/// 途径——输入新密码登录也不会再被记住。
bool shouldPromptRememberedLoginSave({
  required WarehouseRememberedLogin? rememberedLogin,
  required bool hasPromptedSave,
  required bool isPromptShowing,
  required String candidateUsername,
  required String candidatePassword,
}) {
  return !hasPromptedSave &&
      !isPromptShowing &&
      candidateUsername.isNotEmpty &&
      candidatePassword.isNotEmpty &&
      (rememberedLogin == null || rememberedLogin.password.isEmpty);
}

/// 「要不要帮你填密码」的决定是否应该等一等在途的会话探针。
///
/// onPageFinished 同一帧里背靠背发出两件事：收集登录框状态（纯 DOM，毫秒级
/// 回话）与会话探针（fetch 内页，一次网络往返）。弹窗判定若不等探针，「会话
/// 还在 → 不弹」的抑制就永远输给网络往返——入口页即登录页（强智标准形态）
/// 时，弹窗几乎必然在探针结论到达前弹出，而 _hasPromptedAutofill 置位后
/// 迟到的结论再也用不上。三个条件缺一不可：没配置的学校（200+ 所）探针根本
/// 不存在，行为必须与从前逐字节一致；非 unknown 的结论已经可以判；不在途
/// 说明这次探不动（跳过/冷却/超时已收），等不到结论。
bool sessionProbeMayStillSettle({
  required WarehouseSessionProbeConfig? config,
  required WarehouseSessionProbeVerdict verdict,
  required bool inFlight,
}) {
  return config != null &&
      verdict == WarehouseSessionProbeVerdict.unknown &&
      inFlight;
}

/// Whether ordinary web-login import should start background path recording.
///
/// Explicit "record import" always records. Automatic first-import recording
/// only runs when this school+adapter has no saved macro yet.
bool shouldAutoRecordWarehouseImport({
  required bool forceRecord,
  required bool hasExistingMacro,
}) {
  return forceRecord || !hasExistingMacro;
}

/// 返回摘除阈值：路由主动画反向走到这个值以下时，把 WebView 的平台视图摘出树。
///
/// 被动画的视觉位置吃 `Cubic(0.05, 0, 0.1333, 1)` 这条缓出曲线：动画值 0.35
/// 时页面已滑出约 73%，距离动画结束还有约 105ms —— 摘除是异步的（要走平台侧
/// 把真实视图从窗口上移除），必须留在这段窗口里完成，否则动画落地后它还会停在
/// 半路的位置上（真机现象：返回动画结束又闪回"半页"）。也不能取得更早：网页占
/// 页面主体，摘早了会在屏上留一大块空白滑出去。
///
/// 2026-10-06 拆分时去掉了 `@visibleForTesting`：它一直都被网页登录页的返回
/// 动画真正调用（不只是测试用），原标注是错的，只是当时同文件才没被 lint 抓到。
const double platformViewExitDetachThreshold = 0.35;

/// 是否到了"把网页的平台视图摘出树"的时机。
///
/// 只认反向（返回）动画且已滑出大半；进入动画（forward）与已落定（completed /
/// dismissed）一律不摘——落定那一帧路由正在被拆，不能再 setState。
bool shouldDetachPlatformViewOnExit({
  required AnimationStatus status,
  required double value,
}) {
  return status == AnimationStatus.reverse &&
      value <= platformViewExitDetachThreshold;
}

