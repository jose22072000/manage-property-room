package handlers

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type AuditHandler struct {
	Store store.Store
}

func (h *AuditHandler) List(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	actorID := httpx.UserIDFrom(ctx)
	actorRole := httpx.RoleFrom(ctx)

	limit := 500
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 2000 {
			limit = n
		}
	}

	var events []domain.AuditEvent
	var err error

	switch actorRole {
	case domain.RoleAdmin:
		events, err = h.Store.Audit().List(ctx, limit)
	case domain.RoleOwner:
		props, propErr := h.Store.Properties().ListByOwner(ctx, actorID)
		if propErr != nil { httpx.HandleError(w, propErr); return }
		ids := make([]string, 0, len(props))
		for _, p := range props { ids = append(ids, p.ID) }
		events, err = h.Store.Audit().ListByPropertyIDs(ctx, ids, limit)
	case domain.RoleSupervisor:
		props, propErr := h.Store.Properties().ListBySupervisor(ctx, actorID)
		if propErr != nil { httpx.HandleError(w, propErr); return }
		ids := make([]string, 0, len(props))
		for _, p := range props { ids = append(ids, p.ID) }
		events, err = h.Store.Audit().ListByPropertyIDs(ctx, ids, limit)
	default:
		httpx.WriteError(w, http.StatusForbidden, "FORBIDDEN", "access denied")
		return
	}
	if err != nil { httpx.HandleError(w, err); return }
	if events == nil { events = []domain.AuditEvent{} }
	httpx.WriteJSON(w, http.StatusOK, events)
}

func (h *AuditHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Store.Audit().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err); return
	}
	w.WriteHeader(http.StatusNoContent)
}
