package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type PropertiesHandler struct {
	Store store.Store
}

type propertyRequest struct {
	Code       string `json:"code"`
	Name       string `json:"name"`
	TotalRooms int    `json:"totalRooms"`
	ColorSeed  int    `json:"colorSeed"`
	Position   int    `json:"position"`
}

func (h *PropertiesHandler) List(w http.ResponseWriter, r *http.Request) {
	items, err := h.Store.Properties().List(r.Context())
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, items)
}

func (h *PropertiesHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	p, err := h.Store.Properties().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, p)
}

func (h *PropertiesHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req propertyRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Name == "" || req.Code == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "code and name required"); return
	}
	p := &domain.Property{
		ID: uuid.NewString(),
		Code: req.Code, Name: req.Name,
		TotalRooms: req.TotalRooms, ColorSeed: req.ColorSeed, Position: req.Position,
	}
	if err := h.Store.Properties().Create(r.Context(), p); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "create", "property", p.ID, p.Name)
	httpx.WriteJSON(w, http.StatusCreated, p)
}

func (h *PropertiesHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	p, err := h.Store.Properties().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	var req propertyRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Code != "" { p.Code = req.Code }
	if req.Name != "" { p.Name = req.Name }
	p.TotalRooms = req.TotalRooms
	p.ColorSeed = req.ColorSeed
	p.Position = req.Position
	if err := h.Store.Properties().Update(r.Context(), p); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "update", "property", p.ID, p.Name)
	httpx.WriteJSON(w, http.StatusOK, p)
}

func (h *PropertiesHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	p, _ := h.Store.Properties().GetByID(r.Context(), id)
	pName := ""
	if p != nil { pName = p.Name }
	if err := h.Store.Properties().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "delete", "property", id, pName)
	w.WriteHeader(http.StatusNoContent)
}

type assignWorkersRequest struct {
	WorkerIDs []string `json:"workerIds"`
}

// AssignWorkers replaces the worker assignment set for a property.
// For every user, the property is added/removed depending on whether their
// id is in req.WorkerIDs.
func (h *PropertiesHandler) AssignWorkers(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req assignWorkersRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	wanted := make(map[string]struct{}, len(req.WorkerIDs))
	for _, uid := range req.WorkerIDs {
		wanted[uid] = struct{}{}
	}
	all, err := h.Store.Users().List(r.Context())
	if err != nil { httpx.HandleError(w, err); return }
	for _, u := range all {
		hasNow := contains(u.AssignedPropertyIDs, id)
		_, shouldHave := wanted[u.ID]
		if hasNow == shouldHave {
			continue
		}
		next := make([]string, 0, len(u.AssignedPropertyIDs)+1)
		if shouldHave {
			next = append(next, u.AssignedPropertyIDs...)
			next = append(next, id)
		} else {
			for _, pid := range u.AssignedPropertyIDs {
				if pid != id { next = append(next, pid) }
			}
		}
		if err := h.Store.Users().SetAssignedProperties(r.Context(), u.ID, next); err != nil {
			httpx.HandleError(w, err); return
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// Workers returns all users currently assigned to the property.
func (h *PropertiesHandler) Workers(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	users, err := h.Store.Users().ListByProperty(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, users)
}

// Board returns all columns + cards for a property.
func (h *PropertiesHandler) Board(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	cols, err := h.Store.Columns().ListByProperty(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	cards, err := h.Store.Cards().ListByProperty(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"columns": cols, "cards": cards,
	})
}

func contains(s []string, v string) bool {
	for _, x := range s { if x == v { return true } }
	return false
}
