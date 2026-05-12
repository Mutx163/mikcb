import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'about_screen.dart';

class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  List<_ChangelogEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    // 简单方式：直接加载已知的 release notes 文件
    // 由于 AssetManifest 解析较复杂，我们直接遍历已知版本
    final versions = _getKnownVersions();
    final entries = <_ChangelogEntry>[];

    for (final version in versions) {
      try {
        final data = await rootBundle.loadString('docs/releases/$version.md');
        entries.add(_ChangelogEntry(version: version, content: data));
      } catch (_) {
        // 文件不存在，跳过
      }
    }

    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  List<String> _getKnownVersions() {
    // 返回所有已知版本，按倒序排列（最新在前）
    return [
      'v1.2.1.1',
      'v1.2.1',
      'v1.2.0.30',
      'v1.2.0.29',
      'v1.2.0.28',
      'v1.2.0.27',
      'v1.2.0.24',
      'v1.2.0.22',
      'v1.2.0.20',
      'v1.2.0.19',
      'v1.2.0.18',
      'v1.2.0.17',
      'v1.2.0.16',
      'v1.2.0.15',
      'v1.2.0.12',
      'v1.2.0.11',
      'v1.2.0.10',
      'v1.2.0.9',
      'v1.2.0.8',
      'v1.2.0.7',
      'v1.2.0.6',
      'v1.2.0.5',
      'v1.2.0.4',
      'v1.2.0.2',
      'v1.2.0.1',
      'v1.1.10.28',
      'v1.1.10.24',
      'v1.1.10.23',
      'v1.1.10.22',
      'v1.1.10.21',
      'v1.1.10.20',
      'v1.1.10.19',
      'v1.1.10.18',
      'v1.1.10.17',
      'v1.1.10.16',
      'v1.1.10.15',
      'v1.1.10.13',
      'v1.1.10.12',
      'v1.1.10.11',
      'v1.1.10.10',
      'v1.1.10.9',
      'v1.1.10.8',
      'v1.1.10.7',
      'v1.1.10.6',
      'v1.1.10.5',
      'v1.1.10.4',
      'v1.1.10.3',
      'v1.1.10.2',
      'v1.1.10.1',
      'v1.1.10',
      'v1.1.9.7',
      'v1.1.9.6',
      'v1.1.9.5',
      'v1.1.9.4',
      'v1.1.9.3',
      'v1.1.9.2',
      'v1.1.9.1',
      'v1.1.8.2',
      'v1.1.8.1',
      'v1.1.8',
      'v1.1.7.1',
      'v1.1.7',
      'v1.1.6',
      'v1.1.5-a',
      'v1.1.4',
      'v1.1.3',
      'v1.1.2',
      'v1.1.1',
      'v1.1.0',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更新日志'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return _ChangelogCard(entry: entry);
              },
            ),
    );
  }
}

class _ChangelogEntry {
  final String version;
  final String content;

  const _ChangelogEntry({required this.version, required this.content});
}

class _ChangelogCard extends StatefulWidget {
  final _ChangelogEntry entry;

  const _ChangelogCard({required this.entry});

  @override
  State<_ChangelogCard> createState() => _ChangelogCardState();
}

class _ChangelogCardState extends State<_ChangelogCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.entry.version,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                ReleaseNotesMarkdown(
                  data: widget.entry.content,
                  onTapLink: (href) {
                    if (href != null) {
                      // 可以处理链接点击
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
