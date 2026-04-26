import 'package:fastcorr_shared/models/models.dart';
import 'package:flutter/material.dart';

/// Vertical list of dropoff stops, each card showing contact, status and
/// timestamps. Tapping a stop invokes [onLocationTap] (typically used by
/// the host viewmodel to centre the map on that stop).
///
/// Receives [TrackedDropoff] values directly — no per-app model imports.
class LocationStatusList extends StatelessWidget {
  const LocationStatusList({
    super.key,
    required this.dropoffs,
    this.onLocationTap,
    this.padding = const EdgeInsets.all(16),
    this.emptyPlaceholder,
  });

  final List<TrackedDropoff> dropoffs;
  final ValueChanged<TrackedDropoff>? onLocationTap;
  final EdgeInsets padding;
  final Widget? emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    if (dropoffs.isEmpty) {
      return emptyPlaceholder ?? _defaultEmpty(context);
    }

    final ordered = [...dropoffs]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    return ListView.separated(
      padding: padding,
      itemCount: ordered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _DropoffCard(
          dropoff: ordered[index],
          onTap: onLocationTap == null
              ? null
              : () => onLocationTap!(ordered[index]),
        );
      },
    );
  }

  Widget _defaultEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No delivery locations',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropoffCard extends StatelessWidget {
  const _DropoffCard({required this.dropoff, this.onTap});

  final TrackedDropoff dropoff;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;
    final color = theme.colorScheme;

    final statusColor = _statusColor(dropoff.status);
    final statusText = _statusText(dropoff.status);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SequenceBadge(
                    sequence: dropoff.sequence,
                    color: statusColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dropoff.contactName ??
                              dropoff.location.label ??
                              'Stop ${dropoff.sequence}',
                          style: txt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dropoff.location.address != null &&
                            dropoff.location.address!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            dropoff.location.address!,
                            style: txt.bodySmall?.copyWith(
                              color:
                                  color.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StatusChip(
                    text: statusText,
                    color: statusColor,
                  ),
                ],
              ),
              if (dropoff.contactPhone != null &&
                  dropoff.contactPhone!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.phone,
                      size: 14,
                      color: color.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dropoff.contactPhone!,
                      style: txt.bodySmall?.copyWith(
                        color: color.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
              if (dropoff.arrivedAt != null || dropoff.deliveredAt != null) ...[
                const SizedBox(height: 12),
                _Timestamps(dropoff: dropoff),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(AddressStatus status) {
    switch (status) {
      case AddressStatus.delivered:
        return Colors.green;
      case AddressStatus.arrived:
        return Colors.purple;
      case AddressStatus.canceled:
        return Colors.red;
      case AddressStatus.pending:
        return Colors.orange;
    }
  }

  static String _statusText(AddressStatus status) {
    switch (status) {
      case AddressStatus.delivered:
        return 'Delivered';
      case AddressStatus.arrived:
        return 'Arrived';
      case AddressStatus.canceled:
        return 'Cancelled';
      case AddressStatus.pending:
        return 'Pending';
    }
  }
}

class _SequenceBadge extends StatelessWidget {
  const _SequenceBadge({required this.sequence, required this.color});

  final int sequence;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '$sequence',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Timestamps extends StatelessWidget {
  const _Timestamps({required this.dropoff});

  final TrackedDropoff dropoff;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dropoff.arrivedAt != null)
          _row(
            context,
            icon: Icons.location_on,
            label: 'Arrived',
            time: dropoff.arrivedAt!,
            color: Colors.purple,
          ),
        if (dropoff.deliveredAt != null) ...[
          if (dropoff.arrivedAt != null) const SizedBox(height: 4),
          _row(
            context,
            icon: Icons.check_circle_outline,
            label: 'Delivered',
            time: dropoff.deliveredAt!,
            color: Colors.green,
          ),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required DateTime time,
    required Color color,
  }) {
    final txt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ${_formatTime(time)}',
          style: txt.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.day}/${time.month} '
        '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
