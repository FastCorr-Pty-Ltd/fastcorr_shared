/// Shared Communication Widget
/// Gmail-like interface for case communications

import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:stacked/stacked.dart';
import 'package:fastcorr_shared/fastcorr_shared.dart';
import 'shared_communication_viewmodel.dart';
import 'widgets/message_list_panel.dart';
import 'widgets/message_detail_panel.dart';
import 'widgets/compose_dialog.dart';

/// Main shared communication widget with Gmail-like interface
class SharedCommunicationWidget
    extends ViewModelWidget<SharedCommunicationViewModel> {
  final ColorScheme? colorScheme;
  final TextTheme? textTheme;
  final bool isMobile;

  const SharedCommunicationWidget({
    super.key,
    this.colorScheme,
    this.textTheme,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context, SharedCommunicationViewModel viewModel) {
    final colors = colorScheme ?? Theme.of(context).colorScheme;
    final textStyles = textTheme ?? Theme.of(context).textTheme;

    if (viewModel.isBusy) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (!viewModel.hasAccess) {
      return _buildAccessDeniedView(colors, textStyles);
    }

    if (isMobile) {
      return _buildMobileLayout(context, viewModel, colors, textStyles);
    } else {
      return _buildDesktopLayout(context, viewModel, colors, textStyles);
    }
  }

  Widget _buildAccessDeniedView(ColorScheme colors, TextTheme textStyles) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: colors.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Access Denied',
            style: textStyles.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You do not have access to this case\'s communications',
            style: textStyles.bodyMedium?.copyWith(
              color: colors.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    SharedCommunicationViewModel viewModel,
    ColorScheme colors,
    TextTheme textStyles,
  ) {
    return Scaffold(
      body: Column(
        children: [
          if (viewModel.hasError)
            _buildErrorBanner(
              viewModel: viewModel,
              colors: colors,
              textStyles: textStyles,
            ),
          Expanded(
            child: viewModel.selectedMessage == null
                ? MessageListPanel(
                    viewModel: viewModel,
                    colorScheme: colors,
                    textTheme: textStyles,
                  )
                : MessageDetailPanel(
                    viewModel: viewModel,
                    colorScheme: colors,
                    textTheme: textStyles,
                    onBack: () => viewModel.clearSelectedMessage(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => viewModel.startComposing(),
        backgroundColor: colors.primary,
        child: Icon(Icons.add, color: colors.onPrimary),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    SharedCommunicationViewModel viewModel,
    ColorScheme colors,
    TextTheme textStyles,
  ) {
    return Column(
      children: [
        if (viewModel.hasError)
          _buildErrorBanner(
            viewModel: viewModel,
            colors: colors,
            textStyles: textStyles,
          ),
        Expanded(
          child: Row(
            children: [
              // Left Panel - Message List
              Expanded(
                flex: 1,
                child: MessageListPanel(
                  viewModel: viewModel,
                  colorScheme: colors,
                  textTheme: textStyles,
                ),
              ),

              // Divider
              Container(width: 1, color: colors.outline.withOpacity(0.2)),

              // Right Panel - Message Detail
              Expanded(
                flex: 2,
                child: viewModel.selectedMessage == null
                    ? _buildEmptyDetailView(colors, textStyles)
                    : MessageDetailPanel(
                        viewModel: viewModel,
                        colorScheme: colors,
                        textTheme: textStyles,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner({
    required SharedCommunicationViewModel viewModel,
    required ColorScheme colors,
    required TextTheme textStyles,
  }) {
    return Material(
      color: colors.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  viewModel.lastErrorMessage!,
                  style: textStyles.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: viewModel.clearError,
                icon: Icon(Icons.close, color: colors.onErrorContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDetailView(ColorScheme colors, TextTheme textStyles) {
    return Container(
      color: colors.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconlyBroken.chat,
              size: 64,
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a message',
              style: textStyles.titleMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a message from the list to view its content',
              style: textStyles.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compose dialog overlay
class ComposeDialogOverlay extends StatelessWidget {
  final SharedCommunicationViewModel viewModel;
  final ColorScheme? colorScheme;
  final TextTheme? textTheme;

  const ComposeDialogOverlay({
    super.key,
    required this.viewModel,
    this.colorScheme,
    this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (!viewModel.isComposing) return const SizedBox.shrink();

    return Material(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: ComposeDialog(
            viewModel: viewModel,
            colorScheme: colorScheme ?? Theme.of(context).colorScheme,
            textTheme: textTheme ?? Theme.of(context).textTheme,
          ),
        ),
      ),
    );
  }
}
