import 'package:flutter/material.dart';
import '../domain/domain.dart';

// ─────────────────────────────────────────
//  Property gradients — 10 deterministic gradients
//  Mirrors src/lib/propertyVisuals.ts
// ─────────────────────────────────────────

const List<List<Color>> _kGradients = [
  [Color(0xFF3B82F6), Color(0xFF4338CA)], // blue → indigo
  [Color(0xFF10B981), Color(0xFF0D9488)], // emerald → teal
  [Color(0xFFF59E0B), Color(0xFFD97706)], // amber → amber-dark
  [Color(0xFFEF4444), Color(0xFFDC2626)], // red
  [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // violet → purple
  [Color(0xFF06B6D4), Color(0xFF0EA5E9)], // cyan → sky
  [Color(0xFF84CC16), Color(0xFF4D7C0F)], // lime → lime-dark
  [Color(0xFFF97316), Color(0xFFEA580C)], // orange
  [Color(0xFFEC4899), Color(0xFFDB2777)], // pink
  [Color(0xFF6B7280), Color(0xFF374151)], // gray
];

/// Returns a LinearGradient for [property] based on its colorSeed.
LinearGradient propertyGradient(Property property) {
  final colors = _kGradients[property.colorSeed % _kGradients.length];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );
}

/// Returns a single representative color for [property] (first color of gradient).
Color propertyColor(Property property) =>
    _kGradients[property.colorSeed % _kGradients.length][0];

// ─────────────────────────────────────────
//  Column color palette
//  Mirrors COLUMN_COLOR_CLASSES from domain.ts
// ─────────────────────────────────────────

class ColumnPalette {
  const ColumnPalette._();

  static Color borderColor(ColumnColor c) => _border[c]!;
  static Color headerBg(ColumnColor c) => _headerBg[c]!;
  static Color iconColor(ColumnColor c) => _icon[c]!;
  static Color dotColor(ColumnColor c) => _dot[c]!;
  static Color swatchColor(ColumnColor c) => _dot[c]!;

  static const _border = {
    ColumnColor.green: Color(0xFF22C55E),
    ColumnColor.yellow: Color(0xFFEAB308),
    ColumnColor.orange: Color(0xFFF97316),
    ColumnColor.red: Color(0xFFEF4444),
    ColumnColor.purple: Color(0xFFA855F7),
    ColumnColor.blue: Color(0xFF3B82F6),
    ColumnColor.cyan: Color(0xFF06B6D4),
    ColumnColor.lime: Color(0xFF84CC16),
    ColumnColor.pink: Color(0xFFEC4899),
    ColumnColor.gray: Color(0xFF6B7280),
  };

  static const _headerBg = {
    ColumnColor.green: Color(0xFFDCFCE7),
    ColumnColor.yellow: Color(0xFFFEF9C3),
    ColumnColor.orange: Color(0xFFFFEDD5),
    ColumnColor.red: Color(0xFFFEE2E2),
    ColumnColor.purple: Color(0xFFF3E8FF),
    ColumnColor.blue: Color(0xFFDBEAFE),
    ColumnColor.cyan: Color(0xFFCFFAFE),
    ColumnColor.lime: Color(0xFFECFCCB),
    ColumnColor.pink: Color(0xFFFCE7F3),
    ColumnColor.gray: Color(0xFFF3F4F6),
  };

  static const _icon = {
    ColumnColor.green: Color(0xFF16A34A),
    ColumnColor.yellow: Color(0xFFCA8A04),
    ColumnColor.orange: Color(0xFFEA580C),
    ColumnColor.red: Color(0xFFDC2626),
    ColumnColor.purple: Color(0xFF9333EA),
    ColumnColor.blue: Color(0xFF2563EB),
    ColumnColor.cyan: Color(0xFF0891B2),
    ColumnColor.lime: Color(0xFF65A30D),
    ColumnColor.pink: Color(0xFFDB2777),
    ColumnColor.gray: Color(0xFF4B5563),
  };

  static const _dot = {
    ColumnColor.green: Color(0xFF22C55E),
    ColumnColor.yellow: Color(0xFFEAB308),
    ColumnColor.orange: Color(0xFFF97316),
    ColumnColor.red: Color(0xFFEF4444),
    ColumnColor.purple: Color(0xFFA855F7),
    ColumnColor.blue: Color(0xFF3B82F6),
    ColumnColor.cyan: Color(0xFF06B6D4),
    ColumnColor.lime: Color(0xFF84CC16),
    ColumnColor.pink: Color(0xFFEC4899),
    ColumnColor.gray: Color(0xFF6B7280),
  };

  static const List<ColumnColor> all = ColumnColor.values;
}

// ─────────────────────────────────────────
//  Priority colors
// ─────────────────────────────────────────

class PriorityPalette {
  const PriorityPalette._();

  static Color color(CardPriority p) => _colors[p]!;
  static String label(CardPriority p) => _labels[p]!;

  static const _colors = {
    CardPriority.low: Color(0xFF6B7280),
    CardPriority.normal: Color(0xFF3B82F6),
    CardPriority.high: Color(0xFFEF4444),
  };

  static const _labels = {
    CardPriority.low: 'Baja',
    CardPriority.normal: 'Normal',
    CardPriority.high: 'Alta',
  };
}
