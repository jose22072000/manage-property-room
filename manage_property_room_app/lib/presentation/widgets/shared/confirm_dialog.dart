import 'package:flutter/material.dart';

import '../../../core/responsive.dart';

/// Material confirm dialog matching React `ConfirmDialog.tsx` semantics.
///
/// Returns `true` if confirmed, `false` (or `null` → false) otherwise.
/// Uses a bottom sheet on mobile and a centered dialog on tablet/desktop.
class ConfirmDialog {
  ConfirmDialog._();

  static Future<bool> ask(
    BuildContext context, {
    required String message,
    String? description,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool danger = false,
  }) async {
    final isMobile = isMobileSize(context);
    final theme = Theme.of(context);
    final confirmStyle = FilledButton.styleFrom(
      backgroundColor: danger ? Colors.red.shade600 : null,
    );

    Widget buildContent(BuildContext ctx) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  danger ? Icons.warning_amber_rounded : Icons.help_outline,
                  color: danger ? Colors.red.shade600 : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(cancelLabel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: confirmStyle,
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      );
    }

    bool? result;
    if (isMobile) {
      result = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (ctx) => SafeArea(child: buildContent(ctx)),
      );
    } else {
      result = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: buildContent(ctx),
          ),
        ),
      );
    }
    return result ?? false;
  }
}
