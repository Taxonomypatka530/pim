import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/workspace_manager.dart';
import '../state/app_controller.dart';
import 'brand/theme.dart';
import 'widgets/device_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<AppController>().me.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final l = AppLocalizations.of(context);
    final wm = context.read<WorkspaceManager>();
    await context.read<AppController>().setDeviceName(_name.text);
    wm.broadcastProfile();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.watch<AppController>();
    final me = c.me;

    final nameCard = _SettingsCard(
      title: l.deviceNameLabel,
      icon: Icons.badge_rounded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: TextField(
          controller: _name,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveName(),
          decoration: InputDecoration(
            helperText: l.deviceNameHint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check_rounded),
              tooltip: l.save,
              onPressed: _saveName,
            ),
          ),
        ),
      ),
    );

    final appearanceCard = _SettingsCard(
      title: l.appearance,
      icon: Icons.palette_rounded,
      child: Column(
        children: [
          _ChoiceTile(
            icon: Icons.brightness_auto_rounded,
            label: l.themeSystem,
            selected: c.themeMode == ThemeMode.system,
            onTap: () => c.setThemeMode(ThemeMode.system),
          ),
          _ChoiceTile(
            icon: Icons.light_mode_rounded,
            label: l.themeLight,
            selected: c.themeMode == ThemeMode.light,
            onTap: () => c.setThemeMode(ThemeMode.light),
          ),
          _ChoiceTile(
            icon: Icons.dark_mode_rounded,
            label: l.themeDark,
            selected: c.themeMode == ThemeMode.dark,
            onTap: () => c.setThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );

    final languageCard = _SettingsCard(
      title: l.language,
      icon: Icons.translate_rounded,
      child: Column(
        children: [
          _ChoiceTile(
            icon: Icons.public_rounded,
            label: l.systemDefault,
            selected: c.locale == null,
            onTap: () => c.setLocale(null),
          ),
          _ChoiceTile(
            icon: Icons.abc_rounded,
            label: l.english,
            selected: c.locale?.languageCode == 'en',
            onTap: () => c.setLocale(const Locale('en')),
          ),
          _ChoiceTile(
            icon: Icons.abc_rounded,
            label: l.ukrainian,
            selected: c.locale?.languageCode == 'uk',
            onTap: () => c.setLocale(const Locale('uk')),
          ),
        ],
      ),
    );

    final identityCard = _SettingsCard(
      title: l.identity,
      icon: Icons.fingerprint_rounded,
      child: Column(
        children: [
          _InfoTile(
            icon: platformIcon(me.platform),
            label: l.platformLabel,
            value: me.platform,
          ),
          _InfoTile(
            icon: Icons.fingerprint_rounded,
            label: l.deviceId,
            value: me.deviceId,
          ),
        ],
      ),
    );

    final cards = [nameCard, appearanceCard, languageCard, identityCard];

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const maxContent = 980.0;
          final avail = math.min(constraints.maxWidth, maxContent);
          final wide = avail >= 720;
          final cardW = wide ? (avail - 48) / 2 : avail - 32;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContent),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final card in cards)
                      SizedBox(width: cardW, child: card),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = BrandColors.of(context).accent;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = BrandColors.of(context).accent;
    return ListTile(
      leading: icon == null
          ? null
          : Icon(icon, color: selected ? accent : scheme.onSurfaceVariant),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: accent)
          : Icon(Icons.circle_outlined, color: scheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(label),
      subtitle: Text(value, style: TextStyle(color: scheme.onSurfaceVariant)),
    );
  }
}
