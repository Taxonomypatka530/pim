import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/device_specs.dart';
import '../../models/peer_device.dart';
import '../brand/theme.dart';

/// A compact one-line summary of a peer's specs, e.g. "16 cores · 32 GB · Windows 11".
String specSummary(DeviceSpecs specs, AppLocalizations l) {
  final parts = <String>[];
  if (specs.hasCpuName) {
    parts.add(specs.cpuName);
  } else if (specs.hasCpu) {
    parts.add(l.coresLabel(specs.cpuCores));
  }
  if (specs.hasRam) parts.add(specs.ramLabel);
  if (specs.hasOs) parts.add(specs.osName);
  return parts.join(' · ');
}

/// Returns a platform-appropriate glyph for a device.
IconData platformIcon(String platform) {
  switch (platform) {
    case 'windows':
      return Icons.desktop_windows_rounded;
    case 'android':
      return Icons.smartphone_rounded;
    case 'linux':
      return Icons.laptop_chromebook_rounded;
    case 'macos':
    case 'ios':
      return Icons.laptop_mac_rounded;
    default:
      return Icons.devices_other_rounded;
  }
}

/// A tappable card representing one discovered peer.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.messageCount,
    required this.onTap,
  });

  final PeerDevice device;
  final int messageCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = BrandColors.of(context);
    final l = AppLocalizations.of(context);
    final online = device.isOnline;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Avatar(platform: device.platform, online: online),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusDot(online: online),
                        const SizedBox(width: 6),
                        Text(
                          online ? l.online : l.offline,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: online
                                ? brand.online
                                : scheme.onSurfaceVariant,
                            fontWeight:
                                online ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${device.host}:${device.port}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (device.specs.isKnown) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.memory_rounded,
                              size: 13, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              specSummary(device.specs, l),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (messageCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$messageCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.platform, required this.online});
  final String platform;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: online ? scheme.primary : scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        boxShadow: online
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Icon(
        platformIcon(platform),
        color: online ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
    );
  }
}

/// A status dot that gently pulses a halo while the device is online.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.online});
  final bool online;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.online) _c.repeat();
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.online && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.online && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = BrandColors.of(context).online;
    final color = widget.online ? green : scheme.onSurfaceVariant;

    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.online)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                return Container(
                  width: 8 + 6 * t,
                  height: 8 + 6 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: green.withValues(alpha: (1 - t) * 0.5),
                  ),
                );
              },
            ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
