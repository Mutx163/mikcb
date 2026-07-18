import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// Aggregated license texts for one package (from [LicenseRegistry]).
@visibleForTesting
class OpenSourcePackageLicense {
  const OpenSourcePackageLicense({
    required this.packageName,
    required this.licenseBodies,
  });

  final String packageName;
  final List<String> licenseBodies;

  String get combinedLicenseText => licenseBodies.join('\n\n---\n\n');
}

/// Loads and groups [LicenseRegistry] entries by package name (sorted).
@visibleForTesting
Future<List<OpenSourcePackageLicense>> loadOpenSourcePackageLicenses() async {
  final bodiesByPackage = <String, List<String>>{};

  await for (final entry in LicenseRegistry.licenses) {
    final paragraphs = entry.paragraphs
        .map((paragraph) => paragraph.text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    if (paragraphs.isEmpty) {
      continue;
    }
    final body = paragraphs.join('\n\n');
    for (final packageName in entry.packages) {
      final name = packageName.trim();
      if (name.isEmpty) {
        continue;
      }
      bodiesByPackage.putIfAbsent(name, () => <String>[]).add(body);
    }
  }

  final packages =
      bodiesByPackage.entries
          .map(
            (entry) => OpenSourcePackageLicense(
              packageName: entry.key,
              licenseBodies: entry.value,
            ),
          )
          .toList(growable: false)
        ..sort(
          (left, right) => left.packageName.toLowerCase().compareTo(
            right.packageName.toLowerCase(),
          ),
        );
  return packages;
}

/// Dedicated about subpage: app license summary + auto package license list.
class OpenSourceLicensesScreen extends StatefulWidget {
  const OpenSourceLicensesScreen({super.key});

  @override
  State<OpenSourceLicensesScreen> createState() =>
      _OpenSourceLicensesScreenState();
}

class _OpenSourceLicensesScreenState extends State<OpenSourceLicensesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<OpenSourcePackageLicense> _packages = const [];
  bool _isLoading = true;
  String? _loadError;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLicenses() async {
    try {
      final packages = await loadOpenSourcePackageLicenses();
      if (!mounted) {
        return;
      }
      setState(() {
        _packages = packages;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = '$error';
      });
    }
  }

  List<OpenSourcePackageLicense> get _filteredPackages {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _packages;
    }
    return _packages
        .where((package) => package.packageName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _openPackageDetail(OpenSourcePackageLicense package) {
    Navigator.of(context).push(
      HyperosPageRoute(
        settings: RouteSettings(
          name: '/about/oss-licenses/${package.packageName}',
        ),
        builder: (_) => _OpenSourceLicenseDetailScreen(package: package),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filteredPackages;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.aboutOpenSourceLicensesTitle),
      headerExtension: HyperosBlurredHeaderExtension(
        child: HyperosTextField(
          controller: _searchController,
          hint: l10n.aboutOpenSourceLicensesSearchHint,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            setState(() => _query = value);
          },
        ),
      ),
      child: HyperosListView(
        children: [
          HyperosControlCard(
            title: l10n.aboutOpenSourceLicensesAppSectionTitle,
            child: HyperosControlCardInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aboutOpenSourceLicensesAppLicenseLabel,
                    style: HyperosTypography.listDetail(context).copyWith(
                      color: HyperosColors.primaryText(context),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.aboutOpenSourceLicensesIntro,
                    style: HyperosTypography.listDetail(context).copyWith(
                      color: HyperosColors.primaryText(context),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.aboutOpenSourceLicensesExtraUmeng,
                    style: HyperosTypography.listDetail(context).copyWith(
                      color: HyperosColors.primaryText(context),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(
            text: l10n.aboutOpenSourceLicensesPackagesSectionTitle(
              _isLoading ? 0 : _packages.length,
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: HyperosCircularProgress()),
            )
          else if (_loadError != null)
            HyperosHintBanner(
              icon: const Icon(Icons.error_outline_rounded, size: 18),
              title: Text(l10n.aboutOpenSourceLicensesLoadFailed),
            )
          else if (filtered.isEmpty)
            HyperosHintBanner(
              icon: const Icon(Icons.search_off_rounded, size: 18),
              title: Text(l10n.aboutOpenSourceLicensesEmpty),
            )
          else
            HyperosListGroup(
              children: [
                for (final package in filtered)
                  HyperosListTile(
                    icon: Icons.description_outlined,
                    title: package.packageName,
                    details: l10n.aboutOpenSourceLicensesPackageSubtitle(
                      package.licenseBodies.length,
                    ),
                    onTap: () => _openPackageDetail(package),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OpenSourceLicenseDetailScreen extends StatelessWidget {
  const _OpenSourceLicenseDetailScreen({required this.package});

  final OpenSourcePackageLicense package;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = HyperosTypography.listDetail(
      context,
    ).copyWith(color: HyperosColors.primaryText(context), height: 1.45);

    // Use [HyperosListView] (not a bare SingleChildScrollView with parent
    // context inset): header inset only exists under [HyperosSubpage]'s
    // [HyperosBlurredHeaderScope]. Reading inset from this State's context
    // returns 0 and parks body text under the title bar.
    //
    // [SelectionArea] + [Text] keeps long licenses scrollable; [SelectableText]
    // would compete for vertical drag again.
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(package.packageName),
      child: SelectionArea(
        child: HyperosListView(
          children: [
            HyperosControlCard(
              child: HyperosControlCardInset(
                child: Text(package.combinedLicenseText, style: bodyStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
