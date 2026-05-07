package handlers

import (
	"net/http"
	"strconv"

	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type AuditHandler struct {
	Store store.Store
}

func (h *AuditHandler) List(w http.ResponseWriter, r *http.Request) {
	limit := 200
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 1000 {
			limit = n
		}
	}
	events, err := h.Store.Audit().List(r.Context(), limit)
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, events)
}
