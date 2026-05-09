package handlers

import (
	"context"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/store"
)

// effectiveOwnerID returns the user ID under whose tenant scope [userID] operates.
//
//   - admin                 → "" (no tenant scoping; sees everything)
//   - owner                 → their own ID
//   - supervisor            → their creator (the owner who created them)
//   - cleaning/operator/maintenance → walk up `created_by` until an owner is found
//
// Returns "" when no owner can be resolved (legacy data, admin, etc.).
func effectiveOwnerID(ctx context.Context, s store.Store, userID string, role domain.UserRole) string {
	switch role {
	case domain.RoleAdmin:
		return ""
	case domain.RoleOwner:
		return userID
	}
	// Walk up the created_by chain until we find a user with role=owner.
	current := userID
	for i := 0; i < 5; i++ { // safety bound
		u, err := s.Users().GetByID(ctx, current)
		if err != nil || u == nil { return "" }
		if u.Role == domain.RoleOwner { return u.ID }
		if u.CreatedBy == "" { return "" }
		current = u.CreatedBy
	}
	return ""
}

// canCreateRole returns whether an actor of [actorRole] is allowed to create
// a user with [targetRole]. Admin can create anything. Owner can create only
// supervisors. Supervisor can create cleaning, operator and maintenance.
func canCreateRole(actorRole, targetRole domain.UserRole) bool {
	switch actorRole {
	case domain.RoleAdmin:
		return true
	case domain.RoleOwner:
		return targetRole == domain.RoleSupervisor
	case domain.RoleSupervisor:
		return targetRole == domain.RoleCleaning ||
			targetRole == domain.RoleOperator ||
			targetRole == domain.RoleMaintenance
	}
	return false
}

// accessiblePropertyIDs returns the set of property IDs that the given actor
// can see / interact with. For admin it returns nil (meaning "all"); for
// everyone else it builds an explicit set:
//
//   - owner       → properties they own
//   - supervisor  → properties they're assigned to
//   - workers     → properties belonging to one of their groups
func accessiblePropertyIDs(ctx context.Context, s store.Store, userID string, role domain.UserRole) (map[string]struct{}, bool) {
	if role == domain.RoleAdmin {
		return nil, true
	}
	set := make(map[string]struct{})
	switch role {
	case domain.RoleOwner:
		props, err := s.Properties().ListByOwner(ctx, userID)
		if err != nil { return set, false }
		for _, p := range props { set[p.ID] = struct{}{} }
	case domain.RoleSupervisor:
		props, err := s.Properties().ListBySupervisor(ctx, userID)
		if err != nil { return set, false }
		for _, p := range props { set[p.ID] = struct{}{} }
	case domain.RoleCleaning, domain.RoleMaintenance, domain.RoleOperator:
		ids, err := s.Groups().ListPropertiesForUser(ctx, userID)
		if err != nil { return set, false }
		for _, id := range ids { set[id] = struct{}{} }
	}
	return set, false
}
