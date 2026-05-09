package handlers

import (
	"context"
	"net"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

// recordAudit writes an audit event in the background (non-blocking, best-effort).
func recordAudit(ctx context.Context, s store.Store, action, entity, entityID, detail string, propertyID ...string) {
	actorID := httpx.UserIDFrom(ctx)
	actorName := httpx.ActorNameFrom(ctx)
	actorIP := httpx.ActorIPFrom(ctx)
	pid := ""
	if len(propertyID) > 0 { pid = propertyID[0] }

	// Detach context so the goroutine isn't cancelled when the request ends.
	go func() {
		// Fallback: JWT from old tokens may not carry the name claim — look up DB.
		if actorName == "" && actorID != "" {
			if u, err := s.Users().GetByID(context.Background(), actorID); err == nil {
				actorName = u.Name
			}
		}
		_ = s.Audit().Create(context.Background(), &domain.AuditEvent{
			ID:         uuid.NewString(),
			ActorID:    actorID,
			ActorName:  actorName,
			ActorIP:    actorIP,
			Action:     action,
			Entity:     entity,
			EntityID:   entityID,
			Detail:     detail,
			PropertyID: pid,
			CreatedAt:  time.Now().UTC(),
		})
	}()
}

// clientIP extracts the real client IP from a request, respecting X-Forwarded-For.
func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// X-Forwarded-For can be a comma-separated list; take the first (original client).
		if host, _, err := net.SplitHostPort(xff); err == nil {
			return host
		}
		return xff
	}
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
