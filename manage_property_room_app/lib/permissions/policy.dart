import '../domain/domain.dart';

/// Pure, stateless permission engine.
/// All methods are static — no side effects.
class Policy {
  Policy._();

  // ─────────────────────────────────────────
  //  Property visibility
  // ─────────────────────────────────────────

  /// Whether [user] can see [propertyId] in the properties list / board.
  static bool canSeeProperty(AppUser user, String propertyId) {
    if (user.role == UserRole.admin || user.role == UserRole.operator) return true;
    return user.assignedPropertyIds.contains(propertyId);
  }

  // ─────────────────────────────────────────
  //  Board-level actions
  // ─────────────────────────────────────────

  static bool canBoard(AppUser user, BoardAction action) {
    if (user.role == UserRole.admin) return true;

    switch (user.role) {
      case UserRole.operator:
        return _operatorCanBoard(action);
      case UserRole.cleaning:
      case UserRole.maintenance:
        return _workerCanBoard(action);
      case UserRole.admin:
        return true;
    }
  }

  static bool _operatorCanBoard(BoardAction action) {
    switch (action) {
      case BoardAction.addCard:
      case BoardAction.addColumn:
      case BoardAction.renameColumn:
      case BoardAction.setColumnColor:
      case BoardAction.moveColumn:
      case BoardAction.archiveColumn:
      case BoardAction.configureColumn:
      case BoardAction.copyColumn:
        return true;
      case BoardAction.resetAll:
      case BoardAction.manageFields:
      case BoardAction.manageTemplates:
      case BoardAction.manageUsers:
        return false;
    }
  }

  static bool _workerCanBoard(BoardAction action) {
    switch (action) {
      case BoardAction.addCard:
        return true;
      case BoardAction.addColumn:
      case BoardAction.renameColumn:
      case BoardAction.setColumnColor:
      case BoardAction.moveColumn:
      case BoardAction.archiveColumn:
      case BoardAction.configureColumn:
      case BoardAction.copyColumn:
      case BoardAction.resetAll:
      case BoardAction.manageFields:
      case BoardAction.manageTemplates:
      case BoardAction.manageUsers:
        return false;
    }
  }

  // ─────────────────────────────────────────
  //  Card-level actions
  // ─────────────────────────────────────────

  static bool canCard(AppUser user, BoardCard card, CardAction action) {
    if (user.role == UserRole.admin) return true;

    switch (user.role) {
      case UserRole.operator:
        return _operatorCanCard(card, action);
      case UserRole.cleaning:
        return _cleaningCanCard(user, card, action);
      case UserRole.maintenance:
        return _maintenanceCanCard(user, card, action);
      case UserRole.admin:
        return true;
    }
  }

  static bool _operatorCanCard(BoardCard card, CardAction action) {
    switch (action) {
      case CardAction.toggleDone:
      case CardAction.editTitle:
      case CardAction.editDescription:
      case CardAction.editCustomField:
      case CardAction.uploadImage:
      case CardAction.comment:
      case CardAction.assign:
      case CardAction.setPriority:
      case CardAction.setCheckin:
      case CardAction.archive:
      case CardAction.restore:
      case CardAction.move:
        return true;
      case CardAction.delete:
        return false;
    }
  }

  static bool _cleaningCanCard(AppUser user, BoardCard card, CardAction action) {
    switch (action) {
      case CardAction.toggleDone:
      case CardAction.comment:
      case CardAction.uploadImage:
      case CardAction.editCustomField:
      case CardAction.assign:
        return true;
      case CardAction.editTitle:
      case CardAction.editDescription:
      case CardAction.setPriority:
      case CardAction.setCheckin:
      case CardAction.archive:
      case CardAction.restore:
      case CardAction.move:
      case CardAction.delete:
        return false;
    }
  }

  static bool _maintenanceCanCard(AppUser user, BoardCard card, CardAction action) {
    switch (action) {
      case CardAction.toggleDone:
      case CardAction.comment:
      case CardAction.setPriority:
      case CardAction.assign:
        return true;
      case CardAction.uploadImage:
      case CardAction.editCustomField:
      case CardAction.editTitle:
      case CardAction.editDescription:
      case CardAction.setCheckin:
      case CardAction.archive:
      case CardAction.restore:
      case CardAction.move:
      case CardAction.delete:
        return false;
    }
  }

  // ─────────────────────────────────────────
  //  Column visibility
  // ─────────────────────────────────────────

  static bool canSeeColumn(AppUser user, BoardColumn column) {
    return canSeeProperty(user, column.propertyId);
  }
}
