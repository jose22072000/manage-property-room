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
    if (user.role == UserRole.admin ||
        user.role == UserRole.operator ||
        user.role == UserRole.owner ||
        user.role == UserRole.supervisor) return true;
    return user.assignedPropertyIds.contains(propertyId);
  }

  // ─────────────────────────────────────────
  //  Board-level actions
  // ─────────────────────────────────────────

  static bool canBoard(AppUser user, BoardAction action) {
    if (user.role == UserRole.admin) return true;

    switch (user.role) {
      case UserRole.operator:
      case UserRole.owner:
      case UserRole.supervisor:
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
      case UserRole.owner:
      case UserRole.supervisor:
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

  static bool canManageGroups(AppUser user) {
    // Only admin and supervisor manage groups; owner does not
    return user.role == UserRole.admin || user.role == UserRole.supervisor;
  }

  /// Whether [user] can see the Users/Groups management page.
  static bool canSeeUserManagement(AppUser user) {
    return user.role == UserRole.admin ||
        user.role == UserRole.owner ||
        user.role == UserRole.supervisor;
  }

  /// Whether [user] can create properties.
  static bool canCreateProperty(AppUser user) {
    return user.role == UserRole.admin || user.role == UserRole.owner;
  }

  /// Whether [user] can see the Notifications page (audit events).
  static bool canSeeNotifications(AppUser user) {
    return user.role == UserRole.admin || user.role == UserRole.owner;
  }

  /// Whether [user] can assign supervisors to a property.
  static bool canAssignSupervisors(AppUser user, Property property) {
    if (user.role == UserRole.admin) return true;
    if (user.role == UserRole.owner && property.ownerUserId == user.id) return true;
    return false;
  }

  // ─────────────────────────────────────────
  //  Column visibility
  // ─────────────────────────────────────────

  static bool canSeeColumn(AppUser user, BoardColumn column) {
    return canSeeProperty(user, column.propertyId);
  }
}
