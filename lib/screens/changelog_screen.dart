import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/utils/release_notes_digest.dart';
import 'package:university_timetable/widgets/release_digest_view.dart';
import '../widgets/release_notes_markdown.dart';

/// `docs/releases/<version>.md` 的 asset key 匹配规则。
/// 目录同时打包了 html / json 等文件，正则只接受数字版本号（允许 -a 等后缀）。
final RegExp releaseAssetKeyPattern = RegExp(
  r'^docs/releases/(v\d+(?:\.\d+)*(?:-[\w.]+)?)\.md$',
);

/// 按语义版本号倒序排列（最新在前），如 v2.1.1.4 > v2.1.1 > v2.0.5.6。
///
/// 不再是 `@visibleForTesting`：调试页的「模拟收到新版本更新」也要扫同一份
/// `docs/releases/` 资源来取演示正文，两边共用一个排序口径（见
/// `hyperos_showcase_screen.dart` 的 `_loadNewestReleaseNotes`）。
int compareReleaseVersionsDesc(String a, String b) {
  final va = parseReleaseVersion(a);
  final vb = parseReleaseVersion(b);
  for (var i = 0; i < va.length || i < vb.length; i++) {
    final na = i < va.length ? va[i] : 0;
    final nb = i < vb.length ? vb[i] : 0;
    if (na != nb) return nb.compareTo(na);
  }
  return 0;
}

/// 匹配 asset key 中的版本号，如 docs/releases/v2.1.1.4.md → v2.1.1.4。
/// 严格限定数字段（可选 - 后缀），避免误配同目录的 .html 等非版本文件。
///
/// 同 [compareReleaseVersionsDesc]：调试页的更新弹窗演示也用这一条扫描。
String? matchReleaseAssetKey(String assetKey) {
  final match = releaseAssetKeyPattern.firstMatch(assetKey);
  return match?.group(1);
}

/// 解析版本字符串中的数字段，如 v2.1.1.4 → [2, 1, 1, 4]。
List<int> parseReleaseVersion(String version) {
  final match = RegExp(r'v?(\d+(?:\.\d+)*)').firstMatch(version);
  if (match == null) return const [0];
  return match.group(1)!.split('.').map(int.parse).toList();
}

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
    // 自动扫描资源中的 docs/releases/*.md 文件，按版本号倒序展示。
    // 新增版本只需放入对应 md 文件即可，无需再维护硬编码版本列表。
    List<String> versions;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      versions = manifest
          .listAssets()
          .map(matchReleaseAssetKey)
          .whereType<String>()
          .toSet()
          .toList();
      versions.sort(compareReleaseVersionsDesc);
    } catch (e) {
      // AssetManifest 解析失败时回退到硬编码列表，保证页面仍可用
      debugPrint('ChangelogScreen: AssetManifest scan failed, fallback: $e');
      versions = _getKnownVersions();
    }

    if (versions.isEmpty) {
      // 无 release notes 时直接展示空列表，不再回退扫描硬编码列表
      if (mounted) {
        setState(() {
          _entries = [];
          _loading = false;
        });
      }
      return;
    }

    // 并发加载所有 md 文件，结果顺序与倒序列表一致
    final results = await Future.wait(versions.map(_loadEntry));
    final entries = results.whereType<_ChangelogEntry>().toList();

    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<_ChangelogEntry?> _loadEntry(String version) async {
    try {
      final data = await rootBundle.loadString('docs/releases/$version.md');
      // 解析成结构化摘要（重点、分类计数、完整条目）在加载时做一次：
      // 卡片展开/收起只做展示，不必每次重建都重新解析几十条正文。
      return _ChangelogEntry(
        version: version,
        content: data,
        digest: buildReleaseNotesDigest(data),
      );
    } catch (_) {
      // 文件读取失败，跳过
      return null;
    }
  }

  List<String> _getKnownVersions() {
    // AssetManifest 解析失败时的回退版本列表，按倒序排列（最新在前）
    return [
      'v2.1.1.9',
      'v2.1.1.8',
      'v2.1.1.7',
      'v2.1.1.6',
      'v2.1.1.5',
      'v2.1.1.4',
      'v2.1.1.3',
      'v2.1.1.2',
      'v2.1.1.1',
      'v2.1.1',
      'v2.1.0',
      'v2.0.5.6',
      'v2.0.5.5',
      'v2.0.5.4',
      'v2.0.5.3',
      'v2.0.5.2',
      'v2.0.5.1',
      'v2.0.5',
      'v2.0.4.5',
      'v2.0.4.4',
      'v2.0.4.3',
      'v2.0.4.2',
      'v2.0.4.1',
      'v2.0.4',
      'v2.0.3',
      'v2.0.2',
      'v2.0.1',
      'v2.0',
      'v1.3.2',
      'v1.3.1',
      'v1.3',
      'v1.2.1.15',
      'v1.2.1.14',
      'v1.2.1.13',
      'v1.2.1.12',
      'v1.2.1.11',
      'v1.2.1.9',
      'v1.2.1.8',
      'v1.2.1.7',
      'v1.2.1.6',
      'v1.2.1.5',
      'v1.2.1.4',
      'v1.2.1.3',
      'v1.2.1.2',
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
      'v1.1.10.14',
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
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.aboutChangelogTitle),
      // Standard list path (header inset inside the scrollable + notification
      // bubbling) so the large title collapses; the old BodyInset +
      // includeHeaderInset:false combo swallowed vertical scroll notifications
      // and froze the large title.
      child: _loading
          // Non-scroll centered view: inset below the bar manually.
          ? const HyperosBlurredBodyInset(
              child: Center(child: HyperosCircularProgress()),
            )
          : HyperosListView(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                // 默认全部收起：一版动辄几十条，进页面先看到每版的
                // 「3 条重点 + 分类计数」，想读细节再点开。
                return _ChangelogCard(entry: entry);
              },
            ),
    );
  }
}

class _ChangelogEntry {
  final String version;
  final String content;
  final ReleaseNotesDigest digest;

  const _ChangelogEntry({
    required this.version,
    required this.content,
    required this.digest,
  });
}

class _ChangelogCard extends StatelessWidget {
  const _ChangelogCard({required this.entry});

  final _ChangelogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = MiuixTheme.of(context);
    final colors = theme.colors;
    final textStyles = theme.textStyles;
    final digest = entry.digest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HyperosCard(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  HyperosTag(
                    label: entry.version,
                    backgroundColor: colors.surfaceContainerHigh,
                  ),
                ],
              ),
              if (digest.intro.isNotEmpty) ...[
                const SizedBox(height: 8),
                MiuixText(
                  digest.intro,
                  style: textStyles.footnote1,
                  color: colors.onSurfaceSecondary,
                  height: 1.45,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              // 老版本里可能有解析不出条目的正文（纯段落），退回原文渲染，
              // 不让「更新了但这里什么都没有」发生。
              if (digest.isEmpty)
                ReleaseNotesMarkdown(
                  data: entry.content,
                  plainTypography: true,
                  usePrimaryTextColor: true,
                  onTapLink: (href) {},
                )
              else
                ReleaseDigestView(
                  digest: digest,
                  groupEntries: true,
                  alwaysExpandable: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
