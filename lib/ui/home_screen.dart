import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/platform.dart';
import '../l10n/app_localizations.dart';
import '../models/device_specs.dart';
import '../models/workspace.dart';
import '../services/workspace_manager.dart';
import '../state/app_controller.dart';
import 'brand/logo.dart';
import 'brand/theme.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'widgets/device_card.dart';
import 'widgets/radar_pulse.dart';
import 'widgets/text_prompt_dialog.dart';
import 'workspace_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final app = context.watch<AppController>();
    final wm = context.watch<WorkspaceManager>();
    final peers = app.peers;
    final workspaces = wm.workspaces;
    final invites = wm.pendingInvites;

    return Scaffold(
      // On desktop the logo + Settings live in the custom window bar, so the
      // home screen needs no app bar of its own. On mobile show a wordmark bar
      // with a Settings action.
      appBar: isDesktopWindowing
          ? null
          : AppBar(
              title: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: PimLogo(height: 22),
              ),
              actions: [
                IconButton(
                  tooltip: l.settings,
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createWorkspace(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text(l.createWorkspace),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          _SelfCard(
            name: app.me.name,
            address: app.localAddress,
            specs: app.specs,
          ),
          for (final inv in invites)
            _InviteCard(key: ValueKey(inv.workspace.id), invite: inv),
          _SectionHeader(title: l.workspaces),
          if (workspaces.isEmpty)
            _InlineHint(
              icon: Icons.workspaces_outline,
              title: l.noWorkspacesTitle,
              hint: l.noWorkspacesHint,
            )
          else
            for (final w in workspaces)
              _WorkspaceCard(workspace: w, myId: app.me.deviceId),
          _SectionHeader(
            title: l.onlineDevices,
            trailing: peers.isEmpty ? null : _CountBadge(count: peers.length),
          ),
          if (peers.isEmpty)
            _SearchingInline(l: l)
          else
            for (var i = 0; i < peers.length; i++)
              _AnimatedEntry(
                key: ValueKey(peers[i].id),
                index: i,
                child: DeviceCard(
                  device: peers[i],
                  messageCount: app.messageCountWith(peers[i].id),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(peerId: peers[i].id),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _createWorkspace(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final wm = context.read<WorkspaceManager>();
    final name = await promptText(
      context,
      title: l.createWorkspace,
      label: l.workspaceName,
      confirmLabel: l.create,
      capitalizeSentences: true,
    );
    if (name == null || name.trim().isEmpty) return;
    final ws = wm.createWorkspace(name);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WorkspaceScreen(workspaceId: ws.id)),
      );
    }
  }
}

/// Section title with an optional trailing widget.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A compact, consistent notification card: an icon badge, a title, an optional
/// subtitle, and a right-aligned row of actions. Shared by every screen-share
/// prompt and the workspace invite so they all look identical and tidy.
class _ActionBanner extends StatelessWidget {
  const _ActionBanner({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = scheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.09), scheme.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: c, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  actions[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A workspace row on the home screen.
class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.workspace, required this.myId});
  final Workspace workspace;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkspaceScreen(workspaceId: workspace.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.workspaces_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${l.membersCount(workspace.members.length)}'
                      '${workspace.isOwner(myId) ? ' · ${l.owner}' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// An incoming workspace invitation — accept to join and open the workspace.
class _InviteCard extends StatelessWidget {
  const _InviteCard({super.key, required this.invite});
  final WorkspaceInvite invite;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _ActionBanner(
      icon: Icons.mark_email_unread_rounded,
      title: l.invitePrefix(invite.fromName),
      subtitle: '"${invite.workspace.name}"',
      actions: [
        TextButton(
          onPressed: () =>
              context.read<WorkspaceManager>().declineInvite(invite),
          child: Text(l.decline),
        ),
        FilledButton(
          onPressed: () async {
            final wm = context.read<WorkspaceManager>();
            final navigator = Navigator.of(context);
            final id = invite.workspace.id;
            await wm.acceptInvite(invite);
            navigator.push(
              MaterialPageRoute(
                builder: (_) => WorkspaceScreen(workspaceId: id),
              ),
            );
          },
          child: Text(l.accept),
        ),
      ],
    );
  }
}

/// Compact empty hint for a section.
class _InlineHint extends StatelessWidget {
  const _InlineHint({
    required this.icon,
    required this.title,
    required this.hint,
  });
  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "scanning the network" row for the empty devices section.
class _SearchingInline extends StatelessWidget {
  const _SearchingInline({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = BrandColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          RadarPulse(size: 44, color: brand.accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.noDevicesTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  l.scanningNetwork,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades + slides a child in once when it first appears in the list.
/// Keyed by peer id so periodic list refreshes don't re-trigger it.
class _AnimatedEntry extends StatefulWidget {
  const _AnimatedEntry({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final delayMs = (widget.index * 45).clamp(0, 220);
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

class _SelfCard extends StatelessWidget {
  const _SelfCard({
    required this.name,
    required this.address,
    required this.specs,
  });

  final String name;
  final String? address;
  final DeviceSpecs specs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // White ink over the red hero card.
    final ink = scheme.onPrimary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Red gradient base.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      Color.lerp(scheme.primary, scheme.onPrimary, 0.14)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Device visual on the right, bleeding off the edge.
            Positioned(
              right: -18,
              top: -8,
              bottom: -8,
              child: SizedBox(
                width: 220,
                child: Image.asset(
                  'assets/pc.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
            // Scrim so the image dissolves into the card on the left and text
            // stays readable even when pills overlap it.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      scheme.primary,
                      scheme.primary.withValues(alpha: 0.0),
                    ],
                    stops: const [0.35, 0.78],
                  ),
                ),
              ),
            ),
            // Content.
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.thisDevice.toUpperCase(),
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (address != null)
                        _SpecPill(
                            icon: Icons.wifi_rounded,
                            text: address!,
                            ink: ink),
                      if (specs.hasOs)
                        _SpecPill(
                            icon: Icons.terminal_rounded,
                            text: specs.osName,
                            ink: ink),
                      if (specs.hasCpuName)
                        _SpecPill(
                            icon: Icons.memory_rounded,
                            text: specs.cpuName,
                            ink: ink),
                      if (specs.hasCpu)
                        _SpecPill(
                          icon: Icons.developer_board_rounded,
                          text: specs.cpuArch.isNotEmpty
                              ? '${l.coresLabel(specs.cpuCores)} · ${specs.cpuArch}'
                              : l.coresLabel(specs.cpuCores),
                          ink: ink,
                        ),
                      if (specs.hasRam)
                        _SpecPill(
                            icon: Icons.storage_rounded,
                            text: specs.ramLabel,
                            ink: ink),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small icon+value chip used inside the device hero card.
class _SpecPill extends StatelessWidget {
  const _SpecPill({
    required this.icon,
    required this.text,
    required this.ink,
  });

  final IconData icon;
  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ink.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

