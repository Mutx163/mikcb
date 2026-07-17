import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../services/import_random_color_preferences.dart';

/// Master switch for random course colors on the course import hub page.
class ImportRandomColorToggle extends StatefulWidget {
  const ImportRandomColorToggle({super.key});

  @override
  State<ImportRandomColorToggle> createState() =>
      _ImportRandomColorToggleState();
}

class _ImportRandomColorToggleState extends State<ImportRandomColorToggle> {
  bool _enabled = ImportRandomColorPreferences.defaultEnabled;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final enabled = await ImportRandomColorPreferences.isEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = enabled;
      _loaded = true;
    });
  }

  Future<void> _onChanged(bool value) async {
    setState(() {
      _enabled = value;
    });
    await ImportRandomColorPreferences.setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosListGroup(
      children: [
        HyperosSwitchTile(
          icon: Icons.palette_outlined,
          iconAccent: HyperosIconColors.purple,
          title: l10n.importRandomCourseColorTitle,
          subtitle: l10n.importRandomCourseColorSubtitle,
          value: _enabled,
          onChanged: _loaded ? _onChanged : null,
        ),
      ],
    );
  }
}
