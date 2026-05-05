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
    if (user.role == UserRole.admin) return true;
    return user.assignedPropertyIds.contains(propertyId);
  }

  // ─────────────────────────────────────────
  //  Board-level actions
  // ─────────────────────────────────────────

  /// Whether [user] can perform [action] on the board.
  /// Admin can do everything; workers have limited column/board management.
  static bool canBoard(AppUser user, BoardAction action) {
    if (user.role == UserRole.admin) return true;

    switch (action) {
      // Workers can add cards if they see the board
      case BoardAction.addCard:
        return true;
      // Only admins may manage structure, users and fields
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
      case UserRole.cleaning:
        return _cleaningCanCard(user, card, action);
      case UserRole.maintenance:
        return _maintenanceCanCard(user, card, action);
      case UserRole.admin:
        return true;
    }
  }

  static bool _cleaningCanCard(AppUser user, BoardCard card, CardAction action) {
    switch (action) {
      case CardAction.toggleDone:
      case CardAction.comment:
      case CardAction.uploadImage:
      case CardAction.editCustomField:
        return true;
      // Can only (re)assign to themselves
      case CardAction.assign:
        return true;
      // Cannot touch structure / metadata
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

  /// All roles can see all columns by default.
  /// Override here if column-level RBAC is needed in the future.
  static bool canSeeColumn(AppUser user, BoardColumn column) {
    return canSeeProperty(user, column.propertyId);
  }
}
