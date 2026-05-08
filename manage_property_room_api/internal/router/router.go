package router

import (
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/rs/cors"

	"github.com/jose/manage_property_room_api/internal/auth"
	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/handlers"
	"github.com/jose/manage_property_room_api/internal/httpx"
	"github.com/jose/manage_property_room_api/internal/store"
)

type Deps struct {
	Store       store.Store
	AuthSvc     *auth.Service
	TokenIssuer *auth.TokenIssuer
	CORSOrigins []string
}

func New(d Deps) http.Handler {
	r := chi.NewRouter()

	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))

	corsHandler := cors.New(cors.Options{
		AllowedOrigins:   d.CORSOrigins,
		AllowedMethods:   []string{"GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Authorization", "Content-Type"},
		AllowCredentials: false,
		MaxAge:           300,
	})
	r.Use(corsHandler.Handler)

	authH := &handlers.AuthHandler{Svc: d.AuthSvc, Store: d.Store}
	usersH := &handlers.UsersHandler{Store: d.Store}
	propsH := &handlers.PropertiesHandler{Store: d.Store}
	colsH := &handlers.ColumnsHandler{Store: d.Store}
	cardsH := &handlers.CardsHandler{Store: d.Store}
	fieldsH := &handlers.FieldsHandler{Store: d.Store}
	commentsH := &handlers.CommentsHandler{Store: d.Store}
	activityH := &handlers.ActivityHandler{Store: d.Store}
	archiveH := &handlers.ArchiveHandler{Store: d.Store}
	auditH := &handlers.AuditHandler{Store: d.Store}
	groupsH := &handlers.GroupsHandler{Store: d.Store}

	uploadDir := "/data/uploads"
	baseURL := os.Getenv("BASE_URL")
	if baseURL == "" { baseURL = "http://localhost:8080" }
	uploadH := &handlers.UploadHandler{UploadDir: uploadDir, BaseURL: baseURL}

	// Static file serving (property images)
	r.Get("/static/*", func(w http.ResponseWriter, req *http.Request) {
		http.StripPrefix("/static/", http.FileServer(http.Dir(uploadDir))).ServeHTTP(w, req)
	})

	// Public
	r.Get("/health", handlers.Health)
	r.Post("/auth/login", authH.Login)

	// Authenticated
	r.Group(func(r chi.Router) {
		r.Use(httpx.RequireAuth(d.TokenIssuer))

		r.Post("/auth/refresh", authH.Refresh)
		r.Post("/auth/logout", authH.Logout)
		r.Post("/auth/change-password", authH.ChangePassword)

		r.Get("/me", usersH.Me)

		// File upload (admin/owner only)
		r.Group(func(r chi.Router) {
			r.Use(httpx.RequireRole(domain.RoleAdmin, domain.RoleOwner))
			r.Post("/upload", uploadH.Upload)
		})

		// Users — admin sees/manages all; owner creates supervisors; supervisor creates workers
		r.Group(func(r chi.Router) {
			r.Use(httpx.RequireRole(domain.RoleAdmin, domain.RoleOwner, domain.RoleSupervisor))
			r.Get("/users", usersH.List)
			r.Post("/users", usersH.Create)
		})
		r.Group(func(r chi.Router) {
			// Only admin can update/delete/reset any user
			r.Use(httpx.RequireRole(domain.RoleAdmin))
			r.Patch("/users/{id}", usersH.Update)
			r.Delete("/users/{id}", usersH.Delete)
			r.Post("/users/{id}/reset-password", usersH.ResetPassword)
		})

		// Properties
		r.Get("/properties", propsH.List)
		r.Get("/properties/{id}", propsH.Get)
		r.Get("/properties/{id}/board", propsH.Board)
		r.Get("/properties/{id}/workers", propsH.Workers)
		r.Get("/properties/{id}/supervisors", propsH.GetSupervisors)
		r.Group(func(r chi.Router) {
			// Admin or owner can create/update/delete their properties
			r.Use(httpx.RequireRole(domain.RoleAdmin, domain.RoleOwner))
			r.Post("/properties", propsH.Create)
			r.Patch("/properties/{id}", propsH.Update)
			r.Delete("/properties/{id}", propsH.Delete)
			r.Post("/properties/{id}/assign-workers", propsH.AssignWorkers)
			r.Post("/properties/{id}/assign-supervisors", propsH.AssignSupervisors)			})
			r.Group(func(r chi.Router) {
				// Only admin can reassign property ownership
				r.Use(httpx.RequireRole(domain.RoleAdmin))
				r.Post("/properties/{id}/assign-owner", propsH.AssignOwner)		})

		// Columns — structure mutations require admin or operator
		r.Group(func(r chi.Router) {
			r.Use(httpx.RequireRole(domain.RoleAdmin, domain.RoleOperator))
			r.Post("/columns/reorder", colsH.Reorder)
			r.Post("/properties/{id}/columns", colsH.Create)
			r.Patch("/columns/{id}", colsH.Update)
			r.Delete("/columns/{id}", colsH.Delete)
			r.Post("/columns/{id}/duplicate", colsH.Duplicate)
			r.Post("/columns/{id}/copy-to/{propertyId}", colsH.CopyTo)
			r.Post("/columns/{id}/move", colsH.Move)
			r.Post("/columns/{id}/move-cards-to/{targetId}", colsH.MoveAllCards)
			r.Post("/columns/{id}/archive-all-cards", colsH.ArchiveAllCards)
			r.Post("/columns/{id}/archive", colsH.Archive)
			r.Post("/columns/{id}/config", colsH.SetConfig)
		})

		// Cards
		r.Post("/columns/{id}/cards", cardsH.CreateForColumn)
		r.Get("/cards/{id}", cardsH.Get)
		r.Patch("/cards/{id}", cardsH.Update)
		r.Delete("/cards/{id}", cardsH.Delete)
		r.Post("/cards/{id}/move", cardsH.Move)
		r.Post("/cards/{id}/toggle-done", cardsH.ToggleDone)
		r.Post("/cards/{id}/archive", cardsH.Archive)
		r.Post("/cards/{id}/assign", cardsH.Assign)
		r.Post("/cards/reorder", cardsH.Reorder)

		// Fields (custom field definitions)
		r.Get("/fields", fieldsH.List)
		r.Post("/fields", fieldsH.Create)
		r.Patch("/fields/{id}", fieldsH.Update)
		r.Delete("/fields/{id}", fieldsH.Delete)
		r.Post("/fields/reorder", fieldsH.Reorder)

		// Comments
		r.Get("/cards/{id}/comments", commentsH.List)
		r.Post("/cards/{id}/comments", commentsH.Create)

		// Activity
		r.Get("/cards/{id}/activity", activityH.List)

		// Archive
		r.Get("/archive", archiveH.List)
		r.Post("/archive/{id}/restore", archiveH.Restore)
		r.Delete("/archive/{id}", archiveH.Delete)

// Audit / Notifications — admin sees all, owner sees their properties
			r.Group(func(r chi.Router) {
				r.Use(httpx.RequireRole(domain.RoleAdmin, domain.RoleOwner))
			r.Get("/audit", auditH.List)
		})

		// Groups (admin, supervisor only — owner does not manage groups)
		r.Group(func(r chi.Router) {
			r.Use(httpx.RequireRole(domain.RoleAdmin, domain.RoleSupervisor))
			r.Get("/groups", groupsH.List)
			r.Post("/groups", groupsH.Create)
			r.Get("/groups/{id}", groupsH.Get)
			r.Patch("/groups/{id}", groupsH.Update)
			r.Delete("/groups/{id}", groupsH.Delete)
			r.Put("/groups/{id}/users", groupsH.SetUsers)
			r.Put("/groups/{id}/properties", groupsH.SetProperties)
		})
	})

	return r
}
