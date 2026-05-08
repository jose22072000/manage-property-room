package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type GroupsHandler struct {
	Store store.Store
}

type createGroupRequest struct {
	Name        string   `json:"name"`
	UserIDs     []string `json:"userIds"`
	PropertyIDs []string `json:"propertyIds"`
}

type updateGroupRequest struct {
	Name        *string   `json:"name,omitempty"`
	UserIDs     *[]string `json:"userIds,omitempty"`
	PropertyIDs *[]string `json:"propertyIds,omitempty"`
}

func (h *GroupsHandler) List(w http.ResponseWriter, r *http.Request) {
	groups, err := h.Store.Groups().List(r.Context())
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "INTERNAL", "internal server error")
		return
	}
	httpx.WriteJSON(w, http.StatusOK, groups)
}

func (h *GroupsHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createGroupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "invalid json")
		return
	}
	if req.Name == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "name is required")
		return
	}
	g := &domain.Group{
		ID:        uuid.NewString(),
		Name:      req.Name,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	if err := h.Store.Groups().Create(r.Context(), g); err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "INTERNAL", "internal server error")
		return
	}
	if len(req.UserIDs) > 0 {
		_ = h.Store.Groups().SetUsers(r.Context(), g.ID, req.UserIDs)
	}
	if len(req.PropertyIDs) > 0 {
		_ = h.Store.Groups().SetProperties(r.Context(), g.ID, req.PropertyIDs)
	}
	g.UserIDs = req.UserIDs
	g.PropertyIDs = req.PropertyIDs
	httpx.WriteJSON(w, http.StatusCreated, g)
}

func (h *GroupsHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	g, err := h.Store.Groups().GetByID(r.Context(), id)
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, g)
}

func (h *GroupsHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	g, err := h.Store.Groups().GetByID(r.Context(), id)
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	var req updateGroupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "invalid json")
		return
	}
	if req.Name != nil {
		g.Name = *req.Name
	}
	if err := h.Store.Groups().Update(r.Context(), g); err != nil {
		httpx.HandleError(w, err)
		return
	}
	if req.UserIDs != nil {
		_ = h.Store.Groups().SetUsers(r.Context(), id, *req.UserIDs)
		g.UserIDs = *req.UserIDs
	}
	if req.PropertyIDs != nil {
		_ = h.Store.Groups().SetProperties(r.Context(), id, *req.PropertyIDs)
		g.PropertyIDs = *req.PropertyIDs
	}
	httpx.WriteJSON(w, http.StatusOK, g)
}

func (h *GroupsHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Store.Groups().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *GroupsHandler) SetUsers(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req struct {
		UserIDs []string `json:"userIds"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "invalid json")
		return
	}
	if err := h.Store.Groups().SetUsers(r.Context(), id, req.UserIDs); err != nil {
		httpx.HandleError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *GroupsHandler) SetProperties(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req struct {
		PropertyIDs []string `json:"propertyIds"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "invalid json")
		return
	}
	if err := h.Store.Groups().SetProperties(r.Context(), id, req.PropertyIDs); err != nil {
		httpx.HandleError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
