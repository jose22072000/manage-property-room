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
      case CardAction.archive:
      case CardAction.move:
        return true;
      case CardAction.editTitle:
      case CardAction.editDescription:
      case CardAction.setPriority:
      case CardAction.setCheckin:
      case CardAction.restore:
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
      case CardAction.uploadImage:
      case CardAction.editCustomField:
      case CardAction.archive:
      case CardAction.move:
        return true;
      case CardAction.editTitle:
      case CardAction.editDescription:
      case CardAction.setCheckin:
      case CardAction.restore:
      case CardAction.delete:
        return false;
    }
  }

  static bool canManageGroups(AppUser user) {
    // Admin sees all groups; owner sees groups created by their supervisors;
    // supervisor sees only their own groups (server enforces the scoping).
    return user.role == UserRole.admin ||
        user.role == UserRole.owner ||
        user.role == UserRole.supervisor;
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
  /// Admin sees all; owner sees own-property events; supervisor sees assigned-property events.
  static bool canSeeNotifications(AppUser user) {
    return user.role == UserRole.admin ||
        user.role == UserRole.owner ||
        user.role == UserRole.supervisor;
  }

  /// Whether [user] can assign supervisors to a property.
  static bool canAssignSupervisors(AppUser user, Property property) {
    if (user.role == UserRole.admin) return true;
    if (user.role == UserRole.owner && property.ownerUserId == user.id) return true;
    return false;
  }

  /// Whether [user] can edit (rename, change image, etc) a property.
  /// Admin can edit any; owner can edit only properties they own.
  static bool canEditProperty(AppUser user, Property property) {
    if (user.role == UserRole.admin) return true;
    if (user.role == UserRole.owner && property.ownerUserId == user.id) return true;
    return false;
  }

  /// Whether [user] can delete a property. Same rules as edit.
  static bool canDeleteProperty(AppUser user, Property property) =>
      canEditProperty(user, property);

  // ─────────────────────────────────────────
  //  Column visibility
  // ─────────────────────────────────────────

  static bool canSeeColumn(AppUser user, BoardColumn column) {
    return canSeeProperty(user, column.propertyId);
  }

  // ─────────────────────────────────────────
  //  Navigation visibility (header / bottom-nav)
  // ─────────────────────────────────────────

  /// Returns the canonical list of navigation items the [user] should see in
  /// the header (web) and bottom-nav (mobile). Used by `app_shell.dart` and
  /// the router's redirect guard so both stay in sync.
  static List<NavItem> visibleNavItems(AppUser user) {
    switch (user.role) {
      case UserRole.admin:
        return const [
          NavItem.inicio,
          NavItem.todo,
          NavItem.archive,
          NavItem.users,
          NavItem.audit,
          NavItem.settings,
        ];
      case UserRole.owner:
        // Owner sees everything. Users page is scoped on the backend.
        return const [
          NavItem.inicio,
          NavItem.todo,
          NavItem.archive,
          NavItem.users,
          NavItem.audit,
          NavItem.settings,
        ];
      case UserRole.supervisor:
        // Supervisor: no settings, no global audit page. Notifications are
        // scoped to their assigned properties.
        return const [
          NavItem.inicio,
          NavItem.todo,
          NavItem.archive,
          NavItem.users,
          NavItem.audit,
        ];
      case UserRole.operator:
        return const [
          NavItem.inicio,
          NavItem.todo,
          NavItem.settings,
        ];
      case UserRole.cleaning:
      case UserRole.maintenance:
        // Workers only see Inicio (filtered to assigned properties).
        // Tapping their property goes straight to the board, where
        // they can create/move/archive/mark-done/use custom fields.
        return const [
          NavItem.inicio,
        ];
    }
  }

  /// Whether [user] is allowed to navigate to [route]. Used by the router
  /// redirect to block direct URL access by restricted roles.
  static bool canVisitRoute(AppUser user, String route) {
    final items = visibleNavItems(user);
    if (route == '/' || route.startsWith('/properties/')) {
      return items.contains(NavItem.inicio);
    }
    if (route.startsWith('/todo')) return items.contains(NavItem.todo);
    if (route.startsWith('/archive')) return items.contains(NavItem.archive);
    if (route.startsWith('/users') || route.startsWith('/groups')) {
      return items.contains(NavItem.users);
    }
    if (route.startsWith('/audit')) return items.contains(NavItem.audit);
    if (route.startsWith('/settings')) return items.contains(NavItem.settings);
    // Webhooks: admin and owner only.
    if (route.startsWith('/webhooks')) {
      return user.role == UserRole.admin || user.role == UserRole.owner;
    }
    // Notifications page: admin, owner, supervisor.
    if (route.startsWith('/notifications')) {
      return user.role == UserRole.admin ||
          user.role == UserRole.owner ||
          user.role == UserRole.supervisor;
    }
    // Allow login + debug + everything else by default
    return true;
  }
}

/// Canonical navigation destinations used by both the AppShell and the
/// router. Keeping a single enum avoids drift between the menu (what's
/// shown) and the redirect guards (what's accessible).
enum NavItem { inicio, todo, archive, users, audit, settings }
