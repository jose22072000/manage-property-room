package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/jose/manage_property_room_api/internal/auth"
	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type AuthHandler struct {
	Svc   *auth.Service
	Store store.Store
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error())
		return
	}
	if req.Email == "" || req.Password == "" {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "email and password required")
		return
	}
	res, err := h.Svc.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	// Record login event (actor is the just-authenticated user)
	u := res.User
	go func() {
		_ = h.Store.Audit().Create(context.Background(), &domain.AuditEvent{
			ID: uuid.NewString(), ActorID: u.ID, ActorName: u.Name,
			Action: "login", Entity: "user", EntityID: u.ID,
			Detail: u.Email, CreatedAt: time.Now().UTC(),
		})
	}()
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	uid := httpx.UserIDFrom(r.Context())
	res, err := h.Svc.Refresh(r.Context(), uid)
	if err != nil {
		httpx.HandleError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	// Stateless JWT — client discards token. Record audit event for session tracking.
	uid := httpx.UserIDFrom(r.Context())
	actorName := httpx.ActorNameFrom(r.Context())
	if uid != "" {
		go func() {
			_ = h.Store.Audit().Create(context.Background(), &domain.AuditEvent{
				ID: uuid.NewString(), ActorID: uid, ActorName: actorName,
				Action: "logout", Entity: "user", EntityID: uid,
				Detail: "", CreatedAt: time.Now().UTC(),
			})
		}()
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

type changePasswordRequest struct {
	OldPassword string `json:"oldPassword"`
	NewPassword string `json:"newPassword"`
}

func (h *AuthHandler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	var req changePasswordRequest
	if err := httpx.DecodeJSON(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error())
		return
	}
	if len(req.NewPassword) < 6 {
		httpx.WriteError(w, http.StatusBadRequest, "WEAK_PASSWORD", "password must be at least 6 chars")
		return
	}
	uid := httpx.UserIDFrom(r.Context())
	if err := h.Svc.ChangePassword(r.Context(), uid, req.OldPassword, req.NewPassword); err != nil {
		httpx.HandleError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}
