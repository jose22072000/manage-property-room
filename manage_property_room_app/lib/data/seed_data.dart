import '../domain/domain.dart';
import '../data/repositories/repositories.dart';

/// Current seed version. Bump when data shape changes to re-seed.
const _kSeedVersion = 2;

/// Inserts initial demo data if [settingsRepo.getSeedVersion] < [_kSeedVersion].
///
/// Per user request "quita todo las cosas de prueba... solo deja el admin para
/// probar todo", solamente sembramos:
///   • 1 usuario admin (María).
///   • 5 propiedades + columnas por defecto.
///   • Definiciones de campos personalizados.
/// Sin cartas de prueba, sin otros usuarios.
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

  // ── User (admin only) ─────────────────────────────────────────────────
  const users = [
    AppUser(
      id: 'user-maria',
      name: 'María',
      initials: 'MA',
      role: UserRole.admin,
      assignedPropertyIds: [
        'prop-fn13',
        'prop-madrid',
        'prop-romeo',
        'prop-julieta',
        'prop-moroto',
      ],
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
  const fields = [
    FieldDef(id: 'f-salida', label: 'Salida', type: FieldType.text, showOnCard: true, icon: 'exit_to_app'),
    FieldDef(id: 'f-entrada', label: 'Entrada', type: FieldType.text, showOnCard: true, icon: 'login'),
    FieldDef(id: 'f-cobrar', label: 'Cobrar', type: FieldType.checkbox, showOnCard: true, icon: 'payments'),
    FieldDef(
      id: 'f-estado',
      label: 'Estado',
      type: FieldType.select,
      options: ['Limpia', 'Sucia', 'En proceso', 'Revisión'],
      showOnCard: false,
      icon: 'cleaning_services',
    ),
    FieldDef(id: 'f-fotos', label: 'Fotos', type: FieldType.image, showOnCard: false, icon: 'photo_camera'),
  ];
  await fieldRepo.saveAll(fields);

  // ── Default columns per property ──────────────────────────────────────
  const defaultColTitles = [
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

  // Sin cartas: el usuario añade lo que quiera probar.
  await cardRepo.saveAll(const <BoardCard>[]);

  await settingsRepo.setSeedVersion(_kSeedVersion);
}
