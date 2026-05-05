import 'package:flutter_test/flutter_test.dart';
import 'package:manage_property_room_app/domain/domain.dart';
import 'package:manage_property_room_app/permissions/policy.dart';

void main() {
  const admin = AppUser(
    id: 'admin-1',
    name: 'María Admin',
    initials: 'MA',
    role: UserRole.admin,
    assignedPropertyIds: ['prop-1', 'prop-2'],
  );

  const cleaning = AppUser(
    id: 'clean-1',
    name: 'Carlos Limpieza',
    initials: 'CL',
    role: UserRole.cleaning,
    assignedPropertyIds: ['prop-1'],
  );

  const maintenance = AppUser(
    id: 'maint-1',
    name: 'Diego Manten.',
    initials: 'DM',
    role: UserRole.maintenance,
    assignedPropertyIds: ['prop-2'],
  );

  const card = BoardCard(
    id: 'card-1',
    propertyId: 'prop-1',
    columnId: 'col-1',
    title: 'Habitación 101',
    createdAt: DateTime.utc(2024, 1, 1),
  );

  const cardOtherUser = BoardCard(
    id: 'card-2',
    propertyId: 'prop-2',
    columnId: 'col-1',
    title: 'Habitación 202',
    assignedToId: 'other-user',
    createdAt: DateTime.utc(2024, 1, 1),
  );

  group('canSeeProperty', () {
    test('admin sees all properties', () {
      expect(Policy.canSeeProperty(admin, 'prop-1'), isTrue);
      expect(Policy.canSeeProperty(admin, 'prop-unknown'), isTrue);
    });

    test('cleaning only sees assigned properties', () {
      expect(Policy.canSeeProperty(cleaning, 'prop-1'), isTrue);
      expect(Policy.canSeeProperty(cleaning, 'prop-2'), isFalse);
    });

    test('maintenance only sees assigned properties', () {
      expect(Policy.canSeeProperty(maintenance, 'prop-2'), isTrue);
      expect(Policy.canSeeProperty(maintenance, 'prop-1'), isFalse);
    });
  });

  group('canBoard — admin bypasses all', () {
    for (final action in BoardAction.values) {
      test('admin can $action', () {
        expect(Policy.canBoard(admin, action), isTrue);
      });
    }
  });

  group('canBoard — cleaning', () {
    test('cleaning can addCard', () {
      expect(Policy.canBoard(cleaning, BoardAction.addCard), isTrue);
    });

    test('cleaning cannot addColumn', () {
      expect(Policy.canBoard(cleaning, BoardAction.addColumn), isFalse);
    });

    test('cleaning cannot deleteColumn', () {
      expect(Policy.canBoard(cleaning, BoardAction.deleteColumn), isFalse);
    });
  });

  group('canBoard — maintenance', () {
    test('maintenance can addCard', () {
      expect(Policy.canBoard(maintenance, BoardAction.addCard), isTrue);
    });

    test('maintenance cannot manageUsers', () {
      expect(Policy.canBoard(maintenance, BoardAction.manageUsers), isFalse);
    });
  });

  group('canCard — cleaning', () {
    test('cleaning can toggleDone on unassigned card', () {
      expect(Policy.canCard(cleaning, card, CardAction.toggleDone), isTrue);
    });

    test('cleaning can toggleDone on own card', () {
      final ownCard = card.copyWith(assignedToId: cleaning.id);
      expect(Policy.canCard(cleaning, ownCard, CardAction.toggleDone), isTrue);
    });

    test('cleaning cannot archive', () {
      expect(Policy.canCard(cleaning, card, CardAction.archive), isFalse);
    });

    test('cleaning can comment', () {
      expect(Policy.canCard(cleaning, card, CardAction.comment), isTrue);
    });

    test('cleaning can uploadImage', () {
      expect(Policy.canCard(cleaning, card, CardAction.uploadImage), isTrue);
    });
  });

  group('canCard — maintenance', () {
    test('maintenance can setPriority', () {
      expect(Policy.canCard(maintenance, card, CardAction.setPriority), isTrue);
    });

    test('maintenance cannot delete', () {
      expect(Policy.canCard(maintenance, card, CardAction.delete), isFalse);
    });
  });

  group('canCard — admin', () {
    for (final action in CardAction.values) {
      test('admin can $action', () {
        expect(Policy.canCard(admin, card, action), isTrue);
      });
    }
  });
}
