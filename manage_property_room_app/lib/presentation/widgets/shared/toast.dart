import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/notifiers/notifiers.dart';

/// Global toast overlay. Wrap around the app or use within Scaffold via
/// ScaffoldMessenger. Here we use a floating overlay widget.
class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);

    return Stack(
      children: [
        child,
        if (toasts.isNotEmpty)
          Positioned(
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final toast in toasts)
                  _ToastCard(key: ValueKey(toast.id), toast: toast),
              ],
            ),
          ),
      ],
    );
  }
}

class _ToastCard extends ConsumerStatefulWidget {
  const _ToastCard({super.key, required this.toast});

  final ToastMessage toast;

  @override
  ConsumerState<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends ConsumerState<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))
      ..forward();
    _slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    widget.toast.message,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => ref.read(toastProvider.notifier).dismiss(widget.toast.id),
                    child: const Icon(Icons.close, color: Colors.white54, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Confirm dialog helper
// ─────────────────────────────────────────

Future<bool> showConfirm(
  BuildContext context, {
  required String message,
  String? description,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool isDanger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ConfirmDialog(
      message: message,
      description: description,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDanger: isDanger,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.message,
    this.description,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDanger,
  });

  final String message;
  final String? description;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(message),
      content: description != null ? Text(description!) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDanger
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444))
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
