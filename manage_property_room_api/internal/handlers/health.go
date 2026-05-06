package handlers

import (
	"net/http"

	"github.com/jose/manage_property_room_api/internal/httpx"
)

func Health(w http.ResponseWriter, r *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}
