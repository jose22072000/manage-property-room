import 'package:flutter_test/flutter_test.dart';
import 'package:manage_property_room_app/domain/domain.dart';

void main() {
  testWidgets('smoke test — domain model loads', (WidgetTester tester) async {
    // This is a minimal smoke test verifying that core domain types
    // are accessible and functional without a running app.
    const user = AppUser(
      id: 'u-1',
      name: 'Test',
      initials: 'T',
      role: UserRole.admin,
    );
    expect(user.role, UserRole.admin);

    final column = BoardColumn(
      id: 'col-1',
      propertyId: 'prop-1',
      title: 'LISTO',
      color: ColumnColor.green,
    );
    expect(column.color, ColumnColor.green);

    final card = BoardCard(
      id: 'card-1',
      propertyId: 'prop-1',
      columnId: 'col-1',
      title: 'Habitación 101',
      createdAt: DateTime.now(),
    );
    expect(card.isDone, isFalse);
  });
}
