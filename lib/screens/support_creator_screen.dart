import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../services/support_creator_service.dart';

class SupportCreatorScreen extends StatefulWidget {
  const SupportCreatorScreen({super.key});

  @override
  State<SupportCreatorScreen> createState() => _SupportCreatorScreenState();
}

class _SupportCreatorScreenState extends State<SupportCreatorScreen> {
  final SupportCreatorService _service = SupportCreatorService();
  late Future<SupportDonorData> _donorFuture;

  @override
  void initState() {
    super.initState();
    _donorFuture = _loadDonors();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('请作者喝杯咖啡'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.coffee_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '请作者喝杯咖啡',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '扫码支持，昵称会长期显示在鸣谢名单里。',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildQrCard(
                        context,
                        title: '微信',
                        assetPath: 'assets/donate/wechatpay.png',
                        fileName: 'qingyu_kebiao_wechatpay.png',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQrCard(
                        context,
                        title: '支付宝',
                        assetPath: 'assets/donate/alipay.png',
                        fileName: 'qingyu_kebiao_alipay.png',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<SupportDonorData>(
                    future: _donorFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('鸣谢名单'),
                                SizedBox(height: 12),
                                LinearProgressIndicator(minHeight: 3),
                              ],
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '鸣谢名单',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '暂时无法加载在线鸣谢名单。',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.tonalIcon(
                                  onPressed: _reloadDonors,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('重新加载'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final data = snapshot.data ??
                          const SupportDonorData(
                            donors: <SupportDonorEntry>[],
                          );
                      return _buildDonorCard(context, data);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQrCard(
    BuildContext context, {
    required String title,
    required String assetPath,
    required String fileName,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.qr_code_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: () =>
                    _showQrPreview(context, title: title, assetPath: assetPath),
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showQrPreview(
                    context,
                    title: title,
                    assetPath: assetPath,
                  ),
                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                  label: const Text('大图'),
                ),
                FilledButton.icon(
                  onPressed: () => _saveQrToGallery(
                    assetPath: assetPath,
                    fileName: fileName,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('相册'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorCard(BuildContext context, SupportDonorData data) {
    final theme = Theme.of(context);
    final donors = data.donors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title?.isNotEmpty == true ? data.title! : '鸣谢名单',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (data.subtitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          data.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '重新加载',
                  onPressed: _reloadDonors,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (data.updatedAt?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                '更新于 ${data.updatedAt!}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (donors.isEmpty)
              Text(
                '名单还没有填写，你可以直接编辑 docs/donors.json 后重新发布。',
                style: theme.textTheme.bodyMedium,
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: donors.length,
                  itemBuilder: (context, index) {
                    final donor = donors[index];
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  donor.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if ((donor.amount ?? '').isNotEmpty)
                                Text(
                                  donor.amount!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          if ((donor.date ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              donor.date!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if ((donor.message ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              donor.message!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveQrToGallery({
    required String assetPath,
    required String fileName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await _service.saveAssetImageToGallery(
        assetPath: assetPath,
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(saved ? '已保存到相册' : '保存到相册失败'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  void _showQrPreview(
    BuildContext context, {
    required String title,
    required String assetPath,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style:
                      Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _reloadDonors() {
    setState(() {
      _donorFuture = _loadDonors();
    });
  }

  Future<SupportDonorData> _loadDonors() {
    final mirrorUrlPrefix =
        context.read<TimetableProvider>().settings.appUpdateMirrorUrlPrefix;
    return _service.fetchDonors(mirrorUrlPrefix: mirrorUrlPrefix);
  }
}
