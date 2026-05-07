package handlers

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

// recordAudit writes an audit event in the background (non-blocking, best-effort).
func recordAudit(ctx context.Context, s store.Store, action, entity, entityID, detail string) {
	actorID := httpx.UserIDFrom(ctx)
	actorName := httpx.ActorNameFrom(ctx)

	// Detach context so the goroutine isn't cancelled when the request ends.
	go func() {
		// Fallback: JWT from old tokens may not carry the name claim — look up DB.
		if actorName == "" && actorID != "" {
			if u, err := s.Users().GetByID(context.Background(), actorID); err == nil {
				actorName = u.Name
			}
		}
		_ = s.Audit().Create(context.Background(), &domain.AuditEvent{
			ID:        uuid.NewString(),
			ActorID:   actorID,
			ActorName: actorName,
			Action:    action,
			Entity:    entity,
			EntityID:  entityID,
			Detail:    detail,
			CreatedAt: time.Now().UTC(),
		})
	}()
}
