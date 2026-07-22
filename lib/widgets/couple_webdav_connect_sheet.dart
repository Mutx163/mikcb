import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/couple_webdav_config.dart';
import '../services/couple_webdav_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import 'course_field_picker_sheet.dart';

class CoupleWebdavConnectResult {
  const CoupleWebdavConnectResult({
    required this.username,
    required this.password,
    required this.mySlot,
  });

  final String username;
  final String password;

  /// This device's dual-slot id (1 or 2). Must differ from the partner's.
  final int mySlot;
}

class CoupleWebdavConnectSheet extends StatefulWidget {
  const CoupleWebdavConnectSheet({
    super.key,
    required this.service,
    required this.config,
  });

  final CoupleWebdavService service;
  final CoupleWebdavConfig config;

  @override
  State<CoupleWebdavConnectSheet> createState() =>
      _CoupleWebdavConnectSheetState();
}

class _CoupleWebdavConnectSheetState extends State<CoupleWebdavConnectSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _testing = false;
  bool _connecting = false;
  late int _mySlot;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.config.username);
    _passwordController = TextEditingController();
    _mySlot = widget.config.normalizedMySlot;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _testConnection() async {
    final password = _passwordController.text;
    if (_usernameController.text.trim().isEmpty || password.isEmpty) {
      return false;
    }
    setState(() => _testing = true);
    try {
      await widget.service.testConnection(
        config: widget.config.copyWith(
          username: _usernameController.text.trim(),
        ),
        username: _usernameController.text.trim(),
        password: password,
      );
      if (!mounted) {
        return false;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.coupleWebdavTestSuccess,
        kind: AppToastKind.success,
      );
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.coupleWebdavTestFailed,
        kind: AppToastKind.error,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _confirmConnect() async {
    if (_connecting) {
      return;
    }
    setState(() => _connecting = true);
    try {
      final ok = await _testConnection();
      if (!ok || !mounted) {
        return;
      }
      Navigator.of(context).pop(
        CoupleWebdavConnectResult(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          mySlot: _mySlot,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PickerSheetScaffold(
      actions: Row(
        children: [
          Expanded(
            child: HyperosButton(
              label: l10n.cloudSyncTestConnection,
              variant: HyperosButtonVariant.secondary,
              loading: _testing,
              onPressed: _testing || _connecting ? null : _testConnection,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: HyperosButton(
              label: l10n.coupleWebdavConfirmConnect,
              loading: _connecting,
              onPressed: _connecting ? null : _confirmConnect,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.coupleWebdavLoginSheetTitle,
            style: HyperosTypography.sheetTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.coupleWebdavLoginSheetSubtitle,
            style: HyperosTypography.sectionDescription(context),
          ),
          const SizedBox(height: 16),
          HyperosTextField(
            controller: _usernameController,
            label: l10n.cloudSyncUsernameLabel,
            hint: l10n.cloudSyncUsernameHint,
          ),
          const SizedBox(height: 12),
          HyperosTextField(
            controller: _passwordController,
            label: l10n.cloudSyncPasswordLabel,
            hint: l10n.cloudSyncPasswordHint,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.coupleWebdavMySlotLabel,
            style: HyperosTypography.sectionDescription(context),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.coupleWebdavSlotOne,
                  variant: _mySlot == 1
                      ? HyperosButtonVariant.primary
                      : HyperosButtonVariant.secondary,
                  onPressed: _connecting || _testing
                      ? null
                      : () => setState(() => _mySlot = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HyperosButton(
                  label: l10n.coupleWebdavSlotTwo,
                  variant: _mySlot == 2
                      ? HyperosButtonVariant.primary
                      : HyperosButtonVariant.secondary,
                  onPressed: _connecting || _testing
                      ? null
                      : () => setState(() => _mySlot = 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.coupleWebdavMySlotHint,
            style: HyperosTypography.sectionDescription(context),
          ),
        ],
      ),
    );
  }
}
