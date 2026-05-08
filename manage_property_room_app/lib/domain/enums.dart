// Domain enums — no Flutter dependency

enum UserRole { admin, operator, cleaning, maintenance, owner, supervisor }

enum CardKind { room, task, free }

enum FieldType { text, select, checkbox, image }

enum ColumnColor {
  green,
  yellow,
  orange,
  red,
  purple,
  blue,
  cyan,
  lime,
  pink,
  gray,
}

enum CardPriority { low, normal, high }

/// Actions a user can perform on a card.
enum CardAction {
  toggleDone,
  editTitle,
  editDescription,
  editCustomField,
  uploadImage,
  comment,
  assign,
  setPriority,
  setCheckin,
  archive,
  restore,
  move,
  delete,
}

/// Actions a user can perform on the board / columns.
enum BoardAction {
  addColumn,
  renameColumn,
  setColumnColor,
  moveColumn,
  archiveColumn,
  configureColumn,
  copyColumn,
  addCard,
  resetAll,
  manageFields,
  manageTemplates,
  manageUsers,
}
