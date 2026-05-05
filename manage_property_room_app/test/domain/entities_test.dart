import 'package:flutter_test/flutter_test.dart';
import 'package:manage_property_room_app/domain/domain.dart';

void main() {
  group('AppUser', () {
    const user = AppUser(
      id: 'u-1',
      name: 'Ana García',
      initials: 'AG',
      role: UserRole.admin,
      assignedPropertyIds: ['p-1', 'p-2'],
    );

    test('toJson / fromJson round-trip', () {
      final json = user.toJson();
      final restored = AppUser.fromJson(json);
      expect(restored.id, user.id);
      expect(restored.name, user.name);
      expect(restored.role, user.role);
      expect(restored.assignedPropertyIds, user.assignedPropertyIds);
    });

    test('copyWith preserves unmodified fields', () {
      final updated = user.copyWith(name: 'Beatriz');
      expect(updated.name, 'Beatriz');
      expect(updated.id, user.id);
      expect(updated.role, user.role);
    });
  });

  group('Property', () {
    const prop = Property(
      id: 'prop-1',
      code: 'FN13',
      name: 'Finca 13',
      totalRooms: 12,
    );

    test('toJson / fromJson round-trip', () {
      final json = prop.toJson();
      final restored = Property.fromJson(json);
      expect(restored.id, prop.id);
      expect(restored.code, prop.code);
      expect(restored.totalRooms, prop.totalRooms);
    });
  });

  group('BoardColumn', () {
    const col = BoardColumn(
      id: 'col-1',
      propertyId: 'prop-1',
      title: 'LIMPIEZA',
      color: ColumnColor.yellow,
      position: 1,
    );

    test('toJson / fromJson round-trip', () {
      final json = col.toJson();
      final restored = BoardColumn.fromJson(json);
      expect(restored.id, col.id);
      expect(restored.color, col.color);
      expect(restored.config.showComments, isTrue);
    });

    test('copyWith changes color', () {
      final updated = col.copyWith(color: ColumnColor.green);
      expect(updated.color, ColumnColor.green);
      expect(updated.title, col.title);
    });
  });

  group('BoardCard', () {
    final now = DateTime.utc(2024, 6, 15);
    final card = BoardCard(
      id: 'card-1',
      propertyId: 'prop-1',
      columnId: 'col-1',
      title: 'Habitación 101',
      priority: CardPriority.high,
      createdAt: now,
      checkinDate: now.add(const Duration(days: 1)),
    );

    test('toJson / fromJson round-trip', () {
      final json = card.toJson();
      final restored = BoardCard.fromJson(json);
      expect(restored.id, card.id);
      expect(restored.priority, CardPriority.high);
      expect(restored.checkinDate?.day, card.checkinDate?.day);
    });

    test('copyWith clearCheckin', () {
      final updated = card.copyWith(clearCheckin: true);
      expect(updated.checkinDate, isNull);
      expect(updated.title, card.title);
    });

    test('copyWith clearAssignee', () {
      final withAssignee = card.copyWith(assignedToId: 'user-1');
      final cleared = withAssignee.copyWith(clearAssignee: true);
      expect(cleared.assignedToId, isNull);
    });

    test('isDone defaults to false', () {
      expect(card.isDone, isFalse);
    });
  });

  group('FieldDef', () {
    const field = FieldDef(
      id: 'f-1',
      label: 'Estado',
      type: FieldType.select,
      options: ['Limpio', 'Pendiente', 'Ocupado'],
    );

    test('toJson / fromJson round-trip', () {
      final json = field.toJson();
      final restored = FieldDef.fromJson(json);
      expect(restored.label, field.label);
      expect(restored.type, FieldType.select);
      expect(restored.options, field.options);
    });
  });
}
