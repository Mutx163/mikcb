import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../providers/timetable_provider.dart';
import '../services/lan_edit_network_utils.dart';
import '../services/lan_edit_provider_host.dart';
import '../services/lan_edit_server_service.dart';
import '../services/lan_edit_session.dart';

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
            : encodeLanEditUrl(
                host: ip,
                port: _server.port!,
                pin: session.pin,
              );
      });
      _startStatusTimer();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.lanEditStartFailed}: $error',
            ),
          ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.lanEditCopied)),
    );
  }

  String _formatLastActivity(AppLocalizations l10n, DateTime time) {
    return DateFormat.yMd().add_Hms().format(time);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRunning = _server.isRunning;
    final session = _session;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lanEditTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.lanEditIntro,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (!isRunning)
                    FilledButton.icon(
                      onPressed: _isStarting ? null : _startServer,
                      icon: _isStarting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering_rounded),
                      label: Text(l10n.lanEditStart),
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed: _isStopping ? null : _stopServer,
                      icon: _isStopping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.stop_circle_outlined),
                      label: Text(l10n.lanEditStop),
                    ),
                ],
              ),
            ),
          ),
          if (isRunning && session != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.lanEditStatusRunning,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_lanAddress != null && _lanAddress!.isNotEmpty) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _lanAddress!,
                            version: QrVersions.auto,
                            size: MediaQuery.of(context).size.width * 0.5,
                            gapless: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.lanEditQrHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _InfoRow(
                      label: l10n.lanEditAddressLabel,
                      value: _lanAddress ?? l10n.lanEditAddressUnavailable,
                      trailing: _lanAddress == null
                          ? null
                          : IconButton(
                              tooltip: l10n.lanEditCopyAddress,
                              onPressed: _copyAddress,
                              icon: const Icon(Icons.copy_rounded),
                            ),
                    ),
                    _InfoRow(
                      label: l10n.lanEditPinLabel,
                      value: session.pin,
                    ),
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
                      value: _formatLastActivity(
                        l10n,
                        session.lastActivityAt,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.lanEditHotspotHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
