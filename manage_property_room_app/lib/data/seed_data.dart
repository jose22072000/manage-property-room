import '../domain/domain.dart';
import '../data/repositories/repositories.dart';

/// Current seed version. Bump when data shape changes to re-seed.
const _kSeedVersion = 1;

/// Inserts initial demo data if [settingsRepo.getSeedVersion] < [_kSeedVersion].
Future<void> seedIfNeeded({
  required SettingsRepository settingsRepo,
  required UserRepository userRepo,
  required PropertyRepository propertyRepo,
  required ColumnRepository columnRepo,
  required CardRepository cardRepo,
  required FieldRepository fieldRepo,
}) async {
  final current = await settingsRepo.getSeedVersion();
  if (current >= _kSeedVersion) return;

  // ── Users ─────────────────────────────────────────────────────────────
  const u1 = 'user-maria';
  const u2 = 'user-carlos';
  const u3 = 'user-lucia';
  const u4 = 'user-diego';

  final users = [
    const AppUser(
      id: u1,
      name: 'María',
      initials: 'MA',
      role: UserRole.admin,
      assignedPropertyIds: ['prop-fn13', 'prop-madrid', 'prop-romeo', 'prop-julieta', 'prop-moroto'],
    ),
    const AppUser(
      id: u2,
      name: 'Carlos',
      initials: 'CA',
      role: UserRole.cleaning,
      assignedPropertyIds: ['prop-fn13', 'prop-madrid', 'prop-romeo'],
    ),
    const AppUser(
      id: u3,
      name: 'Lucía',
      initials: 'LU',
      role: UserRole.cleaning,
      assignedPropertyIds: ['prop-julieta', 'prop-moroto'],
    ),
    const AppUser(
      id: u4,
      name: 'Diego',
      initials: 'DI',
      role: UserRole.maintenance,
      assignedPropertyIds: ['prop-fn13', 'prop-madrid', 'prop-romeo', 'prop-julieta', 'prop-moroto'],
    ),
  ];
  await userRepo.saveAll(users);

  // ── Properties ────────────────────────────────────────────────────────
  const props = [
    Property(id: 'prop-fn13', code: 'FN13', name: 'FN13', totalRooms: 13, colorSeed: 0),
    Property(id: 'prop-madrid', code: 'MDR', name: 'Madrid Rio', totalRooms: 8, colorSeed: 1),
    Property(id: 'prop-romeo', code: 'ROM', name: 'Romeo', totalRooms: 6, colorSeed: 2),
    Property(id: 'prop-julieta', code: 'JUL', name: 'Julieta', totalRooms: 5, colorSeed: 3),
    Property(id: 'prop-moroto', code: 'MOR', name: 'Moroto', totalRooms: 10, colorSeed: 4),
  ];
  await propertyRepo.saveAll(props);

  // ── Field definitions ─────────────────────────────────────────────────
  final fields = [
    const FieldDef(id: 'f-salida', label: 'Salida', type: FieldType.text, showOnCard: true, icon: 'exit_to_app'),
    const FieldDef(id: 'f-entrada', label: 'Entrada', type: FieldType.text, showOnCard: true, icon: 'login'),
    const FieldDef(id: 'f-cobrar', label: 'Cobrar', type: FieldType.checkbox, showOnCard: true, icon: 'payments'),
    const FieldDef(
      id: 'f-estado',
      label: 'Estado',
      type: FieldType.select,
      options: ['Limpia', 'Sucia', 'En proceso', 'Revisión'],
      showOnCard: false,
      icon: 'cleaning_services',
    ),
    const FieldDef(id: 'f-fotos', label: 'Fotos', type: FieldType.image, showOnCard: false, icon: 'photo_camera'),
  ];
  await fieldRepo.saveAll(fields);

  // ── Columns per property ──────────────────────────────────────────────
  final defaultColTitles = [
    ('CHECKOUT', ColumnColor.orange),
    ('LIMPIEZA', ColumnColor.yellow),
    ('LISTO', ColumnColor.green),
    ('OCUPADO', ColumnColor.blue),
    ('MANTENIMIENTO', ColumnColor.red),
  ];

  final allColumns = <BoardColumn>[];

  for (final prop in props) {
    for (var i = 0; i < defaultColTitles.length; i++) {
      final (title, color) = defaultColTitles[i];
      allColumns.add(BoardColumn(
        id: 'col-${prop.id}-$i',
        propertyId: prop.id,
        title: title,
        color: color,
        position: i,
      ));
    }
  }
  await columnRepo.saveAll(allColumns);

  // ── Sample cards for FN13 ─────────────────────────────────────────────
  final now = DateTime(2026, 5, 5, 10, 0);
  final tomorrow = DateTime(2026, 5, 6);

  final sampleCards = [
    BoardCard(id: 'card-fn13-1', propertyId: 'prop-fn13', columnId: 'col-prop-fn13-0', title: 'Habitación 101', roomCode: '101', priority: CardPriority.high, checkinDate: tomorrow, assignedToId: u2, createdAt: now, customFields: {'f-salida': '10:00', 'f-entrada': '15:00'}),
    BoardCard(id: 'card-fn13-2', propertyId: 'prop-fn13', columnId: 'col-prop-fn13-0', title: 'Habitación 102', roomCode: '102', priority: CardPriority.normal, assignedToId: u2, createdAt: now, position: 1, customFields: {'f-salida': '11:00'}),
    BoardCard(id: 'card-fn13-3', propertyId: 'prop-fn13', columnId: 'col-prop-fn13-1', title: 'Habitación 201', roomCode: '201', priority: CardPriority.normal, assignedToId: u2, createdAt: now, customFields: {'f-estado': 'En proceso'}),
    BoardCard(id: 'card-fn13-4', propertyId: 'prop-fn13', columnId: 'col-prop-fn13-1', title: 'Habitación 202', roomCode: '202', priority: CardPriority.low, createdAt: now, position: 1),
    BoardCard(id: 'card-fn13-5', propertyId: 'prop-fn13', columnId: 'col-prop-fn13-2', title: 'Habitación 301', roomCode: '301', isDone: true, priority: CardPriority.normal, cleanedBy: 'Carlos', createdAt: now),
    BoardCard(id: 'card-fn13-6', propertyId: 'prop-fn13', columnId: 'col-prop-fn13-2', title: 'Habitación 302', roomCode: '302', isDone: true, priority: CardPriority.normal, cleanedBy: 'Carlos', createdAt: now, position: 1),
    BoardCard(id: 'card-fn13-7', propertyId: 'prop-fn13', columnId: 'col-prop-fn13-4', title: 'Fuga agua baño 103', priority: CardPriority.high, kind: CardKind.task, assignedToId: u4, createdAt: now, description: 'El grifo del baño gotea constantemente.'),
    BoardCard(id: 'card-madrid-1', propertyId: 'prop-madrid', columnId: 'col-prop-madrid-0', title: 'Suite A', roomCode: 'SA', priority: CardPriority.high, checkinDate: tomorrow, assignedToId: u2, createdAt: now),
    BoardCard(id: 'card-madrid-2', propertyId: 'prop-madrid', columnId: 'col-prop-madrid-1', title: 'Suite B', roomCode: 'SB', priority: CardPriority.normal, assignedToId: u2, createdAt: now),
    BoardCard(id: 'card-madrid-3', propertyId: 'prop-madrid', columnId: 'col-prop-madrid-2', title: 'Suite C', roomCode: 'SC', isDone: true, cleanedBy: 'Carlos', createdAt: now),
    BoardCard(id: 'card-romeo-1', propertyId: 'prop-romeo', columnId: 'col-prop-romeo-1', title: 'Hab. 1', roomCode: 'R1', assignedToId: u2, createdAt: now),
    BoardCard(id: 'card-romeo-2', propertyId: 'prop-romeo', columnId: 'col-prop-romeo-2', title: 'Hab. 2', roomCode: 'R2', isDone: true, cleanedBy: 'Carlos', createdAt: now),
    BoardCard(id: 'card-julieta-1', propertyId: 'prop-julieta', columnId: 'col-prop-julieta-0', title: 'Hab. Principal', roomCode: 'JP', priority: CardPriority.high, assignedToId: u3, checkinDate: tomorrow, createdAt: now),
    BoardCard(id: 'card-julieta-2', propertyId: 'prop-julieta', columnId: 'col-prop-julieta-2', title: 'Hab. Doble', roomCode: 'JD', isDone: true, cleanedBy: 'Lucía', createdAt: now),
    BoardCard(id: 'card-moroto-1', propertyId: 'prop-moroto', columnId: 'col-prop-moroto-1', title: 'Hab. 01', roomCode: 'M01', assignedToId: u3, createdAt: now),
    BoardCard(id: 'card-moroto-2', propertyId: 'prop-moroto', columnId: 'col-prop-moroto-4', title: 'Cambiar cerradura 03', roomCode: 'M03', priority: CardPriority.high, kind: CardKind.task, assignedToId: u4, createdAt: now),
  ];
  await cardRepo.saveAll(sampleCards);

  await settingsRepo.setSeedVersion(_kSeedVersion);
}
