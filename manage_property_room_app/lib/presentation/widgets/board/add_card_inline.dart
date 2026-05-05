import 'package:flutter/material.dart';

class AddCardInline extends StatefulWidget {
  const AddCardInline({super.key, required this.onAdd, required this.onCancel});

  final Future<void> Function(String title, String roomCode) onAdd;
  final VoidCallback onCancel;

  @override
  State<AddCardInline> createState() => _AddCardInlineState();
}

class _AddCardInlineState extends State<AddCardInline> {
  final _titleCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.1), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Título de la tarjeta...',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
            ),
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            onSubmitted: (_) => _submit(),
          ),
          TextField(
            controller: _roomCtrl,
            decoration: const InputDecoration(
              hintText: 'Código habitación (opcional)',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: _loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Añadir'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, size: 18),
                style: IconButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await widget.onAdd(_titleCtrl.text.trim(), _roomCtrl.text.trim());
    if (mounted) setState(() => _loading = false);
  }
}
