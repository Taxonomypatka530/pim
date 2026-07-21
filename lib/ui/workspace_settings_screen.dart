import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/workspace_manager.dart';
import '../state/app_controller.dart';
import 'brand/theme.dart';
import 'widgets/device_card.dart';

class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final ws = context.read<WorkspaceManager>().workspaceById(widget.workspaceId);
    _name = TextEditingController(text: ws?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _saveName() {
    final l = AppLocalizations.of(context);
    context.read<WorkspaceManager>().renameWorkspace(widget.workspaceId, _name.text);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final wm = context.watch<WorkspaceManager>();
    final app = context.watch<AppController>();
    final ws = wm.workspaceById(widget.workspaceId);

    if (ws == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return Scaffold(appBar: AppBar(title: Text(l.workspaceSettings)));
    }

    final myId = app.me.deviceId;
    final isOwner = ws.isOwner(myId);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.workspaceSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            title: l.workspaceName,
            icon: Icons.workspaces_rounded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: TextField(
                controller: _name,
                enabled: isOwner,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveName(),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  helperText: isOwner ? null : l.owner,
                  suffixIcon: isOwner
                      ? IconButton(
                          tooltip: l.save,
                          icon: const Icon(Icons.check_rounded),
                          onPressed: _saveName,
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: '${l.members}  ·  ${ws.members.length}',
            icon: Icons.group_rounded,
            child: Column(
              children: [
                for (final m in ws.members)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primary.withValues(alpha: 0.14),
                      child: Icon(platformIcon(m.platform),
                          color: scheme.primary),
                    ),
                    title: Text(m.id == myId ? l.you : m.name),
                    subtitle: Text(
                      m.id == ws.ownerId ? l.owner : m.platform,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    trailing: (app.peerById(m.id)?.isOnline ?? m.id == myId)
                        ? Icon(Icons.circle,
                            size: 12, color: BrandColors.of(context).online)
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () async {
              await context.read<WorkspaceManager>().leaveWorkspace(ws.id);
              if (context.mounted) {
                Navigator.of(context)
                  ..pop()
                  ..pop();
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(l.leave),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
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
