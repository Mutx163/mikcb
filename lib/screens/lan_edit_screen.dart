import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../services/lan_edit_network_utils.dart';
import '../services/lan_edit_provider_host.dart';
import '../services/lan_edit_server_service.dart';
import '../services/lan_edit_session.dart';
import '../ui/hyperos/hyperos.dart';

class LanEditScreen extends StatefulWidget {
  const LanEditScreen({super.key});

  @override
  State<LanEditScreen> createState() => _LanEditScreenState();
}

class _LanEditScreenState extends State<LanEditScreen>
    with WidgetsBindingObserver {
  final LanEditServerService _server = LanEditServerService();
  LanEditSession? _session;
  String? _lanAddress;
  bool _isStarting = false;
  bool _isStopping = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _server.onStopped = _handleServerStopped;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _server.onStopped = null;
    _server.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _server.isRunning && mounted) {
      setState(() {});
    }
  }

  void _handleServerStopped() {
    _statusTimer?.cancel();
    _statusTimer = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
      _lanAddress = null;
      _isStopping = false;
    });
  }

  void _startStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_server.isRunning) {
        return;
      }
      setState(() {});
    });
  }

  Future<void> _startServer() async {
    if (_server.isRunning || _isStarting) {
      return;
    }
    setState(() {
      _isStarting = true;
    });
    try {
      final provider = context.read<TimetableProvider>();
      await provider.initialize();
      final session = LanEditSession.create();
      final host = LanEditProviderHost(provider);
      await _server.start(host: host, session: session);
      final ip = await findPreferredLanIPv4();
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _lanAddress = ip == null
            ? null
            : encodeLanEditUrl(host: ip, port: _server.port!, pin: session.pin);
      });
      _startStatusTimer();
    } catch (error) {
      if (mounted) {
        showAppToast(
          context,
          message:
              '${AppLocalizations.of(context)!.lanEditStartFailed}: $error',
          kind: AppToastKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _stopServer() async {
    if (!_server.isRunning || _isStopping) {
      return;
    }
    setState(() {
      _isStopping = true;
    });
    await _server.stop();
  }

  Future<void> _copyAddress() async {
    final address = _lanAddress;
    if (address == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.lanEditCopied,
      kind: AppToastKind.success,
    );
  }

  String _formatLastActivity(AppLocalizations l10n, DateTime time) {
    return DateFormat.yMd().add_Hms().format(time);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final isRunning = _server.isRunning;
    final session = _session;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.lanEditTitle),
      child: HyperosListView(
        children: [
          HyperosSectionLabel(text: l10n.lanEditTitle),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: isRunning
                  ? HyperosButton(
                      label: l10n.lanEditStop,
                      variant: HyperosButtonVariant.secondary,
                      loading: _isStopping,
                      onPressed: _isStopping ? null : _stopServer,
                    )
                  : HyperosButton(
                      label: l10n.lanEditStart,
                      loading: _isStarting,
                      onPressed: _isStarting ? null : _startServer,
                    ),
            ),
          ),
          if (isRunning && session != null) ...[
            const HyperosSectionGap(),
            HyperosSectionLabel(text: l10n.lanEditStatusRunning),
            HyperosControlCard(
              child: HyperosControlCardInset(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_lanAddress != null && _lanAddress!.isNotEmpty) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            // Always white so dark theme does not wash the QR into gray.
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _lanAddress!,
                            version: QrVersions.auto,
                            size: MediaQuery.of(context).size.width * 0.5,
                            gapless: true,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.lanEditQrHint,
                        style: typo.xs2.copyWith(color: colors.mutedForeground),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _InfoRow(
                      label: l10n.lanEditAddressLabel,
                      value: _lanAddress ?? l10n.lanEditAddressUnavailable,
                      trailing: _lanAddress == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              color: HyperosColors.actionIcon(context),
                              onPressed: _copyAddress,
                            ),
                    ),
                    _InfoRow(label: l10n.lanEditPinLabel, value: session.pin),
                    _InfoRow(
                      label: l10n.lanEditPortLabel,
                      value: '${_server.port ?? '-'}',
                    ),
                    _InfoRow(
                      label: l10n.lanEditConnectedClientsLabel,
                      value: session.connectedClientCount == 0
                          ? l10n.lanEditConnectedClientsNone
                          : l10n.lanEditConnectedClientsValue(
                              session.connectedClientCount,
                            ),
                    ),
                    _InfoRow(
                      label: l10n.lanEditLastActivityLabel,
                      value: _formatLastActivity(l10n, session.lastActivityAt),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.lanEditHotspotHint,
                      style: typo.xs2.copyWith(color: colors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography.body;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: typo.xs2.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: typo.sm.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
