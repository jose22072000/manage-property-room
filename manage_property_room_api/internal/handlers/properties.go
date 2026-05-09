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
	ImageURL   string `json:"imageUrl"`
	OwnerID    string `json:"ownerId"`
}

func (h *PropertiesHandler) List(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	actorID := httpx.UserIDFrom(ctx)
	actorRole := httpx.RoleFrom(ctx)
	var items []domain.Property
	var err error
	switch actorRole {
	case domain.RoleOwner:
		items, err = h.Store.Properties().ListByOwner(ctx, actorID)
	case domain.RoleSupervisor:
		items, err = h.Store.Properties().ListBySupervisor(ctx, actorID)
	case domain.RoleCleaning, domain.RoleMaintenance, domain.RoleOperator:
		// Workers see only properties they're members of via groups.
		propIDs, e := h.Store.Groups().ListPropertiesForUser(ctx, actorID)
		if e != nil { httpx.HandleError(w, e); return }
		all, e2 := h.Store.Properties().List(ctx)
		if e2 != nil { httpx.HandleError(w, e2); return }
		set := make(map[string]struct{}, len(propIDs))
		for _, id := range propIDs { set[id] = struct{}{} }
		items = make([]domain.Property, 0, len(propIDs))
		for _, p := range all {
			if _, ok := set[p.ID]; ok { items = append(items, p) }
		}
	default:
		items, err = h.Store.Properties().List(ctx)
	}
	if err != nil { httpx.HandleError(w, err); return }
	if items == nil { items = []domain.Property{} }
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
		ImageURL: req.ImageURL,
	}
	if httpx.RoleFrom(r.Context()) == domain.RoleOwner {
		p.OwnerUserID = httpx.UserIDFrom(r.Context())
	} else if req.OwnerID != "" {
		p.OwnerUserID = req.OwnerID
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
	if req.ImageURL != "" { p.ImageURL = req.ImageURL }
	if req.OwnerID != "" { p.OwnerUserID = req.OwnerID }
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

type assignSupervisorsRequest struct {
	SupervisorIDs []string `json:"supervisorIds"`
}

// AssignSupervisors replaces the supervisor set for a property.
func (h *PropertiesHandler) AssignSupervisors(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req assignSupervisorsRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if err := h.Store.PropertySupervisors().SetSupervisors(r.Context(), id, req.SupervisorIDs); err != nil {
		httpx.HandleError(w, err); return
	}
	// For each supervisor, also update their ListBySupervisor so they can see the property.
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// GetSupervisors returns the list of supervisor IDs assigned to a property.
func (h *PropertiesHandler) GetSupervisors(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	ids, err := h.Store.PropertySupervisors().ListForProperty(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	if ids == nil { ids = []string{} }
	httpx.WriteJSON(w, http.StatusOK, ids)
}

type assignOwnerRequest struct {
	OwnerID string `json:"ownerId"`
}

// AssignOwner sets (or clears) the owner of a property. Admin-only.
func (h *PropertiesHandler) AssignOwner(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req assignOwnerRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	p, err := h.Store.Properties().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	p.OwnerUserID = req.OwnerID
	if err := h.Store.Properties().Update(r.Context(), p); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "assign-owner", "property", p.ID, p.Name)
	httpx.WriteJSON(w, http.StatusOK, p)
}
