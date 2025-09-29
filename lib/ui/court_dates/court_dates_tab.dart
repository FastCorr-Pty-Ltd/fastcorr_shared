import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:stacked/stacked.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../models/court_date_model.dart';
import 'court_dates_viewmodel.dart';
import 'add_court_date_dialog.dart';

/// Shared court dates tab widget that can be used in both user and admin apps
class CourtDatesTab extends StatelessWidget {
  final String caseId;
  final String orgId;
  final String? caseTitle;
  final ColorScheme? colorScheme;
  final TextTheme? textTheme;
  final Function(CourtDateModel?)? onAddCourtDate;
  final Function(CourtDateModel?)? onUpdateCourtDate;
  const CourtDatesTab({
    super.key,
    required this.caseId,
    required this.orgId,
    this.caseTitle,
    this.colorScheme,
    this.textTheme,
    this.onAddCourtDate,
    this.onUpdateCourtDate,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorScheme ?? Theme.of(context).colorScheme;
    final txtTheme = textTheme ?? Theme.of(context).textTheme;

    return ViewModelBuilder<CourtDatesViewModel>.reactive(
      viewModelBuilder: () =>
          CourtDatesViewModel()
            ..initialize(caseId: caseId, orgId: orgId, caseTitle: caseTitle),
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Add Button
              _buildHeader(context, viewModel, color, txtTheme),
              const SizedBox(height: 24),

              // Error Message
              if (viewModel.errorMessage != null) ...[
                Container(
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
                          viewModel.errorMessage!,
                          style: txtTheme.bodyMedium!.copyWith(
                            color: color.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: viewModel.clearError,
                        icon: Icon(
                          IconlyBroken.close_square,
                          color: color.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Court Dates Content
              if (viewModel.courtDates.isNotEmpty) ...[
                // Court Dates Overview
                _buildCourtDatesOverview(viewModel, color, txtTheme),
                const SizedBox(height: 32),

                // Court Dates List
                _buildCourtDatesList(viewModel, context, color, txtTheme),
              ] else
                _buildEmptyState(context, viewModel, color, txtTheme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    CourtDatesViewModel viewModel,
    ColorScheme color,
    TextTheme txtTheme,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            IconlyBroken.calendar,
            size: 80,
            color: color.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Court Dates Available',
            style: txtTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.bold,
              color: color.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No court dates have been scheduled for this case yet.',
            style: txtTheme.bodyMedium!.copyWith(
              color: color.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddCourtDateDialog(context, viewModel),
            icon: Icon(IconlyBroken.plus, size: 20, color: color.onPrimary),
            label: Text(
              'Add First Court Date',
              style: TextStyle(color: color.onPrimary),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CourtDatesViewModel viewModel,
    ColorScheme color,
    TextTheme txtTheme,
  ) {
    return Row(
      children: [
        Icon(IconlyBroken.calendar, color: color.primary, size: 32),
        const SizedBox(width: 12),
        Text(
          'Court Dates',
          style: txtTheme.headlineSmall!.copyWith(
            fontWeight: FontWeight.bold,
            color: color.onSurface,
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => _showAddCourtDateDialog(context, viewModel),
          icon: Icon(IconlyBroken.plus, size: 20, color: color.onPrimary),
          label: Text(
            'Add Court Date',
            style: TextStyle(color: color.onPrimary),
          ),
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

  Widget _buildCourtDatesOverview(
    CourtDatesViewModel viewModel,
    ColorScheme color,
    TextTheme txtTheme,
  ) {
    return Row(
      children: [
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
    Color bgColor,
    Color textColor,
    IconData icon,
    TextTheme txtTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: txtTheme.headlineMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: txtTheme.bodyMedium!.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourtDatesList(
    CourtDatesViewModel viewModel,
    BuildContext context,
    ColorScheme color,
    TextTheme txtTheme,
  ) {
    // Court dates are already sorted by the viewmodel
    final sortedDates = viewModel.courtDates;

    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.outline.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 16,
        minWidth: 800,

        headingRowColor: WidgetStateProperty.all(color.surfaceContainerHighest),
        headingRowHeight: 56,
        dataRowHeight: 64,
        border: TableBorder.all(
          color: color.outline.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        columns: [
          DataColumn2(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Type',
                  style: txtTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                if (viewModel.sortColumn == 'dateType')
                  Icon(
                    viewModel.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: color.primary,
                  ),
              ],
            ),
            onSort: (columnIndex, ascending) {
              viewModel.updateSorting('dateType');
            },
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Status',
                  style: txtTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                if (viewModel.sortColumn == 'status')
                  Icon(
                    viewModel.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: color.primary,
                  ),
              ],
            ),
            onSort: (columnIndex, ascending) {
              viewModel.updateSorting('status');
            },
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Date & Time',
                  style: txtTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                if (viewModel.sortColumn == 'courtDate')
                  Icon(
                    viewModel.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: color.primary,
                  ),
              ],
            ),
            onSort: (columnIndex, ascending) {
              viewModel.updateSorting('courtDate');
            },
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Description',
                  style: txtTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                if (viewModel.sortColumn == 'description')
                  Icon(
                    viewModel.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: color.primary,
                  ),
              ],
            ),
            onSort: (columnIndex, ascending) {
              viewModel.updateSorting('description');
            },
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text(
              'Notes',
              style: txtTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: color.onSurface,
              ),
            ),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Text(
              'Actions',
              style: txtTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: color.onSurface,
              ),
            ),
            size: ColumnSize.S,
          ),
        ],
        rows: sortedDates.map((courtDate) {
          final daysUntil = courtDate.courtDate
              .difference(DateTime.now())
              .inDays;
          final isPast = daysUntil < 0;

          return DataRow2(
            color: WidgetStateProperty.all(
              isPast
                  ? color.surfaceContainerHighest.withValues(alpha: 0.3)
                  : null,
            ),
            cells: [
              // Type
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: CourtDateModel.getDateTypeColor(
                      courtDate.dateType,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CourtDateModel.getDateTypeColor(
                        courtDate.dateType,
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    CourtDateModel.getDateTypeDisplayName(courtDate.dateType),
                    style: txtTheme.bodySmall!.copyWith(
                      color: CourtDateModel.getDateTypeColor(
                        courtDate.dateType,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Status
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(courtDate.status, color),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(courtDate.status, daysUntil),
                    style: txtTheme.bodySmall!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Date & Time
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatDate(courtDate.courtDate),
                      style: txtTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPast
                            ? color.onSurface.withValues(alpha: 0.6)
                            : color.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(courtDate.courtDate),
                      style: txtTheme.bodySmall!.copyWith(
                        color: isPast
                            ? color.onSurface.withValues(alpha: 0.5)
                            : color.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    if (!isPast) ...[
                      const SizedBox(height: 2),
                      Text(
                        _getDaysText(daysUntil),
                        style: txtTheme.bodySmall!.copyWith(
                          color: _getDaysColor(daysUntil, color),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Description
              DataCell(
                Text(
                  courtDate.description,
                  style: txtTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isPast
                        ? color.onSurface.withValues(alpha: 0.6)
                        : color.onSurface,
                  ),
                ),
              ),

              // Notes
              DataCell(
                Text(
                  courtDate.notes ?? 'No notes',
                  style: txtTheme.bodyMedium!.copyWith(
                    color: isPast
                        ? color.onSurface.withValues(alpha: 0.5)
                        : color.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Actions
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _showEditCourtDateDialog(
                        context,
                        viewModel,
                        courtDate,
                      ),
                      icon: Icon(
                        IconlyBroken.edit,
                        size: 20,
                        color: color.primary,
                      ),
                      tooltip: 'Edit',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      onPressed: () => _showDeleteConfirmation(
                        context,
                        viewModel,
                        courtDate,
                      ),
                      icon: Icon(
                        IconlyBroken.delete,
                        size: 20,
                        color: color.error,
                      ),
                      tooltip: 'Delete',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(CourtDateStatus status, ColorScheme color) {
    switch (status) {
      case CourtDateStatus.urgent:
        return color.error;
      case CourtDateStatus.upcoming:
        return color.tertiary;
      case CourtDateStatus.scheduled:
        return color.primary;
      case CourtDateStatus.completed:
        return color.onSurface.withValues(alpha: 0.6);
    }
  }

  String _getStatusText(CourtDateStatus status, int daysUntil) {
    if (daysUntil < 0) return 'PAST';
    if (daysUntil == 0) return 'TODAY';

    switch (status) {
      case CourtDateStatus.urgent:
        return 'URGENT';
      case CourtDateStatus.upcoming:
        return 'UPCOMING';
      case CourtDateStatus.scheduled:
        return 'SCHEDULED';
      case CourtDateStatus.completed:
        return 'COMPLETED';
    }
  }

  String _getDaysText(int daysUntil) {
    if (daysUntil < 0) return '${daysUntil.abs()} days ago';
    if (daysUntil == 0) return 'Today';
    if (daysUntil == 1) return 'Tomorrow';
    if (daysUntil < 7) return 'In $daysUntil days';
    if (daysUntil < 30) return 'In ${(daysUntil / 7).round()} weeks';
    return 'In ${(daysUntil / 30).round()} months';
  }

  Color _getDaysColor(int daysUntil, ColorScheme color) {
    if (daysUntil < 0) return color.onSurface.withValues(alpha: 0.6);
    if (daysUntil <= 7) return color.error;
    if (daysUntil <= 30) return color.tertiary;
    return color.primary;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Show add court date dialog
  Future<void> _showAddCourtDateDialog(
    BuildContext context,
    CourtDatesViewModel viewModel,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AddCourtDateDialog(
        onSave:
            ({
              required String description,
              required DateTime courtDate,
              required CourtDateType dateType,
              String? notes,
            }) async {
              final courtDateModel = await viewModel.addCourtDate(
                description: description,
                courtDate: courtDate,
                dateType: dateType,
                notes: notes,
              );
              if (onAddCourtDate != null) {
                onAddCourtDate!(courtDateModel);
              }

              if (courtDateModel != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Court date added successfully'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            },
      ),
    );
  }

  /// Show edit court date dialog
  Future<void> _showEditCourtDateDialog(
    BuildContext context,
    CourtDatesViewModel viewModel,
    CourtDateModel existingCourtDate,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AddCourtDateDialog(
        existingDate: existingCourtDate,
        onSave:
            ({
              required String description,
              required DateTime courtDate,
              required CourtDateType dateType,
              String? notes,
            }) async {
              final courtDateModel = await viewModel.updateCourtDate(
                dateId: existingCourtDate.dateId,
                description: description,
                courtDate: courtDate,
                dateType: dateType,
                notes: notes,
              );

              if (onUpdateCourtDate != null) {
                onUpdateCourtDate!(courtDateModel);
              }

              if (courtDateModel != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Court date updated successfully'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            },
      ),
    );
  }

  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    CourtDatesViewModel viewModel,
    CourtDateModel courtDate,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Court Date'),
        content: Text(
          'Are you sure you want to delete "${courtDate.description}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await viewModel.deleteCourtDate(courtDate.dateId);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Court date deleted successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }
}
