import 'package:fastcorr_shared/models/models.dart';
import 'package:flutter/material.dart';

/// Compact driver-info card used as an overlay on tracking maps.
///
/// Pure presentation — receives a [TrackedDriver] projection and a few
/// callbacks; the host viewmodel decides what "Call" / "Chat" / "Close"
/// actually do (tel: launch, route to chat sheet, hide overlay, etc.).
///
/// Renders nothing when [driver] is null so callers don't need to add a
/// guarding `if (hasDriver)` themselves.
class DriverInfoPanel extends StatelessWidget {
  const DriverInfoPanel({
    super.key,
    required this.driver,
    this.isOnline = false,
    this.lastUpdatedAt,
    this.onClose,
    this.onCall,
    this.onChat,
    this.maxWidth = 320,
  });

  final TrackedDriver? driver;

  /// Whether the driver location is recent enough to consider "online".
  /// Caller decides the threshold (typically <60s since last ping).
  final bool isOnline;

  /// `lastLocationUpdate` from the driver document; rendered as
  /// "updated 12s ago" hint when present.
  final DateTime? lastUpdatedAt;

  final VoidCallback? onClose;
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final d = driver;
    if (d == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final txt = theme.textTheme;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: (d.photoUrl != null && d.photoUrl!.isNotEmpty)
                        ? NetworkImage(d.photoUrl!)
                        : null,
                    child: (d.photoUrl == null || d.photoUrl!.isEmpty)
                        ? Icon(Icons.person, color: colorScheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name?.trim().isNotEmpty == true ? d.name! : 'Driver',
                          style: txt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        _OnlineBadge(
                          isOnline: isOnline,
                          lastUpdatedAt: lastUpdatedAt,
                        ),
                      ],
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      tooltip: 'Hide',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (d.phone != null && d.phone!.isNotEmpty)
                _DetailRow(
                  icon: Icons.phone,
                  label: 'Phone',
                  value: d.phone!,
                  onTap: onCall,
                ),
              if (d.vehicleInfo != null && d.vehicleInfo!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.directions_car_outlined,
                  label: 'Vehicle',
                  value: d.vehicleInfo!,
                ),
              ],
              if (onCall != null || onChat != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (onCall != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCall,
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    if (onCall != null && onChat != null)
                      const SizedBox(width: 8),
                    if (onChat != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onChat,
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.isOnline, this.lastUpdatedAt});

  final bool isOnline;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final color = isOnline ? Colors.green : Colors.grey;
    final hint = _hint();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            hint,
            style: txt.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _hint() {
    if (lastUpdatedAt == null) return isOnline ? 'Online' : 'Offline';
    final diff = DateTime.now().difference(lastUpdatedAt!);
    if (diff.inSeconds < 60) return '${isOnline ? 'Online' : 'Offline'} • just now';
    if (diff.inMinutes < 60) {
      return '${isOnline ? 'Online' : 'Offline'} • ${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${isOnline ? 'Online' : 'Offline'} • ${diff.inHours}h ago';
    }
    return isOnline ? 'Online' : 'Offline';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;
    final fadedOnSurface =
        theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: fadedOnSurface),
            const SizedBox(width: 12),
            Text(
              label,
              style: txt.bodySmall?.copyWith(
                color: fadedOnSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: txt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 14, color: fadedOnSurface),
            ],
          ],
        ),
      ),
    );
  }
}
