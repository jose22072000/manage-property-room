package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type FieldsHandler struct {
	Store store.Store
}

type fieldRequest struct {
	Label      string            `json:"label"`
	Type       domain.FieldType  `json:"type"`
	Options    []string          `json:"options"`
	Enabled    bool              `json:"enabled"`
	ShowOnCard bool              `json:"showOnCard"`
	Icon       string            `json:"icon"`
	OffLabel   string            `json:"offLabel"`
	Position   int               `json:"position"`
}

func (h *FieldsHandler) List(w http.ResponseWriter, r *http.Request) {
	items, err := h.Store.Fields().List(r.Context())
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *FieldsHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req fieldRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Label == "" || req.Type == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "label and type required"); return
	}
	f := &domain.FieldDef{
		ID: uuid.NewString(), Label: req.Label, Type: req.Type,
		Options: req.Options, Enabled: req.Enabled, ShowOnCard: req.ShowOnCard,
		Icon: req.Icon, OffLabel: req.OffLabel, Position: req.Position,
	}
	if err := h.Store.Fields().Create(r.Context(), f); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusCreated, f)
}

func (h *FieldsHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	f, err := h.Store.Fields().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	var req fieldRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Label != "" { f.Label = req.Label }
	if req.Type != "" { f.Type = req.Type }
	if req.Options != nil { f.Options = req.Options }
	f.Enabled = req.Enabled
	f.ShowOnCard = req.ShowOnCard
	if req.Icon != "" { f.Icon = req.Icon }
	if req.OffLabel != "" { f.OffLabel = req.OffLabel }
	f.Position = req.Position
	if err := h.Store.Fields().Update(r.Context(), f); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusOK, f)
}

func (h *FieldsHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Store.Fields().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err); return
	}
	w.WriteHeader(http.StatusNoContent)
}

type reorderRequest struct {
	IDs []string `json:"ids"`
}

func (h *FieldsHandler) Reorder(w http.ResponseWriter, r *http.Request) {
	var req reorderRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if err := h.Store.Fields().Reorder(r.Context(), req.IDs); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}
