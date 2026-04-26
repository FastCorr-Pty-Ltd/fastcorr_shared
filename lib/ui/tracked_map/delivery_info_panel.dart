import 'package:fastcorr_shared/models/models.dart';
import 'package:flutter/material.dart';

/// Header card describing the order being tracked: title, short id, status
/// chip, progress bar (delivered / total), and a quick pickup-vs-deliveries
/// summary row.
///
/// Pure stateless presentation over a [TrackedOrder].
class DeliveryInfoPanel extends StatelessWidget {
  const DeliveryInfoPanel({super.key, required this.order});

  final TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final txt = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_typeIcon(order.type), color: colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.title?.trim().isNotEmpty == true
                          ? order.title!
                          : _typeLabel(order.type),
                      style: txt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Order #${_shortId(order.orderId)}',
                      style: txt.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _progressText(order),
                style: txt.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '${(order.progress * 100).round()}%',
                style: txt.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: order.progress,
              backgroundColor:
                  colorScheme.outline.withValues(alpha: 0.2),
              valueColor:
                  AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  icon: Icons.location_on_outlined,
                  label: 'Pickup',
                  value: order.pickup?.address ??
                      order.pickup?.label ??
                      'Not set',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InfoItem(
                  icon: Icons.local_shipping_outlined,
                  label: 'Deliveries',
                  value:
                      '${order.totalDropoffs} location${order.totalDropoffs == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _typeIcon(TrackedOrderType type) {
    switch (type) {
      case TrackedOrderType.litigation:
        return Icons.gavel_outlined;
      case TrackedOrderType.delivery:
        return Icons.local_shipping_outlined;
    }
  }

  static String _typeLabel(TrackedOrderType type) {
    switch (type) {
      case TrackedOrderType.litigation:
        return 'Litigation Service';
      case TrackedOrderType.delivery:
        return 'Delivery Service';
    }
  }

  static String _shortId(String orderId) {
    if (orderId.length <= 8) return orderId;
    return orderId.substring(orderId.length - 8);
  }

  static String _progressText(TrackedOrder order) {
    return '${order.completedDropoffs} of ${order.totalDropoffs} '
        'deliver${order.totalDropoffs == 1 ? 'y' : 'ies'} completed';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final Status status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final text = _statusText(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
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

  static Color _statusColor(Status status) {
    switch (status) {
      case Status.completed:
        return const Color(0xFF4CAF50);
      case Status.inProgress:
        return const Color(0xFF2196F3);
      case Status.pickedup:
        return const Color(0xFF4CAF50);
      case Status.arrivedAtPickup:
        return Colors.purple;
      case Status.accepted:
        return Colors.blue;
      case Status.readyForPickup:
        return Colors.orange;
      case Status.pending:
        return Colors.grey;
      case Status.canceled:
      case Status.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _statusText(Status status) {
    switch (status) {
      case Status.readyForPickup:
        return 'Ready';
      case Status.accepted:
        return 'Accepted';
      case Status.arrivedAtPickup:
        return 'Driver Arrived';
      case Status.pickedup:
        return 'Picked Up';
      case Status.inProgress:
        return 'In Transit';
      case Status.completed:
        return 'Delivered';
      case Status.canceled:
        return 'Cancelled';
      case Status.rejected:
        return 'Rejected';
      case Status.pending:
        return 'Pending';
      default:
        return status.name;
    }
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txt = theme.textTheme;
    final faded = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      children: [
        Icon(icon, size: 16, color: faded),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: txt.bodySmall?.copyWith(color: faded, fontSize: 10),
              ),
              Text(
                value,
                style: txt.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
