import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:stacked/stacked.dart';

import '../../models/trial_model.dart';
import 'court_dates_viewmodel.dart';

/// Shared trial schedule tab rendered on the case details screen in both apps.
class CourtDatesTab extends StatelessWidget {
  const CourtDatesTab({
    super.key,
    required this.litNumber,
    this.orgId,
    this.caseTitle,
    this.colorScheme,
    this.textTheme,
    this.onAddTrial,
  });

  final String litNumber;
  final String? orgId;
  final String? caseTitle;
  final ColorScheme? colorScheme;
  final TextTheme? textTheme;
  final Future<void> Function()? onAddTrial;

  @override
  Widget build(BuildContext context) {
    final color = colorScheme ?? Theme.of(context).colorScheme;
    final txtTheme = textTheme ?? Theme.of(context).textTheme;

    return ViewModelBuilder<CourtDatesViewModel>.reactive(
      viewModelBuilder: () => CourtDatesViewModel()
        ..initialize(litNumber: litNumber, orgId: orgId, caseTitle: caseTitle),
      builder: (context, viewModel, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(color, txtTheme),
              const SizedBox(height: 24),
              if (viewModel.errorMessage != null) ...[
                _buildErrorBanner(viewModel.errorMessage!, color, txtTheme),
                const SizedBox(height: 16),
              ],
              if (viewModel.trials.isNotEmpty) ...[
                _buildOverviewRow(viewModel, color, txtTheme),
                const SizedBox(height: 32),
                _buildTrialTable(context, viewModel.trials, color, txtTheme),
              ] else
                _buildEmptyState(color, txtTheme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme color, TextTheme txtTheme) {
    return Row(
      children: [
        Icon(IconlyBroken.calendar, color: color.primary, size: 32),
        const SizedBox(width: 12),
        Text(
          'Trial Schedule',
          style: txtTheme.headlineSmall!.copyWith(
            fontWeight: FontWeight.bold,
            color: color.onSurface,
          ),
        ),
        const Spacer(),
        if (onAddTrial != null)
          ElevatedButton.icon(
            onPressed: () async => onAddTrial?.call(),
            icon: Icon(IconlyBroken.plus, size: 20, color: color.onPrimary),
            label: Text('Add Trial', style: TextStyle(color: color.onPrimary)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBanner(
    String error,
    ColorScheme color,
    TextTheme txtTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.error),
      ),
      child: Row(
        children: [
          Icon(IconlyBroken.danger, color: color.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: txtTheme.bodyMedium!.copyWith(
                color: color.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewRow(
    CourtDatesViewModel viewModel,
    ColorScheme color,
    TextTheme txtTheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            'Total',
            viewModel.totalCount.toString(),
            color.surfaceContainerHighest,
            color.primary,
            IconlyBroken.calendar,
            txtTheme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildOverviewCard(
            'Urgent',
            viewModel.urgentCount.toString(),
            color.errorContainer,
            color.error,
            IconlyBroken.danger,
            txtTheme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildOverviewCard(
            'Upcoming',
            viewModel.upcomingCount.toString(),
            color.tertiaryContainer,
            color.tertiary,
            IconlyBroken.time_circle,
            txtTheme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildOverviewCard(
            'Completed',
            viewModel.completedCount.toString(),
            color.primaryContainer,
            color.primary,
            IconlyBroken.tick_square,
            txtTheme,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
    String title,
    String count,
    Color background,
    Color foreground,
    IconData icon,
    TextTheme txtTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: foreground, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: txtTheme.headlineMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: txtTheme.bodyMedium!.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialTable(
    BuildContext context,
    List<TrialModel> trials,
    ColorScheme color,
    TextTheme txtTheme,
  ) {
    if (trials.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.outline.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DataTable2(
        columnSpacing: 16,
        horizontalMargin: 16,
        minWidth: 900,
        headingRowColor: WidgetStateProperty.all(color.surfaceContainerHighest),
        headingRowHeight: 56,
        dataRowHeight: 68,
        border: TableBorder.all(
          color: color.outline.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        columns: [
          DataColumn2(
            label: Text('Type', style: _headingStyle(txtTheme, color)),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text('Status', style: _headingStyle(txtTheme, color)),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text('Date & Time', style: _headingStyle(txtTheme, color)),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Text('Court', style: _headingStyle(txtTheme, color)),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Text('Correspondent', style: _headingStyle(txtTheme, color)),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Text(
              'Opposing Attorney',
              style: _headingStyle(txtTheme, color),
            ),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Text(
              'Outcome / Notes',
              style: _headingStyle(txtTheme, color),
            ),
            size: ColumnSize.L,
          ),
        ],
        rows: trials.map((trial) {
          final trialDate = _trialDate(trial);
          final daysUntil = trialDate.difference(DateTime.now()).inDays;
          final isPast = trialDate.isBefore(DateTime.now());

          return DataRow2(
            color: WidgetStateProperty.all(
              isPast
                  ? color.surfaceContainerHighest.withValues(alpha: 0.35)
                  : null,
            ),
            cells: [
              DataCell(_buildTypeChip(trial.type, txtTheme)),
              DataCell(_buildStatusChip(trial.status, color, txtTheme)),
              DataCell(_buildDateCell(trialDate, daysUntil, color, txtTheme)),
              DataCell(
                Text(
                  trial.courtName,
                  style: txtTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isPast
                        ? color.onSurface.withValues(alpha: 0.6)
                        : color.onSurface,
                  ),
                ),
              ),
              DataCell(
                Text(
                  trial.correspondentName.isNotEmpty
                      ? trial.correspondentName
                      : 'Unassigned',
                  style: txtTheme.bodyMedium!.copyWith(
                    color: trial.correspondentName.isEmpty
                        ? color.onSurface.withValues(alpha: 0.5)
                        : color.onSurface,
                  ),
                ),
              ),
              DataCell(
                Text(
                  trial.opposingAttorney.isNotEmpty
                      ? trial.opposingAttorney
                      : 'Not specified',
                  style: txtTheme.bodyMedium!.copyWith(
                    color: color.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
              DataCell(
                Text(
                  (trial.trialOutcome?.isNotEmpty ?? false)
                      ? trial.trialOutcome!
                      : 'No outcome recorded',
                  style: txtTheme.bodyMedium!.copyWith(
                    color: color.onSurface.withValues(alpha: 0.75),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme color, TextTheme txtTheme) {
    return Center(
      child: Column(
        children: [
          Icon(
            IconlyBroken.calendar,
            size: 80,
            color: color.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No trials scheduled',
            style: txtTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.bold,
              color: color.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Trials linked to this case will appear here once scheduled.',
            style: txtTheme.bodyMedium!.copyWith(
              color: color.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  TextStyle _headingStyle(TextTheme txtTheme, ColorScheme color) {
    return txtTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: color.onSurface,
    );
  }

  Widget _buildTypeChip(TrialType type, TextTheme txtTheme) {
    final color = _trialTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _trialTypeLabel(type),
        style: txtTheme.bodySmall!.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    TrialStatus status,
    ColorScheme colorScheme,
    TextTheme txtTheme,
  ) {
    final background = _statusBackground(status, colorScheme);
    final foreground = _statusForeground(status, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: txtTheme.bodySmall!.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDateCell(
    DateTime date,
    int daysUntil,
    ColorScheme color,
    TextTheme txtTheme,
  ) {
    final isPast = date.isBefore(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatDate(date),
          style: txtTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w600,
            color: isPast
                ? color.onSurface.withValues(alpha: 0.6)
                : color.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatTime(date),
          style: txtTheme.bodySmall!.copyWith(
            color: color.onSurface.withValues(alpha: 0.6),
          ),
        ),
        if (!isPast) ...[
          const SizedBox(height: 2),
          Text(
            _daysLabel(daysUntil),
            style: txtTheme.bodySmall!.copyWith(
              color: _daysColor(daysUntil, color),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  // Helpers ------------------------------------------------------------------

  DateTime _trialDate(TrialModel trial) {
    final dynamic raw = trial.trialDate;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }

  String _trialTypeLabel(TrialType type) {
    switch (type) {
      case TrialType.trial:
        return 'Trial';
      case TrialType.preTrial:
        return 'Pre-Trial';
      case TrialType.motion:
        return 'Motion';
    }
  }

  Color _trialTypeColor(TrialType type) {
    switch (type) {
      case TrialType.trial:
        return const Color(0xFFF44336);
      case TrialType.preTrial:
        return const Color(0xFF2196F3);
      case TrialType.motion:
        return const Color(0xFF9C27B0);
    }
  }

  String _statusLabel(TrialStatus status) {
    switch (status) {
      case TrialStatus.pending:
        return 'Pending';
      case TrialStatus.urgent:
        return 'Urgent';
      case TrialStatus.proceeding:
        return 'Proceeding';
      case TrialStatus.postponed:
        return 'Postponed';
      case TrialStatus.settled:
        return 'Settled';
    }
  }

  Color _statusBackground(TrialStatus status, ColorScheme scheme) {
    switch (status) {
      case TrialStatus.pending:
        return scheme.primary.withValues(alpha: 0.15);
      case TrialStatus.urgent:
        return scheme.error.withValues(alpha: 0.15);
      case TrialStatus.proceeding:
        return scheme.tertiary.withValues(alpha: 0.15);
      case TrialStatus.postponed:
        return scheme.surfaceContainerHighest.withValues(alpha: 0.25);
      case TrialStatus.settled:
        return scheme.secondary.withValues(alpha: 0.15);
    }
  }

  Color _statusForeground(TrialStatus status, ColorScheme scheme) {
    switch (status) {
      case TrialStatus.pending:
        return scheme.primary;
      case TrialStatus.urgent:
        return scheme.error;
      case TrialStatus.proceeding:
        return scheme.tertiary;
      case TrialStatus.postponed:
        return scheme.onSurface.withValues(alpha: 0.7);
      case TrialStatus.settled:
        return scheme.secondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _daysLabel(int daysUntil) {
    if (daysUntil < 0) return '${daysUntil.abs()} days ago';
    if (daysUntil == 0) return 'Today';
    if (daysUntil == 1) return 'Tomorrow';
    if (daysUntil < 7) return 'In $daysUntil days';
    if (daysUntil < 30) {
      final weeks = (daysUntil / 7).round();
      return 'In $weeks week${weeks == 1 ? '' : 's'}';
    }
    final months = (daysUntil / 30).round();
    return 'In $months month${months == 1 ? '' : 's'}';
  }

  Color _daysColor(int daysUntil, ColorScheme scheme) {
    if (daysUntil < 0) {
      return scheme.onSurface.withValues(alpha: 0.6);
    }
    if (daysUntil <= 7) {
      return scheme.error;
    }
    if (daysUntil <= 30) {
      return scheme.tertiary;
    }
    return scheme.primary;
  }
}
