package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/auth"
	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type UsersHandler struct {
	Store store.Store
}

type createUserRequest struct {
	Email               string          `json:"email"`
	Password            string          `json:"password"`
	Name                string          `json:"name"`
	Initials            string          `json:"initials"`
	Role                domain.UserRole `json:"role"`
	AssignedPropertyIDs []string        `json:"assignedPropertyIds"`
}

type updateUserRequest struct {
	Email               *string          `json:"email,omitempty"`
	Name                *string          `json:"name,omitempty"`
	Initials            *string          `json:"initials,omitempty"`
	Role                *domain.UserRole `json:"role,omitempty"`
	AssignedPropertyIDs *[]string        `json:"assignedPropertyIds,omitempty"`
}

type resetPasswordRequest struct {
	NewPassword string `json:"newPassword"`
	MustChange  bool   `json:"mustChange"`
}

func (h *UsersHandler) Me(w http.ResponseWriter, r *http.Request) {
	uid := httpx.UserIDFrom(r.Context())
	u, err := h.Store.Users().GetByID(r.Context(), uid)
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, u)
}

func (h *UsersHandler) List(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	actorID := httpx.UserIDFrom(ctx)
	actorRole := httpx.RoleFrom(ctx)
	var users []domain.User
	var err error
	switch actorRole {
	case domain.RoleOwner:
		// Owner sees their supervisors PLUS the workers each supervisor created.
		supervisors, e := h.Store.Users().ListCreatedBy(ctx, actorID, []domain.UserRole{domain.RoleSupervisor})
		if e != nil { httpx.HandleError(w, e); return }
		users = append(users, supervisors...)
		for _, sup := range supervisors {
			workers, e2 := h.Store.Users().ListCreatedBy(ctx, sup.ID, []domain.UserRole{
				domain.RoleCleaning, domain.RoleMaintenance, domain.RoleOperator,
			})
			if e2 != nil { httpx.HandleError(w, e2); return }
			users = append(users, workers...)
		}
	case domain.RoleSupervisor:
		// Supervisor sees only the workers they created
		users, err = h.Store.Users().ListCreatedBy(ctx, actorID, []domain.UserRole{
			domain.RoleCleaning, domain.RoleMaintenance, domain.RoleOperator,
		})
	default:
		// Admin sees all
		users, err = h.Store.Users().List(ctx)
	}
	if err != nil { httpx.HandleError(w, err); return }
	httpx.WriteJSON(w, http.StatusOK, users)
}

func (h *UsersHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createUserRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Email == "" || req.Password == "" || req.Name == "" || req.Role == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing fields"); return
	}
	actorRole := httpx.RoleFrom(r.Context())
	if !canCreateRole(actorRole, req.Role) {
		httpx.WriteError(w, http.StatusForbidden, "FORBIDDEN", "cannot create that role"); return
	}
	hash, err := auth.HashPassword(req.Password)
	if err != nil { httpx.HandleError(w, err); return }
	actorID := httpx.UserIDFrom(r.Context())
	u := &domain.User{
		ID: uuid.NewString(),
		Email: req.Email, PasswordHash: hash,
		Name: req.Name, Initials: req.Initials,
		Role: req.Role, MustChangePassword: false,
		CreatedBy: actorID,
		AssignedPropertyIDs: req.AssignedPropertyIDs,
	}
	if err := h.Store.Users().Create(r.Context(), u); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "create", "user", u.ID, u.Name)
	httpx.WriteJSON(w, http.StatusCreated, u)
}

func (h *UsersHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	u, err := h.Store.Users().GetByID(r.Context(), id)
	if err != nil { httpx.HandleError(w, err); return }
	var req updateUserRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if req.Email != nil { u.Email = *req.Email }
	if req.Name != nil { u.Name = *req.Name }
	if req.Initials != nil { u.Initials = *req.Initials }
	if req.Role != nil { u.Role = *req.Role }
	if req.AssignedPropertyIDs != nil { u.AssignedPropertyIDs = *req.AssignedPropertyIDs }
	if err := h.Store.Users().Update(r.Context(), u); err != nil {
		httpx.HandleError(w, err); return
	}
	recordAudit(r.Context(), h.Store, "update", "user", u.ID, u.Name)
	httpx.WriteJSON(w, http.StatusOK, u)
}

func (h *UsersHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	u, _ := h.Store.Users().GetByID(r.Context(), id)
	if err := h.Store.Users().Delete(r.Context(), id); err != nil {
		httpx.HandleError(w, err); return
	}
	name := id
	if u != nil { name = u.Name }
	recordAudit(r.Context(), h.Store, "delete", "user", id, name)
	w.WriteHeader(http.StatusNoContent)
}

func (h *UsersHandler) ResetPassword(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req resetPasswordRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error()); return
	}
	if len(req.NewPassword) < 6 {
		httpx.WriteError(w, http.StatusBadRequest, "WEAK_PASSWORD", "password too short"); return
	}
	hash, err := auth.HashPassword(req.NewPassword)
	if err != nil { httpx.HandleError(w, err); return }
	if err := h.Store.Users().SetPasswordHash(r.Context(), id, hash, req.MustChange); err != nil {
		httpx.HandleError(w, err); return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}
