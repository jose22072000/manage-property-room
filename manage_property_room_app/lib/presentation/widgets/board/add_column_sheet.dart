import 'package:flutter/material.dart';
import '../../../core/property_visuals.dart';
import '../../../domain/domain.dart';

class AddColumnSheet extends StatefulWidget {
  const AddColumnSheet({super.key, required this.propertyId, required this.onAdd});

  final String propertyId;
  final void Function(String title, ColumnColor color) onAdd;

  @override
  State<AddColumnSheet> createState() => _AddColumnSheetState();
}

class _AddColumnSheetState extends State<AddColumnSheet> {
  final TextEditingController _ctrl = TextEditingController();
  ColumnColor _color = ColumnColor.blue;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nueva lista', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la lista',
                hintText: 'Ej: LIMPIEZA, LISTO...',
              ),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ColumnColor.values.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ColumnPalette.dotColor(c),
                      shape: BoxShape.circle,
                      border: selected ? Border.all(color: Colors.black87, width: 2.5) : null,
                      boxShadow: selected
                          ? [BoxShadow(color: ColumnPalette.dotColor(c).withValues(alpha: 0.4), blurRadius: 6)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Crear lista'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_ctrl.text.trim().isEmpty) return;
    widget.onAdd(_ctrl.text.trim(), _color);
  }
}
