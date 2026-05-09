// Package httpx contains HTTP helpers: JSON I/O, error envelope, auth middleware.
package httpx

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"

	"github.com/jose/manage_property_room_api/internal/auth"
	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/store"
)

type ctxKey int

const (
	ctxUserID ctxKey = iota
	ctxRole
	ctxActorName
	ctxActorIP
)

// ── JSON helpers ─────────────────────────────────────────────────────────────

type ErrorEnvelope struct {
	Error ErrorBody `json:"error"`
}

type ErrorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if v == nil {
		return
	}
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("write json: %v", err)
	}
}

func WriteError(w http.ResponseWriter, status int, code, message string) {
	WriteJSON(w, status, ErrorEnvelope{Error: ErrorBody{Code: code, Message: message}})
}

// HandleError maps common errors to HTTP responses.
func HandleError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "resource not found")
	case errors.Is(err, store.ErrConflict):
		WriteError(w, http.StatusConflict, "CONFLICT", "resource already exists")
	case errors.Is(err, auth.ErrInvalidCredentials):
		WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "invalid email or password")
	case errors.Is(err, auth.ErrInvalidToken):
		WriteError(w, http.StatusUnauthorized, "INVALID_TOKEN", "invalid or expired token")
	default:
		log.Printf("internal error: %v", err)
		WriteError(w, http.StatusInternalServerError, "INTERNAL", "internal server error")
	}
}

func DecodeJSON(r *http.Request, v any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	return dec.Decode(v)
}

// ── auth middleware ──────────────────────────────────────────────────────────

// realIP extracts the client IP from a request, respecting X-Forwarded-For.
func realIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return strings.TrimSpace(xri)
	}
	host := r.RemoteAddr
	if h, _, err := splitHostPort(host); err == nil {
		return h
	}
	return host
}

func splitHostPort(hostport string) (string, string, error) {
	for i := len(hostport) - 1; i >= 0; i-- {
		if hostport[i] == ':' {
			return hostport[:i], hostport[i+1:], nil
		}
	}
	return "", "", errors.New("no port in address")
}

func RequireAuth(issuer *auth.TokenIssuer) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h := r.Header.Get("Authorization")
			if !strings.HasPrefix(h, "Bearer ") {
				WriteError(w, http.StatusUnauthorized, "MISSING_TOKEN", "Authorization header missing")
				return
			}
			token := strings.TrimPrefix(h, "Bearer ")
			claims, err := issuer.Parse(token)
			if err != nil {
				WriteError(w, http.StatusUnauthorized, "INVALID_TOKEN", "invalid or expired token")
				return
			}
			ctx := context.WithValue(r.Context(), ctxUserID, claims.UserID)
			ctx = context.WithValue(ctx, ctxRole, claims.Role)
			ctx = context.WithValue(ctx, ctxActorName, claims.ActorName)
			ctx = context.WithValue(ctx, ctxActorIP, realIP(r))
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func RequireRole(roles ...domain.UserRole) func(http.Handler) http.Handler {
	allowed := make(map[domain.UserRole]struct{}, len(roles))
	for _, r := range roles {
		allowed[r] = struct{}{}
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			role, _ := r.Context().Value(ctxRole).(domain.UserRole)
			if _, ok := allowed[role]; !ok {
				WriteError(w, http.StatusForbidden, "FORBIDDEN", "insufficient permissions")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func UserIDFrom(ctx context.Context) string {
	v, _ := ctx.Value(ctxUserID).(string)
	return v
}

func ActorNameFrom(ctx context.Context) string {
	v, _ := ctx.Value(ctxActorName).(string)
	return v
}

func ActorIPFrom(ctx context.Context) string {
	v, _ := ctx.Value(ctxActorIP).(string)
	return v
}

func RoleFrom(ctx context.Context) domain.UserRole {
	v, _ := ctx.Value(ctxRole).(domain.UserRole)
	return v
}
